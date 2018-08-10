######################
# basic auth

# 创建密钥文件

```
# 账号: tfadmin
# 密码: tfadmin
echo -n 'tfadmin:' > htpasswd
openssl passwd -apr1 >> htpasswd
```

# 创建secret

```
kubectl create secret generic traefik-admin-secret --from-file htpasswd --namespace=kube-system
```

#######################
# tls支持

# 创建证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=k8s-master-lb"

kubectl -n kube-system create secret generic traefik-cert --from-file=tls.key --from-file=tls.crt

kubectl apply -f .
