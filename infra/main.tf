
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
# Recursos root
# ============================================================
# Las VPC, subredes, grupos de seguridad y EC2 se definen
# directamente en los archivos de este mismo directorio.
