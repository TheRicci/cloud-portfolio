[aws] {"observed_at":"2026-11-19T16:41:14Z","action":"ready"}
[aws] 
2026-11-19T16:41:17Z PASS ready - Prometheus and Alertmanager APIs responded.
[aws] failed to run commands: exit status 1
2026-11-19T16:42:59Z FAIL notification - Alertmanager notification delivery did not succeed.
[aws] failed to run commands: exit status 1
2026-11-19T16:44:40Z FAIL baseline - The VM-side baseline computation failed.
[aws] {"observed_at":"2026-11-19T16:44:42Z","action":"load_stopped"}
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-19T16:44:52Z","action":"fault_on"}
[aws] {"observed_at":"2026-11-19T16:44:53Z","action":"fault_off"}
[aws] {"observed_at":"2026-11-19T16:44:58Z","action":"load_started"}
[aws] {"total_before":"0","total_after":"100","errors_before":"0","errors_after":"10","observed_at":"2026-11-19T16:44:58Z","action":"count_pass"}
[aws] 
2026-11-19T16:45:02Z PASS count - Stopped k6 and compared direct service counter deltas.
[aws] {"observed_at":"2026-11-19T16:45:15Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0.2","delay_ms":"0","observed_at":"2026-11-19T16:45:22Z","action":"fault_on"}
[aws] 
[aws] {"alert":"HighErrorRate","prometheus_active_at":"2026-11-19T16:45:49.402284957Z","alertmanager_starts_at":"2026-11-19T16:46:49.402Z","observed_at":"2026-11-19T16:46:50Z","action":"alert_fired"}
[aws] 
2026-11-19T16:46:57Z PASS error_fault - HighErrorRate fired with VM-side source timestamps.
2026-11-19T16:57:05Z Timed out waiting for Service error log burst from aws
2026-11-19T16:57:06Z FAIL error_log_alert - Grafana did not observe fresh Loki error logs.
2026-11-19T16:57:06Z Cleanup: clearing faults, stopping CPU burn, and restoring containers.
[aws] {"observed_at":"2026-11-19T16:57:09Z","action":"fault_off"}
[aws] 
[aws] Failed to stop observability-cpu-burn.service: Unit observability-cpu-burn.service not loaded.
[aws] failed to run commands: exit status 5
[aws] {"observed_at":"2026-11-19T16:57:24Z","action":"load_stopped"}
[aws] 
[aws] {"observed_at":"2026-11-19T16:57:31Z","action":"service_started"}
[aws] 
[aws] {"observed_at":"2026-11-19T16:57:38Z","action":"alloy_started"}
[aws] 
