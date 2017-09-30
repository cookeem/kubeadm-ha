> /kind feature

kubeadm now is not support HA, so we can not use kubeadm to setup a production kubernetes cluster. But create a HA cluster from scratch is too complicated, and when I google keyword "kubeadm HA", only few article or mind draft related tell me how to.

So I try lots of ways to reform "kubeadm init", finally I make kubeadm cluster support HA, and I hope this way will help "kubeadm init" support creating a HA production cluster.

Detail operational guidelines is here: https://github.com/cookeem/kubeadm-ha

## Summary

- **Linux version: CentOS 7.3.1611**
- **docker version: 1.12.6**
- **kubeadm version: v1.6.4**
- **kubelet version: v1.6.4**
- **kubernetes version: v1.6.4**

- **Hosts list**

HostName | IPAddress | Notes | Components 
:--- | :--- | :--- | :---
k8s-master1 | 192.168.60.71 | master node 1 | keepalived, nginx, etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy, kube-dashboard, heapster
k8s-master2 | 192.168.60.72 | master node 2 | keepalived, nginx, etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy, kube-dashboard, heapster
k8s-master3 | 192.168.60.73 | master node 3 | keepalived, nginx, etcd, kubelet, kube-apiserver, kube-scheduler, kube-proxy, kube-dashboard, heapster
N/A | 192.168.60.80 | keepalived virtual IP | N/A
k8s-node1 ~ 8 | 192.168.60.81 ~ 88 | 8 worker nodes | kubelet, kube-proxy

- **Detail deployment architecture**

![k8s ha](https://github.com/cookeem/kubeadm-ha/raw/master/images/k8s-ha.png)

## Critical steps

- **1. Deploy an independent etcd tls cluster on all master nodes**

- **2. On k8s-master1: use `kubeadm init` create master connect independent etcd tls cluster**

```
$ cat /root/kubeadm-ha/kubeadm-init.yaml 
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

$ kubeadm init --config=/root/kubeadm-ha/kubeadm-init.yaml
```

- **3. Copy k8s-master1 /etc/kubernetes directory to k8s-master2 and k8s-master3**

- **4. Use ca.key and ca.crt re-create all master nodes' apiserver.key and apiserver.crt certificates**

Modify apiserver.crt `X509v3 Subject Alternative Name` DNS and IP to current hostname and IP address, and add keepalived virtual IP address. 

- **5. Edit all master nodes' admin.conf controller-manager.conf scheduler.conf, replace `server` point to current IP address**

- **6. Setup keepalived, and create a virtual IP redirect to all master nodes**

- **7. Setup nginx as all master apiserver's load balancer**

- **8. Update configmap/kube-proxy, replace `server` point to virtual IP apiserver's load balancer**

## How to make kubeadm support HA

- **1. We can presume our kubeadm init config file like this: **
```
$ cat /root/kubeadm-ha/kubeadm-init.yaml 
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v1.6.4
networking:
  podSubnet: 10.244.0.0/16
ha:
  # this settings is current IP address  
  ip: 192.168.60.71
  # this settings is keepalived virtual IP address
  vip: 192.168.60.80
  # this settings is master nodes' IP address list.
  # 1. kubeadm init use this info to create apiserver.crt and apiserver.key files. 
  # 2. And use this settings to create an etcd tls cluster pods. 
  # 3. And use this settings to create nginx load balancer pods.
  # 4. And use this settings to create keepalived virtual ip.
  masters:
  - 192.168.60.71
  - 192.168.60.72
  - 192.168.60.73
```

- **2. On k8s-master1 we use `kubeadm init --config=/root/kubeadm-ha/kubeadm-init.yaml` create a master node**

kubeadm will create etcd/nginx/keepalived pods and all certificates and *.conf files.

- **3. On k8s-master1 copy /etc/kubernetes/pki directory to k8s-master2 and k8s-master3**

- **4. On k8s-master2 and k8s-master3 replace kubeadm-init.yaml ha.ip settings to current IP address**

- **5. On k8s-master2 and k8s-master3 we use `kubeadm init --config=/root/kubeadm-ha/kubeadm-init.yaml` create 2 master nodes**

kubeadm will create etcd/nginx/keepalived pods and all certificates and *.conf files, then k8s-master2 and k8s-master3 will join the HA cluster automatically.

