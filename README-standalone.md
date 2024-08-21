# kubernetes单节点安装指引

## 版本信息

```bash
# 操作系统版本: Debian 12
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Debian
Description:	Debian GNU/Linux 12 (bookworm)
Release:	12
Codename:	bookworm

# docker版本: 27.1.2
$ docker version
Client: Docker Engine - Community
 Version:           27.1.2
 API version:       1.46
 Go version:        go1.21.13
 Git commit:        d01f264
 Built:             Mon Aug 12 11:50:58 2024
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          27.1.2
  API version:      1.46 (minimum version 1.24)
  Go version:       go1.21.13
  Git commit:       f9522e5
  Built:            Mon Aug 12 11:50:58 2024
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.7.20
  GitCommit:        8fc6bcff51318944179630522a095cc9dbf9f353
 runc:
  Version:          1.1.13
  GitCommit:        v1.1.13-0-g58aa920
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0

# cri-dockerd版本: 0.3.15
$ cri-dockerd --version
cri-dockerd 0.3.15 (e88b1605)

# kubeadm版本: v1.28.2
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"28", GitVersion:"v1.28.2", GitCommit:"89a4ea3e1e4ddd7f7572286090359983e0387b2f", GitTreeState:"clean", BuildDate:"2023-09-13T09:34:32Z", GoVersion:"go1.20.8", Compiler:"gc", Platform:"linux/amd64"}

# kubernetes版本: v1.28.2
$ kubectl get nodes
NAME       STATUS   ROLES           AGE     VERSION
k8s-demo   Ready    control-plane   3m15s   v1.28.2
```

## 安装docker

- 在所有节点安装docker服务

```bash
# 安装基础软件
apt-get -y update
apt-get install -y sudo wget ca-certificates curl gnupg htop git jq tree
apt-get -y install apt-transport-https ca-certificates curl software-properties-common

# 安装docker-ce
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $(lsb_release -cs) stable"
apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

# 检查docker版本
docker version

# 设置docker参数
# 支持国内dockerhub镜像 文档参见: https://github.com/DaoCloud/public-image-mirror
cat << EOF > /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors": [
      "https://docker.m.daocloud.io"
    ]
}
EOF

# 重启docker服务
systemctl restart docker
systemctl status docker

# 验证docker服务是否正常
docker images

# 拉取测试镜像
docker pull busybox

# 运行测试镜像
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
apt-get -y update
apt-get install -y kubelet kubeadm kubectl
kubeadm version

# 获取kubernetes所需要的镜像
kubeadm config images list --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers
export PAUSE_IMAGE=$(kubeadm config images list --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers | grep pause)

# 注意pause镜像用于配置cri-dockerd的启动参数
# 应该是输出 registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9
echo $PAUSE_IMAGE

# 安装cri-dockerd，用于连接kubernetes和docker
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd-0.3.15.amd64.tgz
tar zxvf cri-dockerd-0.3.15.amd64.tgz 
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

# 查看拉取的镜像
docker images

# 部署前清理旧的安装配置
kubeadm reset -f --cri-socket unix:///var/run/cri-dockerd.sock

# 使用kubeadm初始化kubernetes集群
kubeadm init --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers --cri-socket unix:///var/run/cri-dockerd.sock


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

# 检查节点就绪状态，未安装网路网络组件，节点状态为 NOT READY
kubectl get nodes

# 检查pod状态，coredns状态为Pending
kubectl -n kube-system get pods
NAME                               READY   STATUS    RESTARTS   AGE
coredns-6554b8b87f-5r58j           0/1     Pending   0          2m40s
coredns-6554b8b87f-wcbx7           0/1     Pending   0          2m40s
etcd-k8s-demo                      1/1     Running   0          2m45s
kube-apiserver-k8s-demo            1/1     Running   0          2m45s
kube-controller-manager-k8s-demo   1/1     Running   0          2m48s
kube-proxy-6vtzw                   1/1     Running   0          2m40s
kube-scheduler-k8s-demo            1/1     Running   0          2m45s

# 在k8s-demo节点上安装cilium网络组件
wget https://github.com/cilium/cilium-cli/releases/download/v0.16.16/cilium-linux-amd64.tar.gz
tar zxvf cilium-linux-amd64.tar.gz 
mv cilium /usr/local/bin/
cilium install --set cni.chainingMode=portmap

# 检查cilium部署情况
kubectl -n kube-system get pods

# 检查节点就绪状态
kubectl get nodes
NAME       STATUS   ROLES           AGE     VERSION
k8s-demo   Ready    control-plane   3m15s   v1.28.2

# 设置所有master允许调度pod
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# 测试部署应用到kubernetes集群
# 部署一个nginx应用，并暴露到nodePort31000
kubectl run nginx --image=nginx --image-pull-policy=IfNotPresent --port=80 -l=app=nginx
kubectl create service nodeport nginx --tcp=80:80 --node-port=31000

# 检查pod状态
kubectl get pods,svc

# 检查服务是否可以访问
curl k8s-demo:31000
```
