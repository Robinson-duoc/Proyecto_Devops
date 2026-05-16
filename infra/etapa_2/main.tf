terraform {
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

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "main" {
  name   = "${var.project_name}-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Ventas API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Despacho API"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# ECR
############################

resource "aws_ecr_repository" "ventas" {
  name         = "${var.project_name}-ventas"
  force_delete = true
}

resource "aws_ecr_repository" "despacho" {
  name         = "${var.project_name}-despacho"
  force_delete = true
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = true
}

############################
# MYSQL EC2
############################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "mysql" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash

    yum update -y
    yum install docker -y

    systemctl start docker
    systemctl enable docker

    docker run -d \
      --name mysql \
      -e MYSQL_ROOT_PASSWORD=root \
      -e MYSQL_DATABASE=devopsdb \
      -p 3306:3306 \
      mysql:8
  EOF

  tags = {
    Name = "${var.project_name}-mysql"
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

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}

############################
# TASK DEFINITION
############################

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "1024"
  memory = "2048"

  execution_role_arn = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([

    {
      name  = "ventas-service"
      image = "${aws_ecr_repository.ventas.repository_url}:latest"

      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]

      environment = [
        {
          name  = "DB_ENDPOINT"
          value = aws_instance.mysql.private_ip
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = "devopsdb"
        },
        {
          name  = "DB_USERNAME"
          value = "root"
        },
        {
          name  = "DB_PASSWORD"
          value = "root"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ventas"
        }
      }
    },

    {
      name  = "despacho-service"
      image = "${aws_ecr_repository.despacho.repository_url}:latest"

      essential = true

      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
        }
      ]

      environment = [
        {
          name  = "DB_ENDPOINT"
          value = aws_instance.mysql.private_ip
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = "devopsdb"
        },
        {
          name  = "DB_USERNAME"
          value = "root"
        },
        {
          name  = "DB_PASSWORD"
          value = "root"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "despacho"
        }
      }
    },

    {
      name  = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"

      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]

      dependsOn = [
        {
          containerName = "ventas-service"
          condition     = "START"
        },
        {
          containerName = "despacho-service"
          condition     = "START"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "frontend"
        }
      }
    }

  ])
}

############################
# ECS SERVICE
############################

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"

  desired_count = 1

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.main.id]
    assign_public_ip = true
  }

  force_new_deployment = true
}