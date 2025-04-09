# Лабораторна робота №4

## AWS Lambda та EventBridge для автоматичного управління EC2 інстансами

### Завдання

1. Створити Lambda функцію
2. Мова програмування на вибір
3. Функція повинна запускатися за розкладом EventBridge (раз на хвилину)
4. Lambda повинна завершувати всі EC2 інстанси без захисту від видалення в вашому акаунті
5. Написати Terraform код для розгортання цієї функції

### Хід роботи

#### 1. Створення Lambda функції

Створено Lambda функцію на мові Python, яка використовує boto3 AWS SDK для виконання наступних дій:
- Пошук всіх запущених EC2 інстансів
- Перевірка кожного інстансу на наявність захисту від видалення
- Завершення роботи всіх інстансів без захисту

Код Lambda функції:
```python
import boto3

def lambda_handler(event, context):
    # Ініціалізація клієнта EC2
    ec2 = boto3.client('ec2')
    
    # Отримання списку всіх запущених інстансів
    instances = ec2.describe_instances(
        Filters=[
            {
                'Name': 'instance-state-name',
                'Values': ['running']
            }
        ]
    )
    
    instances_to_terminate = []
    
    # Перевірка кожного інстансу на захист від видалення
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            
            # Перевірка атрибуту захисту від видалення
            attributes = ec2.describe_instance_attribute(
                InstanceId=instance_id,
                Attribute='disableApiTermination'
            )
            
            # Якщо захист від видалення вимкнено, додати інстанс до списку для завершення
            if not attributes['DisableApiTermination']['Value']:
                instances_to_terminate.append(instance_id)
    
    # Завершення роботи інстансів без захисту
    if instances_to_terminate:
        ec2.terminate_instances(InstanceIds=instances_to_terminate)
        
    return {
        'statusCode': 200,
        'body': f'Завершено роботу {len(instances_to_terminate)} інстансів: {instances_to_terminate}'
    }
```

#### 2. Створення Terraform конфігурації

Розроблено Terraform код для:
- Створення IAM ролі з необхідними дозволами для Lambda функції
- Розгортання Lambda функції з кодом Python
- Налаштування EventBridge правила для запуску Lambda за розкладом (раз на хвилину)
- Встановлення дозволів для EventBridge на виклик Lambda функції

Основні компоненти Terraform коду:

```hcl
# IAM роль для Lambda
resource "aws_iam_role" "lambda_role" {
  name = "ec2_terminator_lambda_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Політика доступу до EC2
resource "aws_iam_policy" "lambda_ec2_policy" {
  name        = "ec2_terminator_policy"
  description = "Allows Lambda to terminate EC2 instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:TerminateInstances"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Прикріплення політики до ролі
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ec2_policy.arn
}

# Lambda функція
resource "aws_lambda_function" "ec2_terminator" {
  filename      = "lambda_function.zip"
  function_name = "ec2_terminator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  
  # Архівація коду
  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}

# EventBridge правило для запуску Lambda раз на хвилину
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "every-minute"
  description         = "Fires every minute"
  schedule_expression = "rate(1 minute)"
}

# Налаштування цілі для правила - Lambda функції
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "ec2_terminator"
  arn       = aws_lambda_function.ec2_terminator.arn
}

# Дозвіл для EventBridge викликати Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_terminator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}
```

#### 3. Тестування функціональності

1. Розгорнуто інфраструктуру за допомогою Terraform:
   ```bash
   terraform init
   terraform apply
   ```

2. Перевірено роботу Lambda функції:
   - Створено тестові EC2 інстанси без захисту від видалення
   - Створено контрольний інстанс із захистом від видалення
   - Спостерігали за автоматичним завершенням інстансів без захисту
   - Підтверджено збереження інстансів із захистом

### Результати

Успішно створено та розгорнуто автоматизовану систему, яка:
- Сканує EC2 інстанси кожну хвилину
- Виявляє інстанси без захисту від видалення
- Автоматично завершує їх роботу
- Не впливає на інстанси з увімкненим захистом

Система дозволяє підтримувати чистоту AWS акаунту, автоматично видаляючи незахищені інстанси та заощаджуючи кошти.

### Висновки

У процесі виконання лабораторної роботи:
1. Розширено знання про serverless-архітектуру в AWS з використанням Lambda
2. Освоєно роботу з EventBridge для налаштування розкладу виконання функцій
3. Набуто досвіду автоматизації управління ресурсами AWS
4. Прикладено принципи інфраструктури як код (IaC) з використанням Terraform
5. Реалізовано практичне вирішення задачі оптимізації витрат у хмарному середовищі 