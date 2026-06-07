variable "aws_region" {
  description = "AWS Region where the regional TGW lab will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for all lab resources."
  type        = string
  default     = "aws-tgw-segmentation-lab"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "lab-owner"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "study"
}

variable "enable_validation_instances" {
  description = "Create one private EC2 instance per VPC for SSM-based routing validation."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type used for private validation hosts."
  type        = string
  default     = "t3.micro"
}

