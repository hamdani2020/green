output "airflow_url" {
  description = "URL to access Airflow"
  value       = "http://${var.load_balancer_dns_name}:8080"
}

output "airflow_webserver_service_name" {
  description = "Name of the Airflow webserver ECS service"
  value       = aws_ecs_service.airflow_webserver.name
}

output "airflow_scheduler_service_name" {
  description = "Name of the Airflow scheduler ECS service"
  value       = aws_ecs_service.airflow_scheduler.name
}

output "airflow_worker_service_name" {
  description = "Name of the Airflow worker ECS service"
  value       = aws_ecs_service.airflow_worker.name
}

output "airflow_db_endpoint" {
  description = "RDS endpoint for Airflow"
  value       = aws_db_instance.airflow.endpoint
}

output "airflow_redis_endpoint" {
  description = "Redis endpoint for Airflow"
  value       = aws_elasticache_cluster.airflow.cache_nodes[0].address
}

