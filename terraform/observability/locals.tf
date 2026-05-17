locals {
  core_remote_state_key = length(trimspace(var.core_remote_state_key)) > 0 ? var.core_remote_state_key : "oficina-infra-k8s/${var.environment}/core/terraform.tfstate"

  cluster_name = var.enable_new_relic ? nonsensitive(data.terraform_remote_state.core[0].outputs.cluster_name) : "oficina-eks"
  name_prefix  = lower("${var.project_name}-${var.environment}")

  new_relic_account_id   = var.enable_new_relic ? tonumber(nonsensitive(var.new_relic_account_id)) : 1
  new_relic_region       = upper(var.new_relic_region)
  new_relic_log_endpoint = local.new_relic_region == "EU" ? "https://log-api.eu.newrelic.com/log/v1" : "https://log-api.newrelic.com/log/v1"
  synthetic_enabled      = var.enable_new_relic && length(trimspace(nonsensitive(var.api_gateway_url))) > 0

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
