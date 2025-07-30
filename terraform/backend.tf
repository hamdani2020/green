# Uncomment and configure this block to use S3 backend for Terraform state
# You'll need to create the S3 bucket and DynamoDB table first

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "greenai/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }