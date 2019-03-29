# kubeadm-highavailiability (English / 中文) - 基于kubeadm的kubernetes高可用集群部署，支持v1.14.x v1.11.x v1.9.x v1.7.x v1.6.x版本

![k8s logo](images/kubernetes.png)

- [中文文档(for v1.14.x版本)](README_CN.md)
- [English document(for v1.14.x version)](README.md)
- [中文文档(for v1.11.x版本)](v1.11/README_CN.md)
- [English document(for v1.11.x version)](v1.11/README.md)
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

## 目录

- 该指引适用于v1.14.x版本的kubernetes集群

- [部署架构](#部署架构)
  - [部署架构概要](#部署架构概要)
  - [主机清单](#主机清单)
  - [版本信息](#版本信息)
- [安装前准备](#安装前准备)
  - [系统更新](#系统更新)
  - [防火墙设置](#防火墙设置)
  - [系统参数设置](#系统参数设置)
  - [master节点互信设置](#master节点互信设置)
- [安装组件](#安装组件)
  - [docker安装](#docker安装)
  - [kubernetes管理软件安装](#kubernetes管理软件安装)
  - [keepalived安装](#keepalived安装)
- [创建配置文件](#创建配置文件)
  - [生成相关配置文件](#生成相关配置文件)
  - [配置文件清单](#配置文件清单)
- [启动load-balancer](#启动loadbalancer)
  - [启动keepalived](#启动keepalived)
  - [启动nginx-lb](#启动nginxlb)
- [初始化高可用master集群](#初始化高可用master集群)
  - [安装第一个master节点](#安装第一个master节点)
  - [把其他master节点加入controlplane控制平面](#把其他master节点加入controlplane控制平面)
- [把nginx-lb作为kubernetes集群基础服务](#把nginxlb作为kubernetes集群基础服务)
- [添加worker节点](#添加worker节点)
- [安装组件](#安装组件)
  - [kubernetes-dashboard](#kubernetes-dashboard)
    - [安装kubernetes-dashboard](#安装kubernetes-dashboard)
    - [登录kubernetes-dashboard](#登录kubernetes-dashboard)
    - [使用kubernetes-dashboard管理集群](#使用kubernetes-dashboard管理集群)
  - [heapster](#heapster)
    - [安装heapster](#安装heapster)
    - [验证heapster度量信息采集](#验证heapster度量信息采集)
  - [metrics-server](#metrics-server)
    - [安装metrics-server](#安装metrics-server)
  - [prometheus](#prometheus)
    - [安装prometheus相关组件](#安装prometheus相关组件)
    - [使用prometheus监控性能](#使用prometheus监控性能)
    - [使用alertmanager验证告警](#使用alertmanager验证告警)
  - [grafana](#grafana)
    - [安装grafana](#安装grafana)
    - [使用grafana呈现prometheus性能指标](#使用grafana呈现prometheus性能指标)
  - [istio](#istio)
    - [安装istio](#安装istio)
    - [使用istio进行AB测试](#使用istio进行AB测试)
    - [进行服务跟踪](#进行服务跟踪)
    - [进行流量监测](#进行流量监测)
  - [traefik](#traefik)
    - [安装traefik](#安装traefik)
    - [使用traefik作为边界路由器](#使用traefik作为边界路由器)
- [集群验证](#集群验证)
  - [集群高可用验证测试](#集群高可用验证测试)
  - [nodePort测试](#nodeport测试)
  - [集群内服务测试](#集群内服务测试)
  - [测试自动扩缩容](#测试自动扩缩容)
- [证书到期更新](#证书到期更新)


## 部署架构

### 部署架构概要

![](images/kubernetes-ha-architecture.png)

- 如上图，kubernetes高可用集群我们使用`Stacked etcd topology`的模式进行部署，每一个master节点（control plane node）运行`kube-apiserver`、`kube-scheduler`、`kube-controller-manager`，每一个master节点同时也运行`etcd`作为集群运行状态存储。其中`kube-apiserver`以负载均衡（load balancer）的方式向worker节点提供服务。

### 主机清单

主机名 | IP地址 | 说明 | 组件
:--- | :--- | :--- | :---
demo-vip.local     | 172.20.10.9 | keepalived浮动IP | 无
demo-01.local ~ demo-03.local | 172.20.10.10 ~ 12 | master节点 * 3 | keepalived、nginx、kubelet、kube-apiserver、kube-scheduler、kube-controller-manager、etcd
demo-04.local     | 172.20.10.13 | worker节点 * 1 | kubelet

### 版本信息

- 系统版本信息

```bash
# Linux发行版信息
$ cat /etc/redhat-release
CentOS Linux release 7.6.1810 (Core)

# Linux内核
$ uname -a
Linux demo-01.local 5.0.4-1.el7.elrepo.x86_64 #1 SMP Sat Mar 23 18:00:44 EDT 2019 x86_64 x86_64 x86_64 GNU/Linux

# kubernetes版本
$ kubelet --version
Kubernetes v1.14.0

# docker-ce版本信息
$ docker version
Client:
 Version:           18.09.3
 API version:       1.39
 Go version:        go1.10.8
 Git commit:        774a1f4
 Built:             Thu Feb 28 06:33:21 2019
 OS/Arch:           linux/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          18.09.3
  API version:      1.39 (minimum version 1.12)
  Go version:       go1.10.8
  Git commit:       774a1f4
  Built:            Thu Feb 28 06:02:24 2019
  OS/Arch:          linux/amd64
  Experimental:     false

# docker-compose版本
$ docker-compose version
docker-compose version 1.18.0, build 8dd22a9
docker-py version: 2.6.1
CPython version: 3.4.9
OpenSSL version: OpenSSL 1.0.2k-fips  26 Jan 2017
```

- 组件版本信息

组件 | 版本 | 备注
:--- | :--- | :---
calico | v3.6.0 | 网络组件
kubernetes-dashboard | v1.10.1 | kubernetes管理UI
heapster | v1.5.4 | 性能采集组件（kubernetes-dashboard使用）
metrics-server | v0.3.1 | 性能采集组件
prometheus | v2.8.0 | 性能监控组件
alertmanager | v0.16.1 | 告警管理组件
node-exporter | v0.17.0 | 节点性能采集组件
kube-state-metrics | v1.5.0 | kubernetes集群状态采集组件
grafana | v6.0.2 | 性能呈现组件
istio | v1.1.1 | 服务网格
traefik | v1.7.9 | ingress边界路由组件

## 安装前准备

### 系统更新

- 更新操作系统内核

```bash
# 设置elrepo，linux内核更新yum源
$ rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
$ rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

# 查看最新的操作系统内核版本，这里版本为5.0.4-1.el7.elrepo
$ yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
已加载插件：fastestmirror
Loading mirror speeds from cached hostfile
 * elrepo-kernel: mirror-hk.koddos.net
可安装的软件包
kernel-lt.x86_64                             4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-devel.x86_64                       4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-doc.noarch                         4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-headers.x86_64                     4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-tools.x86_64                       4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-tools-libs.x86_64                  4.4.177-1.el7.elrepo            elrepo-kernel
kernel-lt-tools-libs-devel.x86_64            4.4.177-1.el7.elrepo            elrepo-kernel
kernel-ml-devel.x86_64                       5.0.4-1.el7.elrepo              elrepo-kernel
kernel-ml-doc.noarch                         5.0.4-1.el7.elrepo              elrepo-kernel
kernel-ml-headers.x86_64                     5.0.4-1.el7.elrepo              elrepo-kernel
kernel-ml-tools.x86_64                       5.0.4-1.el7.elrepo              elrepo-kernel
kernel-ml-tools-libs.x86_64                  5.0.4-1.el7.elrepo              elrepo-kernel
kernel-ml-tools-libs-devel.x86_64            5.0.4-1.el7.elrepo              elrepo-kernel
perf.x86_64                                  5.0.4-1.el7.elrepo              elrepo-kernel
python-perf.x86_64                           5.0.4-1.el7.elrepo              elrepo-kernel

# 安装新版本内核kernel-ml-5.0.4-1.el7.elrepo
$ yum --disablerepo="*" --enablerepo="elrepo-kernel" install -y kernel-ml-5.0.4-1.el7.elrepo

# 修改/etc/default/grub的启动选项
$ vi /etc/default/grub
GRUB_DEFAULT=0

# 创建grub启动配置文件
$ grub2-mkconfig -o /boot/grub2/grub.cfg

# 重启系统
$ reboot

# 验证系统版本，已经更新为5.0.4-1.el7.elrepo.x86_64
$ uname -a
Linux demo-01.local 5.0.4-1.el7.elrepo.x86_64 #1 SMP Sat Mar 23 18:00:44 EDT 2019 x86_64 x86_64 x86_64 GNU/Linux
```

- 更新系统软件包版本

```bash
# 更新系统软件包版本
$ yum update -y
```

### 防火墙设置

- 所有节点开启firewalld防火墙

```sh
# 重启防火墙
$ systemctl enable firewalld
$ systemctl restart firewalld
$ systemctl status firewalld
```

- master节点需要开放的端口

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 16443*    | Load balancer Kubernetes API server port
TCP | Inbound | 6443*     | Kubernetes API server
TCP | Inbound | 4001      | etcd listen client port
TCP | Inbound | 2379-2380 | etcd server client API
TCP | Inbound | 10250     | Kubelet API
TCP | Inbound | 10251     | kube-scheduler
TCP | Inbound | 10252     | kube-controller-manager
TCP | Inbound | 30000-32767 | NodePort Services

- 所有master节点设置防火墙策略

```bash
# 开放端口策略
$ firewall-cmd --zone=public --add-port=16443/tcp --permanent
$ firewall-cmd --zone=public --add-port=6443/tcp --permanent
$ firewall-cmd --zone=public --add-port=4001/tcp --permanent
$ firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=10251/tcp --permanent
$ firewall-cmd --zone=public --add-port=10252/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
$ firewall-cmd --reload

# 查看端口开放状态
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

- worker节点需要开放的端口

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 10250       | Kubelet API
TCP | Inbound | 30000-32767 | NodePort Services

- 所有worker节点设置防火墙策略

```sh
# 开放端口策略
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
$ firewall-cmd --reload

# 查看端口开放状态
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

- 所有节点必须清理iptables上的icmp禁止策略，否则会引起集群网络检测异常

```bash
# 为防止firewalld服务重启iptables被重置，把策略更新放在crontab中定期更新
$ crontab -e
* * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
```

### 系统参数设置

- 在所有节点上设置SELINUX为permissive模式

```sh
# 修改配置
$ vi /etc/selinux/config
SELINUX=permissive

$ setenforce 0
```

- 在所有节点上设置iptables参数

```sh
# 所有节点配置ip转发
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# 让配置生效
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

- 注意，安装kubernetes集群，要求每个节点至少有2个cpu。

### master节点互信设置

## 安装组件

### docker安装

### kubernetes管理软件安装

### keepalived安装

## 创建配置文件

### 生成相关配置文件

### 配置文件清单

## 启动load-balancer

### 启动keepalived

### 启动nginx-lb

## 初始化高可用master集群

### 安装第一个master节点

### 把其他master节点加入controlplane控制平面

## 把nginx-lb作为kubernetes集群基础服务

## 添加worker节点

## 安装组件

### kubernetes-dashboard

#### 安装kubernetes-dashboard

#### 登录kubernetes-dashboard

#### 使用kubernetes-dashboard管理集群

### heapster

#### 安装heapster

#### 验证heapster度量信息采集

### metrics-server

#### 安装metrics-server

### prometheus

#### 安装prometheus相关组件

#### 使用prometheus监控性能

#### 使用alertmanager验证告警

### grafana

#### 安装grafana

#### 使用grafana呈现prometheus性能指标

### istio

#### 安装istio

#### 使用istio进行AB测试

#### 进行服务跟踪

#### 进行流量监测

### traefik

#### 安装traefik

#### 使用traefik作为边界路由器

## 集群验证

### 集群高可用验证测试

### nodePort测试

### 集群内服务测试

### 测试自动扩缩容

## 证书到期更新

```bash
# 第一个master执行
$ kubeadm init --config=/root/kubeadm-config.yaml --experimental-upload-certs
You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 172.20.10.9:16443 --token m8k0m4.eheru9acqftbre89 \
    --discovery-token-ca-cert-hash sha256:e97e9db0ca6839cae2989571346b6142f7e928861728d5067a979668aaf46954 \
    --experimental-control-plane --certificate-key b1788f02d442c623d28f5281bb566bf4fcd9e739c45f127a95ea07b558538244

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --experimental-upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.20.10.9:16443 --token m8k0m4.eheru9acqftbre89 \
    --discovery-token-ca-cert-hash sha256:e97e9db0ca6839cae2989571346b6142f7e928861728d5067a979668aaf46954


#
$ cat << EOF >> ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF

# 安装calico
$ kubectl apply -f /root/kubeadm-init/calico/calico.yaml
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
daemonset.extensions/calico-node created
serviceaccount/calico-node created
deployment.extensions/calico-kube-controllers created
serviceaccount/calico-kube-controllers created

# 查看pod状态
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-7bfdd87774-gh4rf   1/1     Running   0          24s
kube-system   calico-node-4kcrh                          1/1     Running   0          24s
kube-system   coredns-fb8b8dccf-7fp98                    1/1     Running   0          4m42s
kube-system   coredns-fb8b8dccf-l8xzz                    1/1     Running   0          4m42s
kube-system   etcd-demo-01.local                         1/1     Running   0          4m15s
kube-system   kube-apiserver-demo-01.local               1/1     Running   0          3m59s
kube-system   kube-controller-manager-demo-01.local      1/1     Running   0          3m58s
kube-system   kube-proxy-qf9zp                           1/1     Running   0          4m42s
kube-system   kube-scheduler-demo-01.local               1/1     Running   0          4m17s

# 查看节点状态
$ kubectl get nodes
NAME            STATUS   ROLES    AGE    VERSION
demo-01.local   Ready    master   5m3s   v1.14.0

# 在其他的master节点执行，把节点加入到controlplane
$ kubeadm join 172.20.10.9:16443 --token m8k0m4.eheru9acqftbre89 \
  --discovery-token-ca-cert-hash sha256:e97e9db0ca6839cae2989571346b6142f7e928861728d5067a979668aaf46954 \
  --experimental-control-plane --certificate-key b1788f02d442c623d28f5281bb566bf4fcd9e739c45f127a95ea07b558538244

# 查看pod状态
$ kubectl get pods -n kube-system -o wide
NAME                                       READY   STATUS    RESTARTS   AGE     IP             NODE            NOMINATED NODE   READINESS GATES
calico-kube-controllers-7bfdd87774-gh4rf   1/1     Running   0          5m22s   192.168.8.65   demo-01.local   <none>           <none>
calico-node-4kcrh                          1/1     Running   0          5m22s   172.20.10.10   demo-01.local   <none>           <none>
calico-node-4ljlm                          1/1     Running   0          3m2s    172.20.10.11   demo-02.local   <none>           <none>
calico-node-wh5rs                          1/1     Running   0          102s    172.20.10.12   demo-03.local   <none>           <none>
coredns-fb8b8dccf-7fp98                    1/1     Running   0          9m40s   192.168.8.67   demo-01.local   <none>           <none>
coredns-fb8b8dccf-l8xzz                    1/1     Running   0          9m40s   192.168.8.66   demo-01.local   <none>           <none>
etcd-demo-01.local                         1/1     Running   0          9m13s   172.20.10.10   demo-01.local   <none>           <none>
etcd-demo-02.local                         1/1     Running   0          3m1s    172.20.10.11   demo-02.local   <none>           <none>
etcd-demo-03.local                         1/1     Running   0          100s    172.20.10.12   demo-03.local   <none>           <none>
kube-apiserver-demo-01.local               1/1     Running   0          8m57s   172.20.10.10   demo-01.local   <none>           <none>
kube-apiserver-demo-02.local               1/1     Running   0          3m2s    172.20.10.11   demo-02.local   <none>           <none>
kube-apiserver-demo-03.local               1/1     Running   0          101s    172.20.10.12   demo-03.local   <none>           <none>
kube-controller-manager-demo-01.local      1/1     Running   0          8m56s   172.20.10.10   demo-01.local   <none>           <none>
kube-controller-manager-demo-02.local      1/1     Running   0          3m2s    172.20.10.11   demo-02.local   <none>           <none>
kube-controller-manager-demo-03.local      1/1     Running   0          101s    172.20.10.12   demo-03.local   <none>           <none>
kube-proxy-mt6z6                           1/1     Running   0          102s    172.20.10.12   demo-03.local   <none>           <none>
kube-proxy-qf9zp                           1/1     Running   0          9m40s   172.20.10.10   demo-01.local   <none>           <none>
kube-proxy-sfhrs                           1/1     Running   0          3m2s    172.20.10.11   demo-02.local   <none>           <none>
kube-scheduler-demo-01.local               1/1     Running   0          9m15s   172.20.10.10   demo-01.local   <none>           <none>
kube-scheduler-demo-02.local               1/1     Running   0          3m2s    172.20.10.11   demo-02.local   <none>           <none>
kube-scheduler-demo-03.local               1/1     Running   0          101s    172.20.10.12   demo-03.local   <none>           <none>

# 查看节点状态
$ kubectl get nodes
NAME            STATUS   ROLES    AGE     VERSION
demo-01.local   Ready    master   10m     v1.14.0
demo-02.local   Ready    master   3m10s   v1.14.0
demo-03.local   Ready    master   110s    v1.14.0

# 所有节点暂停kubelet
$ systemctl stop kubelet

# 所有节点停止并删除nginx-lb容器
$ docker stop nginx-lb && docker rm nginx-lb

# 在第一个master节点上执行
$ export K8SHA_HOST1=demo-01.local
$ export K8SHA_HOST2=demo-02.local
$ export K8SHA_HOST3=demo-03.local
$ scp /root/nginx-lb/nginx-lb.conf root@${K8SHA_HOST1}:/etc/kubernetes/
$ scp /root/nginx-lb/nginx-lb.conf root@${K8SHA_HOST2}:/etc/kubernetes/
$ scp /root/nginx-lb/nginx-lb.conf root@${K8SHA_HOST3}:/etc/kubernetes/
$ scp /root/nginx-lb/nginx-lb.yaml root@${K8SHA_HOST1}:/etc/kubernetes/manifests/
$ scp /root/nginx-lb/nginx-lb.yaml root@${K8SHA_HOST2}:/etc/kubernetes/manifests/
$ scp /root/nginx-lb/nginx-lb.yaml root@${K8SHA_HOST3}:/etc/kubernetes/manifests/

# 在所有master节点重启kubelet和docker
$ systemctl restart kubelet docker

# 查看所有pod状态，增加了nginx-lb的pod
$ kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE   IP             NODE            NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-7bfdd87774-gh4rf   1/1     Running   1          24m   192.168.8.69   demo-01.local   <none>           <none>
kube-system   calico-node-4kcrh                          1/1     Running   1          24m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   calico-node-4ljlm                          1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   calico-node-wh5rs                          1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   coredns-fb8b8dccf-7fp98                    1/1     Running   1          28m   192.168.8.70   demo-01.local   <none>           <none>
kube-system   coredns-fb8b8dccf-l8xzz                    1/1     Running   2          28m   192.168.8.68   demo-01.local   <none>           <none>
kube-system   etcd-demo-01.local                         1/1     Running   1          28m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   etcd-demo-02.local                         1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   etcd-demo-03.local                         1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   kube-apiserver-demo-01.local               1/1     Running   1          28m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   kube-apiserver-demo-02.local               1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   kube-apiserver-demo-03.local               1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   kube-controller-manager-demo-01.local      1/1     Running   1          28m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   kube-controller-manager-demo-02.local      1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   kube-controller-manager-demo-03.local      1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   kube-proxy-mt6z6                           1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   kube-proxy-qf9zp                           1/1     Running   1          28m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   kube-proxy-sfhrs                           1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   kube-scheduler-demo-01.local               1/1     Running   1          28m   172.20.10.10   demo-01.local   <none>           <none>
kube-system   kube-scheduler-demo-02.local               1/1     Running   1          22m   172.20.10.11   demo-02.local   <none>           <none>
kube-system   kube-scheduler-demo-03.local               1/1     Running   1          20m   172.20.10.12   demo-03.local   <none>           <none>
kube-system   nginx-lb-demo-01.local                     1/1     Running   0          90s   172.20.10.10   demo-01.local   <none>           <none>
kube-system   nginx-lb-demo-02.local                     1/1     Running   0          72s   172.20.10.11   demo-02.local   <none>           <none>
kube-system   nginx-lb-demo-03.local                     1/1     Running   0          78s   172.20.10.12   demo-03.local   <none>           <none>

# 在worker节点上执行
$ kubeadm join 172.20.10.9:16443 --token m8k0m4.eheru9acqftbre89 \
    --discovery-token-ca-cert-hash sha256:e97e9db0ca6839cae2989571346b6142f7e928861728d5067a979668aaf46954

#
$ kubectl get nodes
NAME            STATUS   ROLES    AGE   VERSION
demo-01.local   Ready    master   99m   v1.14.0
demo-02.local   Ready    master   92m   v1.14.0
demo-03.local   Ready    master   90m   v1.14.0
demo-04.local   Ready    <none>   14s   v1.14.0

# kubectl自动完成
$ yum install -y bash-completion
$ source <(kubectl completion bash)
$ kubectl completion bash > ~/.kube/completion.bash.inc
  printf "
  # Kubectl shell completion
  source '$HOME/.kube/completion.bash.inc'
  " >> $HOME/.bash_profile
  source $HOME/.bash_profile

# 允许master部署应用
$ kubectl taint nodes --all node-role.kubernetes.io/master-

# 安装kubernetes-dashboard
$ kubectl label nodes demo-01.local app=kube-system
$ kubectl label nodes demo-02.local app=kube-system
$ kubectl label nodes demo-03.local app=kube-system

$ kubectl apply -f /root/kubeadm-init/kubernetes-dashboard/kubernetes-dashboard.yaml
secret/kubernetes-dashboard-certs created
serviceaccount/kubernetes-dashboard created
role.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
deployment.apps/kubernetes-dashboard created
service/kubernetes-dashboard created
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user created

# kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
Name:         admin-user-token-96m52
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin-user
              kubernetes.io/service-account.uid: fde9bd21-5108-11e9-8d69-08002712c9f2

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLTk2bTUyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJmZGU5YmQyMS01MTA4LTExZTktOGQ2OS0wODAwMjcxMmM5ZjIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.EkJE7RI89PdrDQrb8NMBGc7oOIlB3P2KEUUcKJO6jbun7YNW8ho_6vJUEgUuIgWoFqjb_jtMcuYHzw9Lo_Q8HsNih5a3GsuJcYFD7qFFOdroYf62FxAr82v8dYBmt2EzGy_yLK6SNibEeAIOFffosL7reIsVs3LcJMQTa2Q-aD9NrwXwdB3B90NZvzd1h6fjArObXKrwe5oeTLVgLFctXTV0hk9SNQxp6ptKpS4fxzMe8pzvI0Ft--FbG4vW2f0Cbd-hAAYi8eJyo65ndhQoq7-bYp2OFu6LbLnTCSPs8D10z0Wnv6o2RDA6Avgg7KT0M_zIRRiHubCJNDmwlTQk3Q

# 安装heapster

# 重建heapster-influxdb-amd64:v1.5.2镜像，修改/etc/config.toml文件
$ docker run -ti --rm --entrypoint "/bin/sh" k8s.gcr.io/heapster-influxdb-amd64:v1.5.2
sed -i "s/localhost/127.0.0.1/g" /etc/config.toml

$ docker ps | grep heapster | grep bin
a9aa804c95d7        k8s.gcr.io/heapster-influxdb-amd64:v1.5.2   "/bin/sh"                2 minutes ago       Up 2 minutes                            priceless_wilson

$ docker commit priceless_wilson k8s.gcr.io/heapster-influxdb-amd64:v1.5.2-fixed

$ kubectl apply -f /root/kubeadm-init/heapster/
clusterrolebinding.rbac.authorization.k8s.io/heapster created
clusterrole.rbac.authorization.k8s.io/heapster created
serviceaccount/heapster created
deployment.extensions/heapster created
service/heapster created
deployment.extensions/monitoring-influxdb created
service/monitoring-influxdb created

$ kubectl top pods -n kube-system
NAME                                       CPU(cores)   MEMORY(bytes)
calico-kube-controllers-7bfdd87774-gh4rf   1m           13Mi
calico-node-4kcrh                          21m          66Mi
calico-node-4ljlm                          23m          65Mi
calico-node-wh5rs                          23m          65Mi
calico-node-wwmpf                          18m          64Mi
coredns-fb8b8dccf-7fp98                    2m           11Mi
coredns-fb8b8dccf-l8xzz                    2m           11Mi
etcd-demo-01.local                         39m          89Mi
etcd-demo-02.local                         52m          84Mi
etcd-demo-03.local                         38m          82Mi
heapster-665bbb7c6f-wd559                  1m           28Mi
kube-apiserver-demo-01.local               77m          229Mi
kube-apiserver-demo-02.local               68m          243Mi
kube-apiserver-demo-03.local               77m          219Mi
kube-controller-manager-demo-01.local      19m          51Mi
kube-controller-manager-demo-02.local      1m           16Mi
kube-controller-manager-demo-03.local      1m           14Mi
kube-proxy-9mcnp                           3m           15Mi
kube-proxy-mt6z6                           1m           14Mi
kube-proxy-qf9zp                           1m           15Mi
kube-proxy-sfhrs                           0m           14Mi
kube-scheduler-demo-01.local               11m          16Mi
kube-scheduler-demo-02.local               1m           13Mi
kube-scheduler-demo-03.local               11m          16Mi
kubernetes-dashboard-5688c4f8bd-g6fnc      0m           20Mi
monitoring-influxdb-fb5756876-xx56f        0m           21Mi
nginx-lb-demo-01.local                     31m          3Mi
nginx-lb-demo-02.local                     0m           2Mi
nginx-lb-demo-03.local                     0m           2Mi

$ kubectl taint nodes --all node-role.kubernetes.io/master-
```