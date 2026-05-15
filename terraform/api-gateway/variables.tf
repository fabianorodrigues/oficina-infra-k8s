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

variable "auth_function_name" {
  description = "Nome da Lambda de autenticacao por CPF."
  type        = string
  default     = "oficina-auth-cpf"
}

variable "authorizer_function_name" {
  description = "Nome da Lambda Authorizer JWT."
  type        = string
  default     = "oficina-jwt-authorizer"
}

variable "backend_listener_ssm_parameter_name" {
  description = "Nome do parametro SSM que contem o Listener ARN do NLB interno. Quando vazio, usa /oficina/{environment}/api/backend-listener-arn."
  type        = string
  default     = ""
}

variable "remote_state_bucket" {
  description = "Bucket S3 do state remoto do oficina-infra-db."
  type        = string
  default     = ""
  sensitive   = true
}

variable "remote_state_region" {
  description = "Regiao do bucket S3 do state remoto."
  type        = string
  default     = "us-east-1"
}

variable "db_remote_state_key" {
  description = "Key do state remoto do oficina-infra-db. Quando vazio, usa oficina-infra-db/{environment}/terraform.tfstate."
  type        = string
  default     = ""
}
