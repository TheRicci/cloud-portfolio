# Package the unified observability stack into an archive for EC2 bootstrap.
data "archive_file" "runtime" {
  type             = "tar.gz"
  output_path      = "${path.module}/.terraform/observability-runtime.tar.gz"
  output_file_mode = "0644"

  # Go Microservice
  source {
    content  = file("${path.module}/../service/Dockerfile")
    filename = "service/Dockerfile"
  }
  source {
    content  = file("${path.module}/../service/go.mod")
    filename = "service/go.mod"
  }
  source {
    content  = file("${path.module}/../service/go.sum")
    filename = "service/go.sum"
  }
  source {
    content  = file("${path.module}/../service/main.go")
    filename = "service/main.go"
  }

  # Docker Compose & Core Configs
  source {
    content  = file("${path.module}/../compose/docker-compose.yml")
    filename = "compose/docker-compose.yml"
  }
  source {
    content  = file("${path.module}/../compose/prometheus.yml")
    filename = "compose/prometheus.yml"
  }
  source {
    content  = file("${path.module}/../compose/rules.yml")
    filename = "compose/rules.yml"
  }
  source {
    content  = file("${path.module}/../compose/alertmanager.yml.tmpl")
    filename = "compose/alertmanager.yml.tmpl"
  }
  source {
    content  = file("${path.module}/../compose/render_alertmanager.py")
    filename = "compose/render_alertmanager.py"
  }
  source {
    content  = file("${path.module}/../compose/loki.yml")
    filename = "compose/loki.yml"
  }
  source {
    content  = file("${path.module}/../compose/config.alloy")
    filename = "compose/config.alloy"
  }
  source {
    content  = file("${path.module}/../compose/k6.js")
    filename = "compose/k6.js"
  }

  # Grafana Provisioning & Dashboard
  source {
    content  = file("${path.module}/../compose/provisioning/datasources/datasources.yml")
    filename = "compose/provisioning/datasources/datasources.yml"
  }
  source {
    content  = file("${path.module}/../compose/provisioning/dashboards/dashboards.yml")
    filename = "compose/provisioning/dashboards/dashboards.yml"
  }
  source {
    content  = file("${path.module}/../compose/provisioning/alerting/rules.json")
    filename = "compose/provisioning/alerting/rules.json"
  }
  source {
    content  = file("${path.module}/../compose/dashboards/dashboard.json")
    filename = "compose/dashboards/dashboard.json"
  }


}

locals {
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    runtime_bundle_base64  = filebase64(data.archive_file.runtime.output_path)
    smtp_username          = var.smtp_username
    smtp_password          = var.smtp_password
    smtp_from              = var.smtp_from
    alert_email            = var.alert_email
    grafana_admin_password = var.grafana_admin_password
    region                 = var.region
  })
}
