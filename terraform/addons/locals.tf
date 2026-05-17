locals {
  core_remote_state_key = length(trimspace(var.core_remote_state_key)) > 0 ? var.core_remote_state_key : "oficina-infra-k8s/${var.environment}/core/terraform.tfstate"

  cluster_name                          = data.terraform_remote_state.core.outputs.cluster_name
  vpc_id                                = data.terraform_remote_state.core.outputs.vpc_id
  aws_load_balancer_controller_role_arn = try(data.terraform_remote_state.core.outputs.aws_load_balancer_controller_role_arn, null)

  aws_load_balancer_controller_enabled      = var.load_balancer_provisioning_mode == "aws_lbc"
  aws_load_balancer_controller_irsa_enabled = local.aws_load_balancer_controller_enabled && var.aws_load_balancer_controller_iam_mode == "irsa"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
