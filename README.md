# kubeadm-highavailiability - kubernetes high availiability deployment based on kubeadm

![k8s logo](images/Kubernetes.png)

- [中文文档](README_CN.md)
- [English document](README.md)

---

- [GitHub project URL](https://github.com/cookeem/kubeadm-ha/)
- [OSChina project URL](https://git.oschina.net/cookeem/kubeadm-ha/)

---

### category

1. [deployment architecture](#deployment-architecture)
    1. [deployment architecture summary](#deployment-architecture-summary)
    1. [detail deployment architecture](#detail-deployment-architecture)
    1. [hosts list](#hosts-list)
1. [prerequisites](#prerequisites)
    1. [version info](#version-info)
    1. [required docker images](#required-docker-images)
    1. [system configuration](#system-configuration)
1. [kubernetes installation](#kubernetes-installation)
    1. [kubernetes and related services installation](#kubernetes-and-related-services-installation)
    1. [load docker images](#load-docker-images)
1. [use kubeadm to init first master](#use-kubeadm-to-init-first-master)
    1. [deploy independent etcd tls cluster](#deploy-independent-etcd-tls-cluster)
    1. [kubeadm init](#kubeadm-init)
    1. [install flannel networks addon](#install-flannel-networks-addon)
    1. [install dashboard addon](#install-dashboard-addon)
    1. [install heapster addon](#install-heapster-addon)
1. [kubernetes masters high avialiability configuration](#kubernetes-masters-high-avialiability-configuration)
    1. [copy configuration files](#copy-configuration-files)
    1. [create certificatie](#create-certificatie)
    1. [edit configuration files](#edit-configuration-files)
    1. [verify master high avialiability](#verify-master-high-avialiability)
    1. [keepalived installation](#keepalived-installation)
    1. [nginx load balancer configuration](#nginx-load-balancer-configuration)
    1. [kube-proxy configuration](#kube-proxy-configuration)
    1. [verfify master high avialiability with keepalived](#verfify-master-high-avialiability-with-keepalived)
1. [k8s-nodes join the kubernetes cluster](#k8s-nodes-join-the-kubernetes-cluster)
    1. [use kubeadm to join the cluster](#use-kubeadm-to-join-the-cluster)
    1. [deploy nginx application to verify installation](#deploy-nginx-application-to-verify-installation)
    

### deployment architecture

#### deployment architecture summary

![ha logo](images/ha.png)

---
[category](#category)

#### detail deployment architecture

![k8s ha](images/k8s-ha.png)

* kubernetes components:

> kube-apiserver: exposes the Kubernetes API. It is the front-end for the Kubernetes control plane. It is designed to scale horizontally – that is, it scales by deploying more instances.

> etcd: is used as Kubernetes’ backing store. All cluster data is stored here. Always have a backup plan for etcd’s data for your Kubernetes cluster.


> kube-scheduler: watches newly created pods that have no node assigned, and selects a node for them to run on.


> kube-controller-manager: runs controllers, which are the background threads that handle routine tasks in the cluster. Logically, each controller is a separate process, but to reduce complexity, they are all compiled into a single binary and run in a single process.

> kubelet: is the primary node agent. It watches for pods that have been assigned to its node (either by apiserver or via local configuration file)

> kube-proxy: enables the Kubernetes service abstraction by maintaining network rules on the host and performing connection forwarding.


* load balancer

> keepalived cluster config a virtual IP address (192.168.60.80), this virtual IP address point to k8s-master1, k8s-master2, k8s-master3. 

> nginx service as the load balancer of k8s-master1, k8s-master2, k8s-master3's apiserver. The other nodes kubernetes services connect the keepalived virtual ip address (192.168.60.80) and nginx exposed port (8443) to communicate with the master cluster's apiservers. 

---
[category](#category)

#### hosts list

 HostName | IPAddress | Notes | Components 
 :--- | :--- | :--- | :---
 k8s-master1 | 192.168.60.71 | master node 1 | etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy
 k8s-master2 | 192.168.60.72 | master node 2 | etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy
 k8s-master3 | 192.168.60.73 | master node 3 | etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy
 N/A | 192.168.60.80 | keepalived virtual IP | N/A
 k8s-node1 ~ 8 | 192.168.60.81 ~ 88 | 8 nodes | kubelet, kube-proxy

---
[category](#category)

### prerequisites

#### version info

* Linux version: CentOS 7.3.1611

```
cat /etc/redhat-release 
CentOS Linux release 7.3.1611 (Core) 
```

* docker version: 1.12.6

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

* kubeadm version: v1.6.4

```
$ kubeadm version
kubeadm version: version.Info{Major:"1", Minor:"6", GitVersion:"v1.6.4", GitCommit:"d6f433224538d4f9ca2f7ae19b252e6fcb66a3ae", GitTreeState:"clean", BuildDate:"2017-05-19T18:33:17Z", GoVersion:"go1.7.5", Compiler:"gc", Platform:"linux/amd64"}
```

* kubelet version: v1.6.4

```
$ kubelet --version
Kubernetes v1.6.4
```

---

[category](#category)

#### required docker images

* on your local laptop MacOSX: pull相关docker镜像
* on your local laptop MacOSX: pull相关docker镜像

```
$ docker pull gcr.io/google_containers/kube-apiserver-amd64:v1.6.4
$ docker pull gcr.io/google_containers/kube-proxy-amd64:v1.6.4
$ docker pull gcr.io/google_containers/kube-controller-manager-amd64:v1.6.4
$ docker pull gcr.io/google_containers/kube-scheduler-amd64:v1.6.4
$ docker pull gcr.io/google_containers/kubernetes-dashboard-amd64:v1.6.1
$ docker pull quay.io/coreos/flannel:v0.7.1-amd64
$ docker pull gcr.io/google_containers/heapster-amd64:v1.3.0
$ docker pull gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.1
$ docker pull gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.1
$ docker pull gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.1
$ docker pull gcr.io/google_containers/etcd-amd64:3.0.17
$ docker pull gcr.io/google_containers/heapster-grafana-amd64:v4.0.2
$ docker pull gcr.io/google_containers/heapster-influxdb-amd64:v1.1.1
$ docker pull nginx:latest
$ docker pull gcr.io/google_containers/pause-amd64:3.0
```

* on your local laptop MacOSX: 获取代码, 并进入代码目录
```
$ git clone https://github.com/cookeem/kubeadm-ha
$ cd kubeadm-ha
```

* on your local laptop MacOSX: 把相关docker镜像保存成文件

```
$ mkdir -p docker-images
$ docker save -o docker-images/kube-apiserver-amd64 gcr.io/google_containers/kube-apiserver-amd64:v1.6.4
$ docker save -o docker-images/kube-proxy-amd64 gcr.io/google_containers/kube-proxy-amd64:v1.6.4
$ docker save -o docker-images/kube-controller-manager-amd64 gcr.io/google_containers/kube-controller-manager-amd64:v1.6.4
$ docker save -o docker-images/kube-scheduler-amd64 gcr.io/google_containers/kube-scheduler-amd64:v1.6.4
$ docker save -o docker-images/kubernetes-dashboard-amd64 gcr.io/google_containers/kubernetes-dashboard-amd64:v1.6.1
$ docker save -o docker-images/flannel quay.io/coreos/flannel:v0.7.1-amd64
$ docker save -o docker-images/heapster-amd64 gcr.io/google_containers/heapster-amd64:v1.3.0
$ docker save -o docker-images/k8s-dns-sidecar-amd64 gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.1
$ docker save -o docker-images/k8s-dns-kube-dns-amd64 gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.1
$ docker save -o docker-images/k8s-dns-dnsmasq-nanny-amd64 gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.1
$ docker save -o docker-images/etcd-amd64 gcr.io/google_containers/etcd-amd64:3.0.17
$ docker save -o docker-images/heapster-grafana-amd64 gcr.io/google_containers/heapster-grafana-amd64:v4.0.2
$ docker save -o docker-images/heapster-influxdb-amd64 gcr.io/google_containers/heapster-influxdb-amd64:v1.1.1
$ docker save -o docker-images/pause-amd64 gcr.io/google_containers/pause-amd64:3.0
$ docker save -o docker-images/nginx nginx:latest
```

* on your local laptop MacOSX: 把代码以及docker镜像复制到所有节点上
```
$ scp -r * root@k8s-master1:/root/kubeadm-ha
$ scp -r * root@k8s-master2:/root/kubeadm-ha
$ scp -r * root@k8s-master3:/root/kubeadm-ha
$ scp -r * root@k8s-node1:/root/kubeadm-ha
$ scp -r * root@k8s-node2:/root/kubeadm-ha
$ scp -r * root@k8s-node3:/root/kubeadm-ha
$ scp -r * root@k8s-node4:/root/kubeadm-ha
$ scp -r * root@k8s-node5:/root/kubeadm-ha
$ scp -r * root@k8s-node6:/root/kubeadm-ha
$ scp -r * root@k8s-node7:/root/kubeadm-ha
$ scp -r * root@k8s-node8:/root/kubeadm-ha
```

---
[category](#category)

#### system configuration

* 以下on all kubernetes nodes: 都是使用root用户进行操作

* on all kubernetes nodes: 增加kubernetes仓库 
```
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```

* on all kubernetes nodes: 进行系统更新
```
$ yum update -y
```

* on all kubernetes nodes: 关闭防火墙
```
$ systemctl disable firewalld && systemctl stop firewalld && systemctl status firewalld
```

* on all kubernetes nodes: 设置SELINUX为permissive模式
```
$ vi /etc/selinux/config
SELINUX=permissive
```

* on all kubernetes nodes: 设置iptables参数, 否则kubeadm init会提示错误
```
$ vi /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

* on all kubernetes nodes: 重启主机
```
$ reboot
```

---
[category](#category)

### kubernetes installation

#### kubernetes and related services installation

* on all kubernetes nodes: 验证SELINUX模式, 必须保证SELINUX为permissive模式, 否则kubernetes启动会出现各种异常
```
$ getenforce
Permissive
```

* on all kubernetes nodes: 安装并启动kubernetes 
```
$ yum install -y docker kubelet kubeadm kubernetes-cni
$ systemctl enable docker && systemctl start docker
$ systemctl enable kubelet && systemctl start kubelet
```
---
[category](#category)

#### load docker images

* on all kubernetes nodes: 导入docker镜像 
```
$ docker load -i /root/kubeadm-ha/docker-images/etcd-amd64
$ docker load -i /root/kubeadm-ha/docker-images/flannel
$ docker load -i /root/kubeadm-ha/docker-images/heapster-amd64
$ docker load -i /root/kubeadm-ha/docker-images/heapster-grafana-amd64
$ docker load -i /root/kubeadm-ha/docker-images/heapster-influxdb-amd64
$ docker load -i /root/kubeadm-ha/docker-images/k8s-dns-dnsmasq-nanny-amd64
$ docker load -i /root/kubeadm-ha/docker-images/k8s-dns-kube-dns-amd64
$ docker load -i /root/kubeadm-ha/docker-images/k8s-dns-sidecar-amd64
$ docker load -i /root/kubeadm-ha/docker-images/kube-apiserver-amd64
$ docker load -i /root/kubeadm-ha/docker-images/kube-controller-manager-amd64
$ docker load -i /root/kubeadm-ha/docker-images/kube-proxy-amd64
$ docker load -i /root/kubeadm-ha/docker-images/kubernetes-dashboard-amd64
$ docker load -i /root/kubeadm-ha/docker-images/kube-scheduler-amd64
$ docker load -i /root/kubeadm-ha/docker-images/pause-amd64
$ docker load -i /root/kubeadm-ha/docker-images/nginx

$ docker images
REPOSITORY                                               TAG                 IMAGE ID            CREATED             SIZE
gcr.io/google_containers/kube-apiserver-amd64            v1.6.4              4e3810a19a64        5 weeks ago         150.6 MB
gcr.io/google_containers/kube-proxy-amd64                v1.6.4              e073a55c288b        5 weeks ago         109.2 MB
gcr.io/google_containers/kube-controller-manager-amd64   v1.6.4              0ea16a85ac34        5 weeks ago         132.8 MB
gcr.io/google_containers/kube-scheduler-amd64            v1.6.4              1fab9be555e1        5 weeks ago         76.75 MB
gcr.io/google_containers/kubernetes-dashboard-amd64      v1.6.1              71dfe833ce74        6 weeks ago         134.4 MB
quay.io/coreos/flannel                                   v0.7.1-amd64        cd4ae0be5e1b        10 weeks ago        77.76 MB
gcr.io/google_containers/heapster-amd64                  v1.3.0              f9d33bedfed3        3 months ago        68.11 MB
gcr.io/google_containers/k8s-dns-sidecar-amd64           1.14.1              fc5e302d8309        4 months ago        44.52 MB
gcr.io/google_containers/k8s-dns-kube-dns-amd64          1.14.1              f8363dbf447b        4 months ago        52.36 MB
gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64     1.14.1              1091847716ec        4 months ago        44.84 MB
gcr.io/google_containers/etcd-amd64                      3.0.17              243830dae7dd        4 months ago        168.9 MB
gcr.io/google_containers/heapster-grafana-amd64          v4.0.2              a1956d2a1a16        5 months ago        131.5 MB
gcr.io/google_containers/heapster-influxdb-amd64         v1.1.1              d3fccbedd180        5 months ago        11.59 MB
nginx                                                    latest              01f818af747d        6 months ago        181.6 MB
gcr.io/google_containers/pause-amd64                     3.0                 99e59f495ffa        14 months ago       746.9 kB
```

---
[category](#category)

### use kubeadm to init first master

#### deploy independent etcd tls cluster

* on k8s-master1: 以docker方式启动etcd集群
```
$ docker stop etcd && docker rm etcd
$ rm -rf /var/lib/etcd-cluster
$ mkdir -p /var/lib/etcd-cluster
$ docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd0 \
--advertise-client-urls=http://192.168.60.71:2379,http://192.168.60.71:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.71:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.71:2380,etcd1=http://192.168.60.72:2380,etcd2=http://192.168.60.73:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd
```

* 在k8s-master2节点上以docker方式启动etcd集群
```
$ docker stop etcd && docker rm etcd
$ rm -rf /var/lib/etcd-cluster
$ mkdir -p /var/lib/etcd-cluster
$ docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd1 \
--advertise-client-urls=http://192.168.60.72:2379,http://192.168.60.72:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.72:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.71:2380,etcd1=http://192.168.60.72:2380,etcd2=http://192.168.60.73:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd
```

* 在k8s-master3节点上以docker方式启动etcd集群
```
$ docker stop etcd && docker rm etcd
$ rm -rf /var/lib/etcd-cluster
$ mkdir -p /var/lib/etcd-cluster
$ docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd2 \
--advertise-client-urls=http://192.168.60.73:2379,http://192.168.60.73:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.73:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.71:2380,etcd1=http://192.168.60.72:2380,etcd2=http://192.168.60.73:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd
```

* on k8s-master1, k8s-master2, k8s-master3: 检查etcd启动状态
```
$ docker exec -ti etcd ash

$ etcdctl member list
1a32c2d3f1abcad0: name=etcd2 peerURLs=http://192.168.60.73:2380 clientURLs=http://192.168.60.73:2379,http://192.168.60.73:4001 isLeader=false
1da4f4e8b839cb79: name=etcd1 peerURLs=http://192.168.60.72:2380 clientURLs=http://192.168.60.72:2379,http://192.168.60.72:4001 isLeader=false
4238bcb92d7f2617: name=etcd0 peerURLs=http://192.168.60.71:2380 clientURLs=http://192.168.60.71:2379,http://192.168.60.71:4001 isLeader=true

$ etcdctl cluster-health
member 1a32c2d3f1abcad0 is healthy: got healthy result from http://192.168.60.73:2379
member 1da4f4e8b839cb79 is healthy: got healthy result from http://192.168.60.72:2379
member 4238bcb92d7f2617 is healthy: got healthy result from http://192.168.60.71:2379
cluster is healthy

$ exit
```

---
[category](#category)

#### kubeadm init

* on k8s-master1: 修改kubeadm-init.yaml文件, 设置etcd.endpoints的${HOST_IP}为k8s-master1, k8s-master2, k8s-master3的IP地址
```
$ vi /root/kubeadm-ha/kubeadm-init.yaml 
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v1.6.4
networking:
  podSubnet: 10.244.0.0/16
etcd:
  endpoints:
  - http://192.168.60.71:2379
  - http://192.168.60.72:2379
  - http://192.168.60.73:2379
```

* 如果使用kubeadm初始化集群, 启动过程可能会卡在以下位置, 那么可能是因为cgroup-driver参数与docker的不一致引起
* [apiclient] Created API client, waiting for the control plane to become ready
* journalctl -t kubelet -S '2017-06-08'查看日志, 发现如下错误
* error: failed to run Kubelet: failed to create kubelet: misconfiguration: kubelet cgroup driver: "systemd"
* 需要修改KUBELET_CGROUP_ARGS=--cgroup-driver=systemd为KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs
```
$ vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
```

* on k8s-master1: 使用kubeadm初始化kubernetes集群, 连接外部etcd集群
```
$ kubeadm init --config=/root/kubeadm-ha/kubeadm-init.yaml
```

* on k8s-master1: 设置kubectl的环境变量KUBECONFIG, 连接kubelet
```
$ vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

$ source ~/.bashrc
```

---
[category](#category)

#### install flannel networks addon

* on k8s-master1: 安装flannel pod网络组件, 必须安装网络组件, 否则kube-dns pod会一直处于ContainerCreating
```
$ kubectl create -f /root/kubeadm-ha/kube-flannel
clusterrole "flannel" created
clusterrolebinding "flannel" created
serviceaccount "flannel" created
configmap "kube-flannel-cfg" created
daemonset "kube-flannel-ds" created
```

* on k8s-master1: 验证kube-dns成功启动, 大概等待3分钟, 验证所有pods的状态为Running
```
$ kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                 READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   kube-apiserver-k8s-master1           1/1       Running   0          3m        192.168.60.71   k8s-master1
kube-system   kube-controller-manager-k8s-master1  1/1       Running   0          3m        192.168.60.71   k8s-master1
kube-system   kube-dns-3913472980-k9mt6            3/3       Running   0          4m        10.244.0.104    k8s-master1
kube-system   kube-flannel-ds-3hhjd                2/2       Running   0          1m        192.168.60.71   k8s-master1
kube-system   kube-proxy-rzq3t                     1/1       Running   0          4m        192.168.60.71   k8s-master1
kube-system   kube-scheduler-k8s-master1           1/1       Running   0          3m        192.168.60.71   k8s-master1
```

---
[category](#category)

#### install dashboard addon

* on k8s-master1: 安装dashboard组件
```
$ kubectl create -f /root/kubeadm-ha/kube-dashboard/
serviceaccount "kubernetes-dashboard" created
clusterrolebinding "kubernetes-dashboard" created
deployment "kubernetes-dashboard" created
service "kubernetes-dashboard" created
```

* on k8s-master1: 启动proxy, 映射地址到0.0.0.0
```
$ kubectl proxy --address='0.0.0.0' &
```

* on your local laptop MacOSX: 访问dashboard地址, 验证dashboard成功启动
```
http://k8s-master1:30000
```

![dashboard](images/dashboard.png)

---
[category](#category)

#### install heapster addon

* on k8s-master1: 允许在master上部署pod, 否则heapster会无法部署
```
$ kubectl taint nodes --all node-role.kubernetes.io/master-
node "k8s-master1" tainted
```

* on k8s-master1: 安装heapster组件, 监控性能
```
$ kubectl create -f /root/kubeadm-ha/kube-heapster
```

* on k8s-master1: 重启docker以及kubelet服务, 让heapster在dashboard上生效显示
```
$ systemctl restart docker kubelet
```

* 在k8s-master上检查pods状态
```
$ kubectl get all --all-namespaces -o wide
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   heapster-783524908-kn6jd                1/1       Running   1          9m        10.244.0.111    k8s-master1
kube-system   kube-apiserver-k8s-master1              1/1       Running   1          15m       192.168.60.71   k8s-master1
kube-system   kube-controller-manager-k8s-master1     1/1       Running   1          15m       192.168.60.71   k8s-master1
kube-system   kube-dns-3913472980-k9mt6               3/3       Running   3          16m       10.244.0.110    k8s-master1
kube-system   kube-flannel-ds-3hhjd                   2/2       Running   3          13m       192.168.60.71   k8s-master1
kube-system   kube-proxy-rzq3t                        1/1       Running   1          16m       192.168.60.71   k8s-master1
kube-system   kube-scheduler-k8s-master1              1/1       Running   1          15m       192.168.60.71   k8s-master1
kube-system   kubernetes-dashboard-2039414953-d46vw   1/1       Running   1          11m       10.244.0.109    k8s-master1
kube-system   monitoring-grafana-3975459543-8l94z     1/1       Running   1          9m        10.244.0.112    k8s-master1
kube-system   monitoring-influxdb-3480804314-72ltf    1/1       Running   1          9m        10.244.0.113    k8s-master1
```

* on your local laptop MacOSX: 访问dashboard地址, 验证heapster成功启动, 查看Pods的CPU以及Memory信息是否正常呈现
```
http://k8s-master1:30000
```

![heapster](images/heapster.png)

* 至此, 第一台master成功安装, 并已经完成flannel, dashboard, heapster的部署

---
[category](#category)

### kubernetes masters high avialiability configuration

#### copy configuration files

* on k8s-master1: 把/etc/kubernetes/复制到k8s-master2, k8s-master3
```
scp -r /etc/kubernetes/ k8s-master2:/etc/
scp -r /etc/kubernetes/ k8s-master3:/etc/
```

* on k8s-master2, k8s-master3: 重启kubelet服务, 并检查kubelet服务状态为active (running)
```
$ systemctl daemon-reload && systemctl restart kubelet

$ systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Tue 2017-06-27 16:24:22 CST; 1 day 17h ago
     Docs: http://kubernetes.io/docs/
 Main PID: 2780 (kubelet)
   Memory: 92.9M
   CGroup: /system.slice/kubelet.service
           ├─2780 /usr/bin/kubelet --kubeconfig=/etc/kubernetes/kubelet.conf --require-...
           └─2811 journalctl -k -f
```

* on k8s-master2, k8s-master3: 设置kubectl的环境变量KUBECONFIG, 连接kubelet
```
$ vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

$ source ~/.bashrc
```

* 在k8s-master2, k8s-master3检测节点状态, 发现节点已经加进来
```
$ kubectl get nodes -o wide
NAME          STATUS    AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION
k8s-master1   Ready     26m       v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.1.el7.x86_64
k8s-master2   Ready     2m        v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.21.1.el7.x86_64
k8s-master3   Ready     2m        v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.21.1.el7.x86_64
```

* on k8s-master2, k8s-master3: 修改kube-apiserver.yaml的配置, ${HOST_IP}改为本机IP
```
$ vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --advertise-address=${HOST_IP}
```

* 在k8s-master2和k8s-master3上的修改kubelet.conf设置, ${HOST_IP}改为本机IP
```
$ vi /etc/kubernetes/kubelet.conf
server: https://${HOST_IP}:6443
```

* 在k8s-master2和k8s-master3上的重启服务
```
$ systemctl daemon-reload && systemctl restart docker kubelet
```

---
[category](#category)

#### create certificatie

* 在k8s-master2和k8s-master3上修改kubelet.conf后, 由于kubelet.conf配置的crt和key与本机IP地址不一致的情况, kubelet服务会异常退出, crt和key必须重新制作. 查看apiserver.crt的签名信息, 发现IP Address以及DNS绑定了k8s-master1, 必须进行相应修改. 
```
openssl x509 -noout -text -in /etc/kubernetes/pki/apiserver.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 9486057293403496063 (0x83a53ed95c519e7f)
    Signature Algorithm: sha1WithRSAEncryption
        Issuer: CN=kubernetes
        Validity
            Not Before: Jun 22 16:22:44 2017 GMT
            Not After : Jun 22 16:22:44 2018 GMT
        Subject: CN=kube-apiserver,
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    d0:10:4a:3b:c4:62:5d:ae:f8:f1:16:48:b3:77:6b:
                    53:4b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Alternative Name: 
                DNS:k8s-master1, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:192.168.60.71
    Signature Algorithm: sha1WithRSAEncryption
         dd:68:16:f9:11:be:c3:3c:be:89:9f:14:60:6b:e0:47:c7:91:
         9e:78:ab:ce
```

* on k8s-master1, k8s-master2, k8s-master3: 使用ca.key和ca.crt制作apiserver.crt和apiserver.key
```
$ mkdir -p /etc/kubernetes/pki-local

$ cd /etc/kubernetes/pki-local
```

* on k8s-master1, k8s-master2, k8s-master3: 生成2048位的密钥对
```
$ openssl genrsa -out apiserver.key 2048
```

* on k8s-master1, k8s-master2, k8s-master3: 生成证书签署请求文件
```
$ openssl req -new -key apiserver.key -subj "/CN=kube-apiserver," -out apiserver.csr
```

* on k8s-master1, k8s-master2, k8s-master3: 编辑apiserver.ext文件, ${HOST_NAME}修改为本机主机名, ${HOST_IP}修改为本机IP地址, ${VIRTUAL_IP}修改为keepalived的虚拟IP（192.168.60.80）
```
$ vi apiserver.ext
subjectAltName = DNS:${HOST_NAME},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP:10.96.0.1, IP:${HOST_IP}, IP:${VIRTUAL_IP}
```

* on k8s-master1, k8s-master2, k8s-master3: 使用ca.key和ca.crt签署上述请求
```
$ openssl x509 -req -in apiserver.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out apiserver.crt -days 365 -extfile /etc/kubernetes/pki-local/apiserver.ext
```

* on k8s-master1, k8s-master2, k8s-master3: 查看新生成的证书：
```
$ openssl x509 -noout -text -in apiserver.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 9486057293403496063 (0x83a53ed95c519e7f)
    Signature Algorithm: sha1WithRSAEncryption
        Issuer: CN=kubernetes
        Validity
            Not Before: Jun 22 16:22:44 2017 GMT
            Not After : Jun 22 16:22:44 2018 GMT
        Subject: CN=kube-apiserver,
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    d0:10:4a:3b:c4:62:5d:ae:f8:f1:16:48:b3:77:6b:
                    53:4b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Alternative Name: 
                DNS:k8s-master3, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:192.168.60.73, IP Address:192.168.60.80
    Signature Algorithm: sha1WithRSAEncryption
         dd:68:16:f9:11:be:c3:3c:be:89:9f:14:60:6b:e0:47:c7:91:
         9e:78:ab:ce
```

* on k8s-master1, k8s-master2, k8s-master3: 把apiserver.crt和apiserver.key文件复制到/etc/kubernetes/pki目录
```
$ cp apiserver.crt apiserver.key /etc/kubernetes/pki/
```

---
[category](#category)

#### edit configuration files

* 在k8s-master2和k8s-master3上修改admin.conf, ${HOST_IP}修改为本机IP地址
```
$ vi /etc/kubernetes/admin.conf
    server: https://${HOST_IP}:6443
```

* 在k8s-master2和k8s-master3上修改controller-manager.conf, ${HOST_IP}修改为本机IP地址
```
$ vi /etc/kubernetes/controller-manager.conf
    server: https://${HOST_IP}:6443
```

* 在k8s-master2和k8s-master3上修改scheduler.conf, ${HOST_IP}修改为本机IP地址
```
$ vi /etc/kubernetes/scheduler.conf
    server: https://${HOST_IP}:6443
```

* on k8s-master1, k8s-master2, k8s-master3: 重启所有服务
```
$ systemctl daemon-reload && systemctl restart docker kubelet
```

---
[category](#category)

#### verify master high avialiability

* on k8s-master1 or k8s-master2 or k8s-master3: 检测服务启动情况, 发现apiserver, controller-manager, kube-scheduler, proxy, flannel已经在k8s-master1, k8s-master2, k8s-master3成功启动
```
$ kubectl get pod --all-namespaces -o wide | grep k8s-master2
kube-system   kube-apiserver-k8s-master2              1/1       Running   1          55s       192.168.60.72   k8s-master2
kube-system   kube-controller-manager-k8s-master2     1/1       Running   2          18m       192.168.60.72   k8s-master2
kube-system   kube-flannel-ds-t8gkh                   2/2       Running   4          18m       192.168.60.72   k8s-master2
kube-system   kube-proxy-bpgqw                        1/1       Running   1          18m       192.168.60.72   k8s-master2
kube-system   kube-scheduler-k8s-master2              1/1       Running   2          18m       192.168.60.72   k8s-master2

$ kubectl get pod --all-namespaces -o wide | grep k8s-master3
kube-system   kube-apiserver-k8s-master3              1/1       Running   1          1m        192.168.60.73   k8s-master3
kube-system   kube-controller-manager-k8s-master3     1/1       Running   2          18m       192.168.60.73   k8s-master3
kube-system   kube-flannel-ds-tmqmx                   2/2       Running   4          18m       192.168.60.73   k8s-master3
kube-system   kube-proxy-4stg3                        1/1       Running   1          18m       192.168.60.73   k8s-master3
kube-system   kube-scheduler-k8s-master3              1/1       Running   2          18m       192.168.60.73   k8s-master3
```

* on k8s-master1 or k8s-master2 or k8s-master3: 通过kubectl logs检查各个controller-manager和scheduler的leader election结果, 可以发现只有一个节点有效表示选举正常
```
$ kubectl logs -n kube-system kube-controller-manager-k8s-master1
$ kubectl logs -n kube-system kube-controller-manager-k8s-master2
$ kubectl logs -n kube-system kube-controller-manager-k8s-master3

$ kubectl logs -n kube-system kube-scheduler-k8s-master1
$ kubectl logs -n kube-system kube-scheduler-k8s-master2
$ kubectl logs -n kube-system kube-scheduler-k8s-master3
```

* on k8s-master1 or k8s-master2 or k8s-master3: 查看deployment的情况
```
$ kubectl get deploy --all-namespaces
NAMESPACE     NAME                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   heapster               1         1         1            1           41m
kube-system   kube-dns               1         1         1            1           48m
kube-system   kubernetes-dashboard   1         1         1            1           43m
kube-system   monitoring-grafana     1         1         1            1           41m
kube-system   monitoring-influxdb    1         1         1            1           41m
```

* on k8s-master1 or k8s-master2 or k8s-master3: 把kubernetes-dashboard, kube-dns、 scale up成replicas=3, 保证各个master节点上都有运行
```
$ kubectl scale --replicas=3 -n kube-system deployment/kube-dns
$ kubectl get pods --all-namespaces -o wide| grep kube-dns

$ kubectl scale --replicas=3 -n kube-system deployment/kubernetes-dashboard
$ kubectl get pods --all-namespaces -o wide| grep kubernetes-dashboard

$ kubectl scale --replicas=3 -n kube-system deployment/heapster
$ kubectl get pods --all-namespaces -o wide| grep heapster

$ kubectl scale --replicas=3 -n kube-system deployment/monitoring-grafana
$ kubectl get pods --all-namespaces -o wide| grep monitoring-grafana

$ kubectl scale --replicas=3 -n kube-system deployment/monitoring-influxdb
$ kubectl get pods --all-namespaces -o wide| grep monitoring-influxdb
```
---
[category](#category)

#### keepalived installation

* on k8s-master1, k8s-master2, k8s-master3: 安装keepalived
```
$ yum install -y keepalived

$ systemctl enable keepalived && systemctl restart keepalived
```

* on k8s-master1, k8s-master2, k8s-master3: 备份keepalived配置文件
```
$ mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
```

* on k8s-master1, k8s-master2, k8s-master3: 设置apiserver监控脚本, 当apiserver检测失败的时候关闭keepalived服务, 转移virtual IP address
```
$ vi /etc/keepalived/check_apiserver.sh
#!/bin/bash
err=0
for k in $( seq 1 10 )
do
    check_code=$(ps -ef|grep kube-apiserver | wc -l)
    if [ "$check_code" = "1" ]; then
        err=$(expr $err + 1)
        sleep 5
        continue
    else
        err=0
        break
    fi
done
if [ "$err" != "0" ]; then
    echo "systemctl stop keepalived"
    /usr/bin/systemctl stop keepalived
    exit 1
else
    exit 0
fi

chmod a+x /etc/keepalived/check_apiserver.sh
```

* on k8s-master1, k8s-master2, k8s-master3: 查看接口名字
```
$ ip a | grep 192.168.60
```

* on k8s-master1, k8s-master2, k8s-master3: 设置keepalived, 参数说明如下：
* state ${STATE}：为MASTER或者BACKUP, 只能有一个MASTER
* interface ${INTERFACE_NAME}：为本机的需要绑定的接口名字（通过上边的```ip a```命令查看）
* mcast_src_ip ${HOST_IP}：为本机的IP地址
* priority ${PRIORITY}：为优先级, 例如102, 101, 100, 优先级越高越容易选择为MASTER, 优先级不能一样
* ${VIRTUAL_IP}：为虚拟的IP地址, 这里设置为192.168.60.80
```
$ vi /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script chk_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 2
    weight -5
    fall 3  
    rise 2
}
vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE_NAME}
    mcast_src_ip ${HOST_IP}
    virtual_router_id 51
    priority ${PRIORITY}
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass 4be37dc3b4c90194d1600c483e10ad1d
    }
    virtual_ipaddress {
        ${VIRTUAL_IP}
    }
    track_script {
       chk_apiserver
    }
}
```

* on k8s-master1, k8s-master2, k8s-master3: 重启keepalived服务, 检测virtual IP address是否生效
```
$ systemctl restart keepalived
$ ping 192.168.60.80
```

---
[category](#category)

#### nginx load balancer configuration

* on k8s-master1, k8s-master2, k8s-master3: 修改nginx-default.conf设置, ${HOST_IP}对应k8s-master1, k8s-master2, k8s-master3的地址. 通过nginx把访问apiserver的6443端口负载均衡到8433端口上
```
$ vi /root/kubeadm-ha/nginx-default.conf
stream {
    upstream apiserver {
        server ${HOST_IP}:6443 weight=5 max_fails=3 fail_timeout=30s;
        server ${HOST_IP}:6443 weight=5 max_fails=3 fail_timeout=30s;
        server ${HOST_IP}:6443 weight=5 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 8443;
        proxy_connect_timeout 1s;
        proxy_timeout 3s;
        proxy_pass apiserver;
    }
}
```

* on k8s-master1, k8s-master2, k8s-master3: 启动nginx容器
```
$ docker run -d -p 8443:8443 \
--name nginx-lb \
--restart always \
-v /root/kubeadm-ha/nginx-default.conf:/etc/nginx/nginx.conf \
nginx
```

* on k8s-master1, k8s-master2, k8s-master3: 检测keepalived服务的virtual IP address指向
```
$ curl -L 192.168.60.80:8443 | wc -l
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14    0    14    0     0  18324      0 --:--:-- --:--:-- --:--:-- 14000
1
```

* 业务恢复后务必重启keepalived, 否则keepalived会处于关闭状态
```
$ systemctl restart keepalived
```

* on k8s-master1, k8s-master2, k8s-master3: 查看keeplived日志, 有以下输出表示当前virtual IP address绑定的主机
```
$ systemctl status keepalived -l
VRRP_Instance(VI_1) Sending gratuitous ARPs on ens160 for 192.168.60.80
```

---
[category](#category)

#### kube-proxy configuration

* on k8s-master1: 设置kube-proxy使用keepalived的virtual IP address, 避免k8s-master1异常的时候所有节点的kube-proxy连接不上
```
$ kubectl get -n kube-system configmap
NAME                                 DATA      AGE
extension-apiserver-authentication   6         4h
kube-flannel-cfg                     2         4h
kube-proxy                           1         4h
```

* on k8s-master1: 修改configmap/kube-proxy的server指向keepalived的virtual IP address
```
$ kubectl edit -n kube-system configmap/kube-proxy
        server: https://192.168.60.80:8443
```

* on k8s-master1: 查看configmap/kube-proxy设置情况
```
$ kubectl get -n kube-system configmap/kube-proxy -o yaml
```

* on k8s-master1: 删除所有kube-proxy的pod, 让proxy重建
```
kubectl get pods --all-namespaces -o wide | grep proxy
```

* on k8s-master1, k8s-master2, k8s-master3: 重启docker kubelet keepalived服务
```
$ systemctl restart docker kubelet keepalived
```

---
[category](#category)

#### verfify master high avialiability with keepalived

* on k8s-master1: 检查各个节点pod的启动状态, 每个上都成功启动heapster, kube-apiserver, kube-controller-manager, kube-dns, kube-flannel, kube-proxy, kube-scheduler, kubernetes-dashboard, monitoring-grafana, monitoring-influxdb. 并且所有pod都处于Running状态表示正常
```
$ kubectl get pods --all-namespaces -o wide | grep k8s-master1

$ kubectl get pods --all-namespaces -o wide | grep k8s-master2

$ kubectl get pods --all-namespaces -o wide | grep k8s-master3
```

---
[category](#category)

### k8s-nodes join the kubernetes cluster

#### use kubeadm to join the cluster
* on k8s-master1: 禁止在所有master节点上发布应用
```
$ kubectl patch node k8s-master1 -p '{"spec":{"unschedulable":true}}'

$ kubectl patch node k8s-master2 -p '{"spec":{"unschedulable":true}}'

$ kubectl patch node k8s-master3 -p '{"spec":{"unschedulable":true}}'
```

* on k8s-master1: 查看集群的token
```
$ kubeadm token list
TOKEN           TTL         EXPIRES   USAGES                   DESCRIPTION
xxxxxx.yyyyyy   <forever>   <never>   authentication,signing   The default bootstrap token generated by 'kubeadm init'
```

* 在k8s-node1 ~ k8s-node8上, ${TOKEN}为k8s-master1上显示的token, ${VIRTUAL_IP}为keepalived的virtual IP address192.168.60.80
```
$ kubeadm join --token ${TOKEN} ${VIRTUAL_IP}:8443
```

---
[category](#category)

#### deploy nginx application to verify installation

* 在k8s-node1 ~ k8s-node8上查看kubelet状态, kubelet状态为active (running)表示kubelet服务正常启动
```
$ systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
   Active: active (running) since Tue 2017-06-27 16:23:43 CST; 1 day 18h ago
     Docs: http://kubernetes.io/docs/
 Main PID: 1146 (kubelet)
   Memory: 204.9M
   CGroup: /system.slice/kubelet.service
           ├─ 1146 /usr/bin/kubelet --kubeconfig=/etc/kubernetes/kubelet.conf --require...
           ├─ 2553 journalctl -k -f
           ├─ 4988 /usr/sbin/glusterfs --log-level=ERROR --log-file=/var/lib/kubelet/pl...
           └─14720 /usr/sbin/glusterfs --log-level=ERROR --log-file=/var/lib/kubelet/pl...
```

* on k8s-master1: 检查各个节点状态, 发现所有k8s-nodes节点成功加入
```
$ kubectl get nodes -o wide
NAME          STATUS                     AGE       VERSION
k8s-master1   Ready,SchedulingDisabled   5h        v1.6.4
k8s-master2   Ready,SchedulingDisabled   4h        v1.6.4
k8s-master3   Ready,SchedulingDisabled   4h        v1.6.4
k8s-node1     Ready                      6m        v1.6.4
k8s-node2     Ready                      4m        v1.6.4
k8s-node3     Ready                      4m        v1.6.4
k8s-node4     Ready                      3m        v1.6.4
k8s-node5     Ready                      3m        v1.6.4
k8s-node6     Ready                      3m        v1.6.4
k8s-node7     Ready                      3m        v1.6.4
k8s-node8     Ready                      3m        v1.6.4
```

* on k8s-master1: 测试部署nginx服务, nginx服务成功部署到k8s-node5上
```
$ kubectl run nginx --image=nginx --port=80
deployment "nginx" created

$ kubectl get pod -o wide -l=run=nginx
NAME                     READY     STATUS    RESTARTS   AGE       IP           NODE
nginx-2662403697-pbmwt   1/1       Running   0          5m        10.244.7.6   k8s-node5
```

* 在k8s-master1让nginx服务外部可见
```
$ kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort
service "nginx" exposed

$ kubectl get svc -l=run=nginx
NAME      CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx     10.105.151.69   <nodes>       80:31639/TCP   43s

$ curl k8s-master2:31639
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

* 至此, kubernetes高可用集群成功部署
---
[category](#category)

