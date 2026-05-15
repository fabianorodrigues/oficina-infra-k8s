data "aws_subnet" "public" {
  count = length(nonsensitive(local.public_subnet_ids))

  id = local.public_subnet_ids[count.index]
}

data "aws_subnet" "private" {
  count = length(nonsensitive(local.private_subnet_ids))

  id = local.private_subnet_ids[count.index]
}

resource "aws_ec2_tag" "public_subnet_cluster" {
  count = length(nonsensitive(local.public_subnet_ids))

  resource_id = local.public_subnet_ids[count.index]
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_cluster" {
  count = length(nonsensitive(local.private_subnet_ids))

  resource_id = local.private_subnet_ids[count.index]
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "subnet_public_elb" {
  count = length(nonsensitive(local.public_subnet_ids))

  resource_id = local.public_subnet_ids[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "subnet_internal_elb" {
  count = length(nonsensitive(local.private_subnet_ids))

  resource_id = local.private_subnet_ids[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = local.public_subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_ec2_tag.public_subnet_cluster,
    aws_ec2_tag.subnet_public_elb
  ]

  lifecycle {
    precondition {
      condition     = length(nonsensitive(local.public_subnet_ids)) >= 2
      error_message = "public_subnet_ids deve conter pelo menos duas subnets para o EKS."
    }

    precondition {
      condition     = length(nonsensitive(local.private_subnet_ids)) >= 2
      error_message = "private_subnet_ids deve conter pelo menos duas subnets para NLB interno e VPC Link."
    }

    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.public : subnet.vpc_id == nonsensitive(local.vpc_id)])
      error_message = "Todas as subnets publicas devem pertencer a vpc_id."
    }

    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.private : subnet.vpc_id == nonsensitive(local.vpc_id)])
      error_message = "Todas as subnets privadas devem pertencer a vpc_id."
    }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = local.eks_node_group_name
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = local.public_subnet_ids
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
    aws_ec2_tag.public_subnet_cluster,
    aws_ec2_tag.subnet_public_elb
  ]

  lifecycle {
    precondition {
      condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
      error_message = "O tamanho do node group deve respeitar node_min_size <= node_desired_size <= node_max_size."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_vpc_nodeport" {
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description       = "Internal NodePort traffic from VPC for NLB instance targets"

  cidr_ipv4   = local.vpc_cidr_block
  from_port   = 30000
  to_port     = 32767
  ip_protocol = "tcp"

  tags = {
    Name = "${var.project_name}-nodes-from-vpc-nodeport"
  }

  lifecycle {
    precondition {
      condition     = nonsensitive(local.vpc_cidr_block) != "0.0.0.0/0"
      error_message = "A regra NodePort deve permitir apenas trafego interno da VPC, nunca 0.0.0.0/0."
    }
  }
}
