output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = module.load_balancer.load_balancer_url
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = module.monitoring.prometheus_url
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = module.monitoring.grafana_url
}