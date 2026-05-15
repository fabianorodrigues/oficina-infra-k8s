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

variable "remote_state_bucket" {
  description = "Bucket S3 do state remoto usado para ler a rede criada pelo oficina-infra-db."
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

variable "override_vpc_id" {
  description = "Override opcional da VPC. Use apenas quando nao for possivel consumir o remote state."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.override_vpc_id == null || can(regex("^vpc-[0-9a-fA-F]+$", nonsensitive(var.override_vpc_id)))
    error_message = "override_vpc_id deve ser null ou um ID de VPC valido."
  }
}

variable "override_public_subnet_ids" {
  description = "Override opcional das subnets publicas usadas pelo EKS/node group minimo."
  type        = list(string)
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition = (
      var.override_public_subnet_ids == null ||
      (
        length(nonsensitive(var.override_public_subnet_ids)) >= 2 &&
        length(distinct(nonsensitive(var.override_public_subnet_ids))) == length(nonsensitive(var.override_public_subnet_ids)) &&
        alltrue([for subnet_id in nonsensitive(var.override_public_subnet_ids) : can(regex("^subnet-[0-9a-fA-F]+$", subnet_id))])
      )
    )
    error_message = "override_public_subnet_ids deve ser null ou conter pelo menos duas subnets validas e sem duplicidade."
  }
}

variable "override_private_subnet_ids" {
  description = "Override opcional das subnets privadas usadas para NLB interno e VPC Link."
  type        = list(string)
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition = (
      var.override_private_subnet_ids == null ||
      (
        length(nonsensitive(var.override_private_subnet_ids)) >= 2 &&
        length(distinct(nonsensitive(var.override_private_subnet_ids))) == length(nonsensitive(var.override_private_subnet_ids)) &&
        alltrue([for subnet_id in nonsensitive(var.override_private_subnet_ids) : can(regex("^subnet-[0-9a-fA-F]+$", subnet_id))])
      )
    )
    error_message = "override_private_subnet_ids deve ser null ou conter pelo menos duas subnets validas e sem duplicidade."
  }
}

variable "override_vpc_cidr_block" {
  description = "Override opcional do CIDR da VPC para regras internas de seguranca."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.override_vpc_cidr_block == null || can(cidrhost(nonsensitive(var.override_vpc_cidr_block), 0))
    error_message = "override_vpc_cidr_block deve ser null ou um CIDR valido."
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

variable "aws_load_balancer_controller_iam_mode" {
  description = "Modo de IAM do AWS Load Balancer Controller. Use node para permissoes existentes no ambiente/node role ou irsa para criar IAM/OIDC dedicado."
  type        = string
  default     = "node"

  validation {
    condition     = contains(["node", "irsa"], var.aws_load_balancer_controller_iam_mode)
    error_message = "aws_load_balancer_controller_iam_mode deve ser node ou irsa."
  }
}

variable "aws_load_balancer_controller_policy_name" {
  description = "Nome da IAM Policy do AWS Load Balancer Controller."
  type        = string
  default     = "oficina-aws-load-balancer-controller"
}

variable "aws_load_balancer_controller_role_name" {
  description = "Nome da IAM Role IRSA do AWS Load Balancer Controller."
  type        = string
  default     = "oficina-aws-load-balancer-controller"
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

variable "api_node_port" {
  description = "NodePort da API no EKS. Usado no modo terraform_nlb."
  type        = number
  default     = 30080

  validation {
    condition     = var.api_node_port >= 30000 && var.api_node_port <= 32767
    error_message = "api_node_port deve estar entre 30000 e 32767."
  }
}

variable "api_health_check_path" {
  description = "Caminho do health check do Target Group. Usado no modo terraform_nlb."
  type        = string
  default     = "/health"
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
