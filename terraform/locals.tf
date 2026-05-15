locals {
  db_remote_state_key = length(trimspace(var.db_remote_state_key)) > 0 ? var.db_remote_state_key : "oficina-infra-db/${var.environment}/terraform.tfstate"

  remote_vpc_id             = try(data.terraform_remote_state.db.outputs.vpc_id, null)
  remote_vpc_cidr_block     = try(data.terraform_remote_state.db.outputs.vpc_cidr_block, null)
  remote_public_subnet_ids  = try(data.terraform_remote_state.db.outputs.public_subnet_ids, null)
  remote_private_subnet_ids = try(data.terraform_remote_state.db.outputs.private_subnet_ids, null)

  vpc_id             = var.override_vpc_id != null ? var.override_vpc_id : local.remote_vpc_id
  vpc_cidr_block     = var.override_vpc_cidr_block != null ? var.override_vpc_cidr_block : local.remote_vpc_cidr_block
  public_subnet_ids  = var.override_public_subnet_ids != null ? var.override_public_subnet_ids : local.remote_public_subnet_ids
  private_subnet_ids = var.override_private_subnet_ids != null ? var.override_private_subnet_ids : local.remote_private_subnet_ids

  eks_node_group_name = "${var.project_name}-node-group"

  aws_load_balancer_controller_irsa_enabled = var.load_balancer_provisioning_mode == "aws_lbc" && var.aws_load_balancer_controller_iam_mode == "irsa"
  nlb_provisioning_enabled                  = var.load_balancer_provisioning_mode == "terraform_nlb"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
