# Nginx Reverse Proxy for Real IP Forwarding

This nginx reverse proxy sits between the Mikrotik router and Traefik, setting proper `X-Forwarded-For` headers so Traefik can see the real client IP.

## Architecture

```
Internet → ISP Router (DMZ) → Mikrotik Router → Nginx (sets X-Forwarded-For) → Traefik → Services
```

## Deployment

### Step 1: Deploy Nginx

```bash
kubectl apply -f nginx/nginx-reverse-proxy.yaml
```

### Step 2: Get Nginx Service IP

```bash
# If using LoadBalancer
kubectl get svc nginx-proxy -n nginx-proxy

# If using NodePort, get the node IP and port
kubectl get svc nginx-proxy -n nginx-proxy -o jsonpath='{.spec.ports[0].nodePort}'
```

### Step 3: Update Mikrotik Router

Point your Mikrotik router's port forwarding to the nginx service instead of directly to Traefik:

**Mikrotik Configuration:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=<nginx-service-ip> \
    to-ports=80,443 comment="Forward to Nginx Proxy"
```

### Step 4: Update Traefik Trusted IPs

Update Traefik's HelmChartConfig to trust the nginx proxy:

```bash
# Get nginx pod IP range
kubectl get pods -n nginx-proxy -o wide
```

Then update `traefik/helmchartconfig.yaml` to include the nginx pod IP in trusted IPs.

### Step 5: Verify

1. **Check nginx is running:**
   ```bash
   kubectl get pods -n nginx-proxy
   kubectl logs -n nginx-proxy -l app=nginx-proxy
   ```

2. **Test the debug service:**
   ```bash
   curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<nginx-ip>/
   ```

3. **Check X-Forwarded-For header:**
   The response should now show your actual client IP, not `10.42.1.0`.

## Configuration Details

### X-Forwarded-For Header

Nginx sets:
- `X-Forwarded-For: $remote_addr` - The actual client IP
- `X-Real-IP: $remote_addr` - Alternative header
- `X-Forwarded-Proto: $scheme` - HTTP or HTTPS
- `Host: $host` - Original host header

### Upstream to Traefik

Nginx forwards to:
- `traefik.kube-system.svc.cluster.local:80` - Traefik service

## Troubleshooting

### Check Nginx Logs

```bash
kubectl logs -n nginx-proxy -l app=nginx-proxy
```

### Check if Headers are Set

```bash
# Access debug service through nginx
curl -v -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<nginx-ip>/
```

Look for `X-Forwarded-For` in the response.

### Verify Traefik Sees Correct IP

After nginx is deployed, check Traefik logs:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

## Alternative: Use NodePort

If LoadBalancer isn't available, change the service type to NodePort:

```yaml
spec:
  type: NodePort  # Instead of LoadBalancer
```

Then point Mikrotik to `<node-ip>:<nodeport>`.

## Cleanup

To remove nginx proxy:

```bash
kubectl delete -f nginx/nginx-reverse-proxy.yaml
```

Then update Mikrotik to point back to Traefik directly.
