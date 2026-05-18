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

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################
# SECURITY GROUPS
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

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description       = "MySQL from ECS"
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [aws_security_group.main.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

############################
# ECR
############################

resource "aws_ecr_repository" "ventas" {
  name         = "${var.project_name}-ventas"
  force_delete = true

  tags = {
    Name = "${var.project_name}-ventas"
  }
}

resource "aws_ecr_repository" "despacho" {
  name         = "${var.project_name}-despacho"
  force_delete = true

  tags = {
    Name = "${var.project_name}-despacho"
  }
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = true

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

############################
# RDS MYSQL (OPTIMIZADO PARA t2.micro)
############################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0.35"
  instance_class         = "db.t2.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  
  db_name  = "innovatech"
  username = "root"
  password = "root"

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot       = true
  publicly_accessible       = false
  multi_az                  = false
  backup_retention_period   = 0
  storage_encrypted         = false
  deletion_protection       = false
  copy_tags_to_snapshot     = false

  tags = {
    Name = "${var.project_name}-db"
  }

  depends_on = [aws_security_group.rds]
}

############################
# CLOUDWATCH
############################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}

############################
# ECS CLUSTER
############################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

############################
# IAM ROLE (USANDO LabRole DE AWS ACADEMY)
############################

data "aws_iam_role" "lab" {
  name = "LabRole"
}

############################
# TASK DEFINITION (OPTIMIZADO t2.micro)
############################

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # REDUCIDO PARA t2.micro: CPU 256 en lugar de 1024
  cpu    = "256"
  memory = "512"

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
          value = aws_db_instance.mysql.address
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = "innovatech"
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
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ventas"
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
          value = aws_db_instance.mysql.address
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = "innovatech"
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
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "despacho"
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

      environment = [
        {
          name  = "REACT_APP_API_VENTAS"
          value = "http://localhost:8080"
        },
        {
          name  = "REACT_APP_API_DESPACHO"
          value = "http://localhost:8081"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }

  ])

  depends_on = [aws_db_instance.mysql]
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

  tags = {
    Name = "${var.project_name}-service"
  }

  depends_on = [aws_ecs_cluster.main]
}
