#!/bin/bash

# Встановлення змінних
AWS_REGION="us-east-1"
ECR_REPO_NAME="tomcat-app"

# Отримання URL репозиторію ECR
ECR_REPO_URI=$(aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} --query 'repositories[0].repositoryUri' --output text)

if [ -z "$ECR_REPO_URI" ]; then
    echo "Помилка: Не вдалося отримати URI репозиторію ECR."
    exit 1
fi

echo "ECR репозиторій URI: ${ECR_REPO_URI}"

# Отримання токена авторизації та авторизація в ECR
echo "Авторизація в ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_URI}

# Перехід до директорії, де знаходиться Dockerfile
cd "$(dirname "$0")"

# Збірка Docker образу з Dockerfile
echo "Збірка Docker образу з Dockerfile..."
docker build -t tomcat-custom .

# Перейменування образу для ECR
echo "Перейменування образу для ECR..."
docker tag tomcat-custom ${ECR_REPO_URI}:latest

# Завантаження образу в ECR
echo "Завантаження образу в ECR..."
docker push ${ECR_REPO_URI}:latest

echo "Готово! Власний образ Tomcat успішно збудовано та завантажено в ECR репозиторій ${ECR_REPO_NAME}" 