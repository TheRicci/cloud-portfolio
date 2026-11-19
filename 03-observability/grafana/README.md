# Grafana Cloud exports

These files are importable templates, not infrastructure-as-code. Create the Grafana Cloud stack and its email contact point manually, confirm it remains on the free plan, then:

1. Import `dashboard.json` through **Dashboards > New > Import**. Grafana resolves the Prometheus and Loki data sources during import.
2. Replace `REPLACE_PROMETHEUS_DATASOURCE_UID` in `no-data-alert.json` and `REPLACE_LOKI_DATASOURCE_UID` in `error-log-burst-alert.json`, then import both rules in **Alerting > Alert rules**. Attach them to the email contact point.
3. Confirm every dashboard panel has data and each rule evaluates, then export the final dashboard and rules back over these files. The exported, working versions are the session evidence.

The no-data rule evaluates each `cloud` label separately. It uses the age of that cloud's newest sample, so either cloud can run alone and it alerts when samples are more than two minutes old.

