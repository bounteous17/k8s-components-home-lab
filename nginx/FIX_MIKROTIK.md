# Fix Mikrotik Router: Switch from Traefik to Nginx

## The Problem

Your Traefik service has EXTERNAL-IPs on all nodes:
- `192.168.11.100, 192.168.11.101, 192.168.11.50, 192.168.11.51`

This means Traefik is directly accessible, and your Mikrotik router is likely still forwarding to one of these IPs instead of nginx.

## Solution: Update Mikrotik NAT Rules

### Step 1: Find Current Traefik Forwarding Rule

**Mikrotik CLI (SSH/Terminal):**
```mikrotik
/ip firewall nat print where comment~"traefik" or comment~"Traefik"
```

Or check all NAT rules:
```mikrotik
/ip firewall nat print
```

Look for rules forwarding ports 80/443 to:
- `192.168.11.50`, `192.168.11.51`, `192.168.11.100`, or `192.168.11.101`
- Or any IP that matches Traefik's EXTERNAL-IPs

### Step 2: Remove or Disable Old Traefik Rule

**Option A: Remove the rule completely**
```mikrotik
# Find the rule number first
/ip firewall nat print

# Remove it (replace [number] with actual rule number)
/ip firewall nat remove [number]
```

**Option B: Disable the rule (safer - can re-enable if needed)**
```mikrotik
/ip firewall nat disable [number]
```

**Mikrotik WebFig:**
1. Go to **IP → Firewall → NAT**
2. Find the rule forwarding to Traefik (check To Addresses column)
3. Either:
   - **Delete** the rule (right-click → Remove), OR
   - **Disable** the rule (uncheck the checkbox)

### Step 3: Add New Nginx Forwarding Rule

**Mikrotik CLI:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=80,443 comment="Forward to Nginx Proxy" \
    place-before=0
```

The `place-before=0` puts it at the top of the list (important - rules are processed in order).

**Mikrotik WebFig:**
1. Click **Add New**
2. **General Tab:**
   - Chain: `dstnat`
   - Protocol: `tcp`
   - Dst. Port: `80,443`
3. **Action Tab:**
   - Action: `dst-nat`
   - To Addresses: `192.168.11.100` ← **This is the nginx node**
   - To Ports: `80,443`
4. **Extra Tab:**
   - Comment: `Forward to Nginx Proxy`
5. **Move the rule to the TOP** of the list (use up arrow or drag)

### Step 4: Verify Rule Order

NAT rules are processed **top to bottom**. The nginx rule must be **above** any Traefik rules.

**Mikrotik CLI:**
```mikrotik
# List all NAT rules to see order
/ip firewall nat print

# Move nginx rule to top (replace [number] with nginx rule number)
/ip firewall nat move [number] 0
```

**Mikrotik WebFig:**
- Use the up/down arrows to move the nginx rule to position 0 (top)

### Step 5: Test

After updating Mikrotik:

1. **Check nginx logs:**
   ```bash
   kubectl logs -n nginx-proxy -l app=nginx-proxy -f
   ```

2. **Access an internal app** (e.g., `https://argocd.home-lab.begoodguys.ovh`)

3. **You should see log entries in nginx** - if you do, traffic is reaching nginx!

4. **If you see entries in Traefik logs instead**, the Mikrotik rule isn't working:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
   ```

## Alternative: Use NodePort Directly

If the service ports (80,443) don't work, use NodePort numbers:

**Mikrotik Configuration:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=32248 comment="Forward HTTP to Nginx NodePort"

add chain=dstnat dst-port=443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=30445 comment="Forward HTTPS to Nginx NodePort"
```

## Quick Checklist

- [ ] Found old Traefik forwarding rule in Mikrotik
- [ ] Removed or disabled old Traefik rule
- [ ] Added new nginx forwarding rule (to 192.168.11.100:80,443)
- [ ] Moved nginx rule to top of NAT rules list
- [ ] Tested access - nginx logs show requests
- [ ] Internal apps now accessible

## Verification Commands

```bash
# 1. Check nginx is running
kubectl get pods -n nginx-proxy

# 2. Watch nginx logs (should see requests when accessing apps)
kubectl logs -n nginx-proxy -l app=nginx-proxy -f

# 3. Check Traefik logs (should NOT see new requests)
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20

# 4. Test nginx directly from cluster
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://nginx-proxy.nginx-proxy.svc.cluster.local/
```

## Still Not Working?

If nginx logs don't show requests:

1. **Double-check Mikrotik rule** - verify To Addresses is `192.168.11.100`
2. **Check rule order** - nginx rule must be first
3. **Check for other forwarding rules** - maybe in different chains (mangle, etc.)
4. **Test nginx directly** - from a device on your network: `curl http://192.168.11.100:32248/`
5. **Check Mikrotik connection tracking** - might need to clear: `/ip firewall connection print` then clear old connections
