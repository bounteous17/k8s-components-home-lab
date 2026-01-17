# Mikrotik RouterOS Configuration for Real IP Forwarding

## Problem

Mikrotik RouterOS doesn't natively support adding HTTP headers like `X-Forwarded-For`. When forwarding traffic to Traefik, the router doesn't preserve the original client IP, so Traefik sees the router's IP instead.

## Solution Options

### Option 1: Use Proxy Protocol (Recommended if Traefik supports it)

Proxy Protocol is a protocol that prepends connection information (including source IP) to TCP connections. It's more reliable than HTTP headers.

#### Mikrotik Configuration

**Using RouterOS CLI:**

```mikrotik
# Enable proxy protocol on the destination NAT rule
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp action=dst-nat \
    to-addresses=<traefik-node-ip> to-ports=80,443 \
    comment="Forward to Traefik with Proxy Protocol"
```

**Note:** Mikrotik RouterOS doesn't natively support Proxy Protocol v2. You may need to use a reverse proxy (nginx) that supports Proxy Protocol.

#### Traefik Configuration

If using Proxy Protocol, configure Traefik to accept it:

```yaml
# In traefik/helmchartconfig.yaml
additionalArguments:
  - --entryPoints.web.proxyProtocol.trustedIPs=192.168.10.0/24,192.168.11.0/24
  - --entryPoints.websecure.proxyProtocol.trustedIPs=192.168.10.0/24,192.168.11.0/24
```

### Option 2: Use Nginx Reverse Proxy (Most Reliable)

Deploy nginx as a reverse proxy that:
1. Receives traffic from Mikrotik router
2. Sets `X-Forwarded-For` headers properly
3. Forwards to Traefik

This is the most reliable solution since Mikrotik doesn't support HTTP header modification.

#### Architecture

```
Internet → ISP Router (DMZ) → Mikrotik Router → Nginx (sets headers) → Traefik → Services
```

#### Nginx Configuration

```nginx
server {
    listen 80;
    listen 443 ssl;
    server_name *.home-lab.begoodguys.ovh;

    # Set X-Forwarded-For header
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $host;

    # Forward to Traefik
    location / {
        proxy_pass http://<traefik-service-ip>:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Option 3: Use Mikrotik Web Proxy (If Available)

Some Mikrotik models support a web proxy feature that can modify headers.

#### Check if Web Proxy is Available

```mikrotik
/ip proxy
print
```

If available, you can configure it to add headers, but this is limited and not recommended for production.

### Option 4: Source NAT with IP Passthrough (Limited)

For internal networks, you can configure source NAT to preserve the source IP, but this only works for internal networks, not external traffic.

#### Mikrotik Configuration

```mikrotik
# For internal networks (192.168.10.0/24, 192.168.11.0/24)
# Don't NAT - let the source IP pass through
/ip firewall nat
add chain=srcnat src-address=192.168.10.0/24 dst-address=<traefik-node-ip> \
    action=accept comment="Allow internal IP passthrough"
add chain=srcnat src-address=192.168.11.0/24 dst-address=<traefik-node-ip> \
    action=accept comment="Allow internal IP passthrough"

# For VPN network (10.255.255.0/24)
add chain=srcnat src-address=10.255.255.0/24 dst-address=<traefik-node-ip> \
    action=accept comment="Allow VPN IP passthrough"
```

**Limitations:**
- Only works if Traefik can directly see the client IP
- Requires routing configuration
- May not work if traffic goes through multiple hops

## Recommended Solution: Nginx Reverse Proxy

Since Mikrotik doesn't support HTTP header modification, the best solution is to deploy nginx as a reverse proxy.

### Step 1: Deploy Nginx

Create `nginx/nginx-reverse-proxy.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-proxy
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-proxy
  namespace: nginx-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-proxy
  template:
    metadata:
      labels:
        app: nginx-proxy
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        - containerPort: 443
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-proxy
  namespace: nginx-proxy
spec:
  type: LoadBalancer  # Or NodePort
  selector:
    app: nginx-proxy
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: nginx-proxy
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        upstream traefik {
            server traefik.kube-system.svc.cluster.local:80;
        }
        
        server {
            listen 80;
            server_name _;
            
            # Set X-Forwarded-For header with real client IP
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Host $host;
            
            location / {
                proxy_pass http://traefik;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
            }
        }
    }
```

### Step 2: Update Mikrotik to Forward to Nginx

Point your Mikrotik router's port forwarding to the nginx service instead of directly to Traefik.

### Step 3: Update Traefik Trusted IPs

Update Traefik's HelmChartConfig to trust the nginx proxy IP:

```yaml
additionalArguments:
  - --entryPoints.web.forwardedHeaders.trustedIPs=192.168.10.0/24,192.168.11.0/24,10.255.255.0/24,<nginx-pod-ip-range>
```

## Alternative: Use Traefik's Direct Access (Simpler)

If you can access Traefik directly from internal networks without going through the router, you can:

1. **Configure Traefik to listen on NodePort** (already done in k3s)
2. **Point Mikrotik port forwarding directly to Traefik NodePort**
3. **Use source NAT passthrough** for internal networks (see Option 4 above)

This way, Traefik sees the real client IP directly without needing headers.

## Quick Reference: Mikrotik NAT Rules

### Port Forwarding to Traefik

```mikrotik
# Forward HTTP/HTTPS to Traefik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=<traefik-node-ip> \
    to-ports=80,443 comment="Forward to Traefik"
```

### Source NAT for Internal Networks

```mikrotik
# Don't NAT internal networks (preserve source IP)
/ip firewall nat
add chain=srcnat src-address=192.168.10.0/24 \
    dst-address=<traefik-node-ip> action=accept \
    comment="Preserve internal IP"
add chain=srcnat src-address=192.168.11.0/24 \
    dst-address=<traefik-node-ip> action=accept \
    comment="Preserve internal IP"
add chain=srcnat src-address=10.255.255.0/24 \
    dst-address=<traefik-node-ip> action=accept \
    comment="Preserve VPN IP"
```

## Testing

After configuration:

1. **Check if X-Forwarded-For is set:**
   ```bash
   curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<cluster-ip>/
   ```

2. **Verify the IP in the response** matches your actual client IP (not 10.42.1.0)

3. **Test from different sources:**
   - VPN: Should show VPN IP (10.255.255.x)
   - Router network: Should show router network IP (192.168.x.x)
   - External: Should show external IP

## Next Steps

1. Choose a solution (recommended: Nginx reverse proxy)
2. Implement the configuration
3. Update Traefik trusted IPs
4. Test and verify X-Forwarded-For headers
5. Update IPWhitelist middleware to remove the pod network workaround
