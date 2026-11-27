#!/usr/bin/env bash
# Probes the VM from outside. Usage: attack-from-outside.sh <ip> <ssh-user> <ssh-key>
# Prints "<check> pass|fail". "pass" means the hardened expectation holds.
# Lines starting with # are notes. Needs the coreutils `timeout` command.
set -u
ip="$1"
user="$2"
key="$3"
opts=(-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=8)

# Control: SSH must work, or none of the other results mean anything.
if ssh "${opts[@]}" -i "$key" -o IdentitiesOnly=yes "$user@$ip" true >/dev/null 2>&1; then
  echo "control_ssh_reachable pass"
else
  echo "control_ssh_reachable fail"
fi

# Which login methods does the server offer an unauthenticated client?
methods="$(ssh "${opts[@]}" -o PreferredAuthentications=none -o PubkeyAuthentication=no \
  "$user@$ip" true 2>&1 | sed -n 's/.*Permission denied (\(.*\)).*/\1/p' | head -1)"
echo "# offered_methods=${methods:-none-seen}"
if [[ -z "$methods" ]]; then
  echo "ssh_password_auth_not_offered fail"
else
  case ",$methods," in
    *,password,* | *,keyboard-interactive,*) echo "ssh_password_auth_not_offered fail" ;;
    *) echo "ssh_password_auth_not_offered pass" ;;
  esac
fi

# The decoy listener must not be reachable through the host firewall.
if timeout 5 bash -c "exec 3<>/dev/tcp/$ip/8080" 2>/dev/null; then
  echo "decoy_port_8080_closed fail"
else
  echo "decoy_port_8080_closed pass"
fi
