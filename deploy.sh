#!/bin/bash

# GreenAI Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🌽 GreenAI Deployment Script${NC}"

# Check if required tools are installed
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All requirements met${NC}"
}

# Initialize Terraform
init_terraform() {
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    cd terraform
    terraform init
    cd ..
    echo -e "${GREEN}✓ Terraform initialized${NC}"
}

# Plan Terraform deployment
plan_terraform() {
    echo -e "${YELLOW}Planning Terraform deployment...${NC}"
    cd terraform
    
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${RED}terraform.tfvars not found. Please copy terraform.tfvars.example and fill in your values.${NC}"
        exit 1
    fi
    
    terraform plan
    cd ..
    echo -e "${GREEN}✓ Terraform plan completed${NC}"
}

# Apply Terraform deployment
apply_terraform() {
    echo -e "${YELLOW}Applying Terraform deployment...${NC}"
    cd terraform
    terraform apply -auto-approve
    
    # Get outputs
    ECR_URL=$(terraform output -raw ecr_repository_url)
    ALB_URL=$(terraform output -raw load_balancer_url)
    
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
    echo -e "${GREEN}ECR Repository: ${ECR_URL}${NC}"
    echo -e "${GREEN}Application URL: ${ALB_URL}${NC}"
    
    cd ..
}

# Build and push Docker image
build_and_push() {
    echo -e "${YELLOW}Building and pushing Docker image...${NC}"
    
    # Get ECR repository URL from Terraform output
    cd terraform
    ECR_URL=$(terraform output -raw ecr_repository_url)
    cd ..
    
    # Login to ECR
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL
    
    # Build image
    docker build -t greenai .
    
    # Tag and push
    docker tag greenai:latest $ECR_URL:latest
    docker push $ECR_URL:latest
    
    echo -e "${GREEN}✓ Docker image built and pushed${NC}"
}

# Update ECS service
update_service() {
    echo -e "${YELLOW}Updating ECS service...${NC}"
    
    aws ecs update-service \
        --cluster greenai-cluster \
        --service greenai-service \
        --force-new-deployment
    
    echo -e "${GREEN}✓ ECS service updated${NC}"
}

# Main deployment function
deploy() {
    check_requirements
    init_terraform
    plan_terraform
    
    echo -e "${YELLOW}Do you want to proceed with the deployment? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        apply_terraform
        build_and_push
        update_service
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    else
        echo -e "${YELLOW}Deployment cancelled.${NC}"
    fi
}

# Parse command line arguments
case "${1:-deploy}" in
    "init")
        check_requirements
        init_terraform
        ;;
    "plan")
        check_requirements
        init_terraform
        plan_terraform
        ;;
    "apply")
        check_requirements
        init_terraform
        apply_terraform
        ;;
    "build")
        build_and_push
        ;;
    "update")
        update_service
        ;;
    "deploy")
        deploy
        ;;
    *)
        echo "Usage: $0 {init|plan|apply|build|update|deploy}"
        echo "  init   - Initialize Terraform"
        echo "  plan   - Plan Terraform deployment"
        echo "  apply  - Apply Terraform deployment"
        echo "  build  - Build and push Docker image"
        echo "  update - Update ECS service"
        echo "  deploy - Full deployment (default)"
        exit 1
        ;;
esac