locals {
  eks_node_group_name = "${var.cluster_name}-nodes"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
