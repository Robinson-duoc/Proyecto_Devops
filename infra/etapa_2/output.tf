output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_address" {
  description = "RDS MySQL address (solo la IP)"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "ECS Service Name"
  value       = aws_ecs_service.app.name
}

output "ecr_ventas_uri" {
  description = "ECR Repository URI - Ventas"
  value       = aws_ecr_repository.ventas.repository_url
}

output "ecr_despacho_uri" {
  description = "ECR Repository URI - Despacho"
  value       = aws_ecr_repository.despacho.repository_url
}

output "ecr_frontend_uri" {
  description = "ECR Repository URI - Frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private Subnet ID"
  value       = aws_subnet.private.id
}

output "security_group_id" {
  description = "ECS Security Group ID"
  value       = aws_security_group.main.id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.app.arn
}
