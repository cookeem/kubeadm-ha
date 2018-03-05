# kubeadm-highavailiability - 基于kubeadm的kubernetes高可用集群部署，支持v1.9.x和v1.7.x版本以及v1.6.x版本

![k8s logo](images/v1.6-v1.7/Kubernetes.png)

- [中文文档(for v1.9.x版本)](README_CN.md)
- [English document(for v1.9.x version)](README.md)
- [中文文档(for v1.7.x版本)](v1.6-v1.7/README_CN.md)
- [English document(for v1.7.x version)](v1.6-v1.7/README.md)
- [中文文档(for v1.6.x版本)](v1.6-v1.7/README_v1.6.x_CN.md)
- [English document(for v1.6.x version)](v1.6-v1.7/README_v1.6.x.md)

---

- [GitHub项目地址](https://github.com/cookeem/kubeadm-ha/)
- [OSChina项目地址](https://git.oschina.net/cookeem/kubeadm-ha/)

---

- 该指引适用于v1.9.x版本的kubernetes集群

> v1.9.0以前的版本kubeadm还不支持高可用部署，因此不推荐作为生产环境的部署方式。从v1.9.x版本开始，kubeadm官方正式支持高可用集群的部署，安装kubeadm务必保证版本至少为1.9.0。

### 目录

### 目录

1. [部署架构](#部署架构)
    1. [概要部署架构](#概要部署架构)
    1. [详细部署架构](#详细部署架构)
    1. [主机节点清单](#主机节点清单)
1. [安装前准备](#安装前准备)
    1. [版本信息](#版本信息)
    1. [所需docker镜像](#所需docker镜像)
    1. [系统设置](#系统设置)
1. [kubernetes安装](#kubernetes安装)
    1. [firewalld和iptables相关端口设置](#firewalld和iptables相关端口设置)
    1. [kubernetes相关服务安装](#kubernetes相关服务安装)
1. [配置文件初始化](#配置文件初始化)
    1. [初始化脚本配置](#初始化脚本配置) 
    1. [独立etcd集群部署](#独立etcd集群部署)
1. [第一台master初始化](#第一台master初始化)
    1. [kubeadm初始化](#kubeadm初始化)
    1. [安装基础组件](#安装基础组件)
1. [master集群高可用设置](#master集群高可用设置)
    1. [复制配置](#复制配置)
    1. [其余master节点初始化](#其余master节点初始化)
    1. [keepalived安装配置](#keepalived安装配置)
    1. [nginx负载均衡配置](#nginx负载均衡配置)
    1. [kube-proxy配置](#kube-proxy配置)
1. [node节点加入高可用集群设置](#node节点加入高可用集群设置)
    1. [kubeadm加入高可用集群](#kubeadm加入高可用集群)
    1. [验证集群高可用设置](#验证集群高可用设置)
    


### 部署架构

#### 概要部署架构

![ha logo](images/v1.6-v1.7/ha.png)

* kubernetes高可用的核心架构是master的高可用，kubectl、客户端以及nodes访问load balancer实现高可用。

---
[返回目录](#目录)

#### 详细部署架构

![k8s ha](images/v1.6-v1.7/k8s-ha.png)

* kubernetes组件说明

> kube-apiserver：集群核心，集群API接口、集群各个组件通信的中枢；集群安全控制；

> etcd：集群的数据中心，用于存放集群的配置以及状态信息，非常重要，如果数据丢失那么集群将无法恢复；因此高可用集群部署首先就是etcd是高可用集群；

> kube-scheduler：集群Pod的调度中心；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-scheduler处于活跃状态；

> kube-controller-manager：集群状态管理器，当集群状态与期望不同时，kcm会努力让集群恢复期望状态，比如：当一个pod死掉，kcm会努力新建一个pod来恢复对应replicas set期望的状态；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-controller-manager处于活跃状态；

> kubelet: kubernetes node agent，负责与node上的docker engine打交道；

> kube-proxy: 每个node上一个，负责service vip到endpoint pod的流量转发，当前主要通过设置iptables规则实现。

* 负载均衡

> keepalived集群设置一个虚拟ip地址，虚拟ip地址指向devops-master01、devops-master02、devops-master03。

> nginx用于devops-master01、devops-master02、devops-master03的apiserver的负载均衡。外部kubectl以及nodes访问apiserver的时候就可以用过keepalived的虚拟ip(192.168.20.10)以及nginx端口(16443)访问master集群的apiserver。

---

[返回目录](#目录)

#### 主机节点清单

主机名 | IP地址 | 说明 | 组件 
:--- | :--- | :--- | :---
devops-master01 ~ 03 | 192.168.20.27 ~ 29 | master节点 * 3 | keepalived、nginx、etcd、kubelet、kube-apiserver、kube-scheduler、kube-proxy、kube-dashboard、heapster、calico
无 | 192.168.20.10 | keepalived虚拟IP | 无
devops-node01 ~ 04 | 192.168.20.17 ~ 20 | node节点 * 4 | kubelet、kube-proxy

---

[返回目录](#目录)

### 安装前准备

#### 版本信息

* Linux版本：CentOS 7.4.1708
* 内核版本: 4.6.4-1.el7.elrepo.x86_64


```
$ cat /etc/redhat-release 
CentOS Linux release 7.4.1708 (Core) 

$ uname -r
4.6.4-1.el7.elrepo.x86_64
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

* kubeadm版本：v1.9.3

```
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"9", GitVersion:"v1.9.3", GitCommit:"d2835416544f298c919e2ead3be3d0864b52323b", GitTreeState:"clean", BuildDate:"2018-02-07T11:55:20Z", GoVersion:"go1.9.2", Compiler:"gc", Platform:"linux/amd64"}
```

* kubelet版本：v1.9.3

```
$ kubelet --version
Kubernetes v1.9.3
```

* 网络组件

> canal (flannel + calico)

---

[返回目录](#目录)

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

[返回目录](#目录)

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

[返回目录](#目录)

### kubernetes安装

#### firewalld和iptables相关端口设置

- 相关端口（master）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 16443*    | Load balancer Kubernetes API server port
TCP | Inbound | 6443*     | Kubernetes API server
TCP | Inbound | 2379-2380 | etcd server client API
TCP | Inbound | 10250     | Kubelet API
TCP | Inbound | 10251     | kube-scheduler
TCP | Inbound | 10252     | kube-controller-manager
TCP | Inbound | 10255     | Read-only Kubelet API

- 相关端口（worker）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 10250       | Kubelet API
TCP | Inbound | 10255       | Read-only Kubelet API
TCP | Inbound | 30000-32767 | NodePort Services**

---

[返回目录](#目录)

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

[返回目录](#目录)

### 配置文件初始化

#### 初始化脚本配置

* 在所有master节点上获取代码，并进入代码目录

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

[返回目录](#目录)

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

[返回目录](#目录)

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

* 至此，第一台master成功安装，并已经完成flannel、calico、dashboard、heapster的部署

---

[返回目录](#目录)

### master集群高可用设置

#### 复制配置

* 在devops-master01上复制目录/etc/kubernetes/pki到devops-master02、devops-master03，从v1.9.x开始，kubeadm会检测pki目录是否有证书，如果已经存在证书则跳过证书生成的步骤

```
scp -r /etc/kubernetes/pki devops-master02:/etc/kubernetes/

scp -r /etc/kubernetes/pki devops-master03:/etc/kubernetes/
```

---
[返回目录](#目录)

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

[返回目录](#目录)

#### keepalived安装配置

* 在master上安装keepalived

```
$ systemctl restart keepalived

$ ping 192.168.20.10
```

---

[返回目录](#目录)

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

[返回目录](#目录)

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

[返回目录](#目录)

### node节点加入高可用集群设置

#### kubeadm加入高可用集群

- 在所有worker节点上进行加入kubernetes集群操作，这里统一使用devops-master01的apiserver地址来加入集群 

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

#### 验证集群高可用设置

```
# 创建一个replicas=3的nginx deployment
$ kubectl run nginx --image=nginx --replicas=3 --port=80
deployment "nginx" created

# 检查nginx pod的创建情况
$ kubectl get pods -l=run=nginx -o wide
NAME                     READY     STATUS    RESTARTS   AGE       IP              NODE
nginx-6c7c8978f5-558kd   1/1       Running   0          9m        10.244.77.217   devops-node03
nginx-6c7c8978f5-ft2z5   1/1       Running   0          9m        10.244.172.67   devops-master01
nginx-6c7c8978f5-jr29b   1/1       Running   0          9m        10.244.85.165   devops-node04

# 创建nginx的NodePort service
$ kubectl expose deployment nginx --type=NodePort --port=80
service "nginx" exposed

# 检查nginx service的创建情况
$ kubectl get svc -l=run=nginx -o wide
NAME      TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE       SELECTOR
nginx     NodePort   10.101.144.192   <none>        80:30847/TCP   10m       run=nginx

# 检查nginx NodePort service是否正常提供服务
$ curl devops-master01:30847
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

- 至此kubernetes高可用集群完成部署😃
