data "aws_subnet" "selected" {
  count = length(nonsensitive(var.subnet_ids))

  id = var.subnet_ids[count.index]
}

resource "aws_ec2_tag" "subnet_cluster" {
  count = length(nonsensitive(var.subnet_ids))

  resource_id = var.subnet_ids[count.index]
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "subnet_public_elb" {
  count = length(nonsensitive(var.subnet_ids))

  resource_id = var.subnet_ids[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_ec2_tag.subnet_cluster,
    aws_ec2_tag.subnet_public_elb
  ]

  lifecycle {
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.selected : subnet.vpc_id == nonsensitive(var.vpc_id)])
      error_message = "Todas as subnets informadas em subnet_ids devem pertencer a vpc_id."
    }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = local.eks_node_group_name
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = local.eks_node_group_name
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_ec2_tag.subnet_cluster,
    aws_ec2_tag.subnet_public_elb
  ]

  lifecycle {
    precondition {
      condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
      error_message = "O tamanho do node group deve respeitar node_min_size <= node_desired_size <= node_max_size."
    }
  }
}
