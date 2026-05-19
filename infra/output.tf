output "frontend_public_ip" {
  description = "IP pública del frontend"
  value       = aws_instance.frontend.public_ip
}

output "backend_private_ip" {
  description = "IP privada del backend"
  value       = aws_instance.backend.private_ip
}

output "data_private_ip" {
  description = "IP privada de la instancia MySQL"
  value       = aws_instance.db.private_ip
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "frontend_sg_id" {
  description = "ID del Security Group Frontend"
  value       = aws_security_group.frontend_sg.id
}

output "frontend_ecr" {
  description = "URL del repositorio ECR frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_despacho_ecr" {
  description = "URL ECR backend despacho"
  value       = aws_ecr_repository.backend_despacho.repository_url
}