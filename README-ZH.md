# kubeadm-highavailiability - 基于kubeadmin的kubernetes高可用集群部署

![CookIM logo](images/Kubernetes.png)

- [中文文档](README-ZH.md)
- [English document](README.md)

##############################################
# check list 检查清单
##############################################

# 1、主机名设置
$ nmtui

# 2、在k8s-registry上把/etc/hosts复制到k8s-master、k8s-slave、k8s-node1 ~ k8s-node8
scp /etc/hosts k8s-master:/etc
scp /etc/hosts k8s-slave:/etc
scp /etc/hosts k8s-node1:/etc
scp /etc/hosts k8s-node2:/etc
scp /etc/hosts k8s-node3:/etc
scp /etc/hosts k8s-node4:/etc
scp /etc/hosts k8s-node5:/etc
scp /etc/hosts k8s-node6:/etc
scp /etc/hosts k8s-node7:/etc
scp /etc/hosts k8s-node8:/etc
scp /etc/hosts k8s-master1:/etc
scp /etc/hosts k8s-master2:/etc

# 3、设置主机互信
# 在各个节点执行
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

# 步骤一：将id_rsa.pub（公钥）追加到授权的key中。在所有节点上先执行
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# 步骤二：复制到第二个节点上，进入下一个节点重新执行步骤一、步骤二
$ scp ~/.ssh/authorized_keys k8s-master:~/.ssh/

# 4、k8s-registry上的yum源设置
$ cat cat /etc/yum.repos.d/fullyum.repo 
[fullyum]
name=fullyum
baseurl=http://k8s-registry:9080/
enable=1
gpgcheck=0

# 在k8s-registry上复制配置文件到各个节点
$ scp /etc/yum.repos.d/fullyum.repo k8s-master:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-master1:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-master2:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-slave:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node1:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node2:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node3:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node4:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node5:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node6:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node7:/etc/yum.repos.d/
$ scp /etc/yum.repos.d/fullyum.repo k8s-node8:/etc/yum.repos.d/

# 在各个节点移除默认/etc/yum.repos.d/
$ cd /etc/yum.repos.d/
$ mkdir bak
$ mv CentOS-* bak/ 
$ yum clean all
$ yum makecache
$ yum search kube --showduplicates

# 5、docker-registry证书设置
# 在各个节点创建目录
$ mkdir -p /etc/docker/certs.d/k8s-registry:5000/

# 把证书从k8s-registry复制到各个节点
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-master:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-master1:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-master2:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-slave:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node1:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node2:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node3:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node4:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node5:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node6:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node7:/etc/docker/certs.d/k8s-registry:5000/
scp /etc/docker/certs.d/k8s-registry:5000/* k8s-node8:/etc/docker/certs.d/k8s-registry:5000/

# 6、在k8s-master、k8s-master1、k8s-master2、k8s-slave、k8s-node1 ~ k8s-node8上安装docker-engine，注意，务必安装1.12.6版本，1.13.x版本有问题，重启后服务无法expose service
$ yum update -y
$ yum list docker-engine --showduplicates
$ yum install -y docker-engine-1.12.6-1.el7.centos
$ systemctl enable docker && systemctl start docker

# 7、在k8s-registry、k8s-master、k8s-master1、k8s-master2、k8s-slave、k8s-node1 ~ k8s-node8上安装glusterfs客户端
# 在各个节点安装glusterfs客户端安装
$ yum install -y glusterfs-server
exit

##############################################
# 在k8s-node1 ~ k8s-node8上创建xfs分区
##############################################

# 查看分区情况
$ lsblk
NAME                         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0                            2:0    1    4K  0 disk 
sda                            8:0    0  100G  0 disk 
├─sda1                         8:1    0    1G  0 part /boot
└─sda2                         8:2    0   99G  0 part 
  ├─cl-root                  253:0    0   50G  0 lvm  /
  ├─cl-swap                  253:1    0   10G  0 lvm  [SWAP]
  └─cl-home                  253:2    0   39G  0 lvm  /home
sdb                            8:16   0  200G  0 disk 
sr0                           11:0    1 1024M  0 rom  
loop0                          7:0    0  100G  0 loop 
└─docker-253:0-34176516-pool 253:3    0  100G  0 dm   
loop1                          7:1    0    2G  0 loop 
└─docker-253:0-34176516-pool 253:3    0  100G  0 dm   

$ fdisk /dev/sdb
n
p
回车
回车
回车
w

$ mkdir -p /glusterfs
$ mkfs.xfs -i size=512 /dev/sdb1
$ mount /dev/sdb1 /glusterfs

# 修改/etc/fstab文件
$ echo '/dev/sdb1               /glusterfs              xfs     defaults        1 2' >> /etc/fstab
$ cat /etc/fstab

# 重启验证
$ reboot
$ lsblk

##############################################
# 在k8s-node1 ~ k8s-node8上启动并配置glusterd
##############################################

# 在k8s-node1 ~ k8s-node8上启动glusterd
$ systemctl enable glusterd && systemctl start glusterd && systemctl status glusterd

# 关闭防火墙
$ systemctl disable firewalld && systemctl stop firewalld && systemctl status firewalld

# 在k8s-node1上监测k8s-node2 ~ k8s-node8
$ gluster peer probe k8s-node2
gluster peer probe k8s-node3
gluster peer probe k8s-node4
gluster peer probe k8s-node5
gluster peer probe k8s-node6
gluster peer probe k8s-node7
gluster peer probe k8s-node8
gluster peer status

# 在k8s-node1 ~ k8s-node8上创建对应目录
$ mkdir -p /opt/gv

# 在任意一个节点上创建gluster volume
$ gluster volume create gv replica 2 strip 4 transport tcp k8s-node1:/opt/gv k8s-node2:/opt/gv k8s-node3:/opt/gv k8s-node4:/opt/gv k8s-node5:/opt/gv k8s-node6:/opt/gv k8s-node7:/opt/gv k8s-node8:/opt/gv
$ gluster volume start gv
$ gluster volume info

# 在k8s-registry下挂装gv，把glusterfs当成本地文件系统使用
$ mkdir -p /mnt/gv
$ mount -t glusterfs k8s-node1:/gv /mnt/gv

# 在k8s-registry下取消gv的挂装
$ umount /mnt/gv


##############################################
# 设置集群ntpupdate
##############################################

# 在k8s-master、k8s-slave、k8s-node1 ~ k8s-node8上安装ntpdate，并进行时区更新
$ yum install -y ntpdate
$ timedatectl set-timezone Asia/Shanghai
$ ntpdate k8s-registry
$ date

# 在k8s-master、k8s-slave、k8s-node1 ~ k8s-node8上设置定时任务
$ crontab -e
20 * * * * /usr/sbin/ntpdate -u k8s-registry

crontab -l
exit

##############################################
# 在k8s-master、k8s-master1、k8s-master2上安装kubernetes相关组件
##############################################

# 在Mac上复制相关yaml文件到k8s-master、k8s-master1、k8s-master2
$ scp -r /Volumes/Share/Install/kubeadm-yaml root@k8s-master:/root/
$ scp -r /Volumes/Share/Install/kubeadm-yaml root@k8s-master1:/root/
$ scp -r /Volumes/Share/Install/kubeadm-yaml root@k8s-master2:/root/

# 在k8s-registry上复制相关镜像文件到k8s-master、k8s-master1、k8s-master2
$ scp -r /data/kubeadm-images/ k8s-master:~
$ scp -r /data/kubeadm-images/ k8s-master1:~
$ scp -r /data/kubeadm-images/ k8s-master2:~

# 在k8s-master、k8s-master1、k8s-master2上安装kubernetes
$ yum install -y kubelet kubeadm kubectl kubernetes-cni
$ systemctl enable kubelet && systemctl start kubelet

# 在k8s-master、k8s-master1、k8s-master2上务必关闭防火墙并重启docker和kubernetes
$ systemctl disable firewalld && systemctl stop firewalld && systemctl status firewalld
$ systemctl restart docker && systemctl restart kubelet

# ！！注意，必须设置setenforce 0
$ vi /etc/selinux/config
SELINUX=permissive

# 在k8s-master、k8s-master1、k8s-master2上重启后查看enforce设置
$ reboot
$ getenforce
Permissive

# 在k8s-master、k8s-master1、k8s-master2上加载相关镜像文件到docker
$ docker load -i /root/kubeadm-images/etcd-amd64
$ docker load -i /root/kubeadm-images/flannel
$ docker load -i /root/kubeadm-images/heapster-amd64
$ docker load -i /root/kubeadm-images/heapster-grafana-amd64
$ docker load -i /root/kubeadm-images/heapster-influxdb-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-dnsmasq-nanny-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-kube-dns-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-sidecar-amd64
$ docker load -i /root/kubeadm-images/kube-apiserver-amd64
$ docker load -i /root/kubeadm-images/kube-controller-manager-amd64
$ docker load -i /root/kubeadm-images/kube-proxy-amd64
$ docker load -i /root/kubeadm-images/kubernetes-dashboard-amd64
$ docker load -i /root/kubeadm-images/kube-scheduler-amd64
$ docker load -i /root/kubeadm-images/pause-amd64

$ docker images
REPOSITORY                                               TAG                 IMAGE ID            CREATED             SIZE
gcr.io/google_containers/kube-apiserver-amd64            v1.6.4              4e3810a19a64        2 weeks ago         150.6 MB
gcr.io/google_containers/kube-controller-manager-amd64   v1.6.4              0ea16a85ac34        2 weeks ago         132.8 MB
gcr.io/google_containers/kube-proxy-amd64                v1.6.4              e073a55c288b        2 weeks ago         109.2 MB
gcr.io/google_containers/kube-scheduler-amd64            v1.6.4              1fab9be555e1        2 weeks ago         76.75 MB
gcr.io/google_containers/kubernetes-dashboard-amd64      v1.6.1              71dfe833ce74        3 weeks ago         134.4 MB
quay.io/coreos/flannel                                   v0.7.1-amd64        cd4ae0be5e1b        7 weeks ago         77.76 MB
gcr.io/google_containers/heapster-amd64                  v1.3.0              f9d33bedfed3        11 weeks ago        68.11 MB
gcr.io/google_containers/k8s-dns-sidecar-amd64           1.14.1              fc5e302d8309        3 months ago        44.52 MB
gcr.io/google_containers/k8s-dns-kube-dns-amd64          1.14.1              f8363dbf447b        3 months ago        52.36 MB
gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64     1.14.1              1091847716ec        3 months ago        44.84 MB
gcr.io/google_containers/etcd-amd64                      3.0.17              243830dae7dd        3 months ago        168.9 MB
gcr.io/google_containers/heapster-grafana-amd64          v4.0.2              a1956d2a1a16        4 months ago        131.5 MB
gcr.io/google_containers/heapster-influxdb-amd64         v1.1.1              d3fccbedd180        4 months ago        11.59 MB
gcr.io/google_containers/pause-amd64                     3.0                 99e59f495ffa        13 months ago       746.9 kB

# kubeadm启动过程会卡在
# [apiclient] Created API client, waiting for the control plane to become ready
# 查看日志，发现如下错误
# journalctl -t kubelet -S '2017-06-08'
# 解决error: failed to run Kubelet: failed to create kubelet: misconfiguration: kubelet cgroup driver: "systemd"
# 需要修改KUBELET_CGROUP_ARGS=--cgroup-driver=systemd为KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs
$ vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"

# 在k8s-master、k8s-master1、k8s-master2上重启服务
$ systemctl daemon-reload && systemctl restart kubelet

# 设置iptables参数，否则会提示错误
# [preflight] Some fatal errors occurred:
# 	/proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
$ vi /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

##############################################
# 在k8s-master上进行kubeadm init
##############################################

# 在k8s-master、k8s-master1、k8s-master2上单独启动etcd集群

docker stop etcd && docker rm etcd
rm -rf /var/lib/etcd-cluster
mkdir -p /var/lib/etcd-cluster

# 在k8s-master上启动TLS的etcd
docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd0 \
--advertise-client-urls=http://192.168.60.72:2379,http://192.168.60.72:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.72:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.72:2380,etcd1=http://192.168.60.77:2380,etcd2=http://192.168.60.78:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd

# 在k8s-master1上启动TLS的etcd
docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd1 \
--advertise-client-urls=http://192.168.60.77:2379,http://192.168.60.77:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.77:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.72:2380,etcd1=http://192.168.60.77:2380,etcd2=http://192.168.60.78:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd

# 在k8s-master2上启动TLS的etcd
docker run -d \
--restart always \
-v /etc/ssl/certs:/etc/ssl/certs \
-v /var/lib/etcd-cluster:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
gcr.io/google_containers/etcd-amd64:3.0.17 \
etcd --name=etcd2 \
--advertise-client-urls=http://192.168.60.78:2379,http://192.168.60.78:4001 \
--listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
--initial-advertise-peer-urls=http://192.168.60.78:2380 \
--listen-peer-urls=http://0.0.0.0:2380 \
--initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
--initial-cluster=etcd0=http://192.168.60.72:2380,etcd1=http://192.168.60.77:2380,etcd2=http://192.168.60.78:2380 \
--initial-cluster-state=new \
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd

# 测试etcd集群是否启动正常

# 在k8s-master、k8s-master1、k8s-master2上检查etcd启动状态
docker exec -ti etcd ash
etcdctl member list
etcdctl cluster-health
exit

# 在k8s-master上设置一个keyvalue
docker exec -ti etcd ash
etcdctl set k1 v1
exit

# 在k8s-master1上获取keyvalue
docker exec -ti etcd ash
etcdctl get k1
exit

# 在k8s-master2上删除keyvalue
docker exec -ti etcd ash
etcdctl rm k1
exit

# 在k8s-master、k8s-master1、k8s-master2上删除kube-ha目录
rm -rf /root/kubeadm-yaml/kube-ha/

# 在Mac上把kube-ha目录复制到k8s-master、k8s-master1、k8s-master2
scp -r /Volumes/Share/Install/kubeadm-yaml/kube-ha root@k8s-master:/root/kubeadm-yaml/
scp -r /Volumes/Share/Install/kubeadm-yaml/kube-ha root@k8s-master1:/root/kubeadm-yaml/
scp -r /Volumes/Share/Install/kubeadm-yaml/kube-ha root@k8s-master2:/root/kubeadm-yaml/

# kubeadm-init.yaml的初始化配置
# 如果使用flannel，必须在init的时候设置以下参数：--pod-network-cidr=10.244.0.0/16，
# ！！非常注意：离线环境下必须指定--kubernetes-version=v1.6.4，否则会启动1.6.0版本，并提示pull images失败！！！
cat /root/kubeadm-yaml/kube-ha/kubeadm-init.yaml 
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v1.6.4
networking:
  podSubnet: 10.244.0.0/16
etcd:
  endpoints:
  - http://192.168.60.72:2379
  - http://192.168.60.78:2379
  - http://192.168.60.79:2379

# 在k8s-master上使用kubeadm初始化kubernetes集群
# 建议加上--skip-preflight-checks，否则会出现etcd检测不通过
$ kubeadm init --config=/root/kubeadm-yaml/kube-ha/kubeadm-init.yaml --skip-preflight-checks

# 在k8s-master上设置kubectl的环境变量，连接kubelet
$ vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

# 在k8s-master上安装flannel pod网络组件
# 必须安装网络组件，否则kube-dns pod会一直处于ContainerCreating
$ kubectl create -f /root/kubeadm-yaml/kube-flannel
clusterrole "flannel" created
clusterrolebinding "flannel" created
serviceaccount "flannel" created
configmap "kube-flannel-cfg" created
daemonset "kube-flannel-ds" created

# 在k8s-master上验证kube-dns成功启动，大概等待3分钟
$ kubectl get pods --all-namespaces -o wide
kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                 READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   kube-apiserver-k8s-master            1/1       Running   0          3m        192.168.60.72   k8s-master
kube-system   kube-controller-manager-k8s-master   1/1       Running   0          3m        192.168.60.72   k8s-master
kube-system   kube-dns-3913472980-k9mt6            3/3       Running   0          4m        10.244.0.104    k8s-master
kube-system   kube-flannel-ds-3hhjd                2/2       Running   0          1m        192.168.60.72   k8s-master
kube-system   kube-proxy-rzq3t                     1/1       Running   0          4m        192.168.60.72   k8s-master
kube-system   kube-scheduler-k8s-master            1/1       Running   0          3m        192.168.60.72   k8s-master

# 在k8s-master上安装dashboard组件
$ kubectl create -f /root/kubeadm-yaml/kube-dashboard/
serviceaccount "kubernetes-dashboard" created
clusterrolebinding "kubernetes-dashboard" created
deployment "kubernetes-dashboard" created
service "kubernetes-dashboard" created

# 在k8s-master上启动proxy，映射地址到0.0.0.0
$ kubectl proxy --address='0.0.0.0' &

# 在Mac上访问dashboard地址：
http://k8s-master:30000

# 在k8s-master上允许在master上部署pod，否则heapster会无法部署
$ kubectl taint nodes --all node-role.kubernetes.io/master-
node "k8s-master" tainted

# 如果上边的命令执行错误，请执行以下命令
$ kubectl patch node k8s-master -p '{"spec":{"unschedulable":false}}'

# 在k8s-master上安装heapster组件，监控性能
$ kubectl create -f /root/kubeadm-yaml/kube-heapster

# 在k8s-master上重启docker以及kubelet服务，让heapster在dashboard上生效显示
$ systemctl restart docker kubelet

# 在k8s-master上检查pods状态
$ kubectl get all --all-namespaces -o wide
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE       IP              NODE
kube-system   heapster-783524908-kn6jd                1/1       Running   1          9m        10.244.0.111    k8s-master
kube-system   kube-apiserver-k8s-master               1/1       Running   1          15m       192.168.60.72   k8s-master
kube-system   kube-controller-manager-k8s-master      1/1       Running   1          15m       192.168.60.72   k8s-master
kube-system   kube-dns-3913472980-k9mt6               3/3       Running   3          16m       10.244.0.110    k8s-master
kube-system   kube-flannel-ds-3hhjd                   2/2       Running   3          13m       192.168.60.72   k8s-master
kube-system   kube-proxy-rzq3t                        1/1       Running   1          16m       192.168.60.72   k8s-master
kube-system   kube-scheduler-k8s-master               1/1       Running   1          15m       192.168.60.72   k8s-master
kube-system   kubernetes-dashboard-2039414953-d46vw   1/1       Running   1          11m       10.244.0.109    k8s-master
kube-system   monitoring-grafana-3975459543-8l94z     1/1       Running   1          9m        10.244.0.112    k8s-master
kube-system   monitoring-influxdb-3480804314-72ltf    1/1       Running   1          9m        10.244.0.113    k8s-master

##############################################
# 在k8s-master、k8s-master1、k8s-master2上配置高可用集群
##############################################

# 在k8s-master上把/etc/kubernetes/复制到k8s-master1、k8s-master2
scp -r /etc/kubernetes/ k8s-master1:/etc/
scp -r /etc/kubernetes/ k8s-master2:/etc/

# 在k8s-master1、k8s-master2重启kubelet服务，并检查kubelet服务状态
systemctl daemon-reload && systemctl restart kubelet
journalctl -u kubelet -f

# 在k8s-master1、k8s-master2上设置kubectl的环境变量，连接kubelet
$ vi ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf

# 在k8s-master1、k8s-master2检测节点状态，发现节点已经加进来
kubectl get nodes -o wide
NAME          STATUS    AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION
k8s-master    Ready     26m       v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.6.1.el7.x86_64
k8s-master1   Ready     2m        v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.21.1.el7.x86_64
k8s-master2   Ready     2m        v1.6.4    <none>        CentOS Linux 7 (Core)   3.10.0-514.21.1.el7.x86_64

# 在k8s-master1、k8s-master2上修改kube-apiserver.yaml的配置
vi /etc/kubernetes/manifests/kube-apiserver.yaml
    - --advertise-address=${HOST_IP}

# 在k8s-master1和k8s-master2上的修改kubelet.conf设置，此时，会出现kubelet配置的crt和key与ip地址不一致的情况，kubelet启动失败，导致k8s-master1和k8s-master2节点丢失，crt和key必须重新制作
vi /etc/kubernetes/kubelet.conf
server: https://${HOST_IP}:6443

# 在k8s-master1和k8s-master2上使用ca.key和ca.crt制作apiserver.crt和apiserver.key
mkdir -p /etc/kubernetes/pki-local
cd /etc/kubernetes/pki-local

# 在k8s-master1和k8s-master2上生成2048位的密钥对
openssl genrsa -out apiserver.key 2048

# 在k8s-master1和k8s-master2上生成证书签署请求文件
openssl req -new -key apiserver.key -subj "/CN=kube-apiserver," -out apiserver.csr

# 在k8s-master1和k8s-master2上编辑apiserver.ext文件，内容如下：
vi apiserver.ext
subjectAltName = DNS:${HOST_NAME},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP:10.96.0.1, IP:${HOST_IP}

# 在k8s-master1和k8s-master2上使用ca.key和ca.crt签署上述请求
openssl x509 -req -in apiserver.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out apiserver.crt -days 365 -extfile apiserver.ext

# 在k8s-master1和k8s-master2上查看新生成的证书：
openssl x509 -noout -text -in apiserver.crt
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
                DNS:k8s-master1, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:172.16.107.130
    Signature Algorithm: sha1WithRSAEncryption
         dd:68:16:f9:11:be:c3:3c:be:89:9f:14:60:6b:e0:47:c7:91:
         9e:78:ab:ce

# 在k8s-master1和k8s-master2上把apiserver.crt和apiserver.key文件复制到/etc/kubernetes/pki目录
cp apiserver.crt apiserver.key /etc/kubernetes/pki/

# 在k8s-master1和k8s-master2上修改admin.conf
vi /etc/kubernetes/admin.conf
    server: https://${HOST_IP}:6443

# 在k8s-master1和k8s-master2上修改controller-manager.conf
vi /etc/kubernetes/controller-manager.conf
    server: https://${HOST_IP}:6443

# 在k8s-master1和k8s-master2上修改scheduler.conf
vi /etc/kubernetes/scheduler.conf
    server: https://${HOST_IP}:6443

# 在k8s-master、k8s-master1、k8s-master2上重启所有服务
systemctl restart docker kubelet

# 在k8s-master上检测服务启动情况，发现apiserver、controller-manager、kube-scheduler、proxy、flannel已经在k8s-master1、k8s-master2成功启动
kubectl get pod --all-namespaces -o wide | grep k8s-master1
kube-system   kube-apiserver-k8s-master1              1/1       Running   1          55s       192.168.60.77   k8s-master1
kube-system   kube-controller-manager-k8s-master1     1/1       Running   2          18m       192.168.60.77   k8s-master1
kube-system   kube-flannel-ds-t8gkh                   2/2       Running   4          18m       192.168.60.77   k8s-master1
kube-system   kube-proxy-bpgqw                        1/1       Running   1          18m       192.168.60.77   k8s-master1
kube-system   kube-scheduler-k8s-master1              1/1       Running   2          18m       192.168.60.77   k8s-master1

kubectl get pod --all-namespaces -o wide | grep k8s-master2
kube-system   kube-apiserver-k8s-master2              1/1       Running   1          1m        192.168.60.78   k8s-master2
kube-system   kube-controller-manager-k8s-master2     1/1       Running   2          18m       192.168.60.78   k8s-master2
kube-system   kube-flannel-ds-tmqmx                   2/2       Running   4          18m       192.168.60.78   k8s-master2
kube-system   kube-proxy-4stg3                        1/1       Running   1          18m       192.168.60.78   k8s-master2
kube-system   kube-scheduler-k8s-master2              1/1       Running   2          18m       192.168.60.78   k8s-master2

# 通过kubectl logs检查各个controller-manager和scheduler的leader election结果
kubectl logs -n kube-system kube-controller-manager-k8s-master
kubectl logs -n kube-system kube-controller-manager-k8s-master1
kubectl logs -n kube-system kube-controller-manager-k8s-master2

kubectl logs -n kube-system kube-scheduler-k8s-master
kubectl logs -n kube-system kube-scheduler-k8s-master1
kubectl logs -n kube-system kube-scheduler-k8s-master2

# 在k8s-master上查看deployment的情况
kubectl get deploy --all-namespaces
NAMESPACE     NAME                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   heapster               1         1         1            1           41m
kube-system   kube-dns               1         1         1            1           48m
kube-system   kubernetes-dashboard   1         1         1            1           43m
kube-system   monitoring-grafana     1         1         1            1           41m
kube-system   monitoring-influxdb    1         1         1            1           41m

# 在k8s-master上把kubernetes-dashboard、kube-dns、 scale up成replicas=3，保证各个master节点上都有运行
kubectl scale --replicas=3 -n kube-system deployment/kube-dns
kubectl get pods --all-namespaces -o wide| grep kube-dns

kubectl scale --replicas=3 -n kube-system deployment/kubernetes-dashboard
kubectl get pods --all-namespaces -o wide| grep kubernetes-dashboard

kubectl scale --replicas=3 -n kube-system deployment/heapster
kubectl get pods --all-namespaces -o wide| grep heapster

kubectl scale --replicas=3 -n kube-system deployment/monitoring-grafana
kubectl get pods --all-namespaces -o wide| grep monitoring-grafana

kubectl scale --replicas=3 -n kube-system deployment/monitoring-influxdb
kubectl get pods --all-namespaces -o wide| grep monitoring-influxdb


################################
# keepalived安装配置
################################

# 在k8s-master、k8s-master1、k8s-master2上安装keepalived
yum install -y keepalived
systemctl enable keepalived && systemctl restart keepalived

# 在k8s-master、k8s-master1、k8s-master2上配置keepalived
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak

# 在k8s-master上设置nginx监控脚本，当nginx检测失败的时候关闭keepalived服务，转移virtual ip
vi /etc/keepalived/check_nginx.sh
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

chmod a+x /etc/keepalived/check_nginx.sh

# 在k8s-master、k8s-master1、k8s-master2上查看接口名字
ip a | grep 192.168.60

# 在k8s-master、k8s-master1、k8s-master2上设置keepalived，参数说明如下：
# state ${STATE}：为MASTER或者BACKUP，只能有一个MASTER
# interface ${INTERFACE_NAME}：为本机的需要绑定的接口名称（如：ens33）
# mcast_src_ip ${HOST_IP}：为本机的IP地址
# priority ${PRIORITY}：为优先级，例如102，优先级越高越容易选择为MASTER，优先级不能一样
# ${VIRTUAL_IP}：为虚拟的IP地址

vi /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script chk_nginx {
    script "/etc/keepalived/check_nginx.sh"
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
       chk_nginx
    }
}

# 在k8s-master、k8s-master1、k8s-master2上重启keepalived服务
systemctl restart keepalived

# 在k8s-master、k8s-master1、k8s-master2上启动nginx容器
docker run -d -p 8443:8443 \
--name nginx-lb \
--restart always \
-v /root/kubeadm-yaml/kube-ha/nginx-default.conf:/etc/nginx/nginx.conf \
k8s-registry:5000/nginx

# 在k8s-master、k8s-master1、k8s-master2上检测keepalived服务的virtual ip指向
curl -L 192.168.60.79:8443 | wc -l
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14    0    14    0     0  18324      0 --:--:-- --:--:-- --:--:-- 14000
1

# 此时virtual ip指向k8s-master，关闭k8s-master上的docker，再次curl发现virtual ip指向k8s-master1。
kubectl logs -f --tail=10 -n kube-system kube-apiserver-k8s-master
kubectl logs -f --tail=10 -n kube-system kube-apiserver-k8s-master1

# 业务恢复后务必重启keepalived，否则keepalived会处于关闭状态
systemctl restart keepalived

# 查看keeplived日志，有以下输出表示当前virtual ip绑定的主机
systemctl status keepalived -l
VRRP_Instance(VI_1) Sending gratuitous ARPs on ens160 for 192.168.60.79


################################
# k8s-master、k8s-master1、k8s-master2设置admin.conf使用keepalived的virtual ip
################################

# 在k8s-master、k8s-master1、k8s-master2上生成2048位的密钥对
openssl genrsa -out apiserver.key 2048

# 在k8s-master、k8s-master1、k8s-master2上生成证书签署请求文件
openssl req -new -key apiserver.key -subj "/CN=kube-apiserver," -out apiserver.csr

# 在k8s-master、k8s-master1、k8s-master2上编辑apiserver.ext文件，新增IP地址指向keepalived的virtual ip，内容如下：
vi apiserver.ext
subjectAltName = DNS:${HOST_NAME},DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP:10.96.0.1, IP:${HOST_IP}, IP:192.168.60.79

# 在k8s-master、k8s-master1、k8s-master2上使用ca.key和ca.crt签署上述请求
openssl x509 -req -in apiserver.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out apiserver.crt -days 365 -extfile apiserver.ext

# 在k8s-master、k8s-master1、k8s-master2上查看新生成的证书：
openssl x509 -noout -text -in apiserver.crt
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
                DNS:k8s-master1, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP Address:10.96.0.1, IP Address:172.16.107.130
    Signature Algorithm: sha1WithRSAEncryption
         dd:68:16:f9:11:be:c3:3c:be:89:9f:14:60:6b:e0:47:c7:91:
         9e:78:ab:ce

# 在k8s-master、k8s-master1、k8s-master2上把apiserver.crt和apiserver.key文件复制到/etc/kubernetes/pki目录
cp apiserver.crt apiserver.key /etc/kubernetes/pki/

# 在k8s-master、k8s-master1、k8s-master2上重启docker kubelet keepalived服务
systemctl restart docker kubelet keepalived

# 在k8s-master、k8s-master1、k8s-master2上修改admin.conf文件，把kubectl指向到keepalived的virtual ip。注意建议不要设置admin.conf，否则kubectl exec会经常出现断连的情况。
vi /etc/kubernetes/admin.conf
    server: https://192.168.60.79:8443

# 在k8s-master、k8s-master1、k8s-master2上检查kubectl连接状态是否正常
kubectl get pods --all-namespaces -o wide | grep master2

kubectl get nodes

# 在k8s-master上设置kube-proxy使用keepalived的virtual ip，避免出现k8s-master异常的时候所有节点连接不上
kubectl get -n kube-system configmap
NAME                                 DATA      AGE
extension-apiserver-authentication   6         4h
kube-flannel-cfg                     2         4h
kube-proxy                           1         4h

# 在k8s-master上修改configmap/kube-proxy的server指向keepalived的virtual ip
kubectl edit -n kube-system configmap/kube-proxy
        server: https://192.168.60.79:8443

# 在k8s-master、k8s-master1、k8s-master2上重启docker kubelet keepalived服务
systemctl restart docker kubelet keepalived

# 在k8s-master上查看configmap/kube-proxy设置情况
kubectl get -n kube-system configmap/kube-proxy -o yaml

# 在k8s-master删除所有kube-proxy的pod，让proxy重建
kubectl get pods --all-namespaces -o wide | grep proxy

##############################################
# 在k8s-node1 ~ k8s-node8上安装kubernetes
##############################################

# 在k8s-master上复制相关镜像文件到k8s-node1 ~ k8s-node8
$ scp -r /root/kubeadm-images/ k8s-node1:/root
$ scp -r /root/kubeadm-images/ k8s-node2:/root
$ scp -r /root/kubeadm-images/ k8s-node3:/root
$ scp -r /root/kubeadm-images/ k8s-node4:/root
$ scp -r /root/kubeadm-images/ k8s-node5:/root
$ scp -r /root/kubeadm-images/ k8s-node6:/root
$ scp -r /root/kubeadm-images/ k8s-node7:/root
$ scp -r /root/kubeadm-images/ k8s-node8:/root

# 在k8s-node1 ~ k8s-node8上安装kubernetes
$ yum install -y kubelet kubeadm kubectl kubernetes-cni
$ systemctl enable kubelet && systemctl start kubelet

# 在k8s-node1 ~ k8s-node8上务必关闭防火墙并重启docker和kubernetes
$ systemctl disable firewalld && systemctl stop firewalld && systemctl status firewalld
$ systemctl restart docker && systemctl restart kubelet

# ！！注意，必须设置setenforce 0，每次重启自动setenforce 0
$ vi /etc/selinux/config
SELINUX=permissive

$ chmod +x /etc/rc.d/rc.local
$ vi /etc/rc.d/rc.local
setenforce 0

$ setenforce 0

# 在k8s-node1 ~ k8s-node8上加载相关镜像文件到docker
$ docker load -i /root/kubeadm-images/etcd-amd64
$ docker load -i /root/kubeadm-images/flannel
$ docker load -i /root/kubeadm-images/heapster-amd64
$ docker load -i /root/kubeadm-images/heapster-grafana-amd64
$ docker load -i /root/kubeadm-images/heapster-influxdb-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-dnsmasq-nanny-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-kube-dns-amd64
$ docker load -i /root/kubeadm-images/k8s-dns-sidecar-amd64
$ docker load -i /root/kubeadm-images/kube-apiserver-amd64
$ docker load -i /root/kubeadm-images/kube-controller-manager-amd64
$ docker load -i /root/kubeadm-images/kube-proxy-amd64
$ docker load -i /root/kubeadm-images/kubernetes-dashboard-amd64
$ docker load -i /root/kubeadm-images/kube-scheduler-amd64
$ docker load -i /root/kubeadm-images/pause-amd64

# 使用kubeadm初始化集群
# kubeadm启动过程会卡在
# [apiclient] Created API client, waiting for the control plane to become ready
# 查看日志，发现如下错误
# journalctl -t kubelet -S '2017-06-08'
# 解决error: failed to run Kubelet: failed to create kubelet: misconfiguration: kubelet cgroup driver: "systemd"
# 需要修改KUBELET_CGROUP_ARGS=--cgroup-driver=systemd为KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs
$ vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"

# 重启服务
$ systemctl daemon-reload && systemctl restart kubelet

# 设置iptables参数，否则会提示错误
# [preflight] Some fatal errors occurred:
# 	/proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
$ sysctl net.bridge.bridge-nf-call-iptables=1
$ sysctl net.bridge.bridge-nf-call-ip6tables=1

# 在k8s-node1 ~ k8s-node8上把节点加入集群，记得加上--skip-preflight-checks
$ kubeadm join --token 73ffdb.3a139e4f487d30bd 192.168.60.79:8443 --skip-preflight-checks

# 查看kubelet状态
$ systemctl status kubelet

# 在k8s-master上禁止在master上发布应用，因为master上没有共享存储glusterfs
$ kubectl patch node k8s-master -p '{"spec":{"unschedulable":true}}'
$ kubectl patch node k8s-master1 -p '{"spec":{"unschedulable":true}}'
$ kubectl patch node k8s-master2 -p '{"spec":{"unschedulable":true}}'

# 在k8s-master上检查各个节点状态
$ kubectl get nodes -o wide
NAME          STATUS                     AGE       VERSION
k8s-master    Ready,SchedulingDisabled   5h        v1.6.4
k8s-master1   Ready,SchedulingDisabled   4h        v1.6.4
k8s-master2   Ready,SchedulingDisabled   4h        v1.6.4
k8s-node1     Ready                      6m        v1.6.4
k8s-node2     Ready                      4m        v1.6.4
k8s-node3     Ready                      4m        v1.6.4
k8s-node4     Ready                      3m        v1.6.4
k8s-node5     Ready                      3m        v1.6.4
k8s-node6     Ready                      3m        v1.6.4
k8s-node7     Ready                      3m        v1.6.4
k8s-node8     Ready                      3m        v1.6.4

##############################################
# 统一k8s集群的timezone
##############################################
# 在k8s-registry上timezone设置
$ ll /etc/localtime
exit
lrwxrwxrwx. 1 root root 35 3月   3 09:48 /etc/localtime -> ../usr/share/zoneinfo/Asia/Shanghai
$ vi /etc/timezone
Asia/Shanghai

# 在k8s-registry上把timezone文件复制到k8s-master、k8s-slave、k8s-node1~k8s-node8上
$ scp /etc/timezone k8s-master:/etc/
$ scp /etc/timezone k8s-slave:/etc/
$ scp /etc/timezone k8s-node1:/etc/
$ scp /etc/timezone k8s-node2:/etc/
$ scp /etc/timezone k8s-node3:/etc/
$ scp /etc/timezone k8s-node4:/etc/
$ scp /etc/timezone k8s-node5:/etc/
$ scp /etc/timezone k8s-node6:/etc/
$ scp /etc/timezone k8s-node7:/etc/
$ scp /etc/timezone k8s-node8:/etc/