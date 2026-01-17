# Mikrotik Router Configuration for Nginx

## Current Setup

- **Nginx Service Type:** LoadBalancer (EXTERNAL-IP pending, using NodePort)
- **NodePorts:** 
  - HTTP: `32248`
  - HTTPS: `30445`
- **Cluster Nodes:**
  - `lion`: 192.168.11.100 (nginx pod is running here)
  - `eagle`: 192.168.11.101
  - `octopus`: 192.168.11.51
  - `panda`: 192.168.11.50

## Recommended Configuration

### Option 1: Use Node IP with Service Ports (Recommended)

Since nginx is running on `lion` (192.168.11.100), use:

**Mikrotik CLI:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=80,443 comment="Forward to Nginx Proxy on lion node"
```

**Mikrotik WebFig:**
- Chain: `dstnat`
- Protocol: `tcp`
- Dst. Port: `80,443`
- Action: `dst-nat`
- To Addresses: `192.168.11.100`
- To Ports: `80,443`

### Option 2: Use NodePort (Alternative)

If Option 1 doesn't work, use the NodePort numbers:

**Mikrotik CLI:**
```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=32248 comment="Forward HTTP to Nginx NodePort"

add chain=dstnat dst-port=443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=30445 comment="Forward HTTPS to Nginx NodePort"
```

**Note:** This requires separate rules for HTTP (80→32248) and HTTPS (443→30445).

### Option 3: Use Any Node IP (Load Balancing)

You can use any node IP, and kube-proxy will route to the nginx pod:

```mikrotik
/ip firewall nat
add chain=dstnat dst-port=80,443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.50 \
    to-ports=80,443 comment="Forward to Nginx (any node)"
```

Use any of: `192.168.11.50`, `192.168.11.51`, `192.168.11.100`, or `192.168.11.101`

## Recommended: Use Option 1

**Use this value in Mikrotik:**
- **To Addresses:** `192.168.11.100` (lion node where nginx is running)
- **To Ports:** `80,443`

## Verification

After configuring Mikrotik:

1. **Test HTTP access:**
   ```bash
   curl -H "Host: ip-debug.home-lab.begoodguys.ovh" http://<your-external-ip>/
   ```

2. **Check nginx logs:**
   ```bash
   kubectl logs -n nginx-proxy -l app=nginx-proxy --tail=20
   ```

3. **Verify X-Forwarded-For header:**
   The debug service should show your real client IP, not `10.42.1.0`

## Troubleshooting

### If Option 1 doesn't work:

1. **Check if nginx is accessible on the node:**
   ```bash
   curl http://192.168.11.100:32248/ -H "Host: ip-debug.home-lab.begoodguys.ovh"
   ```

2. **Try Option 2 (NodePort):**
   Use ports `32248` and `30445` instead of `80` and `443`

3. **Check firewall rules:**
   Ensure Mikrotik allows traffic to the node IP
