# GreenAI AWS ECS Deployment Guide

This guide will help you deploy the GreenAI application to AWS using ECS (Elastic Container Service) with Terraform for infrastructure as code and GitHub Actions for CI/CD.

## Prerequisites

### Required Tools
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Docker](https://www.docker.com/get-started)
- Git

### AWS Requirements
- AWS account with appropriate permissions
- AWS CLI configured with access keys

### Required Secrets
You'll need the following secrets:
- `GEMINI_API_KEY` - Your Google Gemini API key
- `AWS_ACCESS_KEY_ID` - AWS access key for GitHub Actions
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for GitHub Actions

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd greenai
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
aws_region = "us-east-1"
app_name   = "greenai"
environment = "prod"
```

### 3. Set Environment Variables

```bash
export TF_VAR_gemini_api_key="your-gemini-api-key-here"
```

### 4. Deploy Infrastructure

Using the deployment script:
```bash
./deploy.sh
```

Or manually:
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment
terraform apply

# Build and push Docker image
cd ..
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
docker build -t greenai .
docker tag greenai:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest
```

## GitHub Actions CI/CD Setup

### 1. Configure Repository Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions, and add:

- `AWS_ACCESS_KEY_ID`: Your AWS access key ID
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key
- `GEMINI_API_KEY`: Your Google Gemini API key

### 2. GitHub Actions Workflow

The workflow (`.github/workflows/deploy.yml`) will:
- Run tests on every push/PR
- Build and deploy to ECS on pushes to main branch
- Run Terraform plan on pull requests

### 3. Trigger Deployment

Push to the main branch to trigger automatic deployment:
```bash
git add .
git commit -m "Deploy to AWS ECS"
git push origin main
```

## Infrastructure Overview

The Terraform configuration creates:

### Networking
- VPC with public subnets across 2 AZs
- Internet Gateway and route tables
- Security groups for ALB and ECS tasks

### Load Balancing
- Application Load Balancer (ALB)
- Target group for ECS tasks
- Health checks on port 8501

### Container Infrastructure
- ECS Cluster with Fargate
- ECS Service with 2 task replicas
- ECR repository for Docker images
- CloudWatch logs for monitoring

### IAM
- ECS task execution role
- Appropriate policies for ECS operations

## Configuration

### Environment Variables
The application uses these environment variables:
- `GEMINI_API_KEY`: Google Gemini API key (required)
- `STREAMLIT_SERVER_PORT`: Port for Streamlit (default: 8501)

### Scaling
To adjust the number of running tasks, modify the `desired_count` in `terraform/main.tf`:
```hcl
resource "aws_ecs_service" "main" {
  # ...
  desired_count = 2  # Change this value
  # ...
}
```

## Monitoring and Logs

### CloudWatch Logs
Application logs are available in CloudWatch:
- Log Group: `/ecs/greenai`
- Stream: `ecs/greenai/<task-id>`

### Health Checks
- ALB health checks on `/` endpoint
- Docker health check using curl
- ECS service health monitoring

## Troubleshooting

### Common Issues

1. **ECR Login Issues**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ecr-url>
   ```

2. **Task Definition Updates**
   ```bash
   aws ecs update-service --cluster greenai-cluster --service greenai-service --force-new-deployment
   ```

3. **View ECS Logs**
   ```bash
   aws logs tail /ecs/greenai --follow
   ```

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster greenai-cluster --services greenai-service

# List running tasks
aws ecs list-tasks --cluster greenai-cluster --service-name greenai-service

# View task details
aws ecs describe-tasks --cluster greenai-cluster --tasks <task-arn>

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Cleanup

To destroy all resources:
```bash
cd terraform
terraform destroy
```

## Security Considerations

- ECS tasks run in public subnets but only accept traffic from ALB
- Security groups restrict access appropriately
- IAM roles follow least privilege principle
- ECR images are scanned for vulnerabilities
- Secrets are managed through environment variables

## Cost Optimization

- Uses Fargate for serverless container management
- ALB only charges for usage
- CloudWatch logs have 30-day retention
- Consider using spot instances for development environments

## Support

For issues or questions:
1. Check CloudWatch logs for application errors
2. Verify ECS service and task status
3. Check ALB target group health
4. Review security group configurations