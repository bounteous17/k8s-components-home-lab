# Netwatch Monitoring and Automatic Failover

## Overview

Netwatch is a Mikrotik RouterOS tool that monitors network hosts and executes scripts when their status changes. In this configuration, Netwatch monitors all 4 cluster nodes and automatically enables/disables NAT rules based on node availability.

## How It Works

### Monitoring Configuration

Each node is monitored with the following settings:

- **Interval:** 10 seconds (how often to check)
- **Timeout:** 3 seconds (how long to wait for response)
- **Method:** ICMP ping

### Failover Mechanism

When Netwatch detects a status change:

1. **Node Goes Down:**
   - Netwatch pings the node and receives no response within 3 seconds
   - The `down-script` is executed
   - All NAT rules containing the node name in the comment are disabled
   - Traffic automatically stops being forwarded to that node
   - Traffic continues to flow to remaining healthy nodes

2. **Node Recovers:**
   - Netwatch pings the node and receives a response
   - The `up-script` is executed
   - All NAT rules containing the node name in the comment are re-enabled
   - Traffic resumes being forwarded to that node

### Script Execution

The Netwatch scripts use RouterOS's `find` command to locate rules by comment:

```mikrotik
# Enable rules when node is up
/ip firewall nat enable [find comment~"panda"]

# Disable rules when node is down
/ip firewall nat disable [find comment~"panda"]
```

The `~` operator performs a substring match, so it will find:
- `HTTP-panda`
- `HTTPS-panda`
- Any other rule with "panda" in the comment

## Failover Timing

**Detection Time:**
- Minimum: 3 seconds (timeout period)
- Maximum: 13 seconds (interval + timeout)
- Typical: 6-10 seconds (depends on network latency)

**Recovery Time:**
- Similar timing applies when a node recovers
- Rules are re-enabled within 10-13 seconds of node recovery

## Testing Procedures

### 1. Verify Netwatch Monitors Are Active

```mikrotik
# View all Netwatch monitors
/tool netwatch print

# View status of a specific node monitor
/tool netwatch print where comment~"panda"
```

**Expected Output:**
- All 4 monitors should be listed
- Status should show "up" for all healthy nodes
- Last check time should be recent (within last 10 seconds)

### 2. Verify NAT Rules Are Active

```mikrotik
# View all multi-node NAT rules
/ip firewall nat print where comment~"HTTP-" or comment~"HTTPS-"

# Count active rules (should be 8 when all nodes are up)
/ip firewall nat print where comment~"HTTP-" or comment~"HTTPS-" count-only
```

**Expected Output:**
- 8 rules total (4 HTTP + 4 HTTPS)
- All rules should show `disabled=no` when nodes are healthy

### 3. Test Manual Rule Disabling (Simulate Node Failure)

```mikrotik
# Manually disable rules for a node (simulates node failure)
/ip firewall nat disable [find comment~"panda"]

# Verify rules are disabled
/ip firewall nat print where comment~"panda"

# Re-enable rules (simulates node recovery)
/ip firewall nat enable [find comment~"panda"]
```

**Expected Behavior:**
- Rules should show `disabled=yes` after disable command
- Traffic should continue to flow to other nodes
- Rules should show `disabled=no` after enable command

### 4. Test Actual Node Failure

**Method 1: Stop nginx Pod on a Node**

```bash
# SSH to a node and stop nginx pod
kubectl delete pod -n nginx-proxy -l app=nginx-proxy --field-selector spec.nodeName=panda

# Wait 10-15 seconds, then check Mikrotik
# Netwatch should detect the node is still up (node is reachable)
# But nginx won't respond on the NodePort
```

**Note:** This tests service failure, not node failure. The node is still reachable, so Netwatch won't trigger. This is expected - Netwatch monitors node availability, not service availability.

**Method 2: Shut Down or Isolate a Node**

```bash
# Power off or disconnect network from a node
# Or use firewall to block ICMP from Mikrotik to the node
```

**Expected Behavior:**
- Within 10-13 seconds, Netwatch should detect the failure
- NAT rules for that node should be automatically disabled
- Check with: `/ip firewall nat print where comment~"<nodename>"`
- Traffic should continue to other nodes

### 5. Test Node Recovery

```bash
# Restore the node (power on, reconnect network, etc.)
```

**Expected Behavior:**
- Within 10-13 seconds, Netwatch should detect recovery
- NAT rules for that node should be automatically re-enabled
- Traffic should resume to that node

### 6. Monitor Connection Distribution

```mikrotik
# View active connections to see which nodes are receiving traffic
/ip firewall connection print where dst-port=32248 or dst-port=30445

# Count connections per destination
/ip firewall connection print where dst-port=32248 or dst-port=30445 \
    count-only group-by=dst-address
```

**Expected Behavior:**
- Connections should be distributed across all active nodes
- When a node is down, no new connections should go to that node
- When a node recovers, new connections should resume

### 7. Test Load Distribution

Make multiple HTTP/HTTPS requests from external network:

```bash
# Make 20 requests and check which nodes receive them
for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://your-domain.com/
done

# Check nginx logs on each node to see request distribution
kubectl logs -n nginx-proxy -l app=nginx-proxy --tail=20
```

**Expected Behavior:**
- Requests should be distributed across all healthy nodes
- Distribution may not be perfectly even (depends on connection tracking hash)

## Troubleshooting

### Netwatch Not Detecting Failures

**Symptoms:**
- Node is down but NAT rules remain enabled
- Traffic still tries to go to down node

**Diagnosis:**
```mikrotik
# Check Netwatch status
/tool netwatch print

# Check if monitor is running
/tool netwatch print where comment~"<nodename>"
```

**Possible Causes:**
1. Netwatch monitor not configured correctly
2. Script syntax error in up/down scripts
3. Node is reachable but service is down (Netwatch only checks node, not service)

**Solutions:**
- Verify Netwatch configuration matches the script
- Check RouterOS logs: `/log print`
- Test scripts manually: `/ip firewall nat disable [find comment~"panda"]`

### Rules Not Disabling/Enabling

**Symptoms:**
- Netwatch detects status change but rules don't change

**Diagnosis:**
```mikrotik
# Test the script manually
/ip firewall nat disable [find comment~"panda"]
/ip firewall nat print where comment~"panda"

# Check if rules exist with correct comments
/ip firewall nat print where comment~"panda"
```

**Possible Causes:**
1. Comment format doesn't match (case sensitivity, exact string)
2. Rules don't exist or were removed
3. Script execution error

**Solutions:**
- Verify comment format matches exactly (including case)
- Re-run the configuration script to ensure rules exist
- Check RouterOS logs for script execution errors

### Uneven Load Distribution

**Symptoms:**
- Most traffic goes to one node, others receive little

**Explanation:**
- Mikrotik's connection tracking uses a hash-based distribution
- This is not true round-robin - it's based on connection characteristics
- Some unevenness is normal and expected

**Solutions:**
- This is expected behavior - Mikrotik doesn't support weighted or round-robin load balancing
- If you need more even distribution, consider using a dedicated load balancer (HAProxy, nginx, etc.)

### False Positives (Node Marked Down When It's Up)

**Symptoms:**
- Node is healthy but Netwatch marks it as down
- NAT rules get disabled unnecessarily

**Possible Causes:**
1. Network congestion causing ping timeouts
2. Firewall blocking ICMP
3. Node under heavy load, slow to respond

**Solutions:**
- Increase timeout: `timeout=5s` (instead of 3s)
- Increase interval: `interval=15s` (instead of 10s) - reduces false positives but slower detection
- Check network connectivity between Mikrotik and nodes
- Verify firewall allows ICMP from Mikrotik to nodes

## Configuration Reference

### Current Netwatch Settings

```mikrotik
# All monitors use these settings:
interval=10s    # Check every 10 seconds
timeout=3s      # Wait 3 seconds for response
```

### Adjusting Settings

**For Faster Detection (but more false positives):**
```mikrotik
/tool netwatch set [find comment~"panda"] interval=5s timeout=2s
```

**For More Stable (but slower detection):**
```mikrotik
/tool netwatch set [find comment~"panda"] interval=15s timeout=5s
```

**Recommended:** Keep default (10s/3s) unless experiencing issues.

## Monitoring and Maintenance

### Regular Checks

1. **Weekly:** Verify all Netwatch monitors are active
2. **Weekly:** Check NAT rules are all enabled (when nodes are healthy)
3. **After node maintenance:** Verify rules re-enabled automatically
4. **After network changes:** Test failover behavior

### Logging

Netwatch doesn't log status changes by default. To monitor:

```mikrotik
# Enable logging for Netwatch (if supported by your RouterOS version)
# Or use a custom script that logs to a file

# Check RouterOS system log for any errors
/log print where topics~"firewall" or topics~"netwatch"
```

### Backup and Recovery

**Before making changes:**
```mikrotik
/export file=backup-before-netwatch-changes
```

**To restore:**
```mikrotik
/import file=backup-before-netwatch-changes
```

## Advanced: Custom Monitoring

If you need to monitor service availability (not just node availability), you could:

1. Use a custom script that checks HTTP/HTTPS on the NodePort
2. Use RouterOS's HTTP monitoring (if available)
3. Deploy a dedicated monitoring service that updates Mikrotik via API

However, for most use cases, node-level monitoring (current setup) is sufficient since:
- If a node is down, services on it are also down
- Kubernetes will reschedule pods to healthy nodes
- Nginx DaemonSet ensures nginx runs on all nodes

## Summary

Netwatch provides automatic failover by:
- Monitoring node availability every 10 seconds
- Automatically disabling NAT rules when nodes fail
- Automatically re-enabling NAT rules when nodes recover
- Requiring no manual intervention for common failure scenarios

This ensures high availability - as long as at least one node is healthy, traffic will continue to flow.
