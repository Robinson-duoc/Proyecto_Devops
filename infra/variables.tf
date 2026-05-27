# ============================================================
# variables.tf — Variables globales del proyecto
# ============================================================

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en todos los recursos"
  type        = string
  default     = "innovatech"
}

# ──────────────────────────────────────────────
# Red
# ──────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block de la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_public_cidr" {
  description = "CIDR de la subred pública (Frontend)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_private_cidr" {
  description = "CIDR de la subred privada (Backend)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidad"
  type        = string
  default     = "us-east-1a"
}

# ──────────────────────────────────────────────
# EC2
# ──────────────────────────────────────────────
variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nombre del par de claves SSH creado en AWS (sin .pem)"
  type        = string
  # Ejemplo: "mi-clave-innovatech"
}

variable "ami_id" {
  description = "AMI ID para las instancias EC2 (Amazon Linux 2023, us-east-1)"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 - us-east-1
}

# ──────────────────────────────────────────────
# Seguridad
# ──────────────────────────────────────────────

variable "my_ip" {
  description = "Tu IP pública para permitir SSH (formato: x.x.x.x/32)"
  type        = string
}
