# 通过kubeadm安装kubernetes高可用集群

- 容器运行时使用docker
- 适用kubernetes版本: v1.24.x以上版本

- [中文](README.md)
- [English](README-EN.md)

## 部署节点信息

hostname     | ip address      | comment   
:---         | :---            | :---      
k8s-master01 | 192.168.0.101   | kubernetes 控制平面主机 master01
k8s-master02 | 192.168.0.102   | kubernetes 控制平面主机 master02
k8s-master03 | 192.168.0.103   | kubernetes 控制平面主机 master03
k8s-vip      | 192.168.0.100   | kubernetes 浮动IP，通过keepalived创建，如果使用公有云请预先申请该浮动IP

```bash
# 各节点请添加主机名解释
cat << EOF >> /etc/hosts
192.168.0.100    k8s-vip
192.168.0.101    k8s-master01
192.168.0.102    k8s-master02
192.168.0.103    k8s-master03
EOF
```

## 架构说明

![](images/kubeadm-ha.png)

- 演示需要，只部署3个高可用的master节点
- 使用keepalived和nginx作为高可用的负载均衡器，通过dorycli命令行工具生成负载均衡器的配置，并通过docker-compose部署负载均衡器
- 容器运行时使用docker，cri-socket使用cri-dockerd连接docker和kubernetes

## 版本信息

```bash
# 操作系统版本: Debian 11
$ lsb_release -a
No LSB modules are available.
Distributor ID:     Debian
Description:        Debian GNU/Linux 11 (bullseye)
Release:            11
Codename:           bullseye

# docker版本: 24.0.5
$ docker version
Client: Docker Engine - Community
 Version:           24.0.5
 API version:       1.43
 Go version:        go1.20.6
 Git commit:        ced0996
 Built:             Fri Jul 21 20:35:45 2023
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          24.0.5
  API version:      1.43 (minimum version 1.12)
  Go version:       go1.20.6
  Git commit:       a61e2b4
  Built:            Fri Jul 21 20:35:45 2023
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.6.22
  GitCommit:        8165feabfdfe38c65b599c4993d227328c231fca
 runc:
  Version:          1.1.8
  GitCommit:        v1.1.8-0-g82f18fe
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0

# cri-dockerd版本: 0.3.4
$ cri-dockerd --version
cri-dockerd 0.3.4 (e88b1605)

# dorycli版本: v1.5.0
$ dorycli version
dorycli version: v1.5.0
install dory-engine version: v2.5.0
install dory-console version: v2.5.0


# kubeadm版本: v1.28.0
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"28", GitVersion:"v1.28.0", GitCommit:"855e7c48de7388eb330da0f8d9d2394ee818fb8d", GitTreeState:"clean", BuildDate:"2023-08-15T10:20:15Z", GoVersion:"go1.20.7", Compiler:"gc", Platform:"linux/amd64"}

# kubernetes版本: v1.28.0
$ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
k8s-master01   Ready    control-plane   35m   v1.28.0
k8s-master02   Ready    control-plane   31m   v1.28.0
k8s-master03   Ready    control-plane   30m   v1.28.0
```

## 安装docker

- 在所有节点安装docker服务

```bash
# 安装基础软件
apt-get update
apt-get install -y sudo wget ca-certificates curl gnupg htop git jq tree

# 安装docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo   "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |   tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

# 检查docker版本
docker version

# 设置docker参数
cat << EOF > /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF

# 重启docker服务
systemctl restart docker
systemctl status docker

# 验证docker服务是否正常
docker images
docker pull busybox
docker run --rm busybox uname -m
```

## 安装kubernetes

- 在所有节点安装kubernetes相关软件

```bash
# 安装kubernetes相关组件
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
kubeadm version

# 获取kubernetes所需要的镜像
kubeadm config images list --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers
export PAUSE_IMAGE=$(kubeadm config images list --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers | grep pause)

# 注意pause镜像用于配置cri-dockerd的启动参数
# 应该是输出 registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9
echo $PAUSE_IMAGE

# 安装cri-dockerd，用于连接kubernetes和docker
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.4/cri-dockerd-0.3.4.amd64.tgz
tar zxvf cri-dockerd-0.3.4.amd64.tgz 
cd cri-dockerd/
mkdir -p /usr/local/bin
install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd

# 创建cri-docker.socket启动文件
cat << EOF > /etc/systemd/system/cri-docker.socket
[Unit]
Description=CRI Docker Socket for the API
PartOf=cri-docker.service

[Socket]
ListenStream=%t/cri-dockerd.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

# 创建cri-docker.service启动文件
# 注意设置pause容器镜像信息 --pod-infra-container-image=$PAUSE_IMAGE
cat << EOF > /etc/systemd/system/cri-docker.service
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target
Requires=cri-docker.socket

[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --pod-infra-container-image=$PAUSE_IMAGE
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# 启动cri-dockerd
systemctl daemon-reload
systemctl enable --now cri-docker.socket
systemctl restart cri-docker
systemctl status cri-docker

# 通过kubeadm预先拉取所需的容器镜像
kubeadm config images pull --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers --cri-socket unix:///var/run/cri-dockerd.sock
docker images
```

- 在k8s-master01节点通过dorycli创建并启动高可用负载均衡器: keepalived, nginx-lb
- dorycli项目地址: [https://github.com/dory-engine/dorycli](https://github.com/dory-engine/dorycli)

```bash
# 安装dorycli
cd /root
wget https://github.com/dory-engine/dorycli/releases/download/v1.5.0/dorycli-v1.5.0-linux-amd64.tgz
tar zxvf dorycli-v1.5.0-linux-amd64.tgz
chmod a+x dorycli
mv dorycli /usr/bin/

# 设置dorycli的自动完成，可以通过键盘TAB键自动补全子命令和参数
dorycli completion bash -h
source <(dorycli completion bash)
dorycli completion bash > /etc/bash_completion.d/dorycli

# 使用dorycli打印高可用负载均衡器配置信息，并保存到kubeadm-ha.yaml
dorycli install ha print --language zh > kubeadm-ha.yaml

# 根据实际情况修改kubeadm-ha.yaml的配置信息
# 可以通过以下命令获取各个主机的网卡名字
ip address

# 本例子的配置如下，请根据实际情况修改配置
cat kubeadm-ha.yaml
# 需要安装的kubernetes的版本
version: "v1.28.0"
# kubernetes的镜像仓库设置，如果不设置，那么使用官方的默认镜像仓库
imageRepository: "registry.cn-hangzhou.aliyuncs.com/google_containers"
# 使用keepalived创建的高可用kubernetes集群的浮动ip地址
virtualIp: 192.168.0.100
# 使用nginx映射的高可用kubernetes集群的apiserver映射端口
virtualPort: 16443
# 浮动ip地址映射的主机名，请在/etc/hosts配置文件中进行主机名映射设置
virtualHostname: k8s-vip
# kubernetes的容器运行时socket
# docker情况下: unix:///var/run/cri-dockerd.sock
# containerd情况下: unix:///var/run/containerd/containerd.sock
# cri-o情况下: unix:///var/run/crio/crio.sock
criSocket: unix:///var/run/cri-dockerd.sock
# kubernetes集群的pod子网地址，如果不设置，使用默认的pod子网地址
podSubnet: "10.244.0.0/24"
# kubernetes集群的service子网地址，如果不设置，使用默认的service子网地址
serviceSubnet: "10.96.0.0/16"
# keepalived的鉴权密码，如果不设置那么使用随机生成的密码
keepAlivedAuthPass: ""
# kubernetes的controlplane控制平面的主机配置，高可用master节点数量必须为单数并且至少3台
masterHosts:
    # master节点的主机名，请在/etc/hosts配置文件中进行主机名映射设置
  - hostname: k8s-master01
    # master节点的IP地址
    ipAddress: 192.168.0.101
    # master节点互访使用的网卡名字，用于keepalived网卡绑定
    networkInterface: eth0
    # keepalived选举优先级，数值越大优先级越高，各个master节点的优先级不能一样
    keepalivedPriority: 120
    # master节点的主机名，请在/etc/hosts配置文件中进行主机名映射设置
  - hostname: k8s-master02
    # master节点的IP地址
    ipAddress: 192.168.0.102
    # master节点互访使用的网卡名字，用于keepalived网卡绑定
    networkInterface: eth0
    # keepalived选举优先级，数值越大优先级越高，各个master节点的优先级不能一样
    keepalivedPriority: 110
    # master节点的主机名，请在/etc/hosts配置文件中进行主机名映射设置
  - hostname: k8s-master03
    # master节点的IP地址
    ipAddress: 192.168.0.103
    # master节点互访使用的网卡名字，用于keepalived网卡绑定
    networkInterface: eth0
    # keepalived选举优先级，数值越大优先级越高，各个master节点的优先级不能一样
    keepalivedPriority: 100

# 通过dorycli创建可用负载均衡器配置信息，并且把生成的配置输出到当前目录
# 执行命名后，会输出生成的文件说明，以及启动配置文件说明
dorycli install ha script -o . -f kubeadm-ha.yaml --language zh

# 查看dorycli生成的kubeadm-config.yaml配置文件，该配置文件用于kubeadm init初始化kubernetes集群用途
# 本例子生成的配置如下:
cat kubeadm-config.yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
apiServer:
  certSANs:
    - "k8s-vip"
    - "192.168.0.100"
    - "k8s-master01"
    - "192.168.0.101"
    - "k8s-master02"
    - "192.168.0.102"
    - "k8s-master03"
    - "192.168.0.103"
controlPlaneEndpoint: "192.168.0.100:16443"
networking:
  podSubnet: "10.244.0.0/24"
  serviceSubnet: "10.96.0.0/16"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///var/run/cri-dockerd.sock

# 设置master节点的kubernetes高可用负载均衡器的文件路径
export LB_DIR=/data/k8s-lb

# 把高可用负载均衡器的文件复制到k8s-master01
ssh k8s-master01 mkdir -p ${LB_DIR}
scp -r k8s-master01/nginx-lb k8s-master01/keepalived root@k8s-master01:${LB_DIR}

# 在 k8s-master01 节点上启动高可用负载均衡器
ssh k8s-master01 "cd ${LB_DIR}/keepalived/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"
ssh k8s-master01 "cd ${LB_DIR}/nginx-lb/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"

# 把高可用负载均衡器的文件复制到k8s-master02
ssh k8s-master02 mkdir -p ${LB_DIR}
scp -r k8s-master02/nginx-lb k8s-master02/keepalived root@k8s-master02:${LB_DIR}

# 在 k8s-master02 节点上启动高可用负载均衡器
ssh k8s-master02 "cd ${LB_DIR}/keepalived/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"
ssh k8s-master02 "cd ${LB_DIR}/nginx-lb/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"

# 把高可用负载均衡器的文件复制到k8s-master03
ssh k8s-master03 mkdir -p ${LB_DIR}
scp -r k8s-master03/nginx-lb k8s-master03/keepalived root@k8s-master03:${LB_DIR}

# 在 k8s-master03 节点上启动高可用负载均衡器
ssh k8s-master03 "cd ${LB_DIR}/keepalived/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"
ssh k8s-master03 "cd ${LB_DIR}/nginx-lb/ && docker-compose stop && docker-compose rm -f && docker-compose up -d"

# 在各个master节点上检验浮动IP是否已经创建，正常情况下浮动IP绑定在 k8s-master01 上
ip address
```

- 初始化高可用kubernetes集群

```bash
# 在k8s-master01上使用kubeadm-config.yaml配置文件初始化高可用集群
kubeadm init --config=kubeadm-config.yaml --upload-certs
# kubeadm init命令将会输出以下提示，使用该提示在其他master节点执行join操作
You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 192.168.0.100:16443 --token tgszyf.c9dicrflqy85juaf \
    --discovery-token-ca-cert-hash sha256:xxx \
    --control-plane --certificate-key xxx

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.0.100:16443 --token tgszyf.c9dicrflqy85juaf \
    --discovery-token-ca-cert-hash sha256:xxx 


  kubeadm join 192.168.0.100:16443 --token tgszyf.c9dicrflqy85juaf \
    --discovery-token-ca-cert-hash sha256:xxx \
    --control-plane --certificate-key xxx

# 在k8s-master02 和 k8s-master03节点上执行以下命令，把k8s-master02 和 k8s-master03加入到高可用kubernetes集群
# 记住kubeadm join命令需要设置--cri-socket unix:///var/run/cri-dockerd.sock
kubeadm join 192.168.0.100:16443 --token tgszyf.c9dicrflqy85juaf \
        --discovery-token-ca-cert-hash sha256:xxx \
        --control-plane --certificate-key xxx --cri-socket unix:///var/run/cri-dockerd.sock

# 在所有master节点上设置kubectl访问kubernetes集群
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 在所有master节点上设置kubectl的自动完成，可以通过键盘TAB键自动补全子命令和参数
kubectl completion -h
kubectl completion bash > ~/.kube/completion.bash.inc
printf "
# Kubectl shell completion
source '$HOME/.kube/completion.bash.inc'
" >> $HOME/.bash_profile
source $HOME/.bash_profile

# 在k8s-master01节点上安装cilium网络组件
wget https://github.com/cilium/cilium-cli/releases/download/v0.15.6/cilium-linux-amd64.tar.gz
tar zxvf cilium-linux-amd64.tar.gz 
mv cilium /usr/local/bin/
cilium install --version 1.14.0 --set cni.chainingMode=portmap

# 设置所有master允许调度pod
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# 检查所有pod状态是否正常
kubectl get pods -A -o wide
NAMESPACE              NAME                                         READY   STATUS    RESTARTS      AGE     IP              NODE           NOMINATED NODE   READINESS GATES
kube-system            cilium-mwvsr                                 1/1     Running   0             21m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            cilium-operator-b4dfbf784-zgr7v              1/1     Running   0             21m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            cilium-v27l2                                 1/1     Running   0             21m     192.168.0.103   k8s-master03   <none>           <none>
kube-system            cilium-zbcdj                                 1/1     Running   0             21m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            coredns-6554b8b87f-kp7tn                     1/1     Running   0             30m     10.0.2.231      k8s-master03   <none>           <none>
kube-system            coredns-6554b8b87f-zlhgx                     1/1     Running   0             30m     10.0.2.197      k8s-master03   <none>           <none>
kube-system            etcd-k8s-master01                            1/1     Running   0             30m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            etcd-k8s-master02                            1/1     Running   0             26m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            etcd-k8s-master03                            1/1     Running   0             25m     192.168.0.103   k8s-master03   <none>           <none>
kube-system            kube-apiserver-k8s-master01                  1/1     Running   0             30m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            kube-apiserver-k8s-master02                  1/1     Running   0             26m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            kube-apiserver-k8s-master03                  1/1     Running   1 (25m ago)   25m     192.168.0.103   k8s-master03   <none>           <none>
kube-system            kube-controller-manager-k8s-master01         1/1     Running   1 (26m ago)   30m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            kube-controller-manager-k8s-master02         1/1     Running   0             26m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            kube-controller-manager-k8s-master03         1/1     Running   0             24m     192.168.0.103   k8s-master03   <none>           <none>
kube-system            kube-proxy-gr2pt                             1/1     Running   0             26m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            kube-proxy-rkb9b                             1/1     Running   0             30m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            kube-proxy-rvmv4                             1/1     Running   0             25m     192.168.0.103   k8s-master03   <none>           <none>
kube-system            kube-scheduler-k8s-master01                  1/1     Running   1 (26m ago)   30m     192.168.0.101   k8s-master01   <none>           <none>
kube-system            kube-scheduler-k8s-master02                  1/1     Running   0             26m     192.168.0.102   k8s-master02   <none>           <none>
kube-system            kube-scheduler-k8s-master03                  1/1     Running   0             23m     192.168.0.103   k8s-master03   <none>           <none>

# 检查所有节点状态是否正常
kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
k8s-master01   Ready    control-plane   31m   v1.28.0
k8s-master02   Ready    control-plane   27m   v1.28.0
k8s-master03   Ready    control-plane   26m   v1.28.0

# 测试部署应用到kubernetes集群
# 部署一个nginx应用，并暴露到nodePort31000
kubectl run nginx --image=nginx:1.23.1-alpine --image-pull-policy=IfNotPresent --port=80 -l=app=nginx
kubectl create service nodeport nginx --tcp=80:80 --node-port=31000
curl k8s-vip:31000
```

## [可选] 安装管理界面 kubernetes-dashboard

- 为了管理kubernetes中部署的应用，推荐使用`kubernetes-dashboard`
- 要了解更多，请阅读官方代码仓库README.md文档: [kubernetes-dashboard](https://github.com/kubernetes/dashboard)

- 安装:
```shell script
# 安装 kubernetes-dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.1/aio/deploy/recommended.yaml

# 调整kubernetes-dashboard服务使用nodePort暴露端口
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8443
    nodePort: 30000
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
EOF

# 创建管理员serviceaccount
kubectl create serviceaccount -n kube-system admin-user --dry-run=client -o yaml | kubectl apply -f -

# 创建管理员clusterrolebinding
kubectl create clusterrolebinding admin-user --clusterrole=cluster-admin --serviceaccount=kube-system:admin-user --dry-run=client -o yaml | kubectl apply -f -

# 手动创建serviceaccount的secret
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-secret
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF

# 获取kubernetes管理token
kubectl -n kube-system get secret admin-user-secret -o jsonpath='{ .data.token }' | base64 -d

# 使用浏览器访问kubernetes-dashboard: https://k8s-vip:30000
# 使用kubernetes管理token登录kubernetes-dashboard
```

## [可选] 安装ingress控制器 traefik

- 要使用kubernetes的[ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)功能，必须安装ingress controller，推荐使用`traefik`
- 要了解更多，请阅读官方网站文档: [traefik](https://doc.traefik.io/traefik/)

- 在kubernetes所有master节点部署traefik: 
```shell script
# 拉取 traefik helm repo
helm repo add traefik https://helm.traefik.io/traefik
helm fetch traefik/traefik --untar

# 以daemonset方式部署traefik
cat << EOF > traefik.yaml
deployment:
  kind: DaemonSet
image:
  name: traefik
  tag: v2.6.3
pilot:
  enabled: true
experimental:
  plugins:
    enabled: true
ports:
  web:
    hostPort: 80
  websecure:
    hostPort: 443
service:
  type: ClusterIP
EOF

# 安装traefik
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -
helm install -n traefik traefik traefik/ -f traefik.yaml

# 检查安装情况
helm -n traefik list
kubectl -n traefik get pods -o wide
kubectl -n traefik get services -o wide

# 检验traefik安装是否成功，如果输出 404 page not found 表示成功
curl k8s-vip
curl -k https://k8s-vip
```

## [可选] 安装性能数据采集工具 metrics-server

- 为了使用kubernetes的水平扩展缩容功能[horizontal pod autoscale](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)，必须安装`metrics-server`
- 要了解更多，请阅读官方代码仓库README.md文档: [metrics-server](https://github.com/kubernetes-sigs/metrics-server)

```shell script
# 拉取镜像
docker pull registry.aliyuncs.com/google_containers/metrics-server:v0.6.1
docker tag registry.aliyuncs.com/google_containers/metrics-server:v0.6.1 k8s.gcr.io/metrics-server/metrics-server:v0.6.1

# 获取metrics-server安装yaml
curl -O -L https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.1/components.yaml
# 添加--kubelet-insecure-tls参数
sed -i 's/- args:/- args:\n        - --kubelet-insecure-tls/g' components.yaml
# 安装metrics-server
kubectl apply -f components.yaml

# 等待metrics-server正常
kubectl -n kube-system get pods -l=k8s-app=metrics-server

# 查看节点的metrics
kubectl top nodes
NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
k8s-master01   146m         7%     2284Mi          59%       
k8s-master02   123m         6%     2283Mi          59%       
k8s-master03   114m         5%     2180Mi          57%       
```

- 安装metrics-server后kubernetes-dashboard也可以显示性能数据

![](images/kubernetes-dashboard.png)

## [可选] 安装服务网格 istio

- 要使用服务网格的混合灰度发布能力，需要部署istio服务网格
- 要了解更多，请阅读istio官网文档: [istio.io](https://istio.io/latest/docs/)

```shell script
# 安装istioctl，客户端下载地址 https://github.com/istio/istio/releases/tag/1.18.2

# 下载并安装istioctl
wget https://github.com/istio/istio/releases/download/1.18.2/istioctl-1.18.2-linux-amd64.tar.gz
tar zxvf istioctl-1.18.2-linux-amd64.tar.gz
mv istioctl /usr/bin/

# 确认istioctl版本
istioctl version

# 使用istioctl部署istio到kubernetes
istioctl install --set profile=demo \
--set values.gateways.istio-ingressgateway.type=ClusterIP \
--set values.global.imagePullPolicy=IfNotPresent \
--set values.global.proxy_init.resources.limits.cpu=100m \
--set values.global.proxy_init.resources.limits.memory=100Mi \
--set values.global.proxy.resources.limits.cpu=100m \
--set values.global.proxy.resources.limits.memory=100Mi

# 检查istio部署情况
kubectl -n istio-system get pods,svc
```

## [可选] 应用上云引擎 Dory-Engine

[🚀🚀🚀 Dory-Engine平台工程最佳实践 (https://www.bilibili.com/video/BV1oM4y117Pj/)](https://www.bilibili.com/video/BV1oM4y117Pj/)

![](images/what-is-dory.png)

- `Dory-Engine` 是一个非常简单的应用上云引擎，开发人员不用学、不用写、不用配就可以自行把自己编写的程序从源代码，编译、打包、部署到各类k8s环境或者主机环境中。

1. 不用学: 不需要学习如何编写复杂的上云脚本和如何部署应用到k8s，所有配置都所见即所得一看就懂
2. 不用写: 不需要编写复杂的构建、打包、部署的上云脚本，也不需要编写复杂的k8s应用部署文件，只需要几项简单的配置就可以设置好自己的上云流水线
3. 不用配: 不需要配置各个DevOps工具链和k8s环境如何互相配合完成应用上云，项目一开通所有工具链和环境自动完成配置

- 安装指引参见: [https://github.com/dory-engine/dorycli](https://github.com/dory-engine/dorycli)

[🚀🚀🚀 使用dorycli安装部署Dory-Engine (https://www.bilibili.com/video/BV1x94y167T5/)](https://www.bilibili.com/video/BV1x94y167T5/)
