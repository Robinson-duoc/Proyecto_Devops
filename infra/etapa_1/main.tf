terraform {
  required_version = ">= 1.5.0"

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

# =========================================
# ECR - VENTAS SERVICE
# =========================================

resource "aws_ecr_repository" "ventas" {
  name         = "${var.nombre_proyecto}-ventas-service"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.nombre_proyecto
    Service = "ventas"
  }
}

# =========================================
# ECR - DESPACHO SERVICE
# =========================================

resource "aws_ecr_repository" "despacho" {
  name         = "${var.nombre_proyecto}-despacho-service"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.nombre_proyecto
    Service = "despacho"
  }
}

# =========================================
# ECR - FRONTEND
# =========================================

resource "aws_ecr_repository" "frontend" {
  name         = "${var.nombre_proyecto}-frontend"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.nombre_proyecto
    Service = "frontend"
  }
}