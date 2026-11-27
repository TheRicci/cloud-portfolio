21:30:48 Waiting for SSH and cloud-init
21:32:38 Phase 1: baseline (deliberately weak, before any hardening)
21:33:40 baseline: host checks failed=8, outside checks failed=2, Lynis index=58
21:33:40 PASS: outside control: SSH reachable
21:33:40 PASS: baseline is weak as intended, so there is something to fix
21:33:40 Phase 2: apply the hardening playbook
21:34:21 PASS: first playbook run exited 0
21:34:23 first run: 40s, changed=14
21:35:27 hardened: host checks failed=0, outside checks failed=0, Lynis index=70
21:35:28 PASS: all host checks pass after hardening
21:35:28 PASS: all outside probes pass after hardening
21:35:28 Phase 3: idempotence (a second run must change nothing)
21:35:51 PASS: second run changed 0 things
21:35:52 Phase 4: drift. Turn on the scheduled run, break the host, time the repair
21:36:00 PASS: break took effect (5 checks fail)
21:36:18 PASS: host repaired itself in 20s (run interval 3 min)
21:37:23 final: host checks failed=0, outside checks failed=0, Lynis index=70
21:37:24 PASS: outside probes pass after the repair
21:37:24 Session finished with 0 failure(s) after 433s. Evidence is in tests/results/aws/.
21:37:24 Next: teardown runs now. Check Cost Explorer or Cost Management tomorrow and record the actual cost in the README.
21:37:24 Tearing down
