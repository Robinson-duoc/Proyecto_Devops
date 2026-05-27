# ======================================================================
# DATA SOURCE (Necesario para obtener el ID de tu cuenta AWS)
# ======================================================================
data "aws_caller_identity" "current" {}

# ======================================================================
# RED (VPC y Gateways)
# ======================================================================
output "vpc_id" {
  value = aws_vpc.main.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}

# ======================================================================
# SECURITY GROUPS
# ======================================================================
output "sg_frontend_id" {
  value = aws_security_group.frontend_sg.id
}

output "sg_backend_id" {
  value = aws_security_group.backend_sg.id
}

output "sg_data_id" {
  value = aws_security_group.data_sg.id
}

# ======================================================================
# ECR REPOSITORIES (URLs para GitHub Actions)
# ======================================================================
output "ecr_frontend_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_ventas_url" {
  value = aws_ecr_repository.backend_ventas.repository_url
}

output "ecr_backend_despachos_url" {
  value = aws_ecr_repository.backend_despachos.repository_url
}

output "ecr_registry_url" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "docker_login_command" {
  value = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ======================================================================
# BASE DE DATOS (MySQL)
# ======================================================================
output "db_private_ip" {
  value       = aws_instance.db.private_ip
  description = "IP Privada de la instancia MySQL"
}

# ======================================================================
# ECS CLUSTER Y SERVICIOS
# ======================================================================
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "ecs_service_frontend" {
  value = aws_ecs_service.frontend.name
}

output "ecs_service_ventas" {
  value = aws_ecs_service.backend_ventas.name
}

output "ecs_service_despachos" {
  value = aws_ecs_service.backend_despachos.name    
}