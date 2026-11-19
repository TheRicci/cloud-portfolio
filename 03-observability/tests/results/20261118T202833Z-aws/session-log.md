[aws] {"observed_at":"2026-11-18T20:29:04Z","action":"ready"}
[aws] 
2026-11-18T20:29:07Z PASS ready - Prometheus and Alertmanager APIs responded.
[aws] failed to run commands: exit status 1
2026-11-18T20:30:46Z FAIL notification - Alertmanager notification delivery did not succeed.
[aws] Running as unit: observability-k6.service; invocation ID: 5f24ddd9bc614076a105e035deefe000
[aws] failed to run commands: exit status 4
2026-11-18T20:30:56Z FAIL baseline - The VM-side baseline computation failed.
[aws] {"observed_at":"2026-11-18T20:30:58Z","action":"load_stopped"}
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-18T20:31:08Z","action":"fault_on"}
[aws] {"observed_at":"2026-11-18T20:31:09Z","action":"fault_off"}
[aws] {"observed_at":"2026-11-18T20:31:15Z","action":"load_started"}
[aws] {"total_before":"39","total_after":"139","errors_before":"0","errors_after":"10","observed_at":"2026-11-18T20:31:15Z","action":"count_pass"}
[aws] 
2026-11-18T20:31:20Z PASS count - Stopped k6 and compared direct service counter deltas.
[aws] {"observed_at":"2026-11-18T20:31:27Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0.2","delay_ms":"0","observed_at":"2026-11-18T20:31:32Z","action":"fault_on"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:31:41Z FAIL error_fault - HighErrorRate was not observed.
2026-11-18T20:36:42Z Timed out waiting for Service error log burst from aws
2026-11-18T20:36:43Z FAIL error_log_alert - Grafana did not observe fresh Loki error logs.
2026-11-18T20:36:44Z FAIL error_native_quiet - A native CPU alarm fired during the error fault.
[aws] {"observed_at":"2026-11-18T20:36:47Z","action":"fault_off"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 47: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:36:55Z FAIL error_resolution - HighErrorRate did not resolve.
[aws] {"observed_at":"2026-11-18T20:37:13Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"1","delay_ms":"0","observed_at":"2026-11-18T20:37:17Z","action":"fault_on"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:37:25Z FAIL critical_error_fault - CriticalErrorRate was not observed.
[aws] {"observed_at":"2026-11-18T20:37:27Z","action":"fault_off"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 47: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:37:35Z FAIL critical_error_resolution - CriticalErrorRate did not resolve.
[aws] {"observed_at":"2026-11-18T20:37:43Z","action":"load_healthy"}
[aws] 
[aws] {"error_rate":"0","delay_ms":"500","observed_at":"2026-11-18T20:37:48Z","action":"fault_on"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:37:56Z FAIL latency_fault - SlowResponses was not observed.
[aws] {"observed_at":"2026-11-18T20:37:58Z","action":"fault_off"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 47: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:38:07Z FAIL latency_resolution - SlowResponses did not resolve.
[aws] {"observed_at":"2026-11-18T20:38:09Z","action":"service_stopped"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:38:17Z FAIL service_down - ServiceDown did not complete.
[aws] {"observed_at":"2026-11-18T20:38:20Z","action":"alloy_stopped"}
[aws] 
2026-11-18T20:43:25Z Timed out waiting for No data from a VM from aws
2026-11-18T20:43:25Z FAIL pipeline_cut - Grafana no-data alert was not observed.
[aws] failed to run commands: exit status 1
2026-11-18T20:43:31Z FAIL pipeline_prom_quiet - A Prometheus alert fired during the Alloy cut.
[aws] {"observed_at":"2026-11-18T20:43:33Z","action":"alloy_started"}
[aws] 
[aws] {"observed_at":"2026-11-18T20:43:38Z","action":"load_stopped"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:43:46Z FAIL no_traffic - NoTraffic was not observed.
[aws] Running as unit: observability-k6.service; invocation ID: 78da6a3dfc03431a81bcfaf74f41e274
[aws] failed to run commands: exit status 1
[aws] /opt/observability/tests/vm-session.sh: line 47: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:45:31Z FAIL no_traffic_resolution - NoTraffic did not resolve.
[aws] {"observed_at":"2026-11-18T20:45:33Z","action":"cpu_burn_started"}
[aws] 
[aws] /opt/observability/tests/vm-session.sh: line 33: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T20:45:41Z FAIL cpu_prometheus - HighCPU was not observed.
2026-11-18T21:00:43Z Timed out waiting for native CPU alarm from aws
2026-11-18T21:00:43Z FAIL cpu_burn - A native CPU alarm was not observed.
[aws] Failed to stop observability-cpu-burn.service: Unit observability-cpu-burn.service not loaded.
[aws] failed to run commands: exit status 5
[aws] /opt/observability/tests/vm-session.sh: line 47: timeout: unbound variable
[aws] failed to run commands: exit status 1
2026-11-18T21:00:54Z FAIL cpu_resolution - HighCPU did not resolve.
2026-11-18T21:00:54Z Cleanup: clearing faults, stopping CPU burn, and restoring containers.
[aws] {"observed_at":"2026-11-18T21:00:56Z","action":"fault_off"}
[aws] 
[aws] Failed to stop observability-cpu-burn.service: Unit observability-cpu-burn.service not loaded.
[aws] failed to run commands: exit status 5
[aws] {"observed_at":"2026-11-18T21:01:07Z","action":"load_stopped"}
[aws] 
[aws] {"observed_at":"2026-11-18T21:01:12Z","action":"service_started"}
[aws] 
[aws] {"observed_at":"2026-11-18T21:01:17Z","action":"alloy_started"}
[aws] 
