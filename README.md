# kubeadm-highavailiability - kubernetes high availiability deployment based on kubeadm, for Kubernetes version 1.9.x/1.7.x/1.6.x

![k8s logo](images/v1.6-v1.7/Kubernetes.png)

- [中文文档(for v1.9.x版本)](README_CN.md)
- [English document(for v1.9.x version)](README.md)
- [中文文档(for v1.7.x版本)](v1.6-v1.7/README_CN.md)
- [English document(for v1.7.x version)](v1.6-v1.7/README.md)
- [中文文档(for v1.6.x版本)](v1.6-v1.7/README_v1.6.x_CN.md)
- [English document(for v1.6.x version)](v1.6-v1.7/README_v1.6.x.md)

---

- [GitHub project URL](https://github.com/cookeem/kubeadm-ha/)
- [OSChina project URL](https://git.oschina.net/cookeem/kubeadm-ha/)

---

- This operation instruction is for version v1.9.x kubernetes cluster

> Before v1.9.0 kubeadm still not support high availability deployment, so it's not recommend for production usage. But from v1.9.0, kubeadm support high availability deployment officially, this instruction version for at least v1.9.0.

### category

1. [deployment architecture](#deployment-architecture)
    1. [deployment architecture summary](#deployment-architecture-summary)
    1. [detail deployment architecture](#detail-deployment-architecture)
    1. [hosts list](#hosts-list)
    1. [ports list](#ports-list)
1. [prerequisites](#prerequisites)
    1. [version info](#version-info)
    1. [required docker images](#required-docker-images)
    1. [system configuration](#system-configuration)
1. [kubernetes installation](#kubernetes-installation)
    1. [kubernetes and related services installation](#kubernetes-and-related-services-installation)
1. [configuration files settings](#configuration-files-settings)
    1. [script files settings](#script-files-settings) 
    1. [deploy independent etcd cluster](#deploy-independent-etcd-cluster)
1. [use kubeadm to init first master](#use-kubeadm-to-init-first-master)
    1. [kubeadm init](#kubeadm-init)
    1. [basic components installation](#basic-components-installation)
1. [kubernetes masters high avialiability configuration](#kubernetes-masters-high-avialiability-configuration)
    1. [copy configuration files](#copy-configuration-files)
    1. [other master nodes init](#other-master-nodes-init)
    1. [keepalived installation](#keepalived-installation)
    1. [nginx load balancer configuration](#nginx-load-balancer-configuration)
    1. [kube-proxy configuration](#kube-proxy-configuration)
1. [all nodes join the kubernetes cluster](#all-nodes-join-the-kubernetes-cluster)
    1. [use kubeadm to join the cluster](#use-kubeadm-to-join-the-cluster)
    

### deployment architecture

#### deployment architecture summary

![ha logo](images/v1.6-v1.7/ha.png)

---

[category](#category)

#### detail deployment architecture

![k8s ha](images/v1.6-v1.7/k8s-ha.png)

* kubernetes components:

> kube-apiserver: exposes the Kubernetes API. It is the front-end for the Kubernetes control plane. It is designed to scale horizontally – that is, it scales by deploying more instances.

> etcd: is used as Kubernetes’ backing store. All cluster data is stored here. Always have a backup plan for etcd’s data for your Kubernetes cluster.


> kube-scheduler: watches newly created pods that have no node assigned, and selects a node for them to run on.


> kube-controller-manager: runs controllers, which are the background threads that handle routine tasks in the cluster. Logically, each controller is a separate process, but to reduce complexity, they are all compiled into a single binary and run in a single process.

> kubelet: is the primary node agent. It watches for pods that have been assigned to its node (either by apiserver or via local configuration file)

> kube-proxy: enables the Kubernetes service abstraction by maintaining network rules on the host and performing connection forwarding.


* load balancer

> keepalived cluster config a virtual IP address (192.168.20.10), this virtual IP address point to devops-master01, devops-master02, devops-master03. 

> nginx service as the load balancer of devops-master01, devops-master02, devops-master03's apiserver. The other nodes kubernetes services connect the keepalived virtual ip address (192.168.20.10) and nginx exposed port (16443) to communicate with the master cluster's apiservers. 

---

[category](#category)

#### hosts list

HostName | IPAddress | Notes | Components 
:--- | :--- | :--- | :---
devops-master01 ~ 03 | 192.168.20.27 ~ 29 | master nodes * 3 | keepalived, nginx, etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy, kube-dashboard, heapster, calico
N/A | 192.168.20.10 | keepalived virtual IP | N/A
devops-node01 ~ 04 | 192.168.20.17 ~ 20 | worker nodes * 4 | kubelet, kube-proxy

#### ports list

- master ports list

Protocol | Direction | Port | Comment
:--- | :--- | :--- | :---
TCP | Inbound | 16443*    | Load balancer Kubernetes API server port
TCP | Inbound | 6443*     | Kubernetes API server
TCP | Inbound | 2379-2380 | etcd server client API
TCP | Inbound | 10250     | Kubelet API
TCP | Inbound | 10251     | kube-scheduler
TCP | Inbound | 10252     | kube-controller-manager
TCP | Inbound | 10255     | Read-only Kubelet API

- worker ports list

Protocol | Direction | Port | Comment
:--- | :--- | :--- | :---
TCP | Inbound | 10250       | Kubelet API
TCP | Inbound | 10255       | Read-only Kubelet API
TCP | Inbound | 30000-32767 | NodePort Services**

---

[category](#category)

### 安装前准备

#### 版本信息

* Linux版本：CentOS 7.4.1708

```
$ cat /etc/redhat-release 
CentOS Linux release 7.4.1708 (Core) 
```

* docker版本：17.12.0-ce-rc2

```
$ docker version
Client:
 Version:   17.12.0-ce-rc2
 API version:   1.35
 Go version:    go1.9.2
 Git commit:    f9cde63
 Built: Tue Dec 12 06:42:20 2017
 OS/Arch:   linux/amd64

Server:
 Engine:
  Version:  17.12.0-ce-rc2
  API version:  1.35 (minimum version 1.12)
  Go version:   go1.9.2
  Git commit:   f9cde63
  Built:    Tue Dec 12 06:44:50 2017
  OS/Arch:  linux/amd64
  Experimental: false
```

* kubeadm版本：v1.9.1

```
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"9", GitVersion:"v1.9.1", GitCommit:"3a1c9449a956b6026f075fa3134ff92f7d55f812", GitTreeState:"clean", BuildDate:"2018-01-04T11:40:06Z", GoVersion:"go1.9.2", Compiler:"gc", Platform:"linux/amd64"}
```

* kubelet版本：v1.9.1

```
$ kubelet --version
Kubernetes v1.9.1
```

* 网络组件

> flannel

> calico

---

[category](#category)

#### 所需docker镜像

* 相关docker镜像以及版本

```
$ docker pull quay.io/calico/kube-controllers:v2.0.0
$ docker pull quay.io/calico/node:v3.0.1
$ docker pull quay.io/calico/cni:v2.0.0
$ docker pull quay.io/coreos/flannel:v0.9.1-amd64
$ docker pull gcr.io/google_containers/heapster-amd64:v1.4.2
$ docker pull gcr.io/google_containers/heapster-grafana-amd64:v4.4.3
$ docker pull gcr.io/google_containers/heapster-influxdb-amd64:v1.3.3
$ docker pull gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.7
$ docker pull gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.7
$ docker pull gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.7
$ docker pull gcr.io/google_containers/kube-apiserver-amd64:v1.9.1
$ docker pull gcr.io/google_containers/kube-controller-manager-amd64:v1.9.1
$ docker pull gcr.io/google_containers/kube-proxy-amd64:v1.9.1
$ docker pull gcr.io/google_containers/kube-scheduler-amd64:v1.9.1
$ docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.8.1
$ docker pull nginx
```

---

[category](#category)

#### 系统设置

* 在所有kubernetes节点上增加kubernetes仓库 

```
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```

* 在所有kubernetes节点上进行系统更新

```
$ yum update -y
```

* 在所有kubernetes节点上关闭防火墙

```
$ systemctl disable firewalld && systemctl stop firewalld && systemctl status firewalld
```

* 在所有kubernetes节点上设置SELINUX为permissive模式

```
$ vi /etc/selinux/config
SELINUX=permissive

$ setenforce 0
```

* 在所有kubernetes节点上设置iptables参数，否则kubeadm init会提示错误

```
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

* 在所有kubernetes节点上禁用swap

```
$ swapoff -a

# 禁用fstab中的swap项目
$ vi /etc/fstab
#/dev/mapper/centos-swap swap                    swap    defaults        0 0

# 确认swap已经被禁用
$ cat /proc/swaps
Filename                Type        Size    Used    Priority
```

* 在所有kubernetes节点上重启主机

```
$ reboot
```

---

[category](#category)

### kubernetes安装

#### kubernetes相关服务安装

* 在所有kubernetes节点上验证SELINUX模式，必须保证SELINUX为permissive模式，否则kubernetes启动会出现各种异常

```
$ getenforce
Permissive
```

* 在所有kubernetes节点上安装并启动kubernetes 

```
$ yum install -y docker-ce-17.12.0.ce-0.2.rc2.el7.centos.x86_64
$ yum install -y docker-compose-1.9.0-5.el7.noarch
$ systemctl enable docker && systemctl start docker

$ yum install -y kubelet-1.9.1-0.x86_64 kubeadm-1.9.1-0.x86_64 kubectl-1.9.1-0.x86_64
$ systemctl enable kubelet && systemctl start kubelet
```

* 在所有kubernetes节点上设置kubelet使用cgroupfs，与dockerd保持一致，否则kubelet会启动报错

```
# 默认kubelet使用的cgroup-driver=systemd，改为cgroup-driver=cgroupfs
$ vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"

# 重设kubelet服务，并重启kubelet服务
$ systemctl daemon-reload && systemctl restart kubelet
```

* 在所有master节点上安装并启动keepalived

```
$ yum install -y keepalived
$ systemctl enable keepalived && systemctl restart keepalived
```

---

[category](#category)

### 配置文件初始化

#### 初始化脚本配置

* 在所有master节点上获取代码，并进入代码category

```
$ git clone https://github.com/cookeem/kubeadm-ha

$ cd kubeadm-ha
```

* 在所有master节点上设置初始化脚本配置，每一项配置参见脚本中的配置说明，请务必正确配置。该脚本用于生成相关重要的配置文件

```
$ vi create-config.sh

# local machine ip address
export K8SHA_IPLOCAL=192.168.20.27

# local machine etcd name, options: etcd1, etcd2, etcd3
export K8SHA_ETCDNAME=etcd1

# local machine keepalived state config, options: MASTER, BACKUP. One keepalived cluster only one MASTER, other's are BACKUP
export K8SHA_KA_STATE=MASTER

# local machine keepalived priority config, options: 102, 101, 100. MASTER must 102
export K8SHA_KA_PRIO=102

# local machine keepalived network interface name config, for example: eth0
export K8SHA_KA_INTF=nm-bond

#######################################
# all masters settings below must be same
#######################################

# master keepalived virtual ip address
export K8SHA_IPVIRTUAL=192.168.20.10

# master01 ip address
export K8SHA_IP1=192.168.20.27

# master02 ip address
export K8SHA_IP2=192.168.20.28

# master03 ip address
export K8SHA_IP3=192.168.20.29

# master01 hostname
export K8SHA_HOSTNAME1=devops-master01

# master02 hostname
export K8SHA_HOSTNAME2=devops-master02

# master03 hostname
export K8SHA_HOSTNAME3=devops-master03

# keepalived auth_pass config, all masters must be same
export K8SHA_KA_AUTH=4cdf7dc3b4c90194d1600c483e10ad1d

# kubernetes cluster token, you can use 'kubeadm token generate' to get a new one
export K8SHA_TOKEN=7f276c.0741d82a5337f526

# kubernetes CIDR pod subnet, if CIDR pod subnet is "10.244.0.0/16" please set to "10.244.0.0\\/16"
export K8SHA_CIDR=10.244.0.0\\/16

# calico network settings, set a reachable ip address for the cluster network interface, for example you can use the gateway ip address
export K8SHA_CALICO_REACHABLE_IP=192.168.20.1
```

* 在所有master节点上运行配置脚本，创建对应的配置文件，配置文件包括:

> etcd集群docker-compose.yaml文件

> keepalived配置文件

> nginx负载均衡集群docker-compose.yaml文件

> kubeadm init 配置文件

> calico配置文件

```
$ ./create-config.sh
set etcd cluster docker-compose.yaml file success: etcd/docker-compose.yaml
set keepalived config file success: /etc/keepalived/keepalived.conf
set nginx load balancer config file success: nginx-lb/nginx-lb.conf
set kubeadm init config file success: kubeadm-init.yaml
set calico deployment config file success: kube-calico/calico.yaml
```

---

[category](#category)

#### 独立etcd集群部署

* 在所有master节点上重置并启动etcd集群（非TLS模式）

```
# 重置kubernetes集群
$ kubeadm reset

# 清空etcd集群数据
$ rm -rf /var/lib/etcd-cluster

# 重置并启动etcd集群
$ docker-compose --file etcd/docker-compose.yaml stop
$ docker-compose --file etcd/docker-compose.yaml rm -f
$ docker-compose --file etcd/docker-compose.yaml up -d

# 验证etcd集群状态是否正常

$ docker exec -ti etcd etcdctl cluster-health
member 531504c79088f553 is healthy: got healthy result from http://192.168.20.29:2379
member 56c53113d5e1cfa3 is healthy: got healthy result from http://192.168.20.27:2379
member 7026e604579e4d64 is healthy: got healthy result from http://192.168.20.28:2379
cluster is healthy

$ docker exec -ti etcd etcdctl member list
531504c79088f553: name=etcd3 peerURLs=http://192.168.20.29:2380 clientURLs=http://192.168.20.29:2379,http://192.168.20.29:4001 isLeader=false
56c53113d5e1cfa3: name=etcd1 peerURLs=http://192.168.20.27:2380 clientURLs=http://192.168.20.27:2379,http://192.168.20.27:4001 isLeader=false
7026e604579e4d64: name=etcd2 peerURLs=http://192.168.20.28:2380 clientURLs=http://192.168.20.28:2379,http://192.168.20.28:4001 isLeader=true
```

---

[category](#category)

### 第一台master初始化

#### kubeadm初始化

* 在所有master节点上重置网络

```
$ systemctl stop kubelet
$ systemctl stop docker
$ rm -rf /var/lib/cni/
$ rm -rf /var/lib/kubelet/*
$ rm -rf /etc/cni/

# 删除遗留的网络接口
$ ip a | grep -E 'docker|flannel|cni'
$ ip link del docker0
$ ip link del flannel.1
$ ip link del cni0

$ systemctl restart docker && systemctl restart kubelet
$ ip a | grep -E 'docker|flannel|cni'
```

* 在devops-master01上进行初始化，注意，务必把输出的kubeadm join --token XXX --discovery-token-ca-cert-hash YYY 信息记录下来，后续操作需要用到

```
$ kubeadm init --config=kubeadm-init.yaml
...
  kubeadm join --token 7f276c.0741d82a5337f526 192.168.20.27:6443 --discovery-token-ca-cert-hash sha256:a4a1eaf725a0fc67c3028b3063b92e6af7f2eb0f4ae028f12b3415a6fd2d2a5e
```

* 在所有master节点上设置kubectl客户端连接

```
$ vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

$ source ~/.bashrc
```

#### 安装基础组件

* 在devops-master01上安装flannel网络组件

```
# 没有网络组件的情况下，节点状态是不正常的
$ kubectl get node
NAME              STATUS    ROLES     AGE       VERSION
devops-master01   NotReady  master    14s       v1.9.1

# 安装flannel网络组件
$ kubectl apply -f kube-flannel/
clusterrole "flannel" created
clusterrolebinding "flannel" created
serviceaccount "flannel" created
configmap "kube-flannel-cfg" created
daemonset "kube-flannel-ds" created

# 等待所有pods正常
$ kubectl get pods --all-namespaces -o wide -w
```

* 在devops-master01上安装calico网络组件

```
# 设置master节点为schedulable
$ kubectl taint nodes --all node-role.kubernetes.io/master-

# 安装calico网络组件
$ kubectl apply -f kube-calico/
configmap "calico-config" created
secret "calico-etcd-secrets" created
daemonset "calico-node" created
deployment "calico-kube-controllers" created
serviceaccount "calico-kube-controllers" created
serviceaccount "calico-node" created
clusterrole "calico-kube-controllers" created
clusterrolebinding "calico-kube-controllers" created
clusterrole "calico-node" created
clusterrolebinding "calico-node" created
```

* 在devops-master01上安装dashboard

```
$ kubectl apply -f kube-dashboard/
serviceaccount "admin-user" created
clusterrolebinding "admin-user" created
secret "kubernetes-dashboard-certs" created
serviceaccount "kubernetes-dashboard" created
role "kubernetes-dashboard-minimal" created
rolebinding "kubernetes-dashboard-minimal" created
deployment "kubernetes-dashboard" created
service "kubernetes-dashboard" created

$ kubectl get pods --all-namespaces
NAMESPACE       NAME                                        READY     STATUS    RESTARTS   AGE
kube-system     calico-kube-controllers-7749c84f4-p8c4d     1/1       Running   0          3m
kube-system     calico-node-2jlwj                           2/2       Running   6          13m
kube-system     kube-apiserver-devops-master01              1/1       Running   6          5m
kube-system     kube-controller-manager-devops-master01     1/1       Running   8          5m
kube-system     kube-dns-6f4fd4bdf-8jnpc                    3/3       Running   3          4m
kube-system     kube-flannel-ds-2fgsw                       1/1       Running   8          14m
kube-system     kube-proxy-7rh8x                            1/1       Running   3          13m
kube-system     kube-scheduler-devops-master01              1/1       Running   8          5m
kube-system     kubernetes-dashboard-87497878f-p6nj4        1/1       Running   0          4m
```

* 通过浏览器访问dashboard地址

> https://devops-master01:30000/#!/login

* dashboard登录页面效果如下图

![dashboard-login](images/dashboard-login.png)

* 获取token，把token粘贴到login页面的token中，即可进入dashboard

```
$ kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

![dashboard](images/dashboard.png)

* 在devops-master01上安装heapster

```
$ kubectl apply -f kube-heapster/influxdb/
service "monitoring-grafana" created
serviceaccount "heapster" created
deployment "heapster" created
service "heapster" created
deployment "monitoring-influxdb" created
service "monitoring-influxdb" created

$ kubectl apply -f kube-heapster/rbac/
clusterrolebinding "heapster" created

$ kubectl get pods --all-namespaces 
NAME                                      READY     STATUS        RESTARTS   AGE
calico-kube-controllers-7749c84f4-p8c4d   1/1       Running       0          8m
calico-node-2jlwj                         2/2       Running       6          13d
heapster-698c5f45bd-wnv6x                 1/1       Running       0          1m
kube-apiserver-devops-master01            1/1       Running       6          5d
kube-controller-manager-devops-master01   1/1       Running       8          5d
kube-dns-6f4fd4bdf-8jnpc                  3/3       Running       3          4h
kube-flannel-ds-2fgsw                     1/1       Running       8          14d
kube-proxy-7rh8x                          1/1       Running       3          13d
kube-scheduler-devops-master01            1/1       Running       8          5d
kubernetes-dashboard-87497878f-p6nj4      1/1       Running       0          4h
monitoring-grafana-5ffb49ff84-xxwzn       1/1       Running       0          1m
monitoring-influxdb-5b77d47fdd-wd7xm      1/1       Running       0          1m

# 等待5分钟
kubectl top pod --all-namespaces
NAMESPACE     NAME                                      CPU(cores)   MEMORY(bytes)   
kube-system   calico-kube-controllers-d987c6db5-zjxnv   0m           20Mi            
kube-system   calico-node-hmdlg                         16m          83Mi            
kube-system   heapster-dfd674df9-hct67                  1m           24Mi            
kube-system   kube-apiserver-devops-master01            24m          240Mi           
kube-system   kube-controller-manager-devops-master01   14m          50Mi            
kube-system   kube-dns-6f4fd4bdf-zg66x                  1m           49Mi            
kube-system   kube-flannel-ds-h7ng4                     6m           33Mi            
kube-system   kube-proxy-mxcwz                          2m           29Mi            
kube-system   kube-scheduler-devops-master01            5m           22Mi            
kube-system   kubernetes-dashboard-7b7b5cd79b-6ldfn     0m           20Mi            
kube-system   monitoring-grafana-76848b566c-h5998       0m           28Mi            
kube-system   monitoring-influxdb-6c4b84d695-whzmp      1m           24Mi            
```

* 访问dashboard地址，等10分钟，就会显示性能数据

> https://devops-master01:30000/#!/login

![heapster-dashboard](images/heapster-dashboard.png)

![heapster](images/heapster.png)

* 至此，第一台master成功安装，并已经完成flannel, calico, dashboard, heapster的部署

---

[category](#category)

### master集群高可用设置

#### 复制配置

* 在devops-master01上复制category/etc/kubernetes/pki到devops-master02, devops-master03，从v1.9.x开始，kubeadm会检测pkicategory是否有证书，如果已经存在证书则跳过证书生成的步骤

```
scp -r /etc/kubernetes/pki devops-master02:/etc/kubernetes/

scp -r /etc/kubernetes/pki devops-master03:/etc/kubernetes/
```

---
[category](#category)

#### 其余master节点初始化

* 在devops-master02进行初始化

```
# 输出的token和discovery-token-ca-cert-hash应该与devops-master01上的完全一致
$ kubeadm init --config=kubeadm-init.yaml
...
  kubeadm join --token 7f276c.0741d82a5337f526 192.168.20.28:6443 --discovery-token-ca-cert-hash sha256:a4a1eaf725a0fc67c3028b3063b92e6af7f2eb0f4ae028f12b3415a6fd2d2a5e
```

* 在devops-master03进行初始化

```
# 输出的token和discovery-token-ca-cert-hash应该与devops-master01上的完全一致
$ kubeadm init --config=kubeadm-init.yaml
...
  kubeadm join --token 7f276c.0741d82a5337f526 192.168.20.29:6443 --discovery-token-ca-cert-hash sha256:a4a1eaf725a0fc67c3028b3063b92e6af7f2eb0f4ae028f12b3415a6fd2d2a5e
```

* 在devops-master01上检查nodes加入情况

```
$ kubectl get nodes
NAME              STATUS    ROLES     AGE       VERSION
devops-master01   Ready     master    19m       v1.9.1
devops-master02   Ready     master    4m        v1.9.1
devops-master03   Ready     master    4m        v1.9.1
```

* 在所有master上增加apiserver的apiserver-count设置

```
$ vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --apiserver-count=3

# 重启服务
$ systemctl restart docker && systemctl restart kubelet
```

* 在devops-master01上检查高可用状态

```
$ kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                      READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   calico-kube-controllers-d987c6db5-zjxnv   1/1       Running   2          14m       192.168.20.27   devops-master01
kube-system   calico-node-dldxz                         2/2       Running   2          3m        192.168.20.29   devops-master03
kube-system   calico-node-hmdlg                         2/2       Running   4          14m       192.168.20.27   devops-master01
kube-system   calico-node-tkbbx                         2/2       Running   2          3m        192.168.20.28   devops-master02
kube-system   heapster-dfd674df9-hct67                  1/1       Running   2          11m       10.244.172.11   devops-master01
kube-system   kube-apiserver-devops-master01            1/1       Running   1          2m        192.168.20.27   devops-master01
kube-system   kube-apiserver-devops-master02            1/1       Running   1          2m        192.168.20.28   devops-master02
kube-system   kube-apiserver-devops-master03            1/1       Running   0          24s       192.168.20.29   devops-master03
kube-system   kube-controller-manager-devops-master01   1/1       Running   2          15m       192.168.20.27   devops-master01
kube-system   kube-controller-manager-devops-master02   1/1       Running   1          2m        192.168.20.28   devops-master02
kube-system   kube-controller-manager-devops-master03   1/1       Running   1          2m        192.168.20.29   devops-master03
kube-system   kube-dns-6f4fd4bdf-zg66x                  3/3       Running   6          16m       10.244.172.13   devops-master01
kube-system   kube-flannel-ds-6njgf                     1/1       Running   1          3m        192.168.20.29   devops-master03
kube-system   kube-flannel-ds-g24ww                     1/1       Running   1          3m        192.168.20.28   devops-master02
kube-system   kube-flannel-ds-h7ng4                     1/1       Running   2          16m       192.168.20.27   devops-master01
kube-system   kube-proxy-2kk8s                          1/1       Running   1          3m        192.168.20.28   devops-master02
kube-system   kube-proxy-mxcwz                          1/1       Running   2          16m       192.168.20.27   devops-master01
kube-system   kube-proxy-vz7nf                          1/1       Running   1          3m        192.168.20.29   devops-master03
kube-system   kube-scheduler-devops-master01            1/1       Running   2          16m       192.168.20.27   devops-master01
kube-system   kube-scheduler-devops-master02            1/1       Running   1          2m        192.168.20.28   devops-master02
kube-system   kube-scheduler-devops-master03            1/1       Running   1          2m        192.168.20.29   devops-master03
kube-system   kubernetes-dashboard-7b7b5cd79b-6ldfn     1/1       Running   3          12m       10.244.172.12   devops-master01
kube-system   monitoring-grafana-76848b566c-h5998       1/1       Running   2          11m       10.244.172.14   devops-master01
kube-system   monitoring-influxdb-6c4b84d695-whzmp      1/1       Running   2          11m       10.244.172.10   devops-master01
```

* 设置所有master的scheduable

```
$ kubectl taint nodes --all node-role.kubernetes.io/master-
node "devops-master02" untainted
node "devops-master03" untainted
```

* 对基础组件进行多节点scale
```
$ kubectl get deploy -n kube-system
NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
calico-kube-controllers   1         1         1            1           14d
heapster                  1         1         1            0           8m
kube-dns                  3         3         3            3           14d
kubernetes-dashboard      1         1         1            1           14d
monitoring-grafana        1         1         1            0           8m
monitoring-influxdb       1         1         1            0           8m

# calico支持多节点
$ kubectl scale --replicas=3 -n kube-system deployment/calico-kube-controllers
$ kubectl get pods --all-namespaces -o wide| grep calico-kube-controllers

# dns支持多节点
$ kubectl scale --replicas=3 -n kube-system deployment/kube-dns
$ kubectl get pods --all-namespaces -o wide| grep kube-dns

# dashboard支持多节点
$ kubectl scale --replicas=3 -n kube-system deployment/kubernetes-dashboard
$ kubectl get pods --all-namespaces -o wide| grep kubernetes-dashboard

# heapster启动多个就会出现问题，请不要启动多个
```

```
kubectl get nodes
NAME              STATUS    ROLES     AGE       VERSION
devops-master01   Ready     master    38m       v1.9.1
devops-master02   Ready     master    25m       v1.9.1
devops-master03   Ready     master    25m       v1.9.1
```

---

[category](#category)

#### keepalived安装配置

* 在master上安装keepalived

```
$ systemctl restart keepalived

$ ping 192.168.20.10
```

---

[category](#category)

#### nginx负载均衡配置

* 在master上安装并启动nginx作为负载均衡

```
$ docker-compose -f nginx-lb/docker-compose.yaml up -d
```

* 在master上验证负载均衡和keepalived是否成功

```
curl -k 192.168.20.10:16443 | wc -l
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14    0    14    0     0   3958      0 --:--:-- --:--:-- --:--:-- 14000
1
```

---

[category](#category)

#### kube-proxy配置

- 在devops-master01上设置proxy高可用，设置server指向高可用虚拟IP以及负载均衡的16443端口
```
$ kubectl edit -n kube-system configmap/kube-proxy
        server: https://192.168.20.10:16443
```

- 在master上重启proxy

```
$ kubectl get pods --all-namespaces -o wide | grep proxy

$ kubectl delete pod -n kube-system kube-proxy-XXX
```

---

[category](#category)

### node节点加入高可用集群设置

#### kubeadm加入高可用集群

- 在所有worker节点上进行加入kubernetes集群操作

```
$ kubeadm join --token 7f276c.0741d82a5337f526 192.168.20.27:6443 --discovery-token-ca-cert-hash sha256:a4a1eaf725a0fc67c3028b3063b92e6af7f2eb0f4ae028f12b3415a6fd2d2a5e
```

- 在所有worker节点上修改kubernetes集群设置，更改server为高可用虚拟IP以及负载均衡的16443端口

```
sed -e "s/192.168.20.27:6443/192.168.20.10:16443/g" /etc/kubernetes/bootstrap-kubelet.conf > /etc/kubernetes/bootstrap-kubelet.conf

systemctl restart docker && systemctl restart kubelet
```


```
kubectl get nodes
NAME              STATUS    ROLES     AGE       VERSION
devops-master01   Ready     master    46m       v1.9.1
devops-master02   Ready     master    44m       v1.9.1
devops-master03   Ready     master    44m       v1.9.1
devops-node01     Ready     <none>    50s       v1.9.1
devops-node02     Ready     <none>    26s       v1.9.1
devops-node03     Ready     <none>    22s       v1.9.1
devops-node04     Ready     <none>    17s       v1.9.1
```

- 设置workers的节点标签

```
kubectl label nodes devops-node01 role=worker
kubectl label nodes devops-node02 role=worker
kubectl label nodes devops-node03 role=worker
kubectl label nodes devops-node04 role=worker
```

- 至此kubernetes高可用集群完成部署😃
