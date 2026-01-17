# Mikrotik Configuration - Fixed

## What Was Fixed

The Mikrotik router had conflicting NAT rules:
- **Rules 0 and 1:** Forwarding to nginx NodePorts (30445, 32248) ✅ Correct
- **Rules 4 and 5:** Forwarding to Traefik ports (80, 443) ❌ Old rules - now disabled

## Current Configuration

**Active Rules:**
- Rule 0: `ether1:443` → `192.168.11.100:30445` (nginx HTTPS NodePort)
- Rule 1: `ether1:80` → `192.168.11.100:32248` (nginx HTTP NodePort)

**Disabled Rules:**
- Rule 4: Old Traefik HTTP forwarding (disabled)
- Rule 5: Old Traefik HTTPS forwarding (disabled)

## Verification

Nginx is now receiving traffic with real client IPs:
- Internal network: `192.168.10.254`
- External IPs: `193.142.147.209` (and others)

## Test Internal Apps

Now try accessing your internal apps:
- `https://argocd.home-lab.begoodguys.ovh`
- `https://longhorn.home-lab.begoodguys.ovh`
- `https://qbittorrent.home-lab.begoodguys.ovh`

They should work from:
- ✅ VPN (10.255.255.x)
- ✅ Router network (192.168.10.x, 192.168.11.x)
- ❌ External IPs (should be blocked by IPWhitelist)

## Monitor Nginx Logs

Watch nginx logs to see requests:

```bash
kubectl logs -n nginx-proxy -l app=nginx-proxy -f
```

You should see:
- Real client IPs in the logs
- Requests to your internal app domains
- X-Forwarded-For headers being set correctly

## If Still Getting Forbidden

If you still get Forbidden errors:

1. **Check nginx logs** - are requests reaching nginx?
2. **Check Traefik logs** - is Traefik receiving requests from nginx?
3. **Verify X-Forwarded-For header** - use debug service to check
4. **Check IPWhitelist middleware** - verify IP ranges are correct

## Next Steps

1. ✅ Old Traefik rules disabled
2. ✅ Nginx receiving traffic
3. ⏳ Test internal apps access
4. ⏳ Verify X-Forwarded-For headers are correct
5. ⏳ Confirm external IPs are blocked
