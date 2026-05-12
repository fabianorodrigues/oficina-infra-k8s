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
}

output "node_group_name" {
  description = "Nome do node group gerenciado do EKS."
  value       = aws_eks_node_group.this.node_group_name
}
