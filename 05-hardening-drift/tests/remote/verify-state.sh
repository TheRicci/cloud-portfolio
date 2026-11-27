#!/usr/bin/env bash
# Run as root on the VM. Prints "<check> pass|fail" for each desired setting.
# Always exits 0; the caller counts the failures.
# shellcheck disable=SC2329  # the check functions are called indirectly through check()
set -u
ALLOWED_USERS="${ALLOWED_USERS:-ubuntu azureuser}"

check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "$name pass"
  else
    echo "$name fail"
  fi
}

sshd_is() {
  [[ "$(sshd -T 2>/dev/null | awk -v k="$1" '$1 == k {print $2}')" == "$2" ]]
}

max_auth_tries_low() {
  local n
  n="$(sshd -T 2>/dev/null | awk '$1 == "maxauthtries" {print $2}')"
  [[ -n "$n" && "$n" -le 4 ]]
}

no_unexpected_users() {
  local name uid shell
  while IFS=: read -r name _ uid _ _ _ shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ "$name" == nobody ]] && continue
    case "$shell" in
      */nologin | /bin/false) continue ;;
    esac
    case " $ALLOWED_USERS " in
      *" $name "*) continue ;;
    esac
    return 1
  done </etc/passwd
  return 0
}

firewall_active() {
  ufw status | grep -q '^Status: active'
}

firewall_default_deny() {
  ufw status verbose | grep -q 'deny (incoming)'
}

sysctl_is() {
  [[ "$(sysctl -n "$1" 2>/dev/null)" == "$2" ]]
}

auditd_running() {
  systemctl is-active --quiet auditd
}

shadow_mode() {
  [[ "$(stat -c %a /etc/shadow)" == 640 ]]
}

check ssh_root_login_disabled sshd_is permitrootlogin no
check ssh_password_auth_disabled sshd_is passwordauthentication no
check ssh_keyboard_interactive_disabled sshd_is kbdinteractiveauthentication no
check ssh_x11_forwarding_disabled sshd_is x11forwarding no
check ssh_max_auth_tries_low max_auth_tries_low
check no_unexpected_login_users no_unexpected_users
check firewall_active firewall_active
check firewall_default_deny firewall_default_deny
check ip_forwarding_off sysctl_is net.ipv4.ip_forward 0
check reverse_path_filter_on sysctl_is net.ipv4.conf.all.rp_filter 1
check syn_cookies_on sysctl_is net.ipv4.tcp_syncookies 1
check auditd_running auditd_running
check shadow_file_mode_640 shadow_mode
exit 0
