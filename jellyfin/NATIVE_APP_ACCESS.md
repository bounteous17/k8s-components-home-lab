# Jellyfin Native App Access Configuration

## Overview

Jellyfin native apps (mobile, desktop, smart TV) need direct access to the Jellyfin service, bypassing the ingress/nginx reverse proxy. This is configured via a Mikrotik NAT rule that forwards external port 8443 to the Jellyfin NodePort 30843.

## Mikrotik Router Configuration

### NAT Rule for Jellyfin Native Apps

**Rule Details:**
- **Chain:** `dstnat`
- **Protocol:** `tcp`
- **Dst. Port:** `8443` (external port)
- **Action:** `dst-nat`
- **To Addresses:** `192.168.11.100` (or any cluster node IP)
- **To Ports:** `30843` (Jellyfin NodePort)
- **Comment:** `Jellyfin native app access`

### Mikrotik CLI Command

```mikrotik
/ip firewall nat
add chain=dstnat dst-port=8443 protocol=tcp \
    action=dst-nat to-addresses=192.168.11.100 \
    to-ports=30843 comment="Jellyfin native app access"
```

### Mikrotik WebFig Configuration

1. Go to **IP → Firewall → NAT**
2. Click **Add New**
3. **General Tab:**
   - Chain: `dstnat`
   - Protocol: `tcp`
   - Dst. Port: `8443`
4. **Action Tab:**
   - Action: `dst-nat`
   - To Addresses: `192.168.11.100` (or any cluster node)
   - To Ports: `30843`
5. **Comment:** `Jellyfin native app access`
6. Click **OK**

## Kubernetes Configuration

### Jellyfin Service

The Jellyfin service is configured as NodePort:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jellyfin
  namespace: jellyfin
spec:
  type: NodePort
  ports:
    - name: http
      port: 8096
      targetPort: http
      nodePort: 30843  # External access port
      protocol: TCP
```

**Port Mapping:**
- **External (Internet):** Port `8443` (configured in Mikrotik)
- **Mikrotik forwards to:** Port `30843` (NodePort on cluster nodes)
- **Service port:** `8096` (internal Jellyfin port)

## How Native Apps Connect

Jellyfin native apps can connect using:

1. **Domain with port:**
   ```
   jellyfin.home-lab.begoodguys.ovh:8443
   ```

2. **Router external IP with port:**
   ```
   <your-router-external-ip>:8443
   ```

3. **Auto-discovery (LAN only):**
   - Uses UDP port 7359
   - Only works on same local network
   - Not available over internet

## Traffic Flow

```
Internet → ISP Router (DMZ) → Mikrotik Router
                                    ↓
                          NAT Rule (port 8443)
                                    ↓
                    Forward to 192.168.11.100:30843
                                    ↓
                          Kubernetes NodePort
                                    ↓
                              Jellyfin Service
                                    ↓
                            Jellyfin Pod (port 8096)
```

**Note:** This bypasses nginx and Traefik, going directly to the Jellyfin service.

## Verification

### Check Mikrotik Rule

```bash
ssh bounteous@192.168.10.1 '/ip firewall nat print' | grep Jellyfin
```

### Check Jellyfin Service

```bash
kubectl get svc jellyfin -n jellyfin
```

Should show NodePort `30843`.

### Test Connection

From a device on your network:
```bash
curl http://192.168.11.100:30843/health
```

From internet (if port forwarding works):
```bash
curl http://<router-external-ip>:8443/health
```

## Troubleshooting

### Native App Can't Connect

1. **Verify Mikrotik rule exists:**
   ```bash
   ssh bounteous@192.168.10.1 '/ip firewall nat print' | grep 8443
   ```

2. **Check Jellyfin service is running:**
   ```bash
   kubectl get pods -n jellyfin
   kubectl get svc jellyfin -n jellyfin
   ```

3. **Test NodePort directly:**
   ```bash
   # From a device on your network
   curl http://192.168.11.100:30843/health
   ```

4. **Check firewall rules:**
   - Ensure Mikrotik allows traffic on port 8443
   - Check if ISP router also needs port forwarding

5. **Verify app configuration:**
   - Server URL: `jellyfin.home-lab.begoodguys.ovh:8443`
   - Or: `<router-external-ip>:8443`
   - Port must be specified (8443)

### Alternative: Use Ingress for Native Apps

If you want native apps to also use the ingress (for SSL and consistency):

1. Configure Jellyfin to accept reverse proxy connections
2. Update native apps to use `https://jellyfin.home-lab.begoodguys.ovh` (no port)
3. This requires Jellyfin "Known Proxies" configuration

However, direct NodePort access (port 8443) is simpler and more reliable for native apps.

## Summary

- **Web access:** `https://jellyfin.home-lab.begoodguys.ovh` → Ingress → Traefik → Jellyfin
- **Native apps:** `jellyfin.home-lab.begoodguys.ovh:8443` → NodePort 30843 → Jellyfin (direct)

Both methods work simultaneously - web uses ingress, native apps use direct NodePort.
