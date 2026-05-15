variable "aws_region" {
  description = "Regiao AWS usada pelo ambiente."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado em tags."
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Nome do ambiente usado em tags."
  type        = string
  default     = "dev"
}

variable "remote_state_bucket" {
  description = "Bucket S3 do state remoto do core do oficina-infra-k8s."
  type        = string
  default     = ""
  sensitive   = true
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

variable "aws_load_balancer_controller_chart_version" {
  description = "Versao fixa do Helm chart do AWS Load Balancer Controller."
  type        = string
  default     = "1.8.1"
}
