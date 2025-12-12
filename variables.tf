variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ha-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sandbox"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "home_assignment-eu-north"
}

variable "node_group_instance_types" {
  description = "Instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue for KEDA autoscaling"
  type        = string
  default     = "assignment-keda-queue"
}

variable "namespace" {
  description = "Kubernetes namespace for web applications"
  type        = string
  default     = "webapp"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "ha-eks-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Backend configuration
variable "s3_bucket" {
  description = "The name of the S3 bucket for the Terraform state."
  type        = string
}

variable "dynamo_db_table" {
  description = "The name of the DynamoDB table for state locking."
  type        = string
}