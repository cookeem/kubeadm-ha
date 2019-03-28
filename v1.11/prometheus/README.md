# 先创建文件夹和设置权限

mkdir -p /mnt/mycephfs/k8s-deploy/kube-system/prometheus
chown -R 65534:65534 /mnt/mycephfs/k8s-deploy/kube-system/prometheus
