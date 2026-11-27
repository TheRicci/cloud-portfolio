#!/usr/bin/env bash
# Run as root on the VM. Breaks four hardened settings on purpose.
set -u
sed -i 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config.d/00-hardening.conf
systemctl reload ssh
id intruder >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo intruder
ufw --force disable
sysctl -w net.ipv4.ip_forward=1
echo "broken"
