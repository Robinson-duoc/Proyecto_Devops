output "ventas_ecr_url" {
  value = aws_ecr_repository.ventas.repository_url
}

output "despacho_ecr_url" {
  value = aws_ecr_repository.despacho.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "mysql_public_ip" {
  value = aws_instance.mysql.public_ip
}

output "mysql_private_ip" {
  value = aws_instance.mysql.private_ip
}