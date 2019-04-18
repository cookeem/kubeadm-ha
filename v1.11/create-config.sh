#!/bin/bash

#######################################
# set variables below to create the config files, all files will create at ./config directory
#######################################

# master keepalived virtual ip address
export K8SHA_VIP=192.168.20.10

# master01 ip address
export K8SHA_IP1=192.168.20.20

# master02 ip address
export K8SHA_IP2=192.168.20.21

# master03 ip address
export K8SHA_IP3=192.168.20.22

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
export K8SHA_CALICO_REACHABLE_IP=192.168.20.1

# kubernetes CIDR pod subnet, if CIDR pod subnet is "172.168.0.0/16" please set to "172.168.0.0"
export K8SHA_CIDR=172.168.0.0

##############################
# please do not modify anything below
##############################

mkdir -p config/$K8SHA_HOST1/{keepalived,nginx-lb}
mkdir -p config/$K8SHA_HOST2/{keepalived,nginx-lb}
mkdir -p config/$K8SHA_HOST3/{keepalived,nginx-lb}

# create all kubeadm-config.yaml files

cat << EOF > config/$K8SHA_HOST1/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- ${K8SHA_HOST1}
- ${K8SHA_HOST2}
- ${K8SHA_HOST3}
- ${K8SHA_VHOST}
- ${K8SHA_IP1}
- ${K8SHA_IP2}
- ${K8SHA_IP3}
- ${K8SHA_VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${K8SHA_IP1}:2379"
      advertise-client-urls: "https://${K8SHA_IP1}:2379"
      listen-peer-urls: "https://${K8SHA_IP1}:2380"
      initial-advertise-peer-urls: "https://${K8SHA_IP1}:2380"
      initial-cluster: "${K8SHA_HOST1}=https://${K8SHA_IP1}:2380"
    serverCertSANs:
      - ${K8SHA_HOST1}
      - ${K8SHA_IP1}
    peerCertSANs:
      - ${K8SHA_HOST1}
      - ${K8SHA_IP1}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: "${K8SHA_CIDR}/16"
EOF

cat << EOF > config/$K8SHA_HOST2/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- ${K8SHA_HOST1}
- ${K8SHA_HOST2}
- ${K8SHA_HOST3}
- ${K8SHA_VHOST}
- ${K8SHA_IP1}
- ${K8SHA_IP2}
- ${K8SHA_IP3}
- ${K8SHA_VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${K8SHA_IP2}:2379"
      advertise-client-urls: "https://${K8SHA_IP2}:2379"
      listen-peer-urls: "https://${K8SHA_IP2}:2380"
      initial-advertise-peer-urls: "https://${K8SHA_IP2}:2380"
      initial-cluster: "${K8SHA_HOST1}=https://${K8SHA_IP1}:2380,${K8SHA_HOST2}=https://${K8SHA_IP2}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${K8SHA_HOST2}
      - ${K8SHA_IP2}
    peerCertSANs:
      - ${K8SHA_HOST2}
      - ${K8SHA_IP2}
networking:
  # This CIDR is a calico default. Substitute or remove for your CNI provider.
  podSubnet: "${K8SHA_CIDR}/16"
EOF

cat << EOF > config/$K8SHA_HOST3/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.1
apiServerCertSANs:
- ${K8SHA_HOST1}
- ${K8SHA_HOST2}
- ${K8SHA_HOST3}
- ${K8SHA_VHOST}
- ${K8SHA_IP1}
- ${K8SHA_IP2}
- ${K8SHA_IP3}
- ${K8SHA_VIP}
etcd:
  local:
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://${K8SHA_IP3}:2379"
      advertise-client-urls: "https://${K8SHA_IP3}:2379"
      listen-peer-urls: "https://${K8SHA_IP3}:2380"
      initial-advertise-peer-urls: "https://${K8SHA_IP3}:2380"
      initial-cluster: "${K8SHA_HOST1}=https://${K8SHA_IP1}:2380,${K8SHA_HOST2}=https://${K8SHA_IP2}:2380,${K8SHA_HOST3}=https://${K8SHA_IP3}:2380"
      initial-cluster-state: existing
    serverCertSANs:
      - ${K8SHA_HOST3}
      - ${K8SHA_IP3}
    peerCertSANs:
      - ${K8SHA_HOST3}
      - ${K8SHA_IP3}
networking:
  # This CIDR is a calico default. Substitute or remove for your CNI provider.
  podSubnet: "${K8SHA_CIDR}/16"
EOF

echo "create kubeadm-config.yaml files success. config/$K8SHA_HOST1/kubeadm-config.yaml"
echo "create kubeadm-config.yaml files success. config/$K8SHA_HOST2/kubeadm-config.yaml"
echo "create kubeadm-config.yaml files success. config/$K8SHA_HOST3/kubeadm-config.yaml"

# create all keepalived files
cp keepalived/check_apiserver.sh config/$K8SHA_HOST1/keepalived
cp keepalived/check_apiserver.sh config/$K8SHA_HOST2/keepalived
cp keepalived/check_apiserver.sh config/$K8SHA_HOST3/keepalived

sed \
-e "s/K8SHA_KA_STATE/BACKUP/g" \
-e "s/K8SHA_KA_INTF/${K8SHA_NETINF1}/g" \
-e "s/K8SHA_IPLOCAL/${K8SHA_IP1}/g" \
-e "s/K8SHA_KA_PRIO/102/g" \
-e "s/K8SHA_VIP/${K8SHA_VIP}/g" \
-e "s/K8SHA_KA_AUTH/${K8SHA_KEEPALIVED_AUTH}/g" \
keepalived/keepalived.conf.tpl > config/$K8SHA_HOST1/keepalived/keepalived.conf

sed \
-e "s/K8SHA_KA_STATE/BACKUP/g" \
-e "s/K8SHA_KA_INTF/${K8SHA_NETINF2}/g" \
-e "s/K8SHA_IPLOCAL/${K8SHA_IP2}/g" \
-e "s/K8SHA_KA_PRIO/101/g" \
-e "s/K8SHA_VIP/${K8SHA_VIP}/g" \
-e "s/K8SHA_KA_AUTH/${K8SHA_KEEPALIVED_AUTH}/g" \
keepalived/keepalived.conf.tpl > config/$K8SHA_HOST2/keepalived/keepalived.conf

sed \
-e "s/K8SHA_KA_STATE/BACKUP/g" \
-e "s/K8SHA_KA_INTF/${K8SHA_NETINF3}/g" \
-e "s/K8SHA_IPLOCAL/${K8SHA_IP3}/g" \
-e "s/K8SHA_KA_PRIO/100/g" \
-e "s/K8SHA_VIP/${K8SHA_VIP}/g" \
-e "s/K8SHA_KA_AUTH/${K8SHA_KEEPALIVED_AUTH}/g" \
keepalived/keepalived.conf.tpl > config/$K8SHA_HOST3/keepalived/keepalived.conf

echo "create keepalived files success. config/$K8SHA_HOST1/keepalived/"
echo "create keepalived files success. config/$K8SHA_HOST2/keepalived/"
echo "create keepalived files success. config/$K8SHA_HOST3/keepalived/"

# create all nginx-lb files

cp nginx-lb/nginx-lb.yaml config/$K8SHA_HOST1/nginx-lb/
cp nginx-lb/nginx-lb.yaml config/$K8SHA_HOST2/nginx-lb/
cp nginx-lb/nginx-lb.yaml config/$K8SHA_HOST3/nginx-lb/

sed \
-e "s/K8SHA_IP1/$K8SHA_IP1/g" \
-e "s/K8SHA_IP2/$K8SHA_IP2/g" \
-e "s/K8SHA_IP3/$K8SHA_IP3/g" \
nginx-lb/nginx-lb.conf.tpl > config/$K8SHA_HOST1/nginx-lb/nginx-lb.conf

sed \
-e "s/K8SHA_IP1/$K8SHA_IP1/g" \
-e "s/K8SHA_IP2/$K8SHA_IP2/g" \
-e "s/K8SHA_IP3/$K8SHA_IP3/g" \
nginx-lb/nginx-lb.conf.tpl > config/$K8SHA_HOST2/nginx-lb/nginx-lb.conf

sed \
-e "s/K8SHA_IP1/$K8SHA_IP1/g" \
-e "s/K8SHA_IP2/$K8SHA_IP2/g" \
-e "s/K8SHA_IP3/$K8SHA_IP3/g" \
nginx-lb/nginx-lb.conf.tpl > config/$K8SHA_HOST3/nginx-lb/nginx-lb.conf

echo "create nginx-lb files success. config/$K8SHA_HOST1/nginx-lb/"
echo "create nginx-lb files success. config/$K8SHA_HOST2/nginx-lb/"
echo "create nginx-lb files success. config/$K8SHA_HOST3/nginx-lb/"

# create calico yaml file
sed \
-e "s/K8SHA_CALICO_REACHABLE_IP/${K8SHA_CALICO_REACHABLE_IP}/g" \
-e "s/K8SHA_CIDR/${K8SHA_CIDR}/g" \
calico/calico.yaml.tpl > calico/calico.yaml

echo "create calico.yaml file success. calico/calico.yaml"
