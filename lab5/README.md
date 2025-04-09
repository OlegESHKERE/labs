# Лабораторна робота №5

## Розгортання контейнерної інфраструктури в AWS за допомогою Terraform

### Завдання

1. Створити ECR репозиторій "tomcat-app"
2. Завантажити образ tomcat:9.0-jre11 в ECR
3. Створити ECS кластер "tomcat-cluster" (тип FarGate)
4. Створити Task Definition для tomcat сервера
5. Створити Service на порту 8080 для tomcat
6. Застосувати DNS доменне ім'я
7. Відкрити доступ до tomcat сервера з інтернету на порту 80

### Хід роботи

#### 1. Архітектура інфраструктури

Розгорнута інфраструктура складається з наступних компонентів:
- **ECR (Elastic Container Registry)**: приватний репозиторій Docker образів
- **ECS (Elastic Container Service)**: оркестратор контейнерів
- **Fargate**: serverless обчислювальний рушій для контейнерів
- **ALB (Application Load Balancer)**: балансувальник навантаження
- **Route53**: DNS сервіс для маршрутизації запитів

#### 2. Опис Terraform коду

Terraform конфігурація організована наступним чином:

##### ECR репозиторій
```hcl
resource "aws_ecr_repository" "tomcat_app" {
  name                 = "tomcat-app"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

##### ECS кластер
```hcl
resource "aws_ecs_cluster" "tomcat_cluster" {
  name = "tomcat-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

##### Task Definition
```hcl
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
          "awslogs-group"         = "/ecs/tomcat-task"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
```

##### ECS Service
```hcl
resource "aws_ecs_service" "tomcat_service" {
  name            = "tomcat-service"
  cluster         = aws_ecs_cluster.tomcat_cluster.id
  task_definition = aws_ecs_task_definition.tomcat_task.arn
  launch_type     = "FARGATE"
  desired_count   = 2
  
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tomcat_sg.id]
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
    container_name   = "tomcat"
    container_port   = 8080
  }
}
```

##### Load Balancer
```hcl
resource "aws_lb" "tomcat_alb" {
  name               = "tomcat-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.tomcat_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat_tg.arn
  }
}
```

##### DNS налаштування
```hcl
resource "aws_route53_record" "tomcat_dns" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  
  alias {
    name                   = aws_lb.tomcat_alb.dns_name
    zone_id                = aws_lb.tomcat_alb.zone_id
    evaluate_target_health = true
  }
}
```

#### 3. Процес розгортання

1. **Підготовка Terraform налаштувань**:
   - Клонувати репозиторій з кодом
   - Налаштувати змінні в `terraform.tfvars`

2. **Ініціалізація Terraform**:
   ```bash
   terraform init
   ```

3. **Планування та застосування інфраструктури**:
   ```bash
   terraform plan
   terraform apply
   ```

4. **Завантаження Docker образу**:
   ```bash
   # Отримання токена авторизації
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}

   # Завантаження образу з Docker Hub
   docker pull tomcat:9.0-jre11

   # Перейменування з тегом ECR репозиторію
   docker tag tomcat:9.0-jre11 ${ECR_REPOSITORY_URL}:latest

   # Завантаження в ECR
   docker push ${ECR_REPOSITORY_URL}:latest
   ```

#### 4. Перевірка розгортання

1. Перевірити працездатність Tomcat серверу через доменне ім'я:
   ```
   http://your-domain-name/
   ```

2. Перевірити логи сервісу ECS через AWS Management Console або AWS CLI.

### Результати

Розгорнуто повністю автоматизовану контейнерну інфраструктуру, яка включає:
- Приватний репозиторій для Docker образів
- Кластер контейнерів з автоматичним масштабуванням
- Безсерверне оточення без необхідності управління EC2 інстансами
- Балансування навантаження між контейнерами
- Публічний доступ через доменне ім'я

### Висновки

Під час виконання лабораторної роботи:
1. Освоєно розгортання контейнерної інфраструктури AWS за допомогою Terraform
2. Отримано практичні навички роботи з ECR, ECS та Fargate
3. Вивчено принципи налаштування взаємодії між контейнерними сервісами AWS
4. Реалізовано повний конвеєр розгортання від Docker образу до публічно доступного сервісу з доменним ім'ям 