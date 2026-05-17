variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "proyecto-devops"
}

variable "key_pair_name" {
  description = "Nombre del Key Pair EC2"
  type        = string
  default     = "vockey" 
}