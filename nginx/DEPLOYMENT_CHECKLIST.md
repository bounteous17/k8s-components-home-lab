# Nginx Deployment Checklist

## Pre-Deployment

- [x] Nginx YAML file created
- [x] Traefik HelmChartConfig created
- [x] Middleware updated with correct VPN range (10.255.255.0/24)

## Deployment Steps

- [x] Deploy nginx: `kubectl apply -f nginx/nginx-reverse-proxy.yaml`
- [ ] Verify nginx pod is running: `kubectl get pods -n nginx-proxy`
- [ ] Get nginx service IP/NodePort: `kubectl get svc nginx-proxy -n nginx-proxy`
- [ ] Update Mikrotik router port forwarding to point to nginx
- [ ] Apply Traefik HelmChartConfig: `kubectl apply -f traefik/helmchartconfig.yaml`
- [ ] Wait for Traefik to restart: `kubectl rollout status deployment/traefik -n kube-system`
- [ ] Test access from VPN
- [ ] Test access from router network
- [ ] Verify X-Forwarded-For shows real client IP (not 10.42.1.0)

## Verification Commands

```bash
# 1. Check nginx status
kubectl get pods -n nginx-proxy
kubectl logs -n nginx-proxy -l app=nginx-proxy

# 2. Get nginx access info
kubectl get svc nginx-proxy -n nginx-proxy

# 3. Check Traefik configuration
kubectl get deployment traefik -n kube-system -o jsonpath='{.spec.template.spec.containers[0].args[*]}' | tr ' ' '\n' | grep trustedIPs

# 4. Test from debug service (if available)
curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<nginx-ip>/

# 5. Check nginx logs for real IPs
kubectl logs -n nginx-proxy -l app=nginx-proxy --tail=20
```

## Expected Results

After setup:
- ✅ Nginx pod running in `nginx-proxy` namespace
- ✅ Nginx service has EXTERNAL-IP or NodePort
- ✅ Mikrotik forwards to nginx
- ✅ Traefik trusts nginx IP range (10.43.0.0/16)
- ✅ X-Forwarded-For shows real client IP (VPN IP, router network IP)
- ✅ Internal apps accessible from VPN and router network
- ✅ External IPs still blocked (403 Forbidden)
