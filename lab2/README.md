# Лабораторна робота №2

## Налаштування Application Load Balancer та Auto Scaling Group

### Завдання

1. Створити Application Load Balancer (ALB)
2. Створити Auto Scaling Group (ASG) з Launch Template:
   - Використати AWS Ubuntu AMI
   - Тип інстансу: t2-micro
   - Userdata: налаштування nginx серверу
   - Параметри ASG: Min size: 1, desired: 2, max: 3
3. Прикріпити ASG як Target Group до ALB
4. Налаштувати SSL/TLS сертифікат на ALB
5. Зареєструвати A-запис в Route53 для ALB
6. Перевірити кластер у браузері

### Хід роботи

#### 1. Створення Application Load Balancer

У AWS Management Console створено Application Load Balancer з наступними параметрами:
- Схема: інтернет-доступний
- Налаштовані порти для HTTP (80) та HTTPS (443)
- Створено відповідні security groups з необхідними правилами доступу

#### 2. Створення Auto Scaling Group з Launch Template

1. Створено Launch Template з такими параметрами:
   - AMI: Ubuntu Server
   - Тип інстансу: t2-micro
   - Security Group: дозвіл вхідного трафіку на порт 80
   - User Data скрипт для автоматичного встановлення та налаштування nginx:
   ```bash
   #!/bin/bash
   apt-get update
   apt-get install -y nginx
   echo "Hello from $(hostname)" > /var/www/html/index.html
   systemctl enable nginx
   systemctl start nginx
   ```

2. На основі шаблону створено Auto Scaling Group:
   - Мінімальна кількість інстансів: 1
   - Бажана кількість: 2
   - Максимальна кількість: 3
   - Налаштовано політики масштабування на основі навантаження CPU

#### 3. Прикріплення ASG до ALB

Створено Target Group та приєднано до неї Auto Scaling Group. Налаштовано health checks для перевірки працездатності інстансів.

#### 4. Налаштування SSL/TLS сертифікату

1. У AWS Certificate Manager створено та валідовано SSL/TLS сертифікат для домену
2. Сертифікат прикріплено до HTTPS listener у ALB
3. Налаштовано перенаправлення HTTP на HTTPS

#### 5. Налаштування Route53

У Route53 створено A-запис, який вказує на DNS-ім'я Application Load Balancer. Налаштовано аліаси для оптимізованої маршрутизації.

#### 6. Перевірка роботи кластеру

Проведено перевірку доступності веб-сервісу через настроєний домен. Підтверджено:
- Успішне з'єднання по HTTPS
- Коректне балансування навантаження між інстансами
- Автоматичне масштабування при зміні навантаження

### Результати

Успішно розгорнуто високодоступний кластер веб-серверів з автоматичним масштабуванням та балансуванням навантаження. Забезпечено безпечне з'єднання через HTTPS та легкодоступне доменне ім'я.

### Висновки

У процесі виконання лабораторної роботи:
1. Освоєно принципи налаштування та взаємодії AWS ALB та ASG
2. Отримано практичні навички створення шаблонів запуску EC2 інстансів
3. Набуто досвіду з налаштування балансування навантаження та автоматичного масштабування
4. Продемонстровано інтеграцію різних сервісів AWS (EC2, ALB, ASG, Certificate Manager, Route53) для створення надійної інфраструктури 