# kubeadm-highavailiability - 基于kubeadmin的kubernetes高可用集群部署

![k8s logo](images/Kubernetes.png)

---

- [GitHub项目地址](https://github.com/cookeem/kubeadm-ha/)
- [OSChina项目地址](https://git.oschina.net/cookeem/kubeadm-ha/)

---

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
    1. [kubernetes相关服务安装](#kubernetes相关服务安装)
    1. [docker镜像导入](#docker镜像导入)
1. [第一台master初始化](#第一台master初始化)
    1. [独立etcd集群部署](#独立etcd集群部署)
    1. [kubeadm初始化](#kubeadm初始化)
    1. [flannel网络组件安装](#flannel网络组件安装)
    1. [dashboard组件安装](#dashboard组件安装)
    1. [heapster组件安装](#heapster组件安装)
    1. [验证第一台master安装](#验证第一台master安装)
1. [master集群高可用设置](#master集群高可用设置)
    1. [复制配置](#复制配置)
    1. [创建证书](#创建证书)
    1. [修改配置](#修改配置)
    1. [验证高可用安装](#验证高可用安装)
    1. [keepalived安装配置](#keepalived安装配置)
    1. [nginx负载均衡配置](#nginx负载均衡配置)
    1. [验证master集群高可用](#验证master集群高可用)
1. [node节点加入高可用集群设置](#node节点加入高可用集群设置)
    1. [kubeadm加入高可用集群](#kubeadm加入高可用集群)
    1. [部署应用验证集群](#部署应用验证集群)
    

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

> keepalived集群设置一个虚拟ip地址，虚拟ip地址指向k8s-master1、k8s-master2、k8s-master3。

> nginx用于k8s-master1、k8s-master2、k8s-master3的apiserver的负载均衡。外部kubectl以及nodes访问apiserver的时候就可以用过keepalived的虚拟ip(192.168.60.80)以及nginx端口(8443)访问master集群的apiserver。

---
[返回目录](#目录)

#### 主机节点清单

 主机名 | IP地址 | 说明 | 组件 
 :--- | :--- | :--- | :---
 k8s-master1 | 192.168.60.71 | master节点1 | etcd、kubelet、kube-apiserver、kube-scheduler、kube-proxy
 k8s-master2 | 192.168.60.72 | master节点2 | etcd、kubelet、kube-apiserver、kube-scheduler、kube-proxy
 k8s-master3 | 192.168.60.73 | master节点3 | etcd、kubelet、kube-apiserver、kube-scheduler、kube-proxy
 无 | 192.168.60.80 | keepalived虚拟IP | 无
 k8s-node1 ~ 8 | 192.168.60.81 ~ 88 | 8个node节点 | kubelet、kube-proxy

---
[返回目录](#目录)

### 安装前准备

#### 版本信息

* Linux版本：CentOS 7.3.1611

```
cat /etc/redhat-release 
CentOS Linux release 7.3.1611 (Core) 
```

* docker版本：1.12.6

```
$ docker version
Client:
 Version:      1.12.6
 API version:  1.24
 Go version:   go1.6.4
 Git commit:   78d1802
 Built:        Tue Jan 10 20:20:01 2017
 OS/Arch:      linux/amd64

Server:
 Version:      1.12.6
 API version:  1.24
 Go version:   go1.6.4
 Git commit:   78d1802
 Built:        Tue Jan 10 20:20:01 2017
 OS/Arch:      linux/amd64
```

* kubeadm版本：v1.6.4

```
$ kubeadm version
kubeadm version: version.Info{Major:"1", Minor:"6", GitVersion:"v1.6.4", GitCommit:"d6f433224538d4f9ca2f7ae19b252e6fcb66a3ae", GitTreeState:"clean", BuildDate:"2017-05-19T18:33:17Z", GoVersion:"go1.7.5", Compiler:"gc", Platform:"linux/amd64"}
```

* kubelet版本：v1.6.4

```
$ kubelet --version
Kubernetes v1.6.4
```

---

[返回目录](#目录)

#### 所需docker镜像

* 国内可以使用daocloud加速器下载相关镜像，然后通过docker save、docker load把本地下载的镜像放到kubernetes集群的所在机器上，daocloud加速器链接如下：

[https://www.daocloud.io/mirror#accelerator-doc](https://www.daocloud.io/mirror#accelerator-doc)

* 在本机pull相关docker镜像

```
docker pull gcr.io/google_containers/kube-apiserver-amd64:v1.6.4
docker pull gcr.io/google_containers/kube-proxy-amd64:v1.6.4
docker pull gcr.io/google_containers/kube-controller-manager-amd64:v1.6.4
docker pull gcr.io/google_containers/kube-scheduler-amd64:v1.6.4
docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.6.1
docker pull quay.io/coreos/flannel:v0.7.1-amd64
docker pull gcr.io/google_containers/heapster-amd64:v1.3.0
docker pull gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.1
docker pull gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.1
docker pull gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.1
docker pull gcr.io/google_containers/etcd-amd64:3.0.17
docker pull gcr.io/google_containers/heapster-grafana-amd64:v4.0.2
docker pull gcr.io/google_containers/heapster-influxdb-amd64:v1.1.1
docker pull nginx:latest
docker pull gcr.io/google_containers/pause-amd64:3.0
```

---
[返回目录](#目录)

#### 系统设置

---
[返回目录](#目录)

### kubernetes安装

#### kubernetes相关服务安装

---
[返回目录](#目录)

#### docker镜像导入

---
[返回目录](#目录)

### 第一台master初始化

#### 独立etcd集群部署

---
[返回目录](#目录)

#### kubeadm初始化

---
[返回目录](#目录)

#### flannel网络组件安装

---
[返回目录](#目录)

#### dashboard组件安装

---
[返回目录](#目录)

#### heapster组件安装

---
[返回目录](#目录)

#### 验证第一台master安装

---
[返回目录](#目录)

### master集群高可用设置

#### 复制配置

---
[返回目录](#目录)

#### 创建证书

---
[返回目录](#目录)

#### 修改配置

---
[返回目录](#目录)

#### 验证高可用安装

---
[返回目录](#目录)

#### keepalived安装配置

---
[返回目录](#目录)

#### nginx负载均衡配置

---
[返回目录](#目录)

#### 验证master集群高可用

---
[返回目录](#目录)

### node节点加入高可用集群设置

#### kubeadm加入高可用集群

---
[返回目录](#目录)

#### 部署应用验证集群

---
[返回目录](#目录)

