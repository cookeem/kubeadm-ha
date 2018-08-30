# kubeadm-highavailiability - 基于kubeadm的kubernetes高可用集群部署，支持v1.11.x v1.9.x v1.7.x v1.6.x版本

![k8s logo](images/Kubernetes.png)

- [中文文档(for v1.11.x版本)](README_CN.md)
- [English document(for v1.11.x version)](README.md)
- [中文文档(for v1.9.x版本)](v1.9/README_CN.md)
- [English document(for v1.9.x version)](v1.9/README.md)
- [中文文档(for v1.7.x版本)](v1.7/README_CN.md)
- [English document(for v1.7.x version)](v1.7/README.md)
- [中文文档(for v1.6.x版本)](v1.6/README_CN.md)
- [English document(for v1.6.x version)](v1.6/README.md)

---

- [GitHub项目地址](https://github.com/cookeem/kubeadm-ha/)
- [OSChina项目地址](https://git.oschina.net/cookeem/kubeadm-ha/)

---

- 该指引适用于v1.11.x版本的kubernetes集群

> v1.11.x版本支持在control plane上启动TLS的etcd高可用集群。

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
    1. [master节点互信设置](#master节点互信设置)
1. [master高可用安装](#master高可用安装)
    1. [配置文件初始化](#配置文件初始化)
    1. [kubeadm初始化](#kubeadm初始化)
    1. [高可用配置](#高可用配置)
1. [master负载均衡设置](#master负载均衡设置)
    1. [keepalived安装配置](#keepalived安装配置)
    1. [nginx负载均衡配置](#nginx负载均衡配置)
    1. [kube-proxy高可用设置](#kube-proxy高可用设置)
    1. [验证高可用状态](#验证高可用状态)
    1. [基础组件安装](#基础组件安装)
1. [worker节点设置](#worker节点设置)
    1. [worker加入高可用集群](#worker加入高可用集群)
    1. [验证集群高可用设置](#验证集群高可用设置)

### 部署架构

#### 概要部署架构

![ha logo](images/ha.png)

- kubernetes高可用的核心架构是master的高可用，kubectl、客户端以及nodes访问load balancer实现高可用。

---
[返回目录](#目录)

#### 详细部署架构

![k8s ha](images/k8s-ha.png)

- kubernetes组件说明

> kube-apiserver：集群核心，集群API接口、集群各个组件通信的中枢；集群安全控制；
> etcd：集群的数据中心，用于存放集群的配置以及状态信息，非常重要，如果数据丢失那么集群将无法恢复；因此高可用集群部署首先就是etcd是高可用集群；
> kube-scheduler：集群Pod的调度中心；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-scheduler处于活跃状态；
> kube-controller-manager：集群状态管理器，当集群状态与期望不同时，kcm会努力让集群恢复期望状态，比如：当一个pod死掉，kcm会努力新建一个pod来恢复对应replicas set期望的状态；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-controller-manager处于活跃状态；
> kubelet: kubernetes node agent，负责与node上的docker engine打交道；
> kube-proxy: 每个node上一个，负责service vip到endpoint pod的流量转发，当前主要通过设置iptables规则实现。

- 负载均衡

> keepalived集群设置一个虚拟ip地址，虚拟ip地址指向k8s-master01、k8s-master02、k8s-master03。
> nginx用于k8s-master01、k8s-master02、k8s-master03的apiserver的负载均衡。外部kubectl以及nodes访问apiserver的时候就可以用过keepalived的虚拟ip(192.168.20.10)以及nginx端口(16443)访问master集群的apiserver。

---

[返回目录](#目录)

#### 主机节点清单

主机名 | IP地址 | 说明 | 组件
:--- | :--- | :--- | :---
k8s-master01 ~ 03 | 192.168.20.20 ~ 22 | master节点 * 3 | keepalived、nginx、etcd、kubelet、kube-apiserver
k8s-master-lb     | 192.168.20.10 | keepalived虚拟IP | 无
k8s-node01 ~ 08   | 192.168.20.30 ~ 37 | worker节点 * 8 | kubelet

---

[返回目录](#目录)

### 安装前准备

#### 版本信息

- Linux版本：CentOS 7.4.1708

- 内核版本: 4.6.4-1.el7.elrepo.x86_64

```sh
$ cat /etc/redhat-release
CentOS Linux release 7.4.1708 (Core)

$ uname -r
4.6.4-1.el7.elrepo.x86_64
```

- docker版本：17.12.0-ce-rc2

```sh
$ docker version
Client:
 Version:	17.12.0-ce-rc2
 API version:	1.35
 Go version:	go1.9.2
 Git commit:	f9cde63
 Built:	Tue Dec 12 06:42:20 2017
 OS/Arch:	linux/amd64

Server:
 Engine:
  Version:	17.12.0-ce-rc2
  API version:	1.35 (minimum version 1.12)
  Go version:	go1.9.2
  Git commit:	f9cde63
  Built:	Tue Dec 12 06:44:50 2017
  OS/Arch:	linux/amd64
  Experimental:	false
```

- kubeadm版本：v1.11.1

```sh
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.1", GitCommit:"b1b29978270dc22fecc592ac55d903350454310a", GitTreeState:"clean", BuildDate:"2018-07-17T18:50:16Z", GoVersion:"go1.10.3", Compiler:"gc", Platform:"linux/amd64"}
```

- kubelet版本：v1.11.1

```sh
$ kubelet --version
Kubernetes v1.11.1
```

- 网络组件

> calico

---

[返回目录](#目录)

#### 所需docker镜像

- 相关docker镜像以及版本

```sh
# kuberentes basic components

# 通过kubeadm 获取基础组件镜像清单
$ kubeadm config images list --kubernetes-version=v1.11.1
k8s.gcr.io/kube-apiserver-amd64:v1.11.1
k8s.gcr.io/kube-controller-manager-amd64:v1.11.1
k8s.gcr.io/kube-scheduler-amd64:v1.11.1
k8s.gcr.io/kube-proxy-amd64:v1.11.1
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd-amd64:3.2.18
k8s.gcr.io/coredns:1.1.3

# 通过kubeadm 拉取基础镜像
$ kubeadm config images pull --kubernetes-version=v1.11.1

# kubernetes networks add ons
$ docker pull quay.io/calico/typha:v0.7.4
$ docker pull quay.io/calico/node:v3.1.3
$ docker pull quay.io/calico/cni:v3.1.3

# kubernetes metrics server
$ docker pull gcr.io/google_containers/metrics-server-amd64:v0.2.1

# kubernetes dashboard
$ docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.8.3

# kubernetes heapster
$ docker pull k8s.gcr.io/heapster-amd64:v1.5.4
$ docker pull k8s.gcr.io/heapster-influxdb-amd64:v1.5.2
$ docker pull k8s.gcr.io/heapster-grafana-amd64:v5.0.4

# kubernetes apiserver load balancer
$ docker pull nginx:latest

# prometheus
$ docker pull prom/prometheus:v2.3.1

# traefik
$ docker pull traefik:v1.6.3

# istio
$ docker pull docker.io/jaegertracing/all-in-one:1.5
$ docker pull docker.io/prom/prometheus:v2.3.1
$ docker pull docker.io/prom/statsd-exporter:v0.6.0
$ docker pull gcr.io/istio-release/citadel:1.0.0
$ docker pull gcr.io/istio-release/galley:1.0.0
$ docker pull gcr.io/istio-release/grafana:1.0.0
$ docker pull gcr.io/istio-release/mixer:1.0.0
$ docker pull gcr.io/istio-release/pilot:1.0.0
$ docker pull gcr.io/istio-release/proxy_init:1.0.0
$ docker pull gcr.io/istio-release/proxyv2:1.0.0
$ docker pull gcr.io/istio-release/servicegraph:1.0.0
$ docker pull gcr.io/istio-release/sidecar_injector:1.0.0
$ docker pull quay.io/coreos/hyperkube:v1.7.6_coreos.0
```

---

[返回目录](#目录)

#### 系统设置

- 在所有kubernetes节点上增加kubernetes仓库

```sh
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
```

- 在所有kubernetes节点上进行系统更新

```sh
$ yum update -y
```

- 在所有kubernetes节点上设置SELINUX为permissive模式

```sh
$ vi /etc/selinux/config
SELINUX=permissive

$ setenforce 0
```

- 在所有kubernetes节点上设置iptables参数

```sh
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

$ sysctl --system
```

- 在所有kubernetes节点上禁用swap

```sh
$ swapoff -a

# 禁用fstab中的swap项目
$ vi /etc/fstab
#/dev/mapper/centos-swap swap                    swap    defaults        0 0

# 确认swap已经被禁用
$ cat /proc/swaps
Filename                Type        Size    Used    Priority
```

- 在所有kubernetes节点上重启主机

```sh
# 重启主机
$ reboot
```

---

[返回目录](#目录)

### kubernetes安装

#### firewalld和iptables相关端口设置

- 所有节点开启防火墙

```sh
# 重启防火墙
$ systemctl enable firewalld
$ systemctl restart firewalld
$ systemctl status firewalld
```

- 相关端口（master）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 16443*    | Load balancer Kubernetes API server port
TCP | Inbound | 6443*     | Kubernetes API server
TCP | Inbound | 4001      | etcd listen client port
TCP | Inbound | 2379-2380 | etcd server client API
TCP | Inbound | 10250     | Kubelet API
TCP | Inbound | 10251     | kube-scheduler
TCP | Inbound | 10252     | kube-controller-manager
TCP | Inbound | 10255     | Read-only Kubelet API (Deprecated)
TCP | Inbound | 30000-32767 | NodePort Services

- 设置防火墙策略

```sh
$ firewall-cmd --zone=public --add-port=16443/tcp --permanent
$ firewall-cmd --zone=public --add-port=6443/tcp --permanent
$ firewall-cmd --zone=public --add-port=4001/tcp --permanent
$ firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=10251/tcp --permanent
$ firewall-cmd --zone=public --add-port=10252/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

$ firewall-cmd --reload

$ firewall-cmd --list-all --zone=public
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: ens2f1 ens1f0 nm-bond
  sources:
  services: ssh dhcpv6-client
  ports: 4001/tcp 6443/tcp 2379-2380/tcp 10250/tcp 10251/tcp 10252/tcp 30000-32767/tcp
  protocols:
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

- 相关端口（worker）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 10250       | Kubelet API
TCP | Inbound | 30000-32767 | NodePort Services

- 设置防火墙策略

```sh
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

$ firewall-cmd --reload

$ firewall-cmd --list-all --zone=public
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: ens2f1 ens1f0 nm-bond
  sources:
  services: ssh dhcpv6-client
  ports: 10250/tcp 30000-32767/tcp
  protocols:
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

- 在所有kubernetes节点上允许kube-proxy的forward

```sh
$ firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -i docker0 -j ACCEPT -m comment --comment "kube-proxy redirects"
$ firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 1 -o docker0 -j ACCEPT -m comment --comment "docker subnet"
$ firewall-cmd --reload

$ firewall-cmd --direct --get-all-rules
ipv4 filter INPUT 1 -i docker0 -j ACCEPT -m comment --comment 'kube-proxy redirects'
ipv4 filter FORWARD 1 -o docker0 -j ACCEPT -m comment --comment 'docker subnet'

# 重启防火墙
$ systemctl restart firewalld
```

- 解决kube-proxy无法启用nodePort，重启firewalld必须执行以下命令，在所有节点设置定时任务

```sh
$ crontab -e
0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
```

---

[返回目录](#目录)

#### kubernetes相关服务安装

- 在所有kubernetes节点上安装并启动kubernetes

```sh
$ yum install -y docker-ce-17.12.0.ce-0.2.rc2.el7.centos.x86_64
$ yum install -y docker-compose-1.9.0-5.el7.noarch
$ systemctl enable docker && systemctl start docker

$ yum install -y kubelet-1.11.1-0.x86_64 kubeadm-1.11.1-0.x86_64 kubectl-1.11.1-0.x86_64
$ systemctl enable kubelet && systemctl start kubelet
```

- 在所有master节点安装并启动keepalived

```sh
$ yum install -y keepalived
$ systemctl enable keepalived && systemctl restart keepalived
```

#### master节点互信设置

- 在k8s-master01节点上设置节点互信

```sh
$ rm -rf /root/.ssh/*
$ ssh k8s-master01 pwd
$ ssh k8s-master02 rm -rf /root/.ssh/*
$ ssh k8s-master03 rm -rf /root/.ssh/*
$ ssh k8s-master02 mkdir -p /root/.ssh/
$ ssh k8s-master03 mkdir -p /root/.ssh/

$ scp /root/.ssh/known_hosts root@k8s-master02:/root/.ssh/
$ scp /root/.ssh/known_hosts root@k8s-master03:/root/.ssh/

$ ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
$ cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
$ scp /root/.ssh/authorized_keys root@k8s-master02:/root/.ssh/
```

- 在k8s-master02节点上设置节点互信

```sh
$ ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
$ cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
$ scp /root/.ssh/authorized_keys root@k8s-master03:/root/.ssh/
```

- 在k8s-master03节点上设置节点互信

```sh
$ ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
$ cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
$ scp /root/.ssh/authorized_keys root@k8s-master01:/root/.ssh/
$ scp /root/.ssh/authorized_keys root@k8s-master02:/root/.ssh/
```

---

[返回目录](#目录)

### master高可用安装

#### 配置文件初始化

- 在k8s-master01上克隆kubeadm-ha项目源码

```sh
$ git clone https://github.com/cookeem/kubeadm-ha
```

- 在k8s-master01上通过`create-config.sh`脚本创建相关配置文件

```sh
$ cd kubeadm-ha

# 根据create-config.sh的提示，修改以下配置信息
$ vi create-config.sh
# master keepalived virtual ip address
export K8SHA_VIP=192.168.60.79
# master01 ip address
export K8SHA_IP1=192.168.60.72
# master02 ip address
export K8SHA_IP2=192.168.60.77
# master03 ip address
export K8SHA_IP3=192.168.60.78
# master keepalived virtual ip hostname
export K8SHA_VHOST=k8s-master-lb
# master01 hostname
export K8SHA_HOST1=k8s-master01
# master02 hostname
export K8SHA_HOST2=k8s-master02
# master03 hostname
export K8SHA_HOST3=k8s-master03
# master01 network interface name
export K8SHA_NETINF1=nm-bond
# master02 network interface name
export K8SHA_NETINF2=nm-bond
# master03 network interface name
export K8SHA_NETINF3=nm-bond
# keepalived auth_pass config
export K8SHA_KEEPALIVED_AUTH=412f7dc3bfed32194d1600c483e10ad1d
# calico reachable ip address
export K8SHA_CALICO_REACHABLE_IP=192.168.60.1
# kubernetes CIDR pod subnet, if CIDR pod subnet is "172.168.0.0/16" please set to "172.168.0.0"
export K8SHA_CIDR=172.168.0.0

# 以下脚本会创建3个master节点的kubeadm配置文件，keepalived配置文件，nginx负载均衡配置文件，以及calico配置文件
$ ./create-config.sh
create kubeadm-config.yaml files success. config/k8s-master01/kubeadm-config.yaml
create kubeadm-config.yaml files success. config/k8s-master02/kubeadm-config.yaml
create kubeadm-config.yaml files success. config/k8s-master03/kubeadm-config.yaml
create keepalived files success. config/k8s-master01/keepalived/
create keepalived files success. config/k8s-master02/keepalived/
create keepalived files success. config/k8s-master03/keepalived/
create nginx-lb files success. config/k8s-master01/nginx-lb/
create nginx-lb files success. config/k8s-master02/nginx-lb/
create nginx-lb files success. config/k8s-master03/nginx-lb/
create calico.yaml file success. calico/calico.yaml

# 设置相关hostname变量
$ export HOST1=k8s-master01
$ export HOST2=k8s-master02
$ export HOST3=k8s-master03

# 把kubeadm配置文件放到各个master节点的/root/目录
$ scp -r config/$HOST1/kubeadm-config.yaml $HOST1:/root/
$ scp -r config/$HOST2/kubeadm-config.yaml $HOST2:/root/
$ scp -r config/$HOST3/kubeadm-config.yaml $HOST3:/root/

# 把keepalived配置文件放到各个master节点的/etc/keepalived/目录
$ scp -r config/$HOST1/keepalived/* $HOST1:/etc/keepalived/
$ scp -r config/$HOST2/keepalived/* $HOST2:/etc/keepalived/
$ scp -r config/$HOST3/keepalived/* $HOST3:/etc/keepalived/

# 把nginx负载均衡配置文件放到各个master节点的/root/目录
$ scp -r config/$HOST1/nginx-lb $HOST1:/root/
$ scp -r config/$HOST2/nginx-lb $HOST2:/root/
$ scp -r config/$HOST3/nginx-lb $HOST3:/root/
```

---

[返回目录](#目录)

#### kubeadm初始化

- 在k8s-master01节点上使用kubeadm进行kubernetes集群初始化

```sh
# 执行kubeadm init之后务必记录执行结果输出的${YOUR_TOKEN}以及${YOUR_DISCOVERY_TOKEN_CA_CERT_HASH}
$ kubeadm init --config /root/kubeadm-config.yaml
kubeadm join 192.168.20.20:6443 --token ${YOUR_TOKEN} --discovery-token-ca-cert-hash sha256:${YOUR_DISCOVERY_TOKEN_CA_CERT_HASH}
```

- 在所有master节点上设置kubectl的配置文件变量

```sh
$ cat <<EOF >> ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

$ source ~/.bashrc

# 验证是否可以使用kubectl客户端连接集群
$ kubectl get nodes
```

- 在k8s-master01节点上等待 etcd / kube-apiserver / kube-controller-manager / kube-scheduler 启动

```sh
$ kubectl get pods -n kube-system -o wide
NAME                                   READY     STATUS    RESTARTS   AGE       IP              NODE
...
etcd-k8s-master01                      1/1       Running   0          18m       192.168.20.20   k8s-master01
kube-apiserver-k8s-master01            1/1       Running   0          18m       192.168.20.20   k8s-master01
kube-controller-manager-k8s-master01   1/1       Running   0          18m       192.168.20.20   k8s-master01
kube-scheduler-k8s-master01            1/1       Running   1          18m       192.168.20.20   k8s-master01
...
```

---

[返回目录](#目录)

#### 高可用配置

- 在k8s-master01上把证书复制到其他master

```sh
# 根据实际情况修改以下HOSTNAMES变量
$ export CONTROL_PLANE_IPS="k8s-master02 k8s-master03"

# 把证书复制到其他master节点
$ for host in ${CONTROL_PLANE_IPS}; do
  scp /etc/kubernetes/pki/ca.crt $host:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key $host:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key $host:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub $host:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt $host:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key $host:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt $host:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key $host:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf $host:/etc/kubernetes/admin.conf
done
```

- 在k8s-master02上把节点加入集群

```sh
# 创建相关的证书以及kubelet配置文件
$ kubeadm alpha phase certs all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig controller-manager --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig scheduler --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubelet config write-to-disk --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubelet write-env-file --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig kubelet --config /root/kubeadm-config.yaml
$ systemctl restart kubelet

# 设置k8s-master01以及k8s-master02的HOSTNAME以及地址
$ export CP0_IP=192.168.20.20
$ export CP0_HOSTNAME=k8s-master01
$ export CP1_IP=192.168.20.21
$ export CP1_HOSTNAME=k8s-master02

# etcd集群添加节点
$ kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380
$ kubeadm alpha phase etcd local --config /root/kubeadm-config.yaml

# 启动master节点
$ kubeadm alpha phase kubeconfig all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase controlplane all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase mark-master --config /root/kubeadm-config.yaml

# 修改/etc/kubernetes/admin.conf的服务地址指向本机
$ sed -i "s/192.168.20.20:6443/192.168.20.21:6443/g" /etc/kubernetes/admin.conf
```

- 在k8s-master03上把节点加入集群

```sh
# 创建相关的证书以及kubelet配置文件
$ kubeadm alpha phase certs all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig controller-manager --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig scheduler --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubelet config write-to-disk --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubelet write-env-file --config /root/kubeadm-config.yaml
$ kubeadm alpha phase kubeconfig kubelet --config /root/kubeadm-config.yaml
$ systemctl restart kubelet

# 设置k8s-master01以及k8s-master03的HOSTNAME以及地址
$ export CP0_IP=192.168.20.20
$ export CP0_HOSTNAME=k8s-master01
$ export CP2_IP=192.168.20.22
$ export CP2_HOSTNAME=k8s-master03

# etcd集群添加节点
$ kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP2_HOSTNAME} https://${CP2_IP}:2380
$ kubeadm alpha phase etcd local --config /root/kubeadm-config.yaml

# 启动master节点
$ kubeadm alpha phase kubeconfig all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase controlplane all --config /root/kubeadm-config.yaml
$ kubeadm alpha phase mark-master --config /root/kubeadm-config.yaml

# 修改/etc/kubernetes/admin.conf的服务地址指向本机
$ sed -i "s/192.168.20.20:6443/192.168.20.22:6443/g" /etc/kubernetes/admin.conf
```

- 在所有master节点上允许hpa通过接口采集数据，修改`/etc/kubernetes/manifests/kube-controller-manager.yaml`

```sh
$ vi /etc/kubernetes/manifests/kube-controller-manager.yaml
    - --horizontal-pod-autoscaler-use-rest-clients=false
```

- 在所有master上允许istio的自动注入，修改`/etc/kubernetes/manifests/kube-apiserver.yaml`

```sh
$ vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota

# 重启服务
systemctl restart kubelet
```

---

[返回目录](#目录)

### master负载均衡设置

#### keepalived安装配置

- 在所有master节点上重启keepalived

```sh
$ systemctl restart keepalived
$ systemctl status keepalived

# 检查keepalived的vip是否生效
$ curl -k https://k8s-master-lb:6443
```

---

[返回目录](#目录)

#### nginx负载均衡配置

- 在所有master节点上启动nginx-lb

```sh
# 使用docker-compose启动nginx负载均衡
$ docker-compose --file=/root/nginx-lb/docker-compose.yaml up -d
$ docker-compose --file=/root/nginx-lb/docker-compose.yaml ps

# 验证负载均衡的16443端口是否生效
$ curl -k https://k8s-master-lb:16443
```

---

[返回目录](#目录)

#### kube-proxy高可用设置

- 在任意master节点上设置kube-proxy高可用

```sh
# 修改kube-proxy的configmap，把server指向load-balance地址和端口
$ kubectl edit -n kube-system configmap/kube-proxy
    server: https://192.168.20.10:16443
```

- 在任意master节点上重启kube-proxy

```sh
# 查找对应的kube-proxy pods
$ kubectl get pods --all-namespaces -o wide | grep proxy

# 删除并重启对应的kube-proxy pods
$ kubectl delete pod -n kube-system kube-proxy-XXX
```

---

[返回目录](#目录)

#### 验证高可用状态

- 在任意master节点上验证服务启动情况

```sh
# 检查节点情况
$ kubectl get nodes
NAME              STATUS    ROLES     AGE       VERSION
k8s-master01   Ready     master    1h        v1.11.1
k8s-master02   Ready     master    58m       v1.11.1
k8s-master03   Ready     master    55m       v1.11.1

# 检查pods运行情况
$ kubectl get pods -n kube-system -o wide
NAME                                   READY     STATUS    RESTARTS   AGE       IP              NODE
calico-node-nxskr                      2/2       Running   0          46m       192.168.20.22   k8s-master03
calico-node-xv5xt                      2/2       Running   0          46m       192.168.20.20   k8s-master01
calico-node-zsmgp                      2/2       Running   0          46m       192.168.20.21   k8s-master02
coredns-78fcdf6894-kfzc7               1/1       Running   0          1h        172.168.2.3     k8s-master03
coredns-78fcdf6894-t957l               1/1       Running   0          46m       172.168.1.2     k8s-master02
etcd-k8s-master01                      1/1       Running   0          1h        192.168.20.20   k8s-master01
etcd-k8s-master02                      1/1       Running   0          58m       192.168.20.21   k8s-master02
etcd-k8s-master03                      1/1       Running   0          54m       192.168.20.22   k8s-master03
kube-apiserver-k8s-master01            1/1       Running   0          52m       192.168.20.20   k8s-master01
kube-apiserver-k8s-master02            1/1       Running   0          52m       192.168.20.21   k8s-master02
kube-apiserver-k8s-master03            1/1       Running   0          51m       192.168.20.22   k8s-master03
kube-controller-manager-k8s-master01   1/1       Running   0          34m       192.168.20.20   k8s-master01
kube-controller-manager-k8s-master02   1/1       Running   0          33m       192.168.20.21   k8s-master02
kube-controller-manager-k8s-master03   1/1       Running   0          33m       192.168.20.22   k8s-master03
kube-proxy-g9749                       1/1       Running   0          36m       192.168.20.22   k8s-master03
kube-proxy-lhzhb                       1/1       Running   0          35m       192.168.20.20   k8s-master01
kube-proxy-x8jwt                       1/1       Running   0          36m       192.168.20.21   k8s-master02
kube-scheduler-k8s-master01            1/1       Running   1          1h        192.168.20.20   k8s-master01
kube-scheduler-k8s-master02            1/1       Running   0          57m       192.168.20.21   k8s-master02
kube-scheduler-k8s-master03            1/1       Running   1          54m       192.168.20.22   k8s-master03
```

---

[返回目录](#目录)

#### 基础组件安装

- 在任意master节点上允许master上部署pod

```sh
$ kubectl taint nodes --all node-role.kubernetes.io/master-
```

# 在devops-master01上安装calico
kubectl apply -f calico/

# 在devops-master01上安装metrics-server
kubectl apply -f metrics-server/

# 在devops-master01上安装heapster
kubectl apply -f heapster/

# 在devops-master01上安装dashboard
kubectl apply -f dashboard/

# 在devops-master01上后去dashboard的登录token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

---

[返回目录](#目录)

### worker节点设置

#### worker加入高可用集群

---

[返回目录](#目录)

#### 验证集群高可用设置

---

[返回目录](#目录)
