# Current Mikrotik Router Configuration

## Multi-Node Load Balancing with Automatic Failover

The Mikrotik router is configured to forward traffic to all 4 cluster nodes running nginx reverse proxy, with automatic failover using Netwatch monitoring.

### Cluster Nodes

- **panda:** 192.168.11.50 (server)
- **octopus:** 192.168.11.51 (server)
- **lion:** 192.168.11.100 (agent)
- **eagle:** 192.168.11.101 (agent)

### NAT Rules for Port Forwarding

**HTTP Rules (port 80 → NodePort 32248):**
- `HTTP-panda`: Forward to `192.168.11.50:32248`
- `HTTP-octopus`: Forward to `192.168.11.51:32248`
- `HTTP-lion`: Forward to `192.168.11.100:32248`
- `HTTP-eagle`: Forward to `192.168.11.101:32248`

**HTTPS Rules (port 443 → NodePort 30445):**
- `HTTPS-panda`: Forward to `192.168.11.50:30445`
- `HTTPS-octopus`: Forward to `192.168.11.51:30445`
- `HTTPS-lion`: Forward to `192.168.11.100:30445`
- `HTTPS-eagle`: Forward to `192.168.11.101:30445`

**All rules:**
- **Chain:** `dstnat`
- **Interface:** `ether1` (WAN interface)
- **Protocol:** `tcp`
- **Action:** `dst-nat`
- **Placement:** Placed at the top of NAT rules (before old rules)

### Netwatch Monitoring

Each node is monitored by Netwatch for automatic failover:

- **panda monitor:** Pings `192.168.11.50` every 10s, timeout 3s
- **octopus monitor:** Pings `192.168.11.51` every 10s, timeout 3s
- **lion monitor:** Pings `192.168.11.100` every 10s, timeout 3s
- **eagle monitor:** Pings `192.168.11.101` every 10s, timeout 3s

**Failover Behavior:**
- When a node goes down: Netwatch automatically disables all NAT rules containing that node's name in the comment
- When a node recovers: Netwatch automatically re-enables all NAT rules for that node
- Traffic continues to flow to remaining healthy nodes

### Legacy Rules (To Be Removed)

**Old single-node rules (disabled after migration):**
- Rule 0: HTTPS forwarding to `192.168.11.100:30445` (old lion-only rule)
- Rule 1: HTTP forwarding to `192.168.11.100:32248` (old lion-only rule)

**Old Traefik rules (already disabled):**
- Rule 4: Old Traefik HTTP forwarding (disabled)
- Rule 5: Old Traefik HTTPS forwarding (disabled)

## Traffic Flow

```
Internet → ISP Router (DMZ) → Mikrotik Router (ether1)
                                    ↓
                    Multiple NAT Rules (8 total)
                    HTTP/HTTPS for each node
                                    ↓
                    Load Balancing via Connection Tracking
                    (Distributed across active rules)
                                    ↓
        ┌─────────────────────────────────────────────┐
        │  Forward to one of:                         │
        │  • panda:192.168.11.50:32248/30445          │
        │  • octopus:192.168.11.51:32248/30445        │
        │  • lion:192.168.11.100:32248/30445          │
        │  • eagle:192.168.11.101:32248/30445         │
        └─────────────────────────────────────────────┘
                                    ↓
                    Nginx Reverse Proxy (DaemonSet)
                    (Running on all nodes)
                                    ↓
                    Sets X-Forwarded-For (HTTP) or Proxy Protocol (HTTPS)
                                    ↓
                              Traefik
                                    ↓
                    IPWhitelist Middleware checks client IP
                                    ↓
                          Internal Apps (if allowed)
```

## Load Balancing and Failover

**Load Distribution:**
- Mikrotik uses connection tracking to distribute new connections across active NAT rules
- Each new connection is assigned to one of the active rules (based on connection hash)
- Provides basic load balancing across all healthy nodes

**Automatic Failover:**
- Netwatch monitors each node every 10 seconds
- If a node fails to respond within 3 seconds, its NAT rules are automatically disabled
- Traffic automatically shifts to remaining healthy nodes
- When a node recovers, its NAT rules are automatically re-enabled

**High Availability:**
- Service remains available as long as at least one node is healthy
- No manual intervention required for node failures
- Failover typically occurs within 10-13 seconds (monitor interval + timeout)

## Summary

- **HTTP (port 80):** Mikrotik → Load balanced across all nodes → nginx NodePort 32248 → Traefik
- **HTTPS (port 443):** Mikrotik → Load balanced across all nodes → nginx NodePort 30445 → Traefik (with Proxy Protocol)
- **Failover:** Automatic via Netwatch monitoring (10s interval, 3s timeout)
- **Configuration:** See `multi-node-config.rsc` for complete RouterOS script

The configuration provides load balancing and high availability - traffic is distributed across all nodes, and automatic failover ensures service continuity if nodes go down.
