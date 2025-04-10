provider "aws" {
  region = "us-east-1"
}

# Find latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# SNS Topic
resource "aws_sns_topic" "cpu_alarm_topic" {
  name = "cpu_alarm_topic_lab3"
}

# SNS Subscription (e-mail)
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.cpu_alarm_topic.arn
  protocol  = "email"
  endpoint  = "xjp72248@bcooq.com"
}

# IAM Role для CloudWatch Agent (необов'язково, якщо CPU метрики збираються автоматично)
resource "aws_iam_role" "lab3_role" {
  name = "lab3-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy_attachment" "cloudwatch_attach" {
  name       = "lab3-attach-cloudwatch"
  roles      = [aws_iam_role.lab3_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "lab3_profile" {
  name = "lab3-instance-profile"
  role = aws_iam_role.lab3_role.name
}

# Update EC2 to use profile
resource "aws_instance" "lab3" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t2.micro"
  key_name             = "test"
  iam_instance_profile = aws_iam_instance_profile.lab3_profile.name

  tags = {
    Name = "lab3"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y stress
              EOF
}

# CloudWatch Alarm - CPU > 50%
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "CPU-High-Lab3"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 50

  dimensions = {
    InstanceId = aws_instance.lab3.id
  }

  alarm_actions = [aws_sns_topic.cpu_alarm_topic.arn]
  ok_actions    = [aws_sns_topic.cpu_alarm_topic.arn]
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-olegivanuik-labs-2025"
    key            = "lab3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}

