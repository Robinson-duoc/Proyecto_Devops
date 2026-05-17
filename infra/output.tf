# La URL del repositorio donde GitHub subirá el Frontend
output "frontend_repo" {
  value = aws_ecr_repository.frontend.repository_url
}

# El nombre del cluster que GitHub necesita para actualizar la App
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}