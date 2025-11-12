variable "project_name" {
  type        = string
  description = "Prefix for resource naming"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}
