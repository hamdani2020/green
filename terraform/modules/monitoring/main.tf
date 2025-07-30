# ECS Service for Prometheus
resource "aws_ecs_service" "prometheus" {
  name            = "${var.app_name}-prometheus"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.monitoring.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  tags = {
    Name        = "${var.app_name}-prometheus-service"
    Environment = var.environment
  }
}

# ECS Service for Grafana
resource "aws_ecs_service" "grafana" {
  name            = "${var.app_name}-grafana"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.monitoring.id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  tags = {
    Name        = "${var.app_name}-grafana-service"
    Environment = var.environment
  }
}

# Prometheus Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.app_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus/",
        "--web.console.libraries=/etc/prometheus/console_libraries",
        "--web.console.templates=/etc/prometheus/consoles",
        "--storage.tsdb.retention.time=24h",
        "--web.enable-lifecycle"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.monitoring.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "prometheus"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.app_name}-prometheus-task"
    Environment = var.environment
  }
}

# Grafana Task Definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.app_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_admin_password
        },
        {
          name  = "GF_INSTALL_PLUGINS"
          value = "grafana-clock-panel,grafana-simple-json-datasource"
        }
      ]



      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.monitoring.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "grafana"
        }
      }

      essential = true
    }
  ])



  tags = {
    Name        = "${var.app_name}-grafana-task"
    Environment = var.environment
  }
}

# Security Group for Monitoring Services
resource "aws_security_group" "monitoring" {
  name_prefix = "${var.app_name}-monitoring-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Prometheus"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "Grafana"
    from_port       = 3000
    to_port         = 3000
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
    Name        = "${var.app_name}-monitoring-sg"
    Environment = var.environment
  }
}

# Target Groups for Load Balancer
resource "aws_lb_target_group" "prometheus" {
  name        = "${var.app_name}-prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/-/healthy"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.app_name}-prometheus-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.app_name}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.app_name}-grafana-tg"
    Environment = var.environment
  }
}

# Load Balancer Listeners
resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = var.load_balancer_arn
  port              = "9090"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }

  tags = {
    Name        = "${var.app_name}-prometheus-listener"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = var.load_balancer_arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  tags = {
    Name        = "${var.app_name}-grafana-listener"
    Environment = var.environment
  }
}



# CloudWatch Log Group for Monitoring
resource "aws_cloudwatch_log_group" "monitoring" {
  name              = "/ecs/${var.app_name}-monitoring"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-monitoring-logs"
    Environment = var.environment
  }
}
