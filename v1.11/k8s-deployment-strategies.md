# blue-green deploy svc mode

1. create deploy/my-app-v1
2. create svc/my-app -> deploy/my-app-v1
3. create deploy/my-app-v2
4. upgrade: patch svc/my-app -> deploy/my-app-v2
5. rollback: patch svc/my-app -> deploy/my-app-v1
6. confirmed: remove deploy/my-app-v1

# blue-green deploy ingress mode

1. create deploy/my-app-v1
2. create svc/my-app-v1 -> deploy/my-app-v1
3. create ing/my-app -> svc/my-app-v1
4. create deploy/my-app-v2
5. create svc/my-app-v2 -> deploy/my-app-v2
6. upgrade: patch ing/my-app -> svc/my-app-v2
7. rollback: patch ing/my-app -> svc/my-app-v1
8. confirmed: remove deploy/my-app-v1 svc/my-app-v1

# canary deploy svc mode

1. create deploy/my-app-v1 * 10 replicas
2. create svc/my-app -> deploy/my-app (v1 + v2)
3. create deploy/my-app-v2 * 1 replicas
4. upgrade: scale deploy/my-app-v2 * 10 replicas (after user tested)
5. rollback: remove deploy/my-app-v2
5. confirmed: remove deploy/my-app-v1

# ab-testing deploy istio mode

1. create deploy/my-app-v1
2. create svc/my-app-v1 -> deploy/my-app-v1
3. create virtualservice/my-app -> svc/my-app-v1
4. create gateway/my-app -> virtualservice/my-app
5. create deploy/my-app-v2
6. create svc/my-app-v2 -> deploy/my-app-v2
7. upgrade: patch virtualservice/my-app -> svc/my-app-v1 + svc/my-app-v2 match header
7. upgrade: patch virtualservice/my-app -> svc/my-app-v1 * 90% + svc/my-app-v2 * 10% weight
8. rollback: deploy virtualservice/my-app -> svc/my-app-v1
9. confirmed: remove deploy/my-app-v1 svc/my-app-v1

# shadow deploy istio mode

1. create deploy/my-app-v1
2. create svc/my-app-v1 -> deploy/my-app-v1
3. create virtualservice/my-app -> svc/my-app-v1
4. create gateway/my-app -> virtualservice/my-app
5. create deploy/my-app-v2
6. create svc/my-app-v2 -> deploy/my-app-v2
7. upgrade: patch virtualservice/my-app -> svc/my-app-v1 mirror to svc/my-app-v2
8. rollback: deploy virtualservice/my-app -> svc/my-app-v1
9. confirmed: remove deploy/my-app-v1 svc/my-app-v1
