variable "enable_new_relic" {
  description = "Habilita a criacao dos recursos de observabilidade New Relic. O padrao false permite validar o root sem credenciais New Relic."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "Regiao AWS usada pelo ambiente."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado em nomes e tags."
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Nome do ambiente usado em nomes e tags."
  type        = string
  default     = "dev"
}

variable "remote_state_bucket" {
  description = "Bucket S3 do state remoto do core do oficina-infra-k8s."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_new_relic || length(trimspace(nonsensitive(var.remote_state_bucket))) > 0
    error_message = "remote_state_bucket e obrigatorio quando enable_new_relic=true."
  }
}

variable "remote_state_region" {
  description = "Regiao do bucket S3 do state remoto."
  type        = string
  default     = "us-east-1"
}

variable "core_remote_state_key" {
  description = "Key do state remoto do core. Quando vazio, usa oficina-infra-k8s/{environment}/core/terraform.tfstate."
  type        = string
  default     = ""
}

variable "new_relic_account_id" {
  description = "Account ID New Relic usado em dashboards e alertas. Obrigatorio somente quando enable_new_relic=true."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_new_relic || can(regex("^[0-9]+$", nonsensitive(var.new_relic_account_id)))
    error_message = "new_relic_account_id numerico e obrigatorio quando enable_new_relic=true."
  }
}

variable "new_relic_region" {
  description = "Regiao da conta New Relic."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], upper(var.new_relic_region))
    error_message = "new_relic_region deve ser US ou EU."
  }
}

variable "new_relic_license_key" {
  description = "License key New Relic usada pela integracao Kubernetes. Obrigatoria somente quando enable_new_relic=true."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_new_relic || length(trimspace(nonsensitive(var.new_relic_license_key))) > 0
    error_message = "new_relic_license_key e obrigatoria quando enable_new_relic=true."
  }
}

variable "new_relic_user_api_key" {
  description = "User API key New Relic usada pelo provider Terraform. Obrigatoria somente quando enable_new_relic=true."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_new_relic || length(trimspace(nonsensitive(var.new_relic_user_api_key))) > 0
    error_message = "new_relic_user_api_key e obrigatoria quando enable_new_relic=true."
  }
}

variable "new_relic_notification_email" {
  description = "E-mail destino para notificacoes de alertas. Obrigatorio somente quando enable_new_relic=true."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_new_relic || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", nonsensitive(var.new_relic_notification_email)))
    error_message = "new_relic_notification_email valido e obrigatorio quando enable_new_relic=true."
  }
}

variable "api_gateway_url" {
  description = "URL publica do API Gateway usada pelo Synthetic Monitor. Normalmente preenchida automaticamente pelo workflow via SSM Parameter Store; pode ser sobrescrita por API_GATEWAY_URL. Quando vazio, o monitor nao e criado."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = length(trimspace(nonsensitive(var.api_gateway_url))) == 0 || can(regex("^https?://", nonsensitive(var.api_gateway_url)))
    error_message = "api_gateway_url deve ser vazia ou iniciar com http:// ou https://."
  }
}

variable "synthetic_locations_public" {
  description = "Localizacoes publicas usadas pelo Synthetic Monitor."
  type        = list(string)
  default     = ["AWS_US_EAST_1"]
}

variable "api_5xx_threshold" {
  description = "Quantidade de respostas 5xx em 5 minutos para abrir alerta."
  type        = number
  default     = 5
}

variable "ordem_servico_failure_threshold" {
  description = "Quantidade de falhas de processamento de OS em 5 minutos para abrir alerta."
  type        = number
  default     = 1
}

variable "kubernetes_cpu_threshold_percent" {
  description = "Percentual medio de CPU de containers em 5 minutos para abrir alerta."
  type        = number
  default     = 85
}

variable "kubernetes_memory_threshold_percent" {
  description = "Percentual medio de memoria de containers em 5 minutos para abrir alerta."
  type        = number
  default     = 85
}

variable "nri_bundle_chart_version" {
  description = "Versao do chart nri-bundle."
  type        = string
  default     = "7.0.8"
}
