output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "subnet_public_id" {
  description = "ID de la subred pública"
  value       = aws_subnet.public.id
}

output "subnet_private_id" {
  description = "ID de la subred privada"
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "sg_frontend_id" {
  description = "ID del Security Group del Frontend (EC2)"
  value       = aws_security_group.frontend.id
}

output "sg_backend_id" {
  description = "ID del Security Group del Backend (EC2)"
  value       = aws_security_group.backend.id
}

output "sg_ecs_tasks_id" {
  description = "ID del Security Group para tareas ECS Fargate"
  value       = aws_security_group.ecs_tasks.id
}

output "ec2_frontend_public_ip" {
  description = "IP pública EC2 Frontend — abrir en el navegador"
  value       = aws_instance.frontend.public_ip
}

output "ec2_frontend_public_dns" {
  description = "DNS público EC2 Frontend"
  value       = aws_instance.frontend.public_dns
}

output "ec2_backend_private_ip" {
  description = "IP privada EC2 Backend — usar en VITE_API_URL"
  value       = aws_instance.backend.private_ip
}

output "ssh_frontend_command" {
  description = "Comando SSH para conectarse al Frontend"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.frontend.public_ip}"
}

output "app_url" {
  description = "URL de acceso a la aplicación (EC2 Frontend)"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "ecr_frontend_url" {
  description = "URL repositorio ECR Frontend"
  value       = aws_ecr_repository.repo_frontend.repository_url
}

output "ecr_backend_despachos_url" {
  description = "URL repositorio ECR Backend Despachos"
  value       = aws_ecr_repository.repo_despachos.repository_url
}

output "ecr_backend_ventas_url" {
  description = "URL repositorio ECR Backend Ventas"
  value       = aws_ecr_repository.repo_ventas.repository_url
}

output "ecr_registry_url" {
  description = "URL base del registro ECR — usar en docker login"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com"
}

output "docker_login_command" {
  description = "Comando para autenticarse en ECR desde tu PC"
  value       = "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com"
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.innovatech_cluster.name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.innovatech_cluster.arn
}