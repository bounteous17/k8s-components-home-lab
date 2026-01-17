# Troubleshooting: Traffic Not Reaching Nginx

## Problem: Traffic Still Going Directly to Traefik

If you're still getting Forbidden errors and traffic isn't reaching nginx, the Mikrotik router is likely still forwarding to Traefik instead of nginx.

## Step 1: Verify Nginx is Working

Test nginx directly from within the cluster:

```bash
# Test nginx from a pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://nginx-proxy.nginx-proxy.svc.cluster.local/

# Or test from a node
curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://192.168.11.100:32248/
```

If this works, nginx is functioning correctly.

## Step 2: Check Current Mikrotik Configuration

You need to verify/update the Mikrotik router configuration. The issue is likely:

1. **Old Traefik forwarding rule still active**
2. **New nginx rule not created**
3. **Wrong IP/port in the rule**

### Check Mikrotik NAT Rules

**Via Mikrotik CLI (SSH/Terminal):**
```mikrotik
/ip firewall nat print
```

Look for rules forwarding to:
- Traefik (old rule - should be removed or disabled)
- Nginx (new rule - should be active)

### Check Mikrotik WebFig

1. Go to **IP → Firewall → NAT**
2. Look for rules with:
   - Dst. Port: `80,443` or `80` and `443`
   - Action: `dst-nat`
3. Check which IP they're forwarding to:
   - **Old (wrong):** Traefik node IP or Traefik service IP
   - **New (correct):** `192.168.11.100` (nginx node)

## Step 3: Update Mikrotik Router

### Remove Old Traefik Rule

**Mikrotik CLI:**
```mikrotik
# Find the old Traefik rule
/ip firewall nat print

# Remove it (replace [number] with actual rule number)
/ip firewall nat remove [number]

# Or disable it
/ip firewall nat disable [number]
```

**Mikrotik WebFig:**
1. Find the rule forwarding to Traefik
2. Either delete it or disable it

### Add New Nginx Rule

**Mikrotik CLI:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=80,443 comment="Forward to Nginx Proxy" \
    place-before=[first-rule-number]
```

**Mikrotik WebFig:**
1. Click **Add New**
2. **General Tab:**
   - Chain: `dstnat`
   - Protocol: `tcp`
   - Dst. Port: `80,443`
3. **Action Tab:**
   - Action: `dst-nat`
   - To Addresses: `192.168.11.100`
   - To Ports: `80,443`
4. **Comment:** `Forward to Nginx Proxy`
5. **Move rule to top** (important - rules are processed in order)

## Step 4: Verify Rule Order

NAT rules are processed **top to bottom**. Make sure the nginx rule is **above** any Traefik rules.

**Mikrotik CLI:**
```mikrotik
# Move nginx rule to top
/ip firewall nat move [nginx-rule-number] 0
```

**Mikrotik WebFig:**
- Use the up/down arrows to move the nginx rule to the top

## Step 5: Test Direct Access to Nginx

From a device on your network, test nginx directly:

```bash
# Test HTTP
curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://192.168.11.100:32248/

# Test HTTPS (if configured)
curl -k -H "Host: ip-debug.home-lab.begoodguys.ovh" https://192.168.11.100:30445/
```

If this works, nginx is accessible. The issue is Mikrotik routing.

## Step 6: Check What Traefik Sees

Check Traefik logs to see if it's still receiving direct traffic:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 | grep -i "forbidden\|403\|whitelist"
```

If you see logs when accessing internal apps, Traefik is still receiving traffic directly.

## Step 7: Alternative - Use NodePort Directly

If Mikrotik configuration is complex, you can point Mikrotik directly to the NodePort:

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

## Step 8: Verify Nginx Receives Traffic

After updating Mikrotik, check nginx logs:

```bash
# Watch nginx logs in real-time
kubectl logs -n nginx-proxy -l app=nginx-proxy -f
```

Then access one of your internal apps. You should see log entries in nginx.

## Common Issues

### Issue 1: Multiple NAT Rules

**Symptom:** Multiple rules forwarding port 80/443
**Solution:** Remove or disable old rules, keep only nginx rule

### Issue 2: Rule Order

**Symptom:** Nginx rule exists but Traefik rule is processed first
**Solution:** Move nginx rule to top of NAT rules list

### Issue 3: Wrong IP

**Symptom:** Rule points to wrong node IP
**Solution:** Verify nginx pod location: `kubectl get pods -n nginx-proxy -o wide`

### Issue 4: Port Mismatch

**Symptom:** Using wrong ports
**Solution:** Use `80,443` for service ports, or `32248,30445` for NodePorts

## Quick Verification Checklist

- [ ] Nginx pod is running: `kubectl get pods -n nginx-proxy`
- [ ] Nginx is accessible directly: `curl http://192.168.11.100:32248/`
- [ ] Old Traefik NAT rule is removed/disabled
- [ ] New nginx NAT rule is created and active
- [ ] Nginx rule is above Traefik rule (if Traefik rule still exists)
- [ ] Nginx rule points to `192.168.11.100:80,443` or `192.168.11.100:32248,30445`
- [ ] Nginx logs show incoming requests when accessing apps

## Still Not Working?

If nginx is working but Mikrotik still forwards to Traefik:

1. **Check for other forwarding rules** (maybe in different chains)
2. **Check Mikrotik connection tracking** - old connections might be cached
3. **Restart Mikrotik NAT** (if safe to do so)
4. **Check if there's a load balancer** in front of Mikrotik that also needs configuration
