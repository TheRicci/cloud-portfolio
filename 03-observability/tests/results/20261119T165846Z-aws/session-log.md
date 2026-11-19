[aws] {"observed_at":"2026-11-19T16:59:38Z","action":"ready"}
[aws] 
2026-11-19T16:59:43Z PASS ready - Prometheus and Alertmanager APIs responded.
[aws] awk: cmd. line:1: /^alertmanager_notifications_total\{ { total += $2 } END { print total + 0 }
[aws] awk: cmd. line:1:  ^ unterminated regexp
[aws] failed to run commands: exit status 1
2026-11-19T16:59:50Z FAIL notification - Alertmanager notification delivery did not succeed.
[aws] {"observed_at":"2026-11-19T16:59:52Z","action":"load_started"}
[aws] {"error_rate":"0","p95_seconds":"0.09531250000000001","observed_at":"2026-11-19T16:59:57Z","action":"baseline_pass"}
[aws] 
2026-11-19T17:00:02Z PASS baseline - Computed a clean baseline from Prometheus data.
[aws] {"observed_at":"2026-11-19T17:00:04Z","action":"load_stopped"}
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-19T17:00:14Z","action":"fault_on"}
[aws] {"observed_at":"2026-11-19T17:00:15Z","action":"fault_off"}
[aws] {"observed_at":"2026-11-19T17:00:20Z","action":"load_started"}
[aws] {"total_before":"59","total_after":"159","errors_before":"0","errors_after":"10","observed_at":"2026-11-19T17:00:20Z","action":"count_pass"}
[aws] 
2026-11-19T17:00:24Z PASS count - Stopped k6 and compared direct service counter deltas.
[aws] {"observed_at":"2026-11-19T17:00:42Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0.2","delay_ms":"0","observed_at":"2026-11-19T17:00:48Z","action":"fault_on"}
[aws] 
[aws] {"alert":"HighErrorRate","prometheus_active_at":"2026-11-19T17:01:19.402284957Z","alertmanager_starts_at":"2026-11-19T17:02:19.402Z","observed_at":"2026-11-19T17:02:22Z","action":"alert_fired"}
[aws] 
2026-11-19T17:02:28Z PASS error_fault - HighErrorRate fired with VM-side source timestamps.
2026-11-19T17:03:01Z Cleanup: clearing faults, stopping CPU burn, and restoring containers.
[aws] {"observed_at":"2026-11-19T17:03:03Z","action":"fault_off"}
[aws] 
[aws] Failed to stop observability-cpu-burn.service: Unit observability-cpu-burn.service not loaded.
[aws] failed to run commands: exit status 5
[aws] {"observed_at":"2026-11-19T17:03:17Z","action":"load_stopped"}
[aws] 
[aws] {"observed_at":"2026-11-19T17:03:24Z","action":"service_started"}
[aws] 
[aws] {"observed_at":"2026-11-19T17:03:31Z","action":"alloy_started"}
[aws] 
