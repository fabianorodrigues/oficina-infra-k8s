resource "newrelic_alert_policy" "oficina" {
  count = var.enable_new_relic ? 1 : 0

  account_id          = local.new_relic_account_id
  name                = "${local.name_prefix}-observability"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "api_5xx" {
  count = var.enable_new_relic ? 1 : 0

  account_id                     = local.new_relic_account_id
  policy_id                      = newrelic_alert_policy.oficina[0].id
  type                           = "static"
  name                           = "${local.name_prefix}-api-5xx"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  fill_option                    = "static"
  fill_value                     = 0
  expiration_duration            = 300
  close_violations_on_expiration = true

  nrql {
    query = "FROM Span SELECT count(*) WHERE service.name = 'oficina-api' AND span.kind = 'server' AND `http.response.status_code` >= 500"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = var.api_5xx_threshold
    threshold_duration    = 300
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}

resource "newrelic_nrql_alert_condition" "ordem_servico_failure" {
  count = var.enable_new_relic ? 1 : 0

  account_id                     = local.new_relic_account_id
  policy_id                      = newrelic_alert_policy.oficina[0].id
  type                           = "static"
  name                           = "${local.name_prefix}-ordem-servico-falha"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  fill_option                    = "static"
  fill_value                     = 0
  expiration_duration            = 300
  close_violations_on_expiration = true

  nrql {
    query = "FROM Log SELECT count(*) WHERE eventType = 'OrdemServicoFalha' OR message LIKE '%OrdemServicoFalha%'"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = var.ordem_servico_failure_threshold
    threshold_duration    = 300
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}

resource "newrelic_nrql_alert_condition" "kubernetes_cpu" {
  count = var.enable_new_relic ? 1 : 0

  account_id                     = local.new_relic_account_id
  policy_id                      = newrelic_alert_policy.oficina[0].id
  type                           = "static"
  name                           = "${local.name_prefix}-kubernetes-cpu-alta"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = 300
  close_violations_on_expiration = true

  nrql {
    query = "FROM K8sContainerSample SELECT average(cpuUsedCores / cpuRequestedCores * 100) WHERE clusterName = '${local.cluster_name}' AND cpuRequestedCores > 0"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = var.kubernetes_cpu_threshold_percent
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "kubernetes_memory" {
  count = var.enable_new_relic ? 1 : 0

  account_id                     = local.new_relic_account_id
  policy_id                      = newrelic_alert_policy.oficina[0].id
  type                           = "static"
  name                           = "${local.name_prefix}-kubernetes-memoria-alta"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = 300
  close_violations_on_expiration = true

  nrql {
    query = "FROM K8sContainerSample SELECT average(memoryWorkingSetBytes / memoryLimitBytes * 100) WHERE clusterName = '${local.cluster_name}' AND memoryLimitBytes > 0"
  }

  critical {
    operator              = "above_or_equals"
    threshold             = var.kubernetes_memory_threshold_percent
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_notification_destination" "email" {
  count = var.enable_new_relic ? 1 : 0

  account_id = local.new_relic_account_id
  name       = "${local.name_prefix}-observability-email"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.new_relic_notification_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.enable_new_relic ? 1 : 0

  account_id     = local.new_relic_account_id
  name           = "${local.name_prefix}-observability-email"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email[0].id
  product        = "IINT"

  property {
    key   = "subject"
    value = "Oficina - {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "oficina" {
  count = var.enable_new_relic ? 1 : 0

  account_id            = local.new_relic_account_id
  name                  = "${local.name_prefix}-observability"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"
  enabled               = true

  issues_filter {
    name = "${local.name_prefix}-observability-policy"
    type = "FILTER"

    predicate {
      attribute = "accumulations.policyName"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.oficina[0].name]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}

resource "newrelic_synthetics_monitor" "health" {
  count = local.synthetic_enabled ? 1 : 0

  name              = "${local.name_prefix}-health"
  type              = "SIMPLE"
  status            = "ENABLED"
  period            = "EVERY_5_MINUTES"
  uri               = "${trim(nonsensitive(var.api_gateway_url), "/")}/health"
  locations_public  = var.synthetic_locations_public
  validation_string = "Healthy"
  verify_ssl        = true

  tag {
    key    = "service"
    values = ["oficina-api"]
  }

  tag {
    key    = "environment"
    values = [var.environment]
  }
}

resource "newrelic_one_dashboard_json" "oficina" {
  count = var.enable_new_relic ? 1 : 0

  account_id = local.new_relic_account_id
  json = jsonencode({
    name        = "${local.name_prefix}-observability"
    description = "Observabilidade da solucao Oficina."
    permissions = "PUBLIC_READ_ONLY"
    pages = [
      {
        name = "API"
        widgets = [
          {
            title         = "Latencia p95 da API"
            layout        = { column = 1, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM Span SELECT percentile(duration.ms, 95) WHERE service.name = 'oficina-api' AND span.kind = 'server' TIMESERIES"
              }]
            }
          },
          {
            title         = "Erros 5xx"
            layout        = { column = 7, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM Span SELECT count(*) WHERE service.name = 'oficina-api' AND span.kind = 'server' AND `http.response.status_code` >= 500 TIMESERIES"
              }]
            }
          },
          {
            title         = "Healthcheck / Uptime"
            layout        = { column = 1, row = 4, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM SyntheticCheck SELECT percentage(count(*), WHERE result = 'SUCCESS') WHERE monitorName LIKE '%${local.name_prefix}-health%' TIMESERIES"
              }]
            }
          }
        ]
      },
      {
        name = "Kubernetes"
        widgets = [
          {
            title         = "CPU Kubernetes"
            layout        = { column = 1, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM K8sContainerSample SELECT average(cpuUsedCores) WHERE clusterName = '${local.cluster_name}' FACET podName TIMESERIES"
              }]
            }
          },
          {
            title         = "Memoria Kubernetes"
            layout        = { column = 7, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM K8sContainerSample SELECT average(memoryWorkingSetBytes) WHERE clusterName = '${local.cluster_name}' FACET podName TIMESERIES"
              }]
            }
          }
        ]
      },
      {
        name = "Ordens de Servico"
        widgets = [
          {
            title         = "Volume diario de ordens de servico"
            layout        = { column = 1, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.bar" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM Log SELECT count(*) WHERE eventType = 'OrdemServicoCriada' OR message LIKE '%OrdemServicoCriada%' TIMESERIES 1 day"
              }]
            }
          },
          {
            title         = "Tempo medio por status"
            layout        = { column = 7, row = 1, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM Log SELECT average(statusDurationMs) WHERE eventType = 'OrdemServicoStatusAlterado' OR message LIKE '%OrdemServicoStatusAlterado%' FACET statusNovo TIMESERIES"
              }]
            }
          },
          {
            title         = "Falhas no processamento de OS"
            layout        = { column = 1, row = 4, width = 6, height = 3 }
            visualization = { id = "viz.line" }
            rawConfiguration = {
              nrqlQueries = [{
                accountIds = [local.new_relic_account_id]
                query      = "FROM Log SELECT count(*) WHERE eventType = 'OrdemServicoFalha' OR message LIKE '%OrdemServicoFalha%' TIMESERIES"
              }]
            }
          }
        ]
      }
    ]
    variables = []
  })
}
