provider "aws" {
  region = "us-east-1"
}

# === ECR Repository ===
resource "aws_ecr_repository" "tomcat_app" {
  name                 = "tomcat-app"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# === ECS Cluster ===
resource "aws_ecs_cluster" "tomcat_cluster" {
  name = "tomcat-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# === Security Group ===
resource "aws_security_group" "ecs_sg" {
  name_prefix = "tomcat-sg-"
  description = "Security group for Tomcat ECS service"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Tomcat traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "tomcat-ecs-sg"
  }
}

# === IAM Role для ECS Task Execution ===
resource "aws_iam_role" "ecs_execution_role" {
  name = "tomcat_ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

# === CloudWatch Log Group ===
resource "aws_cloudwatch_log_group" "tomcat_logs" {
  name              = "/ecs/tomcat-task"
  retention_in_days = 30
}

# === Task Definition ===
resource "aws_ecs_task_definition" "tomcat_task" {
  family                   = "tomcat-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "tomcat"
      image     = "${aws_ecr_repository.tomcat_app.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.tomcat_logs.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# === ALB ===
resource "aws_lb" "tomcat_alb" {
  name               = "tomcat-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = data.aws_subnets.default.ids
  
  tags = {
    Name = "tomcat-alb"
  }
}

resource "aws_lb_target_group" "tomcat_tg" {
  name        = "tomcat-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  
  tags = {
    Name = "tomcat-target-group"
  }
}

# === ALB Listeners ===
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.tomcat_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
  }
}

# === ECS Service ===
resource "aws_ecs_service" "tomcat_service" {
  name            = "tomcat-service"
  cluster         = aws_ecs_cluster.tomcat_cluster.id
  task_definition = aws_ecs_task_definition.tomcat_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
    container_name   = "tomcat"
    container_port   = 8080
  }
  
  depends_on = [aws_lb_listener.http_listener]
}

# === Route53 A Record ===
resource "aws_route53_record" "tomcat_dns" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "tomcat.olegivanuik.pp.ua"
  type    = "A"

  alias {
    name                   = aws_lb.tomcat_alb.dns_name
    zone_id                = aws_lb.tomcat_alb.zone_id
    evaluate_target_health = true
  }
}

# === Data Sources ===
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_route53_zone" "selected" {
  name = "olegivanuik.pp.ua."
}

# === Outputs ===
output "ecr_repository_url" {
  value       = aws_ecr_repository.tomcat_app.repository_url
  description = "The URL of the ECR repository"
}

output "alb_dns_name" {
  value       = aws_lb.tomcat_alb.dns_name
  description = "The DNS name of the ALB"
}

output "tomcat_url" {
  value       = "http://tomcat.olegivanuik.pp.ua" # Replace with your actual domain
  description = "The URL to access the Tomcat application"
}
