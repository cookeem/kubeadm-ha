version: '2'
services:
  etcd:
    image: gcr.io/google_containers/etcd-amd64:3.1.10
    container_name: etcd
    hostname: etcd
    volumes:
    - /etc/ssl/certs:/etc/ssl/certs
    - /var/lib/etcd-cluster:/var/lib/etcd
    ports:
    - 4001:4001
    - 2380:2380
    - 2379:2379
    restart: always
    command: ["sh", "-c", "etcd --name=K8SHA_ETCDNAME \
      --advertise-client-urls=http://K8SHA_IPLOCAL:2379,http://K8SHA_IPLOCAL:4001 \
      --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
      --initial-advertise-peer-urls=http://K8SHA_IPLOCAL:2380 \
      --listen-peer-urls=http://0.0.0.0:2380 \
      --initial-cluster-token=9477af68bbee1b9ae037d6fd9e7efefd \
      --initial-cluster=etcd1=http://K8SHA_IP1:2380,etcd2=http://K8SHA_IP2:2380,etcd3=http://K8SHA_IP3:2380 \
      --initial-cluster-state=new \
      --auto-tls \
      --peer-auto-tls \
      --data-dir=/var/lib/etcd"]
