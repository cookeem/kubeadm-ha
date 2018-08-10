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
1. [配置文件初始化](#配置文件初始化)
    1. [初始化脚本配置](#初始化脚本配置)
1. [master高可用安装](#master高可用安装)
    1. [kubeadm初始化](#kubeadm初始化)
    1. [kube-proxy配置](#kube-proxy配置)
    1. [安装基础组件](#安装基础组件)
1. [master集群高可用设置](#master集群高可用设置)
    1. [keepalived安装配置](#keepalived安装配置)
    1. [nginx负载均衡配置](#nginx负载均衡配置)
1. [node节点加入高可用集群设置](#node节点加入高可用集群设置)
    1. [kubeadm加入高可用集群](#kubeadm加入高可用集群)
    1. [验证集群高可用设置](#验证集群高可用设置)



### 部署架构

#### 概要部署架构

![ha logo](images/ha.png)

* kubernetes高可用的核心架构是master的高可用，kubectl、客户端以及nodes访问load balancer实现高可用。

---
[返回目录](#目录)

#### 详细部署架构

![k8s ha](images/k8s-ha.png)

* kubernetes组件说明

> kube-apiserver：集群核心，集群API接口、集群各个组件通信的中枢；集群安全控制；

> etcd：集群的数据中心，用于存放集群的配置以及状态信息，非常重要，如果数据丢失那么集群将无法恢复；因此高可用集群部署首先就是etcd是高可用集群；

> kube-scheduler：集群Pod的调度中心；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-scheduler处于活跃状态；

> kube-controller-manager：集群状态管理器，当集群状态与期望不同时，kcm会努力让集群恢复期望状态，比如：当一个pod死掉，kcm会努力新建一个pod来恢复对应replicas set期望的状态；默认kubeadm安装情况下--leader-elect参数已经设置为true，保证master集群中只有一个kube-controller-manager处于活跃状态；

> kubelet: kubernetes node agent，负责与node上的docker engine打交道；

> kube-proxy: 每个node上一个，负责service vip到endpoint pod的流量转发，当前主要通过设置iptables规则实现。

* 负载均衡

> keepalived集群设置一个虚拟ip地址，虚拟ip地址指向k8s-master01、k8s-master02、k8s-master03。

> nginx用于k8s-master01、k8s-master02、k8s-master03的apiserver的负载均衡。外部kubectl以及nodes访问apiserver的时候就可以用过keepalived的虚拟ip(192.168.20.10)以及nginx端口(16443)访问master集群的apiserver。

---

[返回目录](#目录)

#### 主机节点清单

主机名 | IP地址 | 说明 | 组件
:--- | :--- | :--- | :---
k8s-master01 ~ 03 | 192.168.20.27 ~ 29 | master节点 * 3 | keepalived、nginx、etcd、kubelet、kube-apiserver
无 | 192.168.20.10 | keepalived虚拟IP | 无
k8s-node01 ~ 04 | 192.168.20.17 ~ 20 | node节点 * 4 | kubelet

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

* kubeadm版本：v1.11.1

```
$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.1", GitCommit:"b1b29978270dc22fecc592ac55d903350454310a", GitTreeState:"clean", BuildDate:"2018-07-17T18:50:16Z", GoVersion:"go1.10.3", Compiler:"gc", Platform:"linux/amd64"}
```

* kubelet版本：v1.11.1

```
$ kubelet --version
Kubernetes v1.11.1
```

* 网络组件

> calico

---

[返回目录](#目录)

#### 所需docker镜像

* 相关docker镜像以及版本

```
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
docker pull quay.io/calico/typha:v0.7.4
docker pull quay.io/calico/node:v3.1.3
docker pull quay.io/calico/cni:v3.1.3

# kubernetes metrics server
docker pull gcr.io/google_containers/metrics-server-amd64:v0.2.1

# kubernetes dashboard
docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.8.3

# kubernetes heapster
docker pull k8s.gcr.io/heapster-amd64:v1.5.4
docker pull k8s.gcr.io/heapster-influxdb-amd64:v1.5.2
docker pull k8s.gcr.io/heapster-grafana-amd64:v5.0.4

# kubernetes apiserver load balancer
docker pull nginx:latest

# prometheus
docker pull prom/prometheus:v2.3.1

# traefik
docker pull traefik:v1.6.3

# istio
docker pull docker.io/jaegertracing/all-in-one:1.5
docker pull docker.io/prom/prometheus:v2.3.1
docker pull docker.io/prom/statsd-exporter:v0.6.0
docker pull gcr.io/istio-release/citadel:1.0.0
docker pull gcr.io/istio-release/galley:1.0.0
docker pull gcr.io/istio-release/grafana:1.0.0
docker pull gcr.io/istio-release/mixer:1.0.0
docker pull gcr.io/istio-release/pilot:1.0.0
docker pull gcr.io/istio-release/proxy_init:1.0.0
docker pull gcr.io/istio-release/proxyv2:1.0.0
docker pull gcr.io/istio-release/servicegraph:1.0.0
docker pull gcr.io/istio-release/sidecar_injector:1.0.0
docker pull quay.io/coreos/hyperkube:v1.7.6_coreos.0
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
exclude=kube*
EOF
```

* 在所有kubernetes节点上进行系统更新

```
$ yum update -y
```

* 在所有kubernetes节点上设置SELINUX为permissive模式

```
$ vi /etc/selinux/config
SELINUX=permissive

$ setenforce 0
```

* 在所有kubernetes节点上设置iptables参数

```
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

$ sysctl --system
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

- 所有节点开启防火墙

```
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

```
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

```
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

* 在所有kubernetes节点上允许kube-proxy的forward

```
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

```
$ crontab -e
0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
```

---

[返回目录](#目录)


- 所有节点安装并启动组件

```
yum install -y docker-ce-17.12.0.ce-0.2.rc2.el7.centos.x86_64
yum install -y docker-compose-1.9.0-5.el7.noarch
systemctl enable docker && systemctl start docker

yum install -y kubelet-1.11.1-0.x86_64 kubeadm-1.11.1-0.x86_64 kubectl-1.11.1-0.x86_64
systemctl enable kubelet && systemctl start kubelet
```

- 在master节点安装并启动keepalived

```
yum install -y keepalived
systemctl enable keepalived && systemctl restart keepalived
```

# 所有master节点执行
kubeadm reset

mkdir -p /etc/kubernetes/pki/etcd/


# k8s-master01
cat << EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- k8s-master01
- k8s-master02
- k8s-master03
- k8s-master-lb
- 192.168.60.72
- 192.168.60.77
- 192.168.60.78
- 192.168.60.79
#api:
#  controlPlaneEndpoint: "192.168.60.79:6443"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.60.72:2379"
      advertise-client-urls: "https://192.168.60.72:2379"
      listen-peer-urls: "https://192.168.60.72:2380"
      initial-advertise-peer-urls: "https://192.168.60.72:2380"
      initial-cluster: "k8s-master01=https://192.168.60.72:2380"
    serverCertSANs:
      - k8s-master01
      - 192.168.60.72
    peerCertSANs:
      - k8s-master01
      - 192.168.60.72
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: "172.168.0.0/16"
EOF

kubeadm init --config kubeadm-config.yaml

```
输出：
# kubeadm join 192.168.60.72:6443 --token dt48lp.j448b22z81l3kut2 --discovery-token-ca-cert-hash sha256:d50efdf5f5dbe45f35209c56cc5fbea52aecc82a3384d1c2c12c0193958769a5
```

```
cat <<EOF >> ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

# 检查kubernetes状态，等待服务正常起来
kubectl get pods --all-namespaces -o wide -w
```

# 在k8s-master01上把证书复制到其他master
CONTROL_PLANE_IPS="k8s-master02 k8s-master03"
for host in ${CONTROL_PLANE_IPS}; do
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


# k8s-master02
cat << EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- k8s-master01
- k8s-master02
- k8s-master03
- k8s-master-lb
- 192.168.60.72
- 192.168.60.77
- 192.168.60.78
- 192.168.60.79
#api:
#  controlPlaneEndpoint: "192.168.60.79:6443"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.60.77:2379"
      advertise-client-urls: "https://192.168.60.77:2379"
      listen-peer-urls: "https://192.168.60.77:2380"
      initial-advertise-peer-urls: "https://192.168.60.77:2380"
      initial-cluster: "k8s-master01=https://192.168.60.72:2380,k8s-master02=https://192.168.60.77:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - k8s-master02
      - 192.168.60.77
    peerCertSANs:
      - k8s-master02
      - 192.168.60.77
networking:
  # This CIDR is a calico default. Substitute or remove for your CNI provider.
  podSubnet: "172.168.0.0/16"
EOF

kubeadm alpha phase certs all --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig controller-manager --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig scheduler --config kubeadm-config.yaml
kubeadm alpha phase kubelet config write-to-disk --config kubeadm-config.yaml
kubeadm alpha phase kubelet write-env-file --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig kubelet --config kubeadm-config.yaml
systemctl restart kubelet

export CP0_IP=192.168.60.72
export CP0_HOSTNAME=k8s-master01
export CP1_IP=192.168.60.77
export CP1_HOSTNAME=k8s-master02

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP1_HOSTNAME} https://${CP1_IP}:2380
kubeadm alpha phase etcd local --config kubeadm-config.yaml

kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
kubeadm alpha phase controlplane all --config kubeadm-config.yaml
kubeadm alpha phase mark-master --config kubeadm-config.yaml

sed -i "s/192.168.60.72:6443/192.168.60.77:6443/g" /etc/kubernetes/admin.conf


# k8s-master03

cat << EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- k8s-master01
- k8s-master02
- k8s-master03
- k8s-master-lb
- 192.168.60.72
- 192.168.60.77
- 192.168.60.78
- 192.168.60.79
#api:
#  controlPlaneEndpoint: "192.168.60.79:6443"
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://192.168.60.78:2379"
      advertise-client-urls: "https://192.168.60.78:2379"
      listen-peer-urls: "https://192.168.60.78:2380"
      initial-advertise-peer-urls: "https://192.168.60.78:2380"
      initial-cluster: "k8s-master01=https://192.168.60.72:2380,k8s-master02=https://192.168.60.77:2380,k8s-master03=https://192.168.60.78:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - k8s-master03
      - 192.168.60.78
    peerCertSANs:
      - k8s-master03
      - 192.168.60.78
networking:
  # This CIDR is a calico default. Substitute or remove for your CNI provider.
  podSubnet: "172.168.0.0/16"
EOF

kubeadm alpha phase certs all --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig controller-manager --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig scheduler --config kubeadm-config.yaml
kubeadm alpha phase kubelet config write-to-disk --config kubeadm-config.yaml
kubeadm alpha phase kubelet write-env-file --config kubeadm-config.yaml
kubeadm alpha phase kubeconfig kubelet --config kubeadm-config.yaml
systemctl restart kubelet

export CP0_IP=192.168.60.72
export CP0_HOSTNAME=k8s-master01
export CP2_IP=192.168.60.78
export CP2_HOSTNAME=k8s-master03

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -n kube-system etcd-${CP0_HOSTNAME} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${CP0_IP}:2379 member add ${CP2_HOSTNAME} https://${CP2_IP}:2380
kubeadm alpha phase etcd local --config kubeadm-config.yaml

kubeadm alpha phase kubeconfig all --config kubeadm-config.yaml
kubeadm alpha phase controlplane all --config kubeadm-config.yaml
kubeadm alpha phase mark-master --config kubeadm-config.yaml

sed -i "s/192.168.60.72:6443/192.168.60.78:6443/g" /etc/kubernetes/admin.conf

# 在所有master上允许istio的自动注入
vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota

systemctl restart kubelet

# 在k8s-master01上允许master上部署pod
kubectl taint nodes --all node-role.kubernetes.io/master-

# 在k8s-master01上安装calico
kubectl apply -f calico/

# 在k8s-master01上安装metrics-server
kubectl apply -f metrics-server/

# 在k8s-master01上安装heapster
kubectl apply -f heapster/

# 在k8s-master01上安装dashboard
kubectl apply -f dashboard/

# 在k8s-master01上后去dashboard的登录token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLXFyOW01Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJjNWIwY2I1Ny05NjFkLTExZTgtODM5Ni0wMDUwNTY4YTJhM2IiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.oNi7bXONJMrB4WurvsPa0E6nemQbkNM_vQGxdIbGN7WF_k-RK9zbduIhhlGIrtQasoV-uSEMu52TbcC6T_dd6odtvvOrrk2giqqrR_5uHsy2sqBKhu3MNW1hvhtBaVaiKPXWxuESeeb29ELRpYT6ZgsKWj6opKBF-i1K4BKjYip-0-HaVllfaP6IuEHBL_UVOmxcBUA2z7OAOWH3kGmHDm1P4peMlpBsMMMBEfawszJgIFn27Cm_MvH-cqZFIu9dPT0oTPwj9rvTGIw1FVHBc4r0a8XbvWVzpEgjfxfCzwtyiQ0RHeYo-yRyr_igljCjwPRccaHjctBEb_E3skpJ4w
```


- 在k8s-master01上设置proxy高可用

```
kubectl edit -n kube-system configmap/kube-proxy
    server: https://192.168.60.79:16443
```

- 在master上重启proxy

```
kubectl get pods --all-namespaces -o wide | grep proxy

kubectl delete pod -n kube-system kube-proxy-XXX
```

- 在master上允许hpa通过接口采集数据，修改`/etc/kubernetes/manifests/kube-controller-manager.yaml`

```
$ vi /etc/kubernetes/manifests/kube-controller-manager.yaml
  - --horizontal-pod-autoscaler-use-rest-clients=false

# 重启kubelet
$ systemctl restart kubelet
```

- 在workers上加入kubernetes集群

```
kubeadm join 192.168.60.72:6443 --token dt48lp.j448b22z81l3kut2 --discovery-token-ca-cert-hash sha256:d50efdf5f5dbe45f35209c56cc5fbea52aecc82a3384d1c2c12c0193958769a5
```

- 在workers上修改kubernetes集群设置

```
sed -i "s/192.168.60.72:6443/192.168.60.79:16443/g" /etc/kubernetes/bootstrap-kubelet.conf
sed -i "s/192.168.60.77:6443/192.168.60.79:16443/g" /etc/kubernetes/bootstrap-kubelet.conf
sed -i "s/192.168.60.78:6443/192.168.60.79:16443/g" /etc/kubernetes/bootstrap-kubelet.conf

sed -i "s/192.168.60.72:6443/192.168.60.79:16443/g" /etc/kubernetes/kubelet.conf
sed -i "s/192.168.60.77:6443/192.168.60.79:16443/g" /etc/kubernetes/kubelet.conf
sed -i "s/192.168.60.78:6443/192.168.60.79:16443/g" /etc/kubernetes/kubelet.conf

grep 192.168.60 /etc/kubernetes/*.conf

systemctl restart docker kubelet
```

```
kubectl get nodes
NAME           STATUS    ROLES     AGE       VERSION
k8s-master01   Ready     master    2h        v1.11.1
k8s-master02   Ready     master    2h        v1.11.1
k8s-master03   Ready     master    2h        v1.11.1
k8s-node01     Ready     <none>    5m        v1.11.1
k8s-node02     Ready     <none>    5m        v1.11.1
k8s-node03     Ready     <none>    4m        v1.11.1
k8s-node04     Ready     <none>    4m        v1.11.1
k8s-node05     Ready     <none>    4m        v1.11.1
k8s-node06     Ready     <none>    4m        v1.11.1
k8s-node07     Ready     <none>    3m        v1.11.1
k8s-node08     Ready     <none>    3m        v1.11.1
```

```
kubectl label nodes k8s-node01 role=worker
kubectl label nodes k8s-node02 role=worker
kubectl label nodes k8s-node03 role=worker
kubectl label nodes k8s-node04 role=worker

kubectl label nodes k8s-node05 role=testenv
kubectl label nodes k8s-node06 role=testenv
kubectl label nodes k8s-node07 role=testenv
kubectl label nodes k8s-node08 role=testenv

kubectl label nodes k8s-node06 store=localstorage
kubectl label nodes k8s-node07 store=localstorage
kubectl label nodes k8s-node08 store=localstorage
```


- 验证集群高可用

```
# 创建一个replicas=3的nginx deployment
$ kubectl run nginx --image=k8s-reg.io/public/nginx --replicas=3 --port=80
deployment "nginx" created

# 检查nginx pod的创建情况
$ kubectl get pods -l=run=nginx -o wide
NAME                     READY     STATUS    RESTARTS   AGE       IP             NODE
nginx-58b94844fd-7z22d   1/1       Running   0          8s        172.168.5.2    k8s-node03
nginx-58b94844fd-lh82w   1/1       Running   0          8s        172.168.3.11   k8s-node01
nginx-58b94844fd-rkvtb   1/1       Running   0          8s        172.168.9.2    k8s-node07

# 创建nginx的NodePort service
$ kubectl expose deployment nginx --type=NodePort --port=80
service "nginx" exposed

# 检查nginx service的创建情况
$ kubectl get svc -l=run=nginx -o wide
NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE       SELECTOR
nginx     NodePort   10.102.127.3   <none>        80:31065/TCP   17s       run=nginx

# 检查nginx NodePort service是否正常提供服务
$ curl k8s-master-lb:31065
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

- pod之间互访测试

```
kubectl run nginx-client -ti --rm --image=k8s-reg.io/public/alpine-curl -- ash
/ # wget -O - nginx
Connecting to nginx (10.102.101.78:80)
index.html           100% |*****************************************|   612   0:00:00 ETA

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


kubectl delete deploy,svc nginx-server
```

- 测试HPA自动扩展

```
# 创建测试服务
kubectl run nginx-server --requests=cpu=10m --image=k8s-reg.io/public/nginx --port=80
kubectl expose deployment nginx-server --port=80

# 创建hpa
kubectl autoscale deployment nginx-server --cpu-percent=10 --min=1 --max=10
kubectl get hpa
kubectl describe hpa nginx-server

# 给测试服务增加负载
kubectl run -ti --rm load-generator --image=k8s-reg.io/public/busybox -- ash
wget -q -O- http://nginx-server.default.svc.cluster.local
while true; do wget -q -O- http://nginx-server.default.svc.cluster.local; done

# 检查hpa自动扩展情况，一般需要等待几分钟。结束增加负载后，pod自动缩容（自动缩容需要大概10-15分钟）
kubectl get hpa -w

# 删除测试数据
kubectl delete deploy,svc,hpa nginx-server
```
