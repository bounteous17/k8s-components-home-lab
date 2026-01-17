# Current Mikrotik Router Configuration

## NAT Rules for Port Forwarding

The Mikrotik router is configured to forward traffic to nginx reverse proxy:

### Active Rules

**Rule 0:** HTTPS forwarding
- **Chain:** `dstnat`
- **Interface:** `ether1` (WAN interface)
- **Protocol:** `tcp`
- **Dst. Port:** `443`
- **Action:** `dst-nat`
- **To Addresses:** `192.168.11.100` (nginx node - lion)
- **To Ports:** `30445` (nginx HTTPS NodePort)
- **Comment:** "Allow incoming traffic from my WAN Ip without VPN (for isp router wifi)"

**Rule 1:** HTTP forwarding
- **Chain:** `dstnat`
- **Interface:** `ether1` (WAN interface)
- **Protocol:** `tcp`
- **Dst. Port:** `80`
- **Action:** `dst-nat`
- **To Addresses:** `192.168.11.100` (nginx node - lion)
- **To Ports:** `32248` (nginx HTTP NodePort)
- **Comment:** "Allow incoming traffic from my WAN Ip without VPN (for isp router wifi)"

### Disabled Rules (Old Traefik Configuration)

**Rule 4:** Old Traefik HTTP forwarding (disabled)
- Was forwarding to `192.168.11.100:80` (Traefik port)
- Now disabled (marked with X)

**Rule 5:** Old Traefik HTTPS forwarding (disabled)
- Was forwarding to `192.168.11.100:443` (Traefik port)
- Now disabled (marked with X)

## Traffic Flow

```
Internet → ISP Router (DMZ) → Mikrotik Router (ether1)
                                    ↓
                          NAT Rules 0 & 1
                                    ↓
                    Forward to 192.168.11.100:32248 (HTTP)
                    Forward to 192.168.11.100:30445 (HTTPS)
                                    ↓
                          Nginx Reverse Proxy
                                    ↓
                    Sets X-Forwarded-For (HTTP) or Proxy Protocol (HTTPS)
                                    ↓
                              Traefik
                                    ↓
                    IPWhitelist Middleware checks client IP
                                    ↓
                          Internal Apps (if allowed)
```

## Summary

- **HTTP (port 80):** Mikrotik → nginx NodePort 32248 → Traefik
- **HTTPS (port 443):** Mikrotik → nginx NodePort 30445 → Traefik (with Proxy Protocol)

The configuration is correct - all traffic goes through nginx, which sets the proper headers/protocol so Traefik can see the real client IP.
