# MLflow Tracking Server
resource "aws_ecs_service" "mlflow" {
  name            = "${var.app_name}-mlflow"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.mlflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.mlflow.id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mlflow.arn
    container_name   = "mlflow"
    container_port   = 5000
  }

  tags = {
    Name        = "${var.app_name}-mlflow-service"
    Environment = var.environment
  }
}

# MLflow Task Definition
resource "aws_ecs_task_definition" "mlflow" {
  family                   = "${var.app_name}-mlflow"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn           = aws_iam_role.mlflow_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "mlflow"
      image = "python:3.9-slim"
      
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]

      command = [
        "/bin/bash", "-c",
        "pip install mlflow boto3 psycopg2-binary && mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.mlflow.endpoint}:5432/mlflow --default-artifact-root s3://${aws_s3_bucket.mlflow_artifacts.bucket}/artifacts"
      ]

      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "MLFLOW_S3_ENDPOINT_URL"
          value = "https://s3.${var.aws_region}.amazonaws.com"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.mlflow.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "mlflow"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.app_name}-mlflow-task"
    Environment = var.environment
  }
}

# RDS PostgreSQL for MLflow backend
resource "aws_db_instance" "mlflow" {
  identifier     = "${var.app_name}-mlflow-db"
  engine         = "postgres"
  engine_version = "13.13"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "mlflow"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.mlflow_db.id]
  db_subnet_group_name   = aws_db_subnet_group.mlflow.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.app_name}-mlflow-db"
    Environment = var.environment
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "mlflow" {
  name       = "${var.app_name}-mlflow-db-subnet-group"
  subnet_ids = var.public_subnet_ids

  tags = {
    Name        = "${var.app_name}-mlflow-db-subnet-group"
    Environment = var.environment
  }
}

# S3 Bucket for MLflow Artifacts
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "${var.app_name}-mlflow-artifacts-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.app_name}-mlflow-artifacts"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM Role for MLflow Task
resource "aws_iam_role" "mlflow_task_role" {
  name = "${var.app_name}-mlflow-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-mlflow-task-role"
    Environment = var.environment
  }
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "mlflow_s3_policy" {
  name = "${var.app_name}-mlflow-s3-policy"
  role = aws_iam_role.mlflow_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mlflow_artifacts.arn,
          "${aws_s3_bucket.mlflow_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# Security Groups
resource "aws_security_group" "mlflow" {
  name_prefix = "${var.app_name}-mlflow-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MLflow UI"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-mlflow-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "mlflow_db" {
  name_prefix = "${var.app_name}-mlflow-db-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.mlflow.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-mlflow-db-sg"
    Environment = var.environment
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "mlflow" {
  name        = "${var.app_name}-mlflow-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.app_name}-mlflow-tg"
    Environment = var.environment
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "mlflow" {
  load_balancer_arn = var.load_balancer_arn
  port              = "5000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mlflow.arn
  }

  tags = {
    Name        = "${var.app_name}-mlflow-listener"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "mlflow" {
  name              = "/ecs/${var.app_name}-mlflow"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-mlflow-logs"
    Environment = var.environment
  }
}