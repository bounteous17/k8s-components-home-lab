# HTTPS Passthrough Issue

## Problem

When using nginx stream module for SSL passthrough (port 443), nginx works at the TCP level and **cannot set HTTP headers** like `X-Forwarded-For`. This means Traefik won't see the real client IP for HTTPS requests.

## Solutions

### Option 1: Use Proxy Protocol (Recommended)

Proxy Protocol is a TCP-level protocol that prepends connection information (including source IP) to the connection. Traefik supports it.

**Update nginx stream config:**
```nginx
stream {
    upstream traefik_https {
        server traefik.kube-system.svc.cluster.local:443;
    }
    
    server {
        listen 443;
        proxy_pass traefik_https;
        proxy_protocol on;  # Enable Proxy Protocol
        proxy_timeout 1s;
        proxy_responses 1;
    }
}
```

**Update Traefik to accept Proxy Protocol:**
Add to `traefik/helmchartconfig.yaml`:
```yaml
additionalArguments:
  - --entryPoints.websecure.proxyProtocol.trustedIPs=10.42.0.0/16,10.43.0.0/16
  - --entryPoints.websecure.proxyProtocol.insecure=false
```

### Option 2: Have Nginx Terminate SSL

Have nginx terminate SSL and forward HTTP to Traefik. This requires SSL certificates in nginx.

### Option 3: Use HTTP Only (Not Recommended)

Redirect HTTPS to HTTP, but this breaks SSL security.

## Current Status

- ✅ HTTP (port 80) works - nginx sets X-Forwarded-For headers
- ❌ HTTPS (port 443) uses stream passthrough - cannot set headers

## Next Steps

1. Implement Proxy Protocol (Option 1) - most secure and proper solution
2. Or have nginx terminate SSL (Option 2) - requires certificate management
