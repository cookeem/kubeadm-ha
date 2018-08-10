
# 创建密钥文件

```
# 管理员账号: kadmin

# 管理员密码: kAdm#1119

echo -n 'kadmin:' > htpasswd
openssl passwd -apr1 >> htpasswd
```

# 把server.conf和htpasswd复制到对应目录

```
cp server.conf /mnt/mycephfs/k8s-deploy/kube-system/nginx-kibana/
cp htpasswd /mnt/mycephfs/k8s-deploy/kube-system/nginx-kibana/
```

# 在local-storage节点上创建目录，并设置权限
mkdir -p /local-storage/kube-system/elasticsearch
chown -R 1000:1000 /local-storage/kube-system/elasticsearch

cat <<EOF >> /etc/sysctl.conf
vm.max_map_count=262144
EOF

sysctl --system

