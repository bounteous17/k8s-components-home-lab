# Mikrotik RouterOS Configuration Script
# Multi-Node Load Balancing with Netwatch Failover
# 
# This script configures NAT rules to forward HTTP/HTTPS traffic to all 4 cluster nodes
# and sets up Netwatch monitoring for automatic failover.
#
# IMPORTANT: Backup your current configuration before running this script!
# Run: /export file=backup-before-multi-node
#
# Nodes:
# - panda: 192.168.11.50
# - octopus: 192.168.11.51
# - lion: 192.168.11.100
# - eagle: 192.168.11.101
#
# Service Ports:
# - HTTP NodePort: 32248
# - HTTPS NodePort: 30445

###############################################################################
# STEP 1: Create NAT Rules for HTTP (port 80 -> NodePort 32248)
###############################################################################

# HTTP rule for panda node
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.50 to-ports=32248 \
    comment="HTTP-panda" place-before=0

# HTTP rule for octopus node
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.51 to-ports=32248 \
    comment="HTTP-octopus" place-before=0

# HTTP rule for lion node
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.100 to-ports=32248 \
    comment="HTTP-lion" place-before=0

# HTTP rule for eagle node
/ip firewall nat
add chain=dstnat dst-port=80 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.101 to-ports=32248 \
    comment="HTTP-eagle" place-before=0

###############################################################################
# STEP 2: Create NAT Rules for HTTPS (port 443 -> NodePort 30445)
###############################################################################

# HTTPS rule for panda node
/ip firewall nat
add chain=dstnat dst-port=443 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.50 to-ports=30445 \
    comment="HTTPS-panda" place-before=0

# HTTPS rule for octopus node
/ip firewall nat
add chain=dstnat dst-port=443 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.51 to-ports=30445 \
    comment="HTTPS-octopus" place-before=0

# HTTPS rule for lion node
/ip firewall nat
add chain=dstnat dst-port=443 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.100 to-ports=30445 \
    comment="HTTPS-lion" place-before=0

# HTTPS rule for eagle node
/ip firewall nat
add chain=dstnat dst-port=443 protocol=tcp in-interface=ether1 \
    action=dst-nat to-addresses=192.168.11.101 to-ports=30445 \
    comment="HTTPS-eagle" place-before=0

###############################################################################
# STEP 3: Configure Netwatch Monitoring for Automatic Failover
###############################################################################

# Monitor panda node (192.168.11.50)
# When node is UP: Enable all NAT rules containing "panda" in comment
# When node is DOWN: Disable all NAT rules containing "panda" in comment
/tool netwatch
add host=192.168.11.50 interval=10s timeout=3s \
    up-script="/ip firewall nat enable [find comment~\"panda\"]" \
    down-script="/ip firewall nat disable [find comment~\"panda\"]" \
    comment="Monitor panda node"

# Monitor octopus node (192.168.11.51)
/tool netwatch
add host=192.168.11.51 interval=10s timeout=3s \
    up-script="/ip firewall nat enable [find comment~\"octopus\"]" \
    down-script="/ip firewall nat disable [find comment~\"octopus\"]" \
    comment="Monitor octopus node"

# Monitor lion node (192.168.11.100)
/tool netwatch
add host=192.168.11.100 interval=10s timeout=3s \
    up-script="/ip firewall nat enable [find comment~\"lion\"]" \
    down-script="/ip firewall nat disable [find comment~\"lion\"]" \
    comment="Monitor lion node"

# Monitor eagle node (192.168.11.101)
/tool netwatch
add host=192.168.11.101 interval=10s timeout=3s \
    up-script="/ip firewall nat enable [find comment~\"eagle\"]" \
    down-script="/ip firewall nat disable [find comment~\"eagle\"]" \
    comment="Monitor eagle node"

###############################################################################
# VERIFICATION COMMANDS
###############################################################################

# After running this script, verify the configuration:
#
# 1. Check NAT rules are created:
#    /ip firewall nat print where comment~"HTTP-" or comment~"HTTPS-"
#
# 2. Check Netwatch monitors are active:
#    /tool netwatch print
#
# 3. Check status of a specific node monitor:
#    /tool netwatch print where comment~"panda"
#
# 4. Manually test disabling a node's rules:
#    /ip firewall nat disable [find comment~"panda"]
#    /ip firewall nat enable [find comment~"panda"]
#
# 5. View connection tracking to see which nodes are receiving traffic:
#    /ip firewall connection print

###############################################################################
# MIGRATION NOTES
###############################################################################

# After verifying the new configuration works:
#
# 1. Disable old single-node rules (Rule 0 and Rule 1):
#    /ip firewall nat disable [find comment~"Allow incoming traffic from my WAN Ip"]
#
# 2. Monitor for 24-48 hours to ensure stability
#
# 3. Once confirmed working, remove old rules:
#    /ip firewall nat remove [find comment~"Allow incoming traffic from my WAN Ip"]
#
# 4. To rollback, disable all new rules:
#    /ip firewall nat disable [find comment~"HTTP-"] 
#    /ip firewall nat disable [find comment~"HTTPS-"]
#    /ip firewall nat enable [find comment~"Allow incoming traffic from my WAN Ip"]
