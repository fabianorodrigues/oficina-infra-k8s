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

variable "aws_load_balancer_controller_iam_mode" {
  description = "Modo de IAM do AWS Load Balancer Controller. Use node para permissoes existentes no ambiente/node role ou irsa para usar role dedicada."
  type        = string
  default     = "node"

  validation {
    condition     = contains(["node", "irsa"], var.aws_load_balancer_controller_iam_mode)
    error_message = "aws_load_balancer_controller_iam_mode deve ser node ou irsa."
  }
}

variable "load_balancer_provisioning_mode" {
  description = "Modo de provisionamento do NLB. terraform_nlb: Terraform cria NLB/TG/Listener. aws_lbc: AWS Load Balancer Controller."
  type        = string
  default     = "terraform_nlb"

  validation {
    condition     = contains(["terraform_nlb", "aws_lbc"], var.load_balancer_provisioning_mode)
    error_message = "load_balancer_provisioning_mode deve ser terraform_nlb ou aws_lbc."
  }
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Versao fixa do Helm chart do AWS Load Balancer Controller."
  type        = string
  default     = "1.8.1"
}

variable "metrics_server_chart_version" {
  description = "Versao parametrizavel do Helm chart oficial do Metrics Server. Revise antes de uso produtivo."
  type        = string
  default     = "3.13.0"
}
