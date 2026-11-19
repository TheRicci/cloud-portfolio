[aws] {"observed_at":"2026-11-19T16:02:54Z","action":"ready"}
[aws] 
2026-11-19T16:02:58Z PASS ready - Prometheus and Alertmanager APIs responded.
[aws] failed to run commands: exit status 1
2026-11-19T16:04:37Z FAIL notification - Alertmanager notification delivery did not succeed.
[aws] Running as unit: observability-k6.service; invocation ID: 8fd78bab89a64548a2fa3f6b29c80bc0
[aws] failed to run commands: exit status 1
2026-11-19T16:07:37Z FAIL baseline - The VM-side baseline computation failed.
[aws] {"observed_at":"2026-11-19T16:07:39Z","action":"load_stopped"}
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-19T16:07:49Z","action":"fault_on"}
[aws] {"observed_at":"2026-11-19T16:07:50Z","action":"fault_off"}
[aws] {"observed_at":"2026-11-19T16:07:55Z","action":"load_started"}
[aws] {"total_before":"886","total_after":"986","errors_before":"0","errors_after":"10","observed_at":"2026-11-19T16:07:55Z","action":"count_pass"}
[aws] 
2026-11-19T16:08:03Z PASS count - Stopped k6 and compared direct service counter deltas.
[aws] {"observed_at":"2026-11-19T16:08:15Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0.2","delay_ms":"0","observed_at":"2026-11-19T16:08:22Z","action":"fault_on"}
[aws] 
[aws] {"alert":"HighErrorRate","prometheus_active_at":"2026-11-19T16:08:49.402284957Z","alertmanager_starts_at":"2026-11-19T16:09:49.402Z","observed_at":"2026-11-19T16:09:50Z","action":"alert_fired"}
[aws] 
2026-11-19T16:09:56Z PASS error_fault - HighErrorRate fired with VM-side source timestamps.
2026-11-19T16:11:29Z Cleanup: clearing faults, stopping CPU burn, and restoring containers.
[aws] {"observed_at":"2026-11-19T16:11:31Z","action":"fault_off"}
[aws] 
