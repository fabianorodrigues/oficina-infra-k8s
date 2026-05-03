output "ecr_repository_name" {
  description = "Nome do repositorio ECR da imagem Docker da Oficina API."
  value       = aws_ecr_repository.api.name
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR para build e push da imagem Docker da Oficina API."
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_registry_id" {
  description = "ID da registry AWS ECR que contem o repositorio."
  value       = aws_ecr_repository.api.registry_id
}

