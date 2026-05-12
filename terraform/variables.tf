variable "aws_region" {
  description = "Regiao AWS usada pelo ambiente de validacao."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado em nomes e tags."
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Nome do ambiente usado em tags e metadados."
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "ID da VPC existente criada pelo oficina-infra-db."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^vpc-[0-9a-fA-F]+$", nonsensitive(var.vpc_id)))
    error_message = "vpc_id deve ser um ID de VPC valido, por exemplo vpc-0123456789abcdef0."
  }
}

variable "subnet_ids" {
  description = "IDs das subnets publicas existentes criadas pelo oficina-infra-db."
  type        = list(string)
  sensitive   = true

  validation {
    condition = (
      length(nonsensitive(var.subnet_ids)) >= 2 &&
      length(distinct(nonsensitive(var.subnet_ids))) == length(nonsensitive(var.subnet_ids)) &&
      alltrue([for subnet_id in nonsensitive(var.subnet_ids) : can(regex("^subnet-[0-9a-fA-F]+$", subnet_id))])
    )
    error_message = "subnet_ids deve conter pelo menos duas subnets validas e sem duplicidade."
  }
}

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "oficina-eks"

  validation {
    condition     = length(var.cluster_name) <= 100 && can(regex("^[0-9A-Za-z][A-Za-z0-9_-]*$", var.cluster_name))
    error_message = "cluster_name deve ter ate 100 caracteres e conter apenas letras, numeros, hifen ou underscore."
  }
}

variable "node_instance_types" {
  description = "Tipos de instancia usados pelo node group gerenciado."
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_instance_types) >= 1 && alltrue([for instance_type in var.node_instance_types : length(trimspace(instance_type)) > 0])
    error_message = "node_instance_types deve conter ao menos um tipo de instancia valido."
  }
}

variable "node_min_size" {
  description = "Quantidade minima de nodes no node group."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 0
    error_message = "node_min_size deve ser maior ou igual a 0."
  }
}

variable "node_desired_size" {
  description = "Quantidade desejada de nodes no node group."
  type        = number
  default     = 1

  validation {
    condition     = var.node_desired_size >= 0
    error_message = "node_desired_size deve ser maior ou igual a 0."
  }
}

variable "node_max_size" {
  description = "Quantidade maxima de nodes no node group."
  type        = number
  default     = 2

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size deve ser maior ou igual a 1."
  }
}

variable "eks_cluster_role_arn" {
  description = "ARN da IAM Role existente usada pelo control plane do EKS. Nao ha fallback automatico."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", nonsensitive(var.eks_cluster_role_arn)))
    error_message = "eks_cluster_role_arn deve ser um ARN valido de IAM Role."
  }
}

variable "eks_node_role_arn" {
  description = "ARN da IAM Role existente usada pelo node group do EKS. Nao ha fallback automatico."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", nonsensitive(var.eks_node_role_arn)))
    error_message = "eks_node_role_arn deve ser um ARN valido de IAM Role."
  }
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

variable "ecr_mutable_alias_tag" {
  description = "Tag alias mutavel permitida no ECR para a imagem operacional mais recente."
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.ecr_mutable_alias_tag))
    error_message = "ecr_mutable_alias_tag deve ser uma tag Docker valida, por exemplo latest."
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
