variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "greenai"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "gemini_api_key" {
  description = "Gemini API key"
  type        = string
  sensitive   = true
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Memory for ECS task"
  type        = number
  default     = 2048
}



# MLflow Variables
variable "mlflow_db_username" {
  description = "Database username for MLflow"
  type        = string
  default     = "mlflow"
}

variable "mlflow_db_password" {
  description = "Database password for MLflow"
  type        = string
  sensitive   = true
}

# Airflow Variables
variable "airflow_db_username" {
  description = "Database username for Airflow"
  type        = string
  default     = "airflow"
}

variable "airflow_db_password" {
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