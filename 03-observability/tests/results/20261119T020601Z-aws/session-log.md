[aws] {"observed_at":"2026-11-19T02:06:28Z","action":"ready"}
[aws] 
2026-11-19T02:06:31Z PASS ready - Prometheus and Alertmanager APIs responded.
[aws] failed to run commands: exit status 1
2026-11-19T02:08:09Z FAIL notification - Alertmanager notification delivery did not succeed.
[aws] Running as unit: observability-k6.service; invocation ID: 063869f14c3847838e776abd12849baa
[aws] failed to run commands: exit status 4
2026-11-19T02:08:33Z FAIL baseline - The VM-side baseline computation failed.
[aws] {"observed_at":"2026-11-19T02:08:36Z","action":"load_stopped"}
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-19T02:08:46Z","action":"fault_on"}
[aws] {"observed_at":"2026-11-19T02:08:47Z","action":"fault_off"}
[aws] {"observed_at":"2026-11-19T02:08:52Z","action":"load_started"}
[aws] {"total_before":"108","total_after":"208","errors_before":"0","errors_after":"10","observed_at":"2026-11-19T02:08:52Z","action":"count_pass"}
[aws] 
2026-11-19T02:08:57Z PASS count - Stopped k6 and compared direct service counter deltas.
[aws] {"observed_at":"2026-11-19T02:09:15Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0.2","delay_ms":"0","observed_at":"2026-11-19T02:09:23Z","action":"fault_on"}
[aws] 
[aws] {"alert":"HighErrorRate","prometheus_active_at":"2026-11-19T02:10:04.402284957Z","alertmanager_starts_at":"2026-11-19T02:11:04.402Z","observed_at":"2026-11-19T02:11:06Z","action":"alert_fired"}
[aws] 
2026-11-19T02:11:09Z PASS error_fault - HighErrorRate fired with VM-side source timestamps.
2026-11-19T02:14:54Z Cleanup: clearing faults, stopping CPU burn, and restoring containers.
