# kubernetes 高可用 master 安装

- k8s master firewall需要开放相关端口（master）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 6443*   | Kubernetes API server
TCP | Inbound | 2379-2380 | etcd server client API
TCP | Inbound | 10250   | Kubelet API
TCP | Inbound | 10251   | kube-scheduler
TCP | Inbound | 10252   | kube-controller-manager
TCP | Inbound | 10255   | Read-only Kubelet API (Deprecated)

```
systemctl status firewalld

firewall-cmd --zone=public --add-port=4001/tcp --permanent
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10251/tcp --permanent
firewall-cmd --zone=public --add-port=10252/tcp --permanent
firewall-cmd --zone=public --add-port=10255/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

firewall-cmd --reload
firewall-cmd --list-all --zone=public
```

- k8s worker firewall需要开放相关端口（worker）

协议 | 方向 | 端口 | 说明
:--- | :--- | :--- | :---
TCP | Inbound | 10250     | Kubelet API
TCP | Inbound | 10255     | Read-only Kubelet API (Deprecated)
TCP | Inbound | 30000-32767 | NodePort Services**

```
systemctl status firewalld

firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10255/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

firewall-cmd --reload
firewall-cmd --list-all --zone=public
```

- 所有k8s节点允许kube-proxy的forward

```
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -i docker0 -j ACCEPT -m comment --comment "kube-proxy redirects"
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 1 -o docker0 -j ACCEPT -m comment --comment "docker subnet"
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 1 -i flannel.1 -j ACCEPT -m comment --comment "flannel subnet"
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 1 -o flannel.1 -j ACCEPT -m comment --comment "flannel subnet"
firewall-cmd --reload
firewall-cmd --list-all --zone=public
firewall-cmd --direct --get-all-rules

systemctl restart firewalld
```

- 解决kube-proxy无法启用nodePort，重启firewalld必须执行以下命令

```
crontab -e
0,5,10,15,20,25,30,35,40,45,50,55 * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
```

- 所有节点设置enforce

```
$ vi /etc/selinux/config
SELINUX=permissive

$ setenforce 0

$ getenforce
Permissive
```

- 所有节点设置sysctl

```
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

- 所有节点安装并启动组件

```
yum install -y docker-ce-17.12.0.ce-0.2.rc2.el7.centos.x86_64
yum install -y docker-compose-1.9.0-5.el7.noarch
systemctl enable docker && systemctl start docker

yum install -y kubelet-1.11.1-0.x86_64 kubeadm-1.11.1-0.x86_64 kubectl-1.11.1-0.x86_64
systemctl enable kubelet && systemctl start kubelet
```

- 所有节点安装ceph组件，用于连接cephfs

```
yum -y install ceph-common
```

- 在master节点安装并启动keepalived

```
yum install -y keepalived
systemctl enable keepalived && systemctl restart keepalived
```

- 所有节点设置harbor的registry

```
mkdir -p /etc/docker/certs.d/devops-reg.io

cat <<EOF > /etc/docker/certs.d/devops-reg.io/devops-reg.io.crt
-----BEGIN CERTIFICATE-----
MIIFvzCCA6egAwIBAgIJAN9MRxf7YGQeMA0GCSqGSIb3DQEBCwUAMIGJMQswCQYD
VQQGEwJDTjESMBAGA1UECAwJZ3Vhbmdkb25nMRIwEAYDVQQHDAlndWFuZ3pob3Ux
DTALBgNVBAoMBGdtY2MxDDAKBgNVBAsMA3N3ZzEWMBQGA1UEAwwNZGV2b3BzLXJl
Zy5pbzEdMBsGCSqGSIb3DQEJARYOY29va2VlbUBxcS5jb20wHhcNMTgwMTE3MDIy
NDUxWhcNMTkwMTE3MDIyNDUxWjCBiTELMAkGA1UEBhMCQ04xEjAQBgNVBAgMCWd1
YW5nZG9uZzESMBAGA1UEBwwJZ3Vhbmd6aG91MQ0wCwYDVQQKDARnbWNjMQwwCgYD
VQQLDANzd2cxFjAUBgNVBAMMDWRldm9wcy1yZWcuaW8xHTAbBgkqhkiG9w0BCQEW
DmNvb2tlZW1AcXEuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
wCYBO6sdvHLqa2aFmb308QBRlekVrADhBkRB/TlPYoO8CTGnNDBzJPrOo7a+VyiZ
0BGVzaCbm5uoUc55vfvAm36/EsisiHMGBW+Z/OcMxWXs+WNv6ziRloh8pzNHUkC6
kyhqoqqOA8INv18UBcmmA9d3lyyMcz0ybPj8s+PpTFlwDK/7KBgtf0/lD2JRQW2B
b9EKsC/wHGYM3GDhX/fvSogbOMq/D1kZExRHsOH4VJuYmY9rGh0eGHAGymGUL5hA
SftKK9N0guLqtAHxC3yzTTkzQ4YL6ps1mQRg2D2FlkSjpCYiT1ey31P1wIDlGRYY
AgDfKxqjGTy0GuWCt9mi2sC0hs0pyI1NRLIyf0OOuaBMkgwg+arxQ/yu2ipqzmVD
CjTsYnfZoGl5tY+syJjMc+kFEk/OJMbqajEEVnetkDnaHyL9uj4sAiy+ZUhFpjex
ivtO7V9MqrR6XAJln9YZkR1TFyWKG9wzw6FCXqzHO7Tn53nWvPWe/+JFfN/2KajC
sJ5GBzWdVDow19MAu2adlkDAfXdkkKDNTuj8/Sf3+imhcFLJlmmuK1mP1OwTxFwZ
86OFfT6/hAQJPwTSz1XMuqKudo7ekJNzOXFVVE7ppHdr8BKT9Shl97VIvh8DidTy
CiA53RTR1XjLYUXIjkuJ4xopP0Y+HlHkKpeZIAo4PlkCAwEAAaMoMCYwJAYDVR0R
BB0wG4INZGV2b3BzLXJlZy5pb4cEwKgUH4cEvABgTzANBgkqhkiG9w0BAQsFAAOC
AgEAXbNxTcqHBgS32j3NeInftDhT/H+PU69MyDv+Wjyrya/oy5w9EdmlDixOx3un
94vj1uqUp/YWmlrq5cMDsdWcW+Q+mWza5/x0egUOHpe1iWAvczC2+8Wf1eXwYIJZ
bAdm271XyWWglTGonFvdw9pE6r0i9jn2evRbxqEYd1YLdmJCmUAE9DoUnLxGHEah
QWwd/WscFyP9QrojmXRTwCr/h12zLoArQldEbCTHpWvKOes+cCII0VX9tX0c2ucL
TJWuGXXIwGY2r8UEv7ISf7OXMh8XAeix7nml4yulBFxBjq+NtpUk0wyCSCC1cyHE
csjvzXiVCK9FYcNyI3gm7pzAu5va35G60yb0wETirXrc7No/HsIH490frDHpsFa5
3sc9ia6LuM5gxieCkwiwG8rb//wE7y7FU+tGTdyogIFqZOA3JxpuKcrXsgBg4D1f
DkVfARasycxFa2SnR+YOV7IBI4jMICi7AN+z3TF8YiDQSVYGl05TzIKLj+tjHxrD
A+fMhYL5q1JfiupMSxWhs+/pdcPwYOAgZnyqrGtLYKG7QwM8+FznCRCrypwHerTE
T1N5oF6HrxAINjTAm4bcRQwLcvvuekcBIHUSPvQqF0Omfn4Y6W9N8RgLh61V3hq5
et2CIhi2ykpxNqOEWmH1isv7SvCZymslzhqjdpuWOFF/7xE=
-----END CERTIFICATE-----
EOF

docker login devops-reg.io
```

- 所有节点加载相关docker images

```
k8s.gcr.io/kube-apiserver-amd64:v1.11.1
k8s.gcr.io/kube-controller-manager-amd64:v1.11.1
k8s.gcr.io/kube-scheduler-amd64:v1.11.1
k8s.gcr.io/kube-proxy-amd64:v1.11.1
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd-amd64:3.2.18
k8s.gcr.io/coredns:1.1.3
```

- 所有节点禁用swap

```
swapoff -a

vi /etc/fstab
#/dev/mapper/centos-swap swap          swap  defaults    0 0

cat /proc/swaps
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
$ kubectl run nginx --image=devops-reg.io/public/nginx --replicas=3 --port=80
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
kubectl run nginx-client -ti --rm --image=devops-reg.io/public/alpine-curl -- ash
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
kubectl run nginx-server --requests=cpu=10m --image=devops-reg.io/public/nginx --port=80
kubectl expose deployment nginx-server --port=80

# 创建hpa
kubectl autoscale deployment nginx-server --cpu-percent=10 --min=1 --max=10
kubectl get hpa
kubectl describe hpa nginx-server

# 给测试服务增加负载
kubectl run -ti --rm load-generator --image=devops-reg.io/public/busybox -- ash
wget -q -O- http://nginx-server.default.svc.cluster.local
while true; do wget -q -O- http://nginx-server.default.svc.cluster.local; done

# 检查hpa自动扩展情况，一般需要等待几分钟。结束增加负载后，pod自动缩容（自动缩容需要大概10-15分钟）
kubectl get hpa -w

# 删除测试数据
kubectl delete deploy,svc,hpa nginx-server
```
