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

# Завантаження образу Tomcat з Docker Hub
echo "Завантаження образу tomcat:9.0-jre11 з Docker Hub..."
docker pull tomcat:9.0-jre11

# Перейменування образу для ECR
echo "Перейменування образу для ECR..."
docker tag tomcat:9.0-jre11 ${ECR_REPO_URI}:latest

# Завантаження образу в ECR
echo "Завантаження образу в ECR..."
docker push ${ECR_REPO_URI}:latest

echo "Готово! Образ tomcat:9.0-jre11 успішно завантажено в ECR репозиторій ${ECR_REPO_NAME}" 