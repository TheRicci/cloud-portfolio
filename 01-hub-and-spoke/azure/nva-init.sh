#!/bin/bash
# nva-init.sh
# Applied via cloud-init on NVA boot.
#
# Secure-by-default policy for the project validation matrix. It permits only
# a Spoke 1 initiated connection to the test service on Spoke 2 (TCP/8443),
# permits tracked return traffic, logs drops, and denies everything else.

set -euo pipefail

# ── OS-level IP forwarding ───────────────────────────────────────────────────
# Azure NIC-level ip_forwarding (set in Terraform) is also required.
# Both must be enabled — Azure passes the packet, OS must forward it.
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# ── iptables: stateful FORWARD policy ────────────────────────────────────────

# Reset
iptables -F FORWARD
iptables -P FORWARD DROP

# Return traffic must belong to an existing flow; Spoke 2 cannot initiate a
# new connection to Spoke 1 through this rule.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 10.1.0.0/16 -d 10.2.0.0/16 -p tcp --dport 8443 \
  -m conntrack --ctstate NEW -j ACCEPT

# Keep a bounded forensic record without allowing a log flood to exhaust disk.
iptables -A FORWARD -m limit --limit 10/min --limit-burst 20 -j LOG \
  --log-prefix "NVA-FORWARD-DROP: " --log-level 4

# This is an ephemeral test appliance. Production should manage persistent
# policy through the image or configuration-management pipeline.
