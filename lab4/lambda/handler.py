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
        print(f"Terminated instances: {instances_to_terminate}")
    else:
        print("No instances to terminate")
        
    return {
        'statusCode': 200,
        'body': f'Завершено роботу {len(instances_to_terminate)} інстансів: {instances_to_terminate}'
    }
