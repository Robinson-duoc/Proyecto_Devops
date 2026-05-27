# ============================================================
# CONFIGURACIÓN INICIAL & PROVEEDORES
# ============================================================
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# RED PRINCIPAL (VPC, Subnets, Gateways y Tablas de Ruta)
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_cidr
  availability_zone = var.availability_zone

  tags = {
    Name    = "${var.project_name}-subnet-private"
    Project = var.project_name
    Tier    = "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# GRUPOS DE SEGURIDAD (Security Groups)
# ============================================================
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "Security Group para instancia EC2 Frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-frontend"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Security Group para instancia EC2 Backend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API Despachos desde Frontend"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "API Ventas desde Frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-backend"
    Project = var.project_name
    Tier    = "private"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-sg-ecs-tasks"
  description = "Security Group para tareas ECS Fargate"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP Frontend desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Despachos desde VPC"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "API Ventas desde VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "MySQL interno entre contenedores ECS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ecs-tasks"
    Project = var.project_name
  }
}

# ============================================================
# INSTANCIAS EC2 & USER DATA LOCALS
# ============================================================
locals {
  user_data_docker = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker git aws-cli
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker, Docker Compose y AWS CLI instalados" >> /var/log/user-data.log
  EOF
}

resource "aws_instance" "frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = local.user_data_docker

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-vol-frontend"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-ec2-frontend"
    Project = var.project_name
    Tier    = "public"
    Role    = "frontend"
  }
}

resource "aws_instance" "backend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  key_name                    = var.key_name
  associate_public_ip_address = false
  user_data                   = local.user_data_docker

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-vol-backend"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-ec2-backend"
    Project = var.project_name
    Tier    = "private"
    Role    = "backend"
  }
}

# ============================================================
# REPOSITORIOS ECR (Elastic Container Registry)
# ============================================================
resource "aws_ecr_repository" "repo_frontend" {
  name                 = "innovatech-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name    = "innovatech-frontend"
    Project = var.project_name
  }
}

resource "aws_ecr_repository" "repo_despachos" {
  name                 = "innovatech-backend-despachos"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name    = "innovatech-backend-despachos"
    Project = var.project_name
  }
}

resource "aws_ecr_repository" "repo_ventas" {
  name                 = "innovatech-backend-ventas"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name    = "innovatech-backend-ventas"
    Project = var.project_name
  }
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.repo_frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener solo las ultimas 5 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "despachos" {
  repository = aws_ecr_repository.repo_despachos.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener solo las ultimas 5 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "ventas" {
  repository = aws_ecr_repository.repo_ventas.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener solo las ultimas 5 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# ============================================================
# ECS CLUSTER, TASK DEFINITIONS Y SERVICIOS
# ============================================================
resource "aws_ecs_cluster" "innovatech_cluster" {
  name = "innovatech-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/innovatech-frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "despachos" {
  name              = "/ecs/innovatech-despachos"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "ventas" {
  name              = "/ecs/innovatech-ventas"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "mysql_despachos" {
  name              = "/ecs/innovatech-mysql-despachos"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "mysql_ventas" {
  name              = "/ecs/innovatech-mysql-ventas"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "task_frontend" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/innovatech-frontend:latest"
      essential = true
      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]
      environment = [
        { name = "VITE_API_URL", value = "http://localhost:8081" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/innovatech-frontend"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "task_despachos" {
  family                   = "despachos-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024" 
  memory                   = "2048"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "mysql-despachos"
      image     = "mysql:8.0"
      essential = true
      portMappings = [{ containerPort = 3306, hostPort = 3306, protocol = "tcp" }]
      environment = [
        { name = "MYSQL_ROOT_PASSWORD", value = "rootpass123" },
        { name = "MYSQL_DATABASE",      value = "despachos_db" },
        { name = "MYSQL_USER",          value = "despacho_user" },
        { name = "MYSQL_PASSWORD",      value = "despacho_pass123" }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -prootpass123 || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 40
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/innovatech-mysql-despachos"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "mysql-despachos"
        }
      }
    },
    {
      name      = "despachos-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/innovatech-backend-despachos:latest"
      essential = true
      portMappings = [{ containerPort = 8081, hostPort = 8081, protocol = "tcp" }]
      environment = [
        { name = "DB_ENDPOINT", value = "127.0.0.1" },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = "despachos_db" },
        { name = "DB_USERNAME", value = "despacho_user" },
        { name = "DB_PASSWORD", value = "despacho_pass123" },
        { name = "SPRING_PROFILES_ACTIVE",     value = "prod" },
        { name = "SPRING_DATASOURCE_URL",      value = "jdbc:mysql://127.0.0.1:3306/despachos_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" },
        { name = "SPRING_DATASOURCE_USERNAME", value = "despacho_user" },
        { name = "SPRING_DATASOURCE_PASSWORD", value = "despacho_pass123" }
      ]
      dependsOn = [{ containerName = "mysql-despachos", condition = "HEALTHY" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/innovatech-despachos"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "despachos"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "task_ventas" {
  family                   = "ventas-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "mysql-ventas"
      image     = "mysql:8.0"
      essential = true
      portMappings = [{ containerPort = 3306, hostPort = 3306, protocol = "tcp" }]
      environment = [
        { name = "MYSQL_ROOT_PASSWORD", value = "rootpass123" },
        { name = "MYSQL_DATABASE",      value = "ventas_db" },
        { name = "MYSQL_USER",          value = "ventas_user" },
        { name = "MYSQL_PASSWORD",      value = "ventas_pass123" }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -prootpass123 || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 40
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/innovatech-mysql-ventas"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "mysql-ventas"
        }
      }
    },
    {
      name      = "ventas-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/innovatech-backend-ventas:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
      environment = [
        { name = "DB_ENDPOINT", value = "127.0.0.1" },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = "ventas_db" },
        { name = "DB_USERNAME", value = "ventas_user" },
        { name = "DB_PASSWORD", value = "ventas_pass123" },
        { name = "SPRING_PROFILES_ACTIVE",     value = "prod" },
        { name = "SPRING_DATASOURCE_URL",      value = "jdbc:mysql://127.0.0.1:3306/ventas_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" },
        { name = "SPRING_DATASOURCE_USERNAME", value = "ventas_user" },
        { name = "SPRING_DATASOURCE_PASSWORD", value = "ventas_pass123" }
      ]
      dependsOn = [{ containerName = "mysql-ventas", condition = "HEALTHY" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/innovatech-ventas"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ventas"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "svc_frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.innovatech_cluster.id
  task_definition = aws_ecs_task_definition.task_frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "svc_despachos" {
  name            = "despachos-service"
  cluster         = aws_ecs_cluster.innovatech_cluster.id
  task_definition = aws_ecs_task_definition.task_despachos.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "svc_ventas" {
  name            = "ventas-service"
  cluster         = aws_ecs_cluster.innovatech_cluster.id
  task_definition = aws_ecs_task_definition.task_ventas.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
}