# 📊 GreenAI Monitoring Setup Guide

This guide covers setting up comprehensive monitoring for your GreenAI Streamlit application using Prometheus and Grafana on AWS ECS.

## 🔐 GitHub Actions Secrets Setup

### Required Secrets in GitHub Repository

Navigate to: **Settings → Secrets and variables → Actions → New repository secret**

```bash
# AWS Credentials (Required)
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG...

# Application Secrets (Required)
GEMINI_API_KEY=your-gemini-api-key-here

# Monitoring Secrets (Optional - will use defaults if not set)
GRAFANA_ADMIN_PASSWORD=your-secure-password-here

# Configuration (Optional - defaults provided)
AWS_REGION=us-east-1
ECR_REPOSITORY=greenai
```

### Using Secrets in Terraform

The secrets are automatically passed to Terraform through environment variables:

```bash
# In your deployment
export TF_VAR_gemini_api_key="${{ secrets.GEMINI_API_KEY }}"
export TF_VAR_grafana_admin_password="${{ secrets.GRAFANA_ADMIN_PASSWORD }}"
```

## 📊 Monitoring Architecture

### Components Deployed

1. **Prometheus** (Port 9090)
   - Metrics collection and storage
   - Scrapes metrics from Streamlit app
   - Time-series database

2. **Grafana** (Port 3000)
   - Visualization dashboards
   - Alerting and notifications
   - User-friendly interface

3. **Streamlit Metrics** (Port 8502)
   - Custom metrics endpoint
   - Application performance metrics
   - Business metrics (YOLO detections, API calls)

### Metrics Collected

#### System Metrics
- CPU usage percentage
- Memory usage (bytes)
- Active users count
- Request count and duration

#### Application Metrics
- YOLO detection count
- Gemini API call success/failure rates
- Request patterns and endpoints
- Error rates and response times

## 🚀 Deployment Steps

### 1. Update terraform.tfvars

```hcl
# Basic Configuration
aws_region  = "us-east-1"
app_name    = "greenai"
environment = "prod"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# ECS Configuration
desired_count = 2
cpu          = 1024
memory       = 2048

# Monitoring Configuration
grafana_admin_password = "your-secure-password"
```

### 2. Deploy Infrastructure

```bash
cd terraform

# Set environment variables
export TF_VAR_gemini_api_key="your-gemini-api-key"
export TF_VAR_grafana_admin_password="your-grafana-password"

# Deploy
terraform init
terraform plan
terraform apply
```

### 3. Access Monitoring Dashboards

After deployment, Terraform will output the URLs:

```bash
# Get the URLs
terraform output prometheus_url
terraform output grafana_url
terraform output load_balancer_url
```

## 📈 Accessing Dashboards

### Prometheus (Metrics & Queries)
- **URL**: `http://your-alb-url:9090`
- **Purpose**: Raw metrics, queries, and alerts
- **Key Endpoints**:
  - `/metrics` - Metrics endpoint
  - `/targets` - Scrape targets status
  - `/graph` - Query interface

### Grafana (Visualization)
- **URL**: `http://your-alb-url:3000`
- **Login**: 
  - Username: `admin`
  - Password: `your-grafana-password`
- **Features**:
  - Pre-built dashboards
  - Custom visualizations
  - Alerting rules

## 🔧 Grafana Dashboard Setup

### 1. Add Prometheus Data Source

1. Login to Grafana
2. Go to **Configuration → Data Sources**
3. Add Prometheus data source:
   - URL: `http://prometheus:9090`
   - Access: Server (default)

### 2. Import Dashboard

Create a custom dashboard with these panels:

#### System Metrics Panel
```json
{
  "title": "System Metrics",
  "targets": [
    {
      "expr": "streamlit_cpu_usage_percent",
      "legendFormat": "CPU Usage %"
    },
    {
      "expr": "streamlit_memory_usage_bytes / 1024 / 1024",
      "legendFormat": "Memory Usage MB"
    }
  ]
}
```

#### Application Metrics Panel
```json
{
  "title": "Application Metrics",
  "targets": [
    {
      "expr": "rate(streamlit_requests_total[5m])",
      "legendFormat": "Requests/sec"
    },
    {
      "expr": "streamlit_active_users",
      "legendFormat": "Active Users"
    }
  ]
}
```

#### YOLO Detection Panel
```json
{
  "title": "YOLO Detections",
  "targets": [
    {
      "expr": "rate(streamlit_yolo_detections_total[5m])",
      "legendFormat": "Detections/sec"
    }
  ]
}
```

## 🚨 Alerting Setup

### Prometheus Alerts

Create alert rules in Prometheus:

```yaml
# High CPU Usage
- alert: HighCPUUsage
  expr: streamlit_cpu_usage_percent > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High CPU usage detected"

# High Memory Usage
- alert: HighMemoryUsage
  expr: streamlit_memory_usage_bytes > 1.5e9
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High memory usage detected"

# API Failures
- alert: HighAPIFailureRate
  expr: rate(streamlit_gemini_api_calls_total{status="error"}[5m]) > 0.1
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "High Gemini API failure rate"
```

## 🔍 Monitoring Queries

### Useful Prometheus Queries

```promql
# Request rate
rate(streamlit_requests_total[5m])

# Average response time
rate(streamlit_request_duration_seconds_sum[5m]) / rate(streamlit_request_duration_seconds_count[5m])

# Error rate
rate(streamlit_gemini_api_calls_total{status="error"}[5m]) / rate(streamlit_gemini_api_calls_total[5m])

# Detection rate
rate(streamlit_yolo_detections_total[5m])

# Memory usage trend
increase(streamlit_memory_usage_bytes[1h])
```

## 🛠️ Troubleshooting

### Common Issues

1. **Metrics not appearing**
   - Check if metrics server is running on port 8502
   - Verify Prometheus can reach the metrics endpoint
   - Check security group rules

2. **Grafana connection issues**
   - Verify Prometheus data source URL
   - Check network connectivity between services
   - Ensure proper security group configuration

3. **High resource usage**
   - Monitor ECS task CPU/memory limits
   - Adjust task definitions if needed
   - Scale services based on load

### Debugging Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster greenai-cluster --services greenai-service

# View logs
aws logs tail /ecs/greenai --follow
aws logs tail /ecs/greenai-monitoring --follow

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## 📊 Metrics Integration in Code

Your Streamlit application now includes metrics tracking:

```python
from metrics_middleware import (
    track_yolo_detection,
    track_gemini_api_call,
    track_request,
    initialize_metrics
)

# Initialize metrics on app start
initialize_metrics()

# Track YOLO detections
def detect_objects(image):
    # ... detection logic ...
    track_yolo_detection()
    return results

# Track API calls
def call_gemini_api():
    try:
        # ... API call ...
        track_gemini_api_call('success')
    except Exception:
        track_gemini_api_call('error')
```

## 🎯 Next Steps

1. **Set up alerting** - Configure Grafana alerts for critical metrics
2. **Create custom dashboards** - Build dashboards specific to your use case
3. **Add more metrics** - Track business-specific KPIs
4. **Set up log aggregation** - Centralize logs with ELK stack or CloudWatch Insights
5. **Performance optimization** - Use metrics to identify bottlenecks

Your GreenAI application now has enterprise-grade monitoring! 🎉