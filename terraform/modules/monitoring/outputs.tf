output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${var.load_balancer_dns_name}:9090"
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${var.load_balancer_dns_name}:3000"
}

output "monitoring_security_group_id" {
  description = "ID of the monitoring security group"
  value       = aws_security_group.monitoring.id
}

