variable "aws_region" {
  description = "Regiao AWS usada no AWS Academy Learner Lab."
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
  default     = "academy"
}

variable "ecr_repository_name" {
  description = "Nome do repositorio ECR da imagem Docker da Oficina API."
  type        = string
  default     = "oficina-api"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.ecr_repository_name))
    error_message = "ecr_repository_name deve ser um nome valido de repositorio ECR, por exemplo oficina-api."
  }
}

variable "ecr_force_delete" {
  description = "Permite destruir o repositorio ECR mesmo contendo imagens. O padrao preserva imagens."
  type        = bool
  default     = false
}

variable "untagged_image_expire_days" {
  description = "Quantidade de dias para manter imagens sem tag no ECR."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_expire_days >= 1
    error_message = "untagged_image_expire_days deve ser maior ou igual a 1."
  }
}

variable "tagged_image_count_limit" {
  description = "Quantidade maxima de imagens tagueadas mantidas no ECR."
  type        = number
  default     = 30

  validation {
    condition     = var.tagged_image_count_limit >= 1
    error_message = "tagged_image_count_limit deve ser maior ou igual a 1."
  }
}

