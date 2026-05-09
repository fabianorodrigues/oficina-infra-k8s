locals {
  eks_node_group_name = "${var.project_name}-node-group"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
