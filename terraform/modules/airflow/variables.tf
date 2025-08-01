variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  type        = string
}

variable "load_balancer_arn" {
  description = "ARN of the load balancer"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group"
  type        = string
}

variable "db_username" {
  description = "Database username for Airflow"
  type        = string
  default     = "airflow"
}

variable "db_password" {
  description = "Database password for Airflow"
  type        = string
  sensitive   = true
}

variable "airflow_fernet_key" {
  description = "Fernet key for Airflow encryption"
  type        = string
  sensitive   = true
}

variable "airflow_secret_key" {
  description = "Secret key for Airflow webserver"
  type        = string
  sensitive   = true
}

variable "mlflow_tracking_uri" {
  description = "MLflow tracking server URI"
  type        = string
}

variable "mlflow_s3_bucket_arn" {
  description = "ARN of the MLflow S3 bucket"
  type        = string
}

variable "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  type        = string
}