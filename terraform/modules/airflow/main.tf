# Airflow Webserver
resource "aws_ecs_service" "airflow_webserver" {
  name            = "${var.app_name}-airflow-webserver"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_webserver.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.airflow.id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.airflow.arn
    container_name   = "airflow-webserver"
    container_port   = 8080
  }

  depends_on = [aws_ecs_service.airflow_scheduler]

  tags = {
    Name        = "${var.app_name}-airflow-webserver-service"
    Environment = var.environment
  }
}

# Airflow Scheduler
resource "aws_ecs_service" "airflow_scheduler" {
  name            = "${var.app_name}-airflow-scheduler"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_scheduler.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.airflow.id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  tags = {
    Name        = "${var.app_name}-airflow-scheduler-service"
    Environment = var.environment
  }
}

# Airflow Worker
resource "aws_ecs_service" "airflow_worker" {
  name            = "${var.app_name}-airflow-worker"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.airflow_worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.airflow.id]
    subnets          = var.public_subnet_ids
    assign_public_ip = true
  }

  tags = {
    Name        = "${var.app_name}-airflow-worker-service"
    Environment = var.environment
  }
}

# Airflow Webserver Task Definition
resource "aws_ecs_task_definition" "airflow_webserver" {
  family                   = "${var.app_name}-airflow-webserver"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn           = aws_iam_role.airflow_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-webserver"
      image = "apache/airflow:2.7.0"
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      command = ["webserver"]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "CeleryExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__RESULT_BACKEND"
          value = "db+postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__BROKER_URL"
          value = "redis://${aws_elasticache_cluster.airflow.cache_nodes[0].address}:6379/0"
        },
        {
          name  = "AIRFLOW__CORE__FERNET_KEY"
          value = var.airflow_fernet_key
        },
        {
          name  = "AIRFLOW__WEBSERVER__SECRET_KEY"
          value = var.airflow_secret_key
        },
        {
          name  = "AIRFLOW__CORE__DAGS_FOLDER"
          value = "/opt/airflow/dags"
        },
        {
          name  = "MLFLOW_TRACKING_URI"
          value = var.mlflow_tracking_uri
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "webserver"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.app_name}-airflow-webserver-task"
    Environment = var.environment
  }
}

# Airflow Scheduler Task Definition
resource "aws_ecs_task_definition" "airflow_scheduler" {
  family                   = "${var.app_name}-airflow-scheduler"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn           = aws_iam_role.airflow_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-scheduler"
      image = "apache/airflow:2.7.0"

      command = ["scheduler"]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "CeleryExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__RESULT_BACKEND"
          value = "db+postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__BROKER_URL"
          value = "redis://${aws_elasticache_cluster.airflow.cache_nodes[0].address}:6379/0"
        },
        {
          name  = "AIRFLOW__CORE__FERNET_KEY"
          value = var.airflow_fernet_key
        },
        {
          name  = "AIRFLOW__CORE__DAGS_FOLDER"
          value = "/opt/airflow/dags"
        },
        {
          name  = "MLFLOW_TRACKING_URI"
          value = var.mlflow_tracking_uri
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "scheduler"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.app_name}-airflow-scheduler-task"
    Environment = var.environment
  }
}

# Airflow Worker Task Definition
resource "aws_ecs_task_definition" "airflow_worker" {
  family                   = "${var.app_name}-airflow-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn           = aws_iam_role.airflow_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "airflow-worker"
      image = "apache/airflow:2.7.0"

      command = ["celery", "worker"]

      environment = [
        {
          name  = "AIRFLOW__CORE__EXECUTOR"
          value = "CeleryExecutor"
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__RESULT_BACKEND"
          value = "db+postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.airflow.endpoint}:5432/airflow"
        },
        {
          name  = "AIRFLOW__CELERY__BROKER_URL"
          value = "redis://${aws_elasticache_cluster.airflow.cache_nodes[0].address}:6379/0"
        },
        {
          name  = "AIRFLOW__CORE__FERNET_KEY"
          value = var.airflow_fernet_key
        },
        {
          name  = "AIRFLOW__CORE__DAGS_FOLDER"
          value = "/opt/airflow/dags"
        },
        {
          name  = "MLFLOW_TRACKING_URI"
          value = var.mlflow_tracking_uri
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.airflow.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "worker"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.app_name}-airflow-worker-task"
    Environment = var.environment
  }
}

# RDS PostgreSQL for Airflow metadata
resource "aws_db_instance" "airflow" {
  identifier     = "${var.app_name}-airflow-db"
  engine         = "postgres"
  engine_version = "13.13"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "airflow"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.airflow_db.id]
  db_subnet_group_name   = aws_db_subnet_group.airflow.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.app_name}-airflow-db"
    Environment = var.environment
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "airflow" {
  name       = "${var.app_name}-airflow-db-subnet-group"
  subnet_ids = var.public_subnet_ids

  tags = {
    Name        = "${var.app_name}-airflow-db-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Redis for Celery broker
resource "aws_elasticache_cluster" "airflow" {
  cluster_id           = "${var.app_name}-airflow-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.airflow.name
  security_group_ids   = [aws_security_group.airflow_redis.id]

  tags = {
    Name        = "${var.app_name}-airflow-redis"
    Environment = var.environment
  }
}

resource "aws_elasticache_subnet_group" "airflow" {
  name       = "${var.app_name}-airflow-cache-subnet"
  subnet_ids = var.public_subnet_ids
}

# IAM Role for Airflow Tasks
resource "aws_iam_role" "airflow_task_role" {
  name = "${var.app_name}-airflow-task-role"

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
    Name        = "${var.app_name}-airflow-task-role"
    Environment = var.environment
  }
}

# IAM Policy for S3 and ECS access
resource "aws_iam_role_policy" "airflow_policy" {
  name = "${var.app_name}-airflow-policy"
  role = aws_iam_role.airflow_task_role.id

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
          var.mlflow_s3_bucket_arn,
          "${var.mlflow_s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Security Groups
resource "aws_security_group" "airflow" {
  name_prefix = "${var.app_name}-airflow-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Airflow UI"
    from_port       = 8080
    to_port         = 8080
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
    Name        = "${var.app_name}-airflow-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "airflow_db" {
  name_prefix = "${var.app_name}-airflow-db-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.airflow.id]
  }

  tags = {
    Name        = "${var.app_name}-airflow-db-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "airflow_redis" {
  name_prefix = "${var.app_name}-airflow-redis-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.airflow.id]
  }

  tags = {
    Name        = "${var.app_name}-airflow-redis-sg"
    Environment = var.environment
  }
}

# Target Group and Listener
resource "aws_lb_target_group" "airflow" {
  name        = "${var.app_name}-airflow-tg"
  port        = 8080
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
    Name        = "${var.app_name}-airflow-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "airflow" {
  load_balancer_arn = var.load_balancer_arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }

  tags = {
    Name        = "${var.app_name}-airflow-listener"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "airflow" {
  name              = "/ecs/${var.app_name}-airflow"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-airflow-logs"
    Environment = var.environment
  }
}