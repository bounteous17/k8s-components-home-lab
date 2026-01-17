# Nginx Reverse Proxy Setup Instructions

## Step 1: Verify Nginx is Running

```bash
# Check nginx pod status
kubectl get pods -n nginx-proxy

# Check nginx logs
kubectl logs -n nginx-proxy -l app=nginx-proxy

# Get nginx service IP/NodePort
kubectl get svc nginx-proxy -n nginx-proxy
```

**Note the EXTERNAL-IP or NodePort** - you'll need this for Mikrotik configuration.

If using LoadBalancer and EXTERNAL-IP shows `<pending>`, you may need to:
- Change service type to NodePort (see below)
- Or wait for LoadBalancer to get an IP

## Step 2: Get Nginx Access Information

### Option A: LoadBalancer (if EXTERNAL-IP is assigned)

```bash
kubectl get svc nginx-proxy -n nginx-proxy
# Use the EXTERNAL-IP value
```

### Option B: NodePort (if LoadBalancer doesn't work)

If LoadBalancer doesn't get an IP, change to NodePort:

```bash
kubectl patch svc nginx-proxy -n nginx-proxy -p '{"spec":{"type":"NodePort"}}'
kubectl get svc nginx-proxy -n nginx-proxy
# Note the NodePort (e.g., 32248 for HTTP, 30445 for HTTPS)
# Use <node-ip>:<nodeport>
```

### Option C: Get Node IP

```bash
# Get cluster node IPs
kubectl get nodes -o wide
# Use one of the INTERNAL-IP addresses
```

## Step 3: Update Mikrotik Router

Point your Mikrotik router's port forwarding to nginx instead of Traefik:

### Mikrotik CLI Configuration

```mikrotik
# Remove old Traefik forwarding rule (if exists)
/ip firewall nat remove [find comment~"Traefik"]

# Add new rule to forward to nginx
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=<nginx-ip-or-node-ip> \
    to-ports=80,443 comment="Forward to Nginx Proxy"
```

**Replace `<nginx-ip-or-node-ip>` with:**
- LoadBalancer EXTERNAL-IP, OR
- Node IP (if using NodePort), OR
- Node IP:NodePort (if using NodePort with specific port)

### Mikrotik WebFig Configuration

1. Go to **IP → Firewall → NAT**
2. Find the rule forwarding to Traefik
3. Edit the rule:
   - **General Tab:**
     - Chain: `dstnat`
     - Protocol: `tcp`
     - Dst. Port: `80,443`
   - **Action Tab:**
     - Action: `dst-nat`
     - To Addresses: `<nginx-ip-or-node-ip>` (from Step 2)
     - To Ports: `80,443`
   - **Comment:** `Forward to Nginx Proxy`

## Step 4: Update Traefik Trusted IPs

Apply the Traefik HelmChartConfig to trust nginx:

```bash
kubectl apply -f traefik/helmchartconfig.yaml
```

This configures Traefik to trust forwarded headers from:
- Internal networks: `192.168.10.0/24`, `192.168.11.0/24`, `10.255.255.0/24`
- Kubernetes service network: `10.43.0.0/16` (where nginx pod IPs are)

Wait for Traefik to restart (may take 1-2 minutes):

```bash
kubectl rollout status deployment/traefik -n kube-system
```

## Step 5: Update IPWhitelist Middleware

Update the middleware to remove the pod network workaround (if you added it):

```bash
# Edit middlewares/ipwhitelist-internal.yaml
# Remove: - 10.42.0.0/16 (pod network workaround)
# Keep: - 192.168.10.0/24, 192.168.11.0/24, 10.255.255.0/24

kubectl apply -f middlewares/ipwhitelist-internal.yaml
```

## Step 6: Test the Setup

### Test 1: Check Nginx is Receiving Traffic

```bash
# Check nginx access logs
kubectl logs -n nginx-proxy -l app=nginx-proxy --tail=20 -f
```

Access one of your services and you should see log entries.

### Test 2: Verify X-Forwarded-For Header

Create a test service or use the debug service:

```bash
# If you have the debug service
curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<nginx-ip>/
```

The response should show your **actual client IP** in `X-Forwarded-For`, not `10.42.1.0`.

### Test 3: Access Internal Apps

Try accessing your internal apps:
- `https://argocd.home-lab.begoodguys.ovh`
- `https://longhorn.home-lab.begoodguys.ovh`
- `https://qbittorrent.home-lab.begoodguys.ovh`

They should now work from VPN and router network.

## Troubleshooting

### Nginx Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n nginx-proxy -l app=nginx-proxy

# Check logs
kubectl logs -n nginx-proxy -l app=nginx-proxy
```

### Nginx Can't Connect to Traefik

```bash
# Verify Traefik service exists
kubectl get svc traefik -n kube-system

# Test connectivity from nginx pod
kubectl exec -n nginx-proxy -l app=nginx-proxy -- wget -O- http://traefik.kube-system.svc.cluster.local:80/ping
```

### Still Seeing Wrong IP

1. **Check nginx is setting headers:**
   ```bash
   kubectl exec -n nginx-proxy -l app=nginx-proxy -- cat /etc/nginx/nginx.conf | grep X-Forwarded-For
   ```

2. **Check Traefik trusted IPs:**
   ```bash
   kubectl get deployment traefik -n kube-system -o jsonpath='{.spec.template.spec.containers[0].args[*]}' | tr ' ' '\n' | grep trustedIPs
   ```

3. **Check Traefik logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
   ```

### LoadBalancer Stuck on Pending

If LoadBalancer doesn't get an IP (common in bare metal k3s):

```bash
# Change to NodePort
kubectl patch svc nginx-proxy -n nginx-proxy -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get svc nginx-proxy -n nginx-proxy
# Use <node-ip>:<nodeport> in Mikrotik
```

## Architecture After Setup

```
Internet → ISP Router (DMZ) → Mikrotik Router → Nginx (sets X-Forwarded-For) → Traefik → Services
                                                                                      ↓
                                                                              IPWhitelist checks
                                                                              X-Forwarded-For header
                                                                                      ↓
                                                                              ✅ Allows if IP in whitelist
```

## Next Steps

1. ✅ Nginx deployed
2. ⏳ Update Mikrotik router port forwarding
3. ⏳ Apply Traefik HelmChartConfig
4. ⏳ Test access from VPN/router network
5. ⏳ Remove pod network workaround from middleware (if added)

## Cleanup (if needed)

To remove nginx and revert to direct Traefik access:

```bash
# Remove nginx
kubectl delete -f nginx/nginx-reverse-proxy.yaml

# Update Mikrotik to point back to Traefik
# Remove Traefik HelmChartConfig (optional)
kubectl delete helmchartconfig traefik -n kube-system
```
