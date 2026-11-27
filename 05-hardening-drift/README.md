# Hardening and Drift

A small, short-lived lab: one Ubuntu 24.04 VM on AWS and one on Azure are configured only by Ansible, scanned before and after, attacked from outside, deliberately broken, and watched while they repair themselves. Each cloud is run separately, on its own day or in its own sitting.

## What it demonstrates

- **Terraform creates the machine; Ansible owns what is inside it.** There is no manual SSH configuration. Everything on the OS is enforced by `ansible/local.yml` and the `hardening` role.
- **Pull-mode convergence (`ansible-pull` + `systemd` timer):** Instead of pushing playbooks from a control node, the VM runs `hardening-pull` locally (`connection: local`) against a git repository on disk, scheduled by `hardening-pull.timer` (`OnCalendar=*:0/3`). On every tick, Ansible compares the live host against the role and reverts any drift.
- **Layered OS hardening across 8 task modules:**
  - `packages`: installs `auditd`, `ufw`, `unattended-upgrades`, `libpam-pwquality`, `debsums`, and `apt-listchanges`.
  - `ssh`: removes the weak baseline drop-in, writes `00-hardening.conf` (named `00-` so it wins OpenSSH's first-value-wins ordering over `50-cloud-init.conf`), validates with `sshd -t` before saving, restricts `/etc/ssh/sshd_config` to `0600`, and reloads `ssh` via a handler.
  - `users`: reads `/etc/passwd`, removes any non-system login user (`UID >= 1000`) not in `hardening_allowed_login_users`, and locks the `root` password.
  - `firewall`: allows TCP `22` in UFW, sets default-deny incoming and default-allow outgoing, and enables UFW.
  - `sysctl`: applies kernel network/memory settings (disables `ip_forward`, enables `rp_filter`, `tcp_syncookies`, `randomize_va_space`, `kptr_restrict`, `dmesg_restrict`, `suid_dumpable=0`) with `sysctl_set: true` so live kernel drift is caught immediately.
  - `audit`: writes `/etc/audit/rules.d/99-hardening.rules` watching `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow`, `/etc/sudoers*`, and `/etc/ssh/sshd_config*`, and enables `auditd`.
  - `updates`: enables `APT::Periodic::Update-Package-Lists` and `Unattended-Upgrade`.
  - `misc`: enforces permissions on `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow`, blacklists unused filesystem kernel modules (`cramfs`, `freevxfs`, `hfs`, `hfsplus`, `udf`), and disables core dumps.
- **Idempotence (`changed=0`):** A second playbook run must report zero changes. If a convergence loop keeps reporting changes on a healthy host, you cannot tell real drift apart from playbook noise.
- **Outside + inside verification:** Combines 13 on-host checks (`verify-state.sh`), a Lynis before/after scan, and external network probes (`attack-from-outside.sh`) from your own machine.
- **Automated drift repair & clean teardown:** Deliberately breaks four settings (causing 5 host checks to fail), times how long the timer takes to self-heal, destroys all cloud resources on every exit, and runs a tag-based leftover audit.

## What the Lynis Hardening Index is

[Lynis](https://cisofy.com/lynis/) is an open-source security auditing tool for Linux (`lynis audit system --quick`). After scanning the host, it outputs a **Hardening Index** from `0` to `100` along with a list of `warnings` and `suggestions`.

- **How it works:** Each check that finds a hardening control in place adds weight to the score, while missing controls generate suggestions that hold the score down. The index is a weighted ratio of implemented controls to applicable checks — **not** a percentage of CIS benchmarks passed or a pass/fail security grade.
- **How to read the numbers:** A stock Ubuntu cloud image typically scores in the high 50s to low 60s. Reaching the 70s reflects solid OS-level hardening (SSH, firewall, kernel sysctls, auditd, auto-updates, file permissions). Scoring 90+ requires aggressive measures like removing compilers, dedicated partitions (`/tmp`, `/var`, `/home`), and file-integrity daemons (AIDE) that are out of scope for this lab.
- **Why it is here:** Because the index is a relative signal rather than a pass/fail gate, this lab uses it to show **before-and-after movement** alongside explicit host checks and outside network probes.

## Why Ansible and how self-repair works

`cloud-init` only runs once at first boot, and plain shell scripts are imperative — re-running them safely without side effects is fragile. **Ansible** is declarative and idempotent: every task declares the *desired end state* of a resource rather than a one-time command. On a compliant host, Ansible does nothing (`changed=0`); on a drifted host, it repairs only what diverged.

This lab turns Ansible into a lightweight, agentless **self-healing loop** using `ansible-pull` and a `systemd` timer:

1. **Source of truth on disk:** `run-session.sh` packages `ansible/` into `cloud-init` user data (`TF_VAR_ansible_bundle_b64`), which unpacks it into `/var/lib/hardening/repo` and commits it locally (standalone Terraform runs without the bundle clone `repo_url` at `repo_sha`).
2. **Scheduled convergence (`systemd`):** `hardening-pull.timer` fires every 3 minutes (`OnCalendar=*:0/3`, `AccuracySec=5s`) and starts `hardening-pull.service`.
3. **Concurrency lock & pull:** `/usr/local/bin/hardening-pull` acquires `/run/lock/hardening-pull.lock` via `flock` (preventing overlapping runs) and executes `ansible-pull --inventory localhost, 05-hardening-drift/ansible/local.yml` with `connection: local`.
4. **Targeted drift remediation:** When Phase 4 runs `break.sh`, four settings are deliberately broken (`PermitRootLogin yes`, user `intruder` added with `sudo`, `ufw` disabled, `net.ipv4.ip_forward=1`). On the next timer tick, Ansible inspects live state and repairs only those four items:
   - `ssh.yml` detects the modified `00-hardening.conf`, restores it from template, validates syntax with `sshd -t`, and triggers the `Reload sshd` handler.
   - `users.yml` reads `getent passwd` and deletes `intruder` (`state: absent`, `remove: true`).
   - `firewall.yml` re-enables `ufw` with default-deny incoming (closing port `8080` again).
   - `sysctl.yml` (`sysctl_set: true`) checks the live kernel value of `net.ipv4.ip_forward` and resets it to `0` immediately.
5. **Run log:** Every execution appends `<start> <end> exit=<code> changed=<n>` to `/var/log/hardening/runs.log`, giving a clean timeline of baseline apply, `changed=0` idempotence, and drift repair.

## The baseline is deliberately weak

Stock Ubuntu cloud images are already decent. To have something to fix, `cloud-init` adds a weak SSH drop-in (`/etc/ssh/sshd_config.d/10-lab-baseline.conf` with `PasswordAuthentication yes`, `PermitRootLogin yes`, `X11Forwarding yes`, `MaxAuthTries 10`) and starts a decoy web listener (`lab-decoy.service`) on port 8080. This simulates a hand-configured server. No account has a password, so none of this is exploitable, but say so plainly when you present the before and after numbers. Set `weak_baseline = false` to see what the stock image scores.

## Inbound access

Unlike `03-observability` and `04-backup-and-restore` (which use SSM / Azure Run Command), this lab uses inbound SSH because the point is to test the host's own `sshd` configuration and `ufw` firewall from the outside. The AWS security group and Azure NSG allow only TCP `22` and TCP `8080` from your current public IP as a `/32`. `run-session.sh` detects your IP automatically and passes it to Terraform. Port `8080` is the decoy; nothing else is open.

## How a session works

| Phase | What happens | Pass rule |
| --- | --- | --- |
| Bootstrap | Terraform provisions the VM; `cloud-init` installs packages, plants the weak baseline + decoy, unpacks `ansible/` into a local git repo, and installs `hardening-pull` + systemd units | SSH reachable and `/var/lib/hardening/bootstrap-done` exists |
| 1. Baseline | Runs `verify-state.sh`, `lynis-score.sh`, and `attack-from-outside.sh` against the weak VM | Host checks fail (`> 0`), port 8080 is open, and key-based SSH works |
| 2. Harden | Runs `sudo /usr/local/bin/hardening-pull` once, then re-scans inside and outside | Exit `0`. All 13 host checks and all outside probes pass |
| 3. Idempotence | Runs `hardening-pull` a second time immediately | `changed=0` |
| 4. Drift | Enables `hardening-pull.timer`, runs `break.sh` (enables root login, adds `intruder` with `sudo`, disables UFW, sets `ip_forward=1`), then polls `verify-state.sh` every 15s | Break takes effect (`>= 3` failures) and all 13 checks pass again within 3 intervals + 2 min |
| 5. Final | Re-runs `verify-state.sh`, `lynis-score.sh`, and `attack-from-outside.sh` | All host checks and outside probes pass |
| 6. Teardown | `terraform destroy -auto-approve`, then `audit-leftovers.sh` | Audit prints nothing and exits `0` |

The teardown runs on every exit, including failures.

## Layout

| Path | Purpose |
| --- | --- |
| `ansible/` | `local.yml`, the `hardening` role, collection requirements, `hardening-pull`, and its systemd units |
| `common/cloud-init.yaml.tftpl` | Bootstrap shared by both clouds: packages, weak baseline, decoy, pull wrapper |
| `aws/`, `azure/` | Separate Terraform roots with no shared state |
| `tests/` | `run-session.sh`, `teardown.sh`, `audit-leftovers.sh`, `attack-from-outside.sh`, `remote/` on-VM scripts, and `results/` for committed evidence |
| `ci/` | Static-check workflow template (`hardening-drift-static.yml`) |
| `docs/aws-vs-azure.md` | Side-by-side measured results, to fill in after real sessions |

## Security and secret boundaries

- There are no secret variables. Do not put a key, token, account ID or subscription ID in the repository, Terraform variables, state, screenshots or shell history.
- The SSH private key stays on your machine (by default `run-session.sh` generates an ephemeral ed25519 keypair in `tests/.session/` and deletes it on exit). Only the public key goes to Terraform.
- Use a remote, encrypted state backend (`backend.tf.example` in each root). Do not use local state for a live session.
- The SSH client options in the scripts disable host key checking, because the VM is new every session. That is acceptable for a throwaway lab and wrong anywhere else.

## Before any apply

1. Choose one region per cloud and confirm the VM size is available there (`t3.micro` on AWS, `Standard_B2ats_v2` on Azure).
2. Create a budget alert of about $5 on each cloud. The script asks you to confirm.
3. Have `terraform`, `ssh`, `ssh-keygen`, `jq`, `curl`, `git`, `tar`, and the cloud CLI installed, and be logged in. On macOS the outside probe needs GNU `timeout`.
4. Create the remote state backend and copy `backend.tf.example` to `backend.tf` (or pass `-backend=false` / `-backend-config=...` via `TF_INIT_ARGS`).

## Running a session

```bash
export REGION=<region>
# optional: export SSH_KEY=~/.ssh/<key> TF_INIT_ARGS="-backend-config=..."
tests/run-session.sh aws      # one cloud at a time
tests/run-session.sh azure
```

The script plans, asks you to type `apply <cloud>`, applies, runs the phases, writes evidence to `tests/results/<cloud>/` and tears down. Commit the results folder afterwards. If the script is killed, run `tests/teardown.sh <cloud>` from the same machine and check the audit output.

Evidence written per cloud: `results.json`, `session-log.md`, `host-checks-*.txt`, `outside-*.txt`, `lynis-*.txt`, `ansible-run-1.txt`, `ansible-run-2.txt`, `runs.log`.

## What I would add in production

A managed image pipeline (Packer) so VMs boot already hardened, a CIS-aligned benchmark with an exception register instead of a Lynis score, central log shipping and alerting for the audit rules, cloud-native configuration enforcement (AWS Systems Manager State Manager, Azure Machine Configuration), patch orchestration, and a signed, reviewed pull source instead of a local bundle or unverified commit.
