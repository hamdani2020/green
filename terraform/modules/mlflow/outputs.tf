output "mlflow_url" {
  description = "URL to access MLflow"
  value       = "http://${var.load_balancer_dns_name}:5000"
}

output "mlflow_s3_bucket_arn" {
  description = "ARN of the MLflow S3 bucket"
  value       = aws_s3_bucket.mlflow_artifacts.arn
}

output "mlflow_service_name" {
  description = "Name of the MLflow ECS service"
  value       = aws_ecs_service.mlflow.name
}

output "mlflow_s3_bucket" {
  description = "S3 bucket for MLflow artifacts"
  value       = aws_s3_bucket.mlflow_artifacts.bucket
}

output "mlflow_db_endpoint" {
  description = "RDS endpoint for MLflow"
  value       = aws_db_instance.mlflow.endpoint
}

output "mlflow_task_role_arn" {
  description = "ARN of the MLflow task role"
  value       = aws_iam_role.mlflow_task_role.arn
}
