#!/bin/bash

#######################################
# set variables below to create the config files, all files will create at ./config directory
#######################################

# master keepalived virtual ip address
export K8SHA_VIP=172.20.10.9

# master01 ip address
export K8SHA_IP1=172.20.10.10

# master02 ip address
export K8SHA_IP2=172.20.10.11

# master03 ip address
export K8SHA_IP3=172.20.10.12

# master keepalived virtual ip hostname
export K8SHA_VHOST=demo-vip.local

# master01 hostname
export K8SHA_HOST1=demo-01.local

# master02 hostname
export K8SHA_HOST2=demo-02.local

# master03 hostname
export K8SHA_HOST3=demo-03.local

# master01 network interface name
export K8SHA_NETINF1=enp0s3

# master02 network interface name
export K8SHA_NETINF2=enp0s3

# master03 network interface name
export K8SHA_NETINF3=enp0s3

# keepalived auth_pass config
export K8SHA_KEEPALIVED_AUTH=412f7dc3bfed32194d1600c483e10ad1d

# calico reachable ip address
export K8SHA_CALICO_REACHABLE_IP=172.20.10.1

# kubernetes CIDR pod subnet
export K8SHA_CIDR=192.168.0.0

##############################
# please do not modify anything below
##############################

mkdir -p config/$K8SHA_HOST1/{keepalived,nginx-lb}
mkdir -p config/$K8SHA_HOST2/{keepalived,nginx-lb}
mkdir -p config/$K8SHA_HOST3/{keepalived,nginx-lb}

# create all kubeadm-config.yaml files

sed \
-e "s/K8SHA_HOST1/${K8SHA_HOST1}/g" \
-e "s/K8SHA_HOST2/${K8SHA_HOST2}/g" \
-e "s/K8SHA_HOST3/${K8SHA_HOST3}/g" \
-e "s/K8SHA_VHOST/${K8SHA_VHOST}/g" \
-e "s/K8SHA_IP1/${K8SHA_IP1}/g" \
-e "s/K8SHA_IP2/${K8SHA_IP2}/g" \
-e "s/K8SHA_IP3/${K8SHA_IP3}/g" \
-e "s/K8SHA_VIP/${K8SHA_VIP}/g" \
-e "s/K8SHA_CIDR/${K8SHA_CIDR}/g" \
kubeadm-config.yaml.tpl > kubeadm-config.yaml

echo "create kubeadm-config.yaml files success. kubeadm-config.yaml"

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

cp nginx-lb/docker-compose.yaml config/$K8SHA_HOST1/nginx-lb/
cp nginx-lb/docker-compose.yaml config/$K8SHA_HOST2/nginx-lb/
cp nginx-lb/docker-compose.yaml config/$K8SHA_HOST3/nginx-lb/

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

scp -r config/$K8SHA_HOST1/nginx-lb root@$K8SHA_HOST1:/root/
scp -r config/$K8SHA_HOST2/nginx-lb root@$K8SHA_HOST2:/root/
scp -r config/$K8SHA_HOST3/nginx-lb root@$K8SHA_HOST3:/root/

scp -r config/$K8SHA_HOST1/keepalived/* root@$K8SHA_HOST1:/etc/keepalived/
scp -r config/$K8SHA_HOST2/keepalived/* root@$K8SHA_HOST2:/etc/keepalived/
scp -r config/$K8SHA_HOST3/keepalived/* root@$K8SHA_HOST3:/etc/keepalived/
