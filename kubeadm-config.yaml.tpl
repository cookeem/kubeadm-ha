apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.14.0
apiServerCertSANs:
- K8SHA_HOST1
- K8SHA_HOST2
- K8SHA_HOST3
- K8SHA_VHOST
- K8SHA_IP1
- K8SHA_IP2
- K8SHA_IP3
- K8SHA_VIP
controlPlaneEndpoint: "K8SHA_VIP:16443"
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: "K8SHA_CIDR/16"
