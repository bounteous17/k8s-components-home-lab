# Verify Nginx Setup

## Current Configuration

- **Mikrotik forwarding to:** `192.168.11.100:80,443` ✅
- **Nginx pod on node:** `lion` (192.168.11.100) ✅
- **Nginx service type:** LoadBalancer with NodePorts
- **Nginx NodePorts:** HTTP `32248`, HTTPS `30445`

## Test Nginx Accessibility

### Test 1: Direct NodePort Access

From a device on your network, test nginx directly:

```bash
# Test HTTP NodePort
curl -v -H "Host: ip-debug.home-lab.begoodguys.ovh" http://192.168.11.100:32248/

# Test HTTPS NodePort (if configured)
curl -k -v -H "Host: ip-debug.home-lab.begoodguys.ovh" https://192.168.11.100:30445/
```

If this works, nginx is accessible. The issue is Mikrotik port forwarding.

### Test 2: Check if Mikrotik is Using Correct Ports

Mikrotik might be forwarding to ports 80/443, but the service might need NodePort access.

**Option A: Use NodePort in Mikrotik (Recommended)**

Update Mikrotik to forward to NodePorts:

```mikrotik
/ip firewall nat
# Remove old rule first
remove [old-rule-number]

# Add new rules with NodePort
add chain=dstnat dst-port=80 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=32248 comment="Forward HTTP to Nginx NodePort"

add chain=dstnat dst-port=443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=30445 comment="Forward HTTPS to Nginx NodePort"
```

**Option B: Change Service to NodePort Type**

If LoadBalancer isn't working, change to NodePort:

```bash
kubectl patch svc nginx-proxy -n nginx-proxy -p '{"spec":{"type":"NodePort"}}'
```

Then Mikrotik can forward to `192.168.11.100:32248` and `192.168.11.100:30445`.

### Test 3: Check Nginx Logs

Watch nginx logs while accessing an app:

```bash
kubectl logs -n nginx-proxy -l app=nginx-proxy -f
```

Then access `https://argocd.home-lab.begoodguys.ovh` (or another internal app).

**Expected:** You should see log entries in nginx
**If not:** Traffic isn't reaching nginx

### Test 4: Check Traefik Logs

Check if Traefik is still receiving traffic:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
```

If you see new log entries when accessing apps, traffic is still going to Traefik directly.

## Common Issues

### Issue 1: Port Mismatch

**Symptom:** Mikrotik forwards to 80/443 but service needs NodePort
**Solution:** Update Mikrotik to use NodePorts (32248, 30445) or change service type

### Issue 2: externalTrafficPolicy

**Symptom:** Traffic goes to wrong node
**Solution:** Set `externalTrafficPolicy: Local` (already done)

### Issue 3: Firewall Rules

**Symptom:** Traffic blocked before reaching nginx
**Solution:** Check Mikrotik firewall rules allow traffic to node IP

### Issue 4: Service Not Ready

**Symptom:** Nginx pod running but service not accessible
**Solution:** Check service endpoints: `kubectl get endpoints nginx-proxy -n nginx-proxy`

## Quick Fix: Use NodePort in Mikrotik

Since your nginx service has NodePorts `32248` (HTTP) and `30445` (HTTPS), update Mikrotik:

**Mikrotik Configuration:**
```mikrotik
/ip firewall nat
# Update existing rule or add new
add chain=dstnat dst-port=80 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=32248 comment="Forward HTTP to Nginx"

add chain=dstnat dst-port=443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=30445 comment="Forward HTTPS to Nginx"
```

This should work immediately.
