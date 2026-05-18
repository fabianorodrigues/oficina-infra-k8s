resource "kubernetes_namespace" "newrelic" {
  count = var.enable_new_relic ? 1 : 0

  metadata {
    name = "newrelic"

    labels = {
      app = "newrelic"
    }
  }

  lifecycle {
    # Proteção contra destruição acidental. Para recriação intencional, remover temporariamente em PR específico e justificado.
    prevent_destroy = true
  }
}

resource "helm_release" "nri_bundle" {
  count = var.enable_new_relic ? 1 : 0

  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = var.nri_bundle_chart_version
  namespace  = kubernetes_namespace.newrelic[0].metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  set_sensitive {
    name  = "global.licenseKey"
    value = var.new_relic_license_key
  }

  set {
    name  = "global.cluster"
    value = local.cluster_name
  }

  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.privileged"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  set {
    name  = "nri-metadata-injection.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.enabled"
    value = "true"
  }

  set {
    name  = "newrelic-logging.enableLinux"
    value = "true"
  }

  set {
    name  = "newrelic-logging.endpoint"
    value = local.new_relic_log_endpoint
  }

  set {
    name  = "newrelic-logging.lowDataMode"
    value = "false"
  }

  set {
    name  = "newrelic-logging.fluentBit.k8sLoggingExclude"
    value = "false"
  }

  lifecycle {
    # Proteção contra destruição acidental. Para recriação intencional, remover temporariamente em PR específico e justificado.
    prevent_destroy = true
  }
}
