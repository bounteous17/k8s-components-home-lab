# Debugging Forbidden Errors After Nginx Setup

## Current Status

- ✅ Nginx is receiving traffic
- ✅ Nginx is forwarding to Traefik
- ❌ Traefik is returning Forbidden (403)

## What We Fixed

1. **Updated middleware to use IPAllowList** (was using deprecated IPWhiteList)
2. **Middleware exists** in `default` namespace
3. **Traefik trusted IPs configured** to trust nginx (10.43.0.0/16)

## Next Steps to Debug

### 1. Check What IP Nginx is Setting

Check nginx logs to see what IP it's seeing and setting in X-Forwarded-For:

```bash
kubectl logs -n nginx-proxy -l app=nginx-proxy --tail=20
```

Look for the client IP in the logs. It should be your real IP (VPN IP, router network IP, etc.).

### 2. Verify X-Forwarded-For Header

Create a test to see what Traefik is receiving:

```bash
# If you have the debug service
curl -H "Host: ip-debug.home-lab.begoodguys.ovh" https://longhorn.home-lab.begoodguys.ovh/
```

Check the X-Forwarded-For header in the response.

### 3. Check Traefik Logs for IPWhitelist Decisions

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50 | grep -i "allow\|deny\|whitelist\|forbidden"
```

### 4. Verify Middleware is Applied

The middleware should now be using IPAllowList. Check:

```bash
kubectl get middleware ipwhitelist-internal -n default -o yaml
```

Should show `ipAllowList` (not `ipWhiteList`).

### 5. Test with Different IPs

Try accessing from:
- VPN (10.255.255.x) - should work
- Router network (192.168.10.x or 192.168.11.x) - should work
- External IP - should be blocked

## Common Issues

### Issue 1: X-Forwarded-For Shows Wrong IP

If X-Forwarded-For shows nginx pod IP (10.42.x.x) instead of your real IP:
- Nginx is not setting the header correctly
- Check nginx config: `kubectl exec -n nginx-proxy -l app=nginx-proxy -- cat /etc/nginx/nginx.conf`

### Issue 2: IP Not in Whitelist

If your IP is not in the whitelist ranges:
- Check your actual IP: `curl ifconfig.me` (from VPN/network)
- Verify it's in: 192.168.10.0/24, 192.168.11.0/24, or 10.255.255.0/24
- Update middleware if needed

### Issue 3: Traefik Not Trusting Nginx

If Traefik doesn't trust nginx's X-Forwarded-For header:
- Verify HelmChartConfig is applied
- Check Traefik args include nginx IP range (10.43.0.0/16)
- Restart Traefik if needed

## Quick Test

After the middleware update, try accessing again:

```bash
# From VPN or router network
curl -v https://longhorn.home-lab.begoodguys.ovh/
```

Check:
1. Does nginx log show your real IP?
2. Does Traefik log show the request?
3. What IP does Traefik see in X-Forwarded-For?
