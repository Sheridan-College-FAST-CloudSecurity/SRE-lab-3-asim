variable "config_file" {
  description = "../configs/default.json"
  type        = string
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Public subnet CIDR"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., development)"
}