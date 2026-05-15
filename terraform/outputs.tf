output "ecr_repository_name" {
  description = "Nome do repositorio ECR da imagem Docker da Oficina API."
  value       = aws_ecr_repository.api.name
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR para build e push da imagem Docker da Oficina API."
  value       = aws_ecr_repository.api.repository_url
  sensitive   = true
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.this.name
  sensitive   = true
}

output "node_group_name" {
  description = "Nome do node group gerenciado do EKS."
  value       = aws_eks_node_group.this.node_group_name
  sensitive   = true
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN da IAM Role IRSA usada pelo AWS Load Balancer Controller."
  value       = aws_iam_role.aws_load_balancer_controller.arn
  sensitive   = true
}

output "vpc_id" {
  description = "ID da VPC consumida do oficina-infra-db."
  value       = local.vpc_id
  sensitive   = true
}

output "vpc_cidr_block" {
  description = "CIDR da VPC consumida do oficina-infra-db."
  value       = local.vpc_cidr_block
  sensitive   = true
}
