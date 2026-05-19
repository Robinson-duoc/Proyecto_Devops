provider "aws" {
  region = var.aws_region
}

data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "innovatech-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "innova-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "innova-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "innova-gw"
  }
}

############################
# SUBNETS & ROUTING
############################

# 1. Subred Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# 2. Subred Privada
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

# 3. Route Table Pública (apunta al Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 4. Asociar Subred Pública a su Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 5. Route Table Privada (apunta al NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# 6. Asociar Subred Privada a su Route Table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-frontend-sg"
  }
}

resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-backend-sg"
  }
}

resource "aws_security_group" "data_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "innovatech-sg"
  }
}

############################
# ECR
############################

resource "aws_ecr_repository" "backend" {
  name         = "${var.project_name}-backend"
  force_delete = true
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = true
}

############################
# MYSQL EC2
############################

resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/ec2/${var.project_name}"
  retention_in_days = 7
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.data_sg.id]
  key_name               = var.key_pair_name
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

    # Esperar a que Docker esté realmente listo
    until docker info > /dev/null 2>&1; do
      echo "Esperando Docker..."
      sleep 3
    done

    # Limpiar espacio por si acaso
    docker system prune -af

    # Levantar MySQL optimizado
    docker run -d \
    --name mysql \
    -e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=innova_db \
    -e MYSQL_ROOT_HOST=% \
    -p 3306:3306 \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    mysql:8-oracle \
    --bind-address=0.0.0.0 \
    --performance-schema=OFF
  EOF

  tags = {
    Name = "${var.project_name}-mysql"
    Role = "Database"
  }
}

resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  depends_on = [aws_nat_gateway.nat]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker aws-cli
    systemctl start docker
    systemctl enable docker
    
    docker pull ${aws_ecr_repository.backend.repository_url}:latest
    docker run -d \
      --name backend \
      -p 8080:8080 \
      -e DB_HOST=${aws_instance.db.private_ip} \
      -e DB_PORT=3306 \
      -e DB_NAME=innovatech_db \
      -e DB_USERNAME=root \
      -e DB_PASSWORD=root \
      --restart always \
      ${aws_ecr_repository.backend.repository_url}:latest
  EOF

  tags = {
    Name = "${var.project_name}-backend"
    Role = "Backend"
  }
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker aws-cli
    systemctl start docker
    systemctl enable docker

    docker pull ${aws_ecr_repository.frontend.repository_url}:latest
    docker run -d \
      --name frontend \
      -p 80:80 \
      --restart always \
      ${aws_ecr_repository.frontend.repository_url}:latest
  EOF

  tags = {
    Name = "${var.project_name}-frontend"
    Role = "Frontend"
  }
}

############################
# CLOUDWATCH
############################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

############################
# ECS
############################

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-x86_64"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t2.micro"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab_profile.name
  }

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

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
  max_size            = 1
  vpc_zone_identifier = [aws_subnet.public.id]

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

resource "aws_cloudwatch_log_group" "ecs_frontend" {
  name              = "/ecs/${var.project_name}-frontend"
  retention_in_days = 7
}

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

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

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
  name            = "${var.project_name}-frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 1
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}

resource "aws_ecr_repository" "backend_despacho" {
  name         = "${var.project_name}-backend-despacho"
  force_delete = true
}

resource "aws_cloudwatch_log_group" "ecs_backend_ventas" {
  name              = "/ecs/${var.project_name}-backend-ventas"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "ecs_backend_despacho" {
  name              = "/ecs/${var.project_name}-backend-despacho"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "backend_ventas" {
  family                   = "${var.project_name}-backend-ventas"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name      = "backend-ventas"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST",     value = aws_instance.db.private_ip },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = var.db_name },
        { name = "DB_USERNAME", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend_ventas.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend-ventas"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend_despacho" {
  family                   = "${var.project_name}-backend-despacho"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name      = "backend-despacho"
      image     = "${aws_ecr_repository.backend_despacho.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST",     value = aws_instance.db.private_ip },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = var.db_name },
        { name = "DB_USERNAME", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend_despacho.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend-despacho"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend_ventas" {
  name            = "${var.project_name}-backend-ventas-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_ventas.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 0
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}

resource "aws_ecs_service" "backend_despacho" {
  name            = "${var.project_name}-backend-despacho-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_despacho.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 0
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}
