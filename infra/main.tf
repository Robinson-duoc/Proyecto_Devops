# ======================================================================
# 1. PROVIDER Y VARIABLES
# ======================================================================

provider "aws" {
  region = var.aws_region
}

# Variables de Red e Infraestructura (Vienen de terraform.tfvars)
variable "aws_region" { default = "us-east-1" }
variable "project_name" { default = "innovatech" }
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "subnet_public_cidr" { default = "10.0.1.0/24" }
variable "subnet_private_cidr" { default = "10.0.2.0/24" }
variable "availability_zone" { default = "us-east-1a" }
variable "instance_type" { default = "t2.micro" }
variable "ami_id" { default = "ami-0c02fb55956c7d316" }
variable "key_name" { description = "Nombre de la llave SSH en AWS" }
variable "my_ip" { description = "Tu IP pública" }

# Variables de la Base de Datos
variable "db_name" { default = "innovatech_db" }
variable "db_user" { default = "root" }
variable "db_password" { default = "root" }

# ======================================================================
# 2. DATA SOURCES (Roles de AWS Academy y AMIs)
# ======================================================================

data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-x86_64"]
  }
}

# ======================================================================
# 3. RED (VPC, Subredes, Gateways)
# ======================================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone
  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_cidr
  availability_zone = var.availability_zone
  tags = { Name = "${var.project_name}-private-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "${var.project_name}-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "${var.project_name}-nat-gw" }
}

# ======================================================================
# 4. SECURITY GROUPS
# ======================================================================

resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-frontend-sg" }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # Limitado a tu IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-backend-sg" }

  ingress {
    from_port       = 8080 # Puerto de Ventas
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }
  ingress {
    from_port       = 9090 # Puerto de Despachos
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "data_sg" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-data-sg" }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ======================================================================
# 5. ECR REPOSITORIES (Nombres exactos para GitHub Actions)
# ======================================================================

resource "aws_ecr_repository" "frontend" {
  name         = "innovatech-frontend"
  force_delete = true
}

resource "aws_ecr_repository" "backend_ventas" {
  name         = "innovatech-backend-ventas"
  force_delete = true
}

resource "aws_ecr_repository" "backend_despachos" {
  name         = "innovatech-backend-despachos"
  force_delete = true
}

# ======================================================================
# 6. INSTANCIA DE BASE DE DATOS (EC2)
# ======================================================================

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id # Mejor práctica: DB en red privada
  vpc_security_group_ids = [aws_security_group.data_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    
    until docker info > /dev/null 2>&1; do sleep 3; done
    
    docker run -d \
    --name mysql \
    -e MYSQL_ROOT_PASSWORD=${var.db_password} \
    -e MYSQL_DATABASE=${var.db_name} \
    -p 3306:3306 \
    --restart always \
    mysql:8-oracle \
    --bind-address=0.0.0.0 \
    --performance-schema=OFF
  EOF

  tags = {
    Name = "${var.project_name}-mysql"
    Role = "Database"
  }
}

# ======================================================================
# 7. CLUSTER ECS Y AUTO SCALING
# ======================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab_profile.name
  }

  vpc_security_group_ids = [aws_security_group.frontend_sg.id, aws_security_group.backend_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = [aws_subnet.public.id] # Instancias en red pública para salir a internet

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 1
  }
}

# ======================================================================
# 8. ECS TASK DEFINITIONS Y SERVICES
# ======================================================================

# --- LOGS DE CLOUDWATCH ---
resource "aws_cloudwatch_log_group" "ecs_frontend" {
  name              = "/ecs/${var.project_name}-frontend"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "ecs_backend_ventas" {
  name              = "/ecs/${var.project_name}-backend-ventas"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "ecs_backend_despachos" {
  name              = "/ecs/${var.project_name}-backend-despachos"
  retention_in_days = 7
}

# --- FRONTEND ---
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256
      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  depends_on      = [aws_ecs_cluster_capacity_providers.main]
}

# --- BACKEND VENTAS ---
resource "aws_ecs_task_definition" "backend_ventas" {
  family                   = "${var.project_name}-backend-ventas"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name      = "backend-ventas"
      image     = "${aws_ecr_repository.backend_ventas.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]
      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://${aws_instance.db.private_ip}:3306/${var.db_name}?useSSL=false" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_user },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password },
        { name = "SPRING_JPA_HIBERNATE_DDL_AUTO", value = "update" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend_ventas.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ventas"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend_ventas" {
  name            = "ventas-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_ventas.arn
  desired_count   = 1
  depends_on      = [aws_ecs_cluster_capacity_providers.main]
}

# --- BACKEND DESPACHOS ---
resource "aws_ecs_task_definition" "backend_despachos" {
  family                   = "${var.project_name}-backend-despachos"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name      = "backend-despachos"
      image     = "${aws_ecr_repository.backend_despachos.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256
      portMappings = [{
        containerPort = 8080
        hostPort      = 9090 # Diferente puerto en el Host para que no colisione con Ventas
        protocol      = "tcp"
      }]
      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:mysql://${aws_instance.db.private_ip}:3306/${var.db_name}?useSSL=false" },
        { name = "SPRING_DATASOURCE_USERNAME", value = var.db_user },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password },
        { name = "SPRING_JPA_HIBERNATE_DDL_AUTO", value = "update" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend_despachos.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "despachos"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend_despachos" {
  name            = "despachos-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_despachos.arn
  desired_count   = 1
  depends_on      = [aws_ecs_cluster_capacity_providers.main]
}