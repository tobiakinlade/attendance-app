#!/bin/bash
# import-resources.sh

cd terraform

echo "🔄 Importing existing AWS resources into Terraform state..."
echo ""

# VPC
echo "Importing VPC..."
terraform import aws_vpc.main vpc-0fb44cd87b386c446

# Internet Gateway
echo "Importing Internet Gateway..."
terraform import aws_internet_gateway.main igw-07c3fc0c241ba9d86

# Subnets
echo "Importing Subnets..."
terraform import 'aws_subnet.public[0]' subnet-0601685bb302d05c5
terraform import 'aws_subnet.public[1]' subnet-0f18224ca573dd613
terraform import 'aws_subnet.private_app[0]' subnet-03f65b0de4ead35b0
terraform import 'aws_subnet.private_app[1]' subnet-033b86dc6bedc61a8
terraform import 'aws_subnet.private_db[0]' subnet-053a5ded5721073e0
terraform import 'aws_subnet.private_db[1]' subnet-0ea8a4544cb8fbd82

# EIP and NAT Gateway
echo "Importing NAT Gateway..."
terraform import aws_eip.nat eipalloc-0734a01c4ff681883
terraform import aws_nat_gateway.main nat-04ae25b3e1a937941

# Route Tables
echo "Importing Route Tables..."
terraform import aws_route_table.public rtb-0a35ef928010f5fcf
terraform import aws_route_table.private rtb-09f89522971091526
terraform import 'aws_route_table_association.public[0]' rtbassoc-01a4ade91249fe83e
terraform import 'aws_route_table_association.public[1]' rtbassoc-08e869de80e6007fb
terraform import 'aws_route_table_association.private_app[0]' rtbassoc-0ce3520466fec3cc4
terraform import 'aws_route_table_association.private_app[1]' rtbassoc-08e9a997f8aa3cd02
terraform import 'aws_route_table_association.private_db[0]' rtbassoc-0fa9bb8f6d0b10e1c
terraform import 'aws_route_table_association.private_db[1]' rtbassoc-082dd99a3c9fc835b

# Security Groups
echo "Importing Security Groups..."
terraform import aws_security_group.alb sg-02d9b7a0f6b9c2330
terraform import aws_security_group.ecs_tasks sg-05abdadc02c0e5ef0
terraform import aws_security_group.rds sg-0706534beb97ad7c8

# ALB
echo "Importing ALB..."
terraform import aws_lb.main arn:aws:elasticloadbalancing:eu-west-2:180048382895:loadbalancer/app/attendance-app-dev-alb/bfa1c22d9e4a0569
terraform import aws_lb_target_group.main arn:aws:elasticloadbalancing:eu-west-2:180048382895:targetgroup/attendance-app-dev-tg/481cc5c8a3fc30e8
terraform import aws_lb_listener.http arn:aws:elasticloadbalancing:eu-west-2:180048382895:listener/app/attendance-app-dev-alb/bfa1c22d9e4a0569/151d4e02e2569ec1
terraform import 'aws_lb_listener.https[0]' arn:aws:elasticloadbalancing:eu-west-2:180048382895:listener/app/attendance-app-dev-alb/bfa1c22d9e4a0569/2329dce02bb53807

# ECR
echo "Importing ECR..."
terraform import aws_ecr_repository.main attendance-app-dev
terraform import aws_ecr_lifecycle_policy.main attendance-app-dev

# ECS
echo "Importing ECS..."
terraform import aws_ecs_cluster.main arn:aws:ecs:eu-west-2:180048382895:cluster/attendance-app-dev-cluster
terraform import aws_ecs_task_definition.main attendance-app-dev
terraform import aws_ecs_service.main arn:aws:ecs:eu-west-2:180048382895:service/attendance-app-dev-cluster/attendance-app-dev-service

# CloudWatch
echo "Importing CloudWatch..."
terraform import aws_cloudwatch_log_group.ecs /ecs/attendance-app-dev
terraform import aws_cloudwatch_dashboard.main attendance-app-dev-dashboard

# IAM
echo "Importing IAM..."
terraform import aws_iam_role.ecs_task_execution attendance-app-dev-ecs-exec-role
terraform import aws_iam_role.ecs_task attendance-app-dev-ecs-task-role
terraform import aws_iam_role_policy_attachment.ecs_task_execution attendance-app-dev-ecs-exec-role/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# RDS
echo "Importing RDS..."
terraform import aws_db_subnet_group.main attendance-app-dev-db-subnet
terraform import aws_db_instance.main db-HFTOQX7PWQSYGAJOIDCR6JVRRE

# ACM
echo "Importing ACM..."
terraform import 'aws_acm_certificate.main[0]' arn:aws:acm:eu-west-2:180048382895:certificate/73ec0d4c-e0c0-4b95-8fa5-d886a4632548
terraform import 'aws_acm_certificate_validation.main[0]' arn:aws:acm:eu-west-2:180048382895:certificate/73ec0d4c-e0c0-4b95-8fa5-d886a4632548

# Route53
echo "Importing Route53..."
terraform import 'aws_route53_record.cert_validation["tech-with-tobi.com"]' Z0263565359IBMRU1XEIY__9279ec20121d56ab48bcc1690e77a1bc.tech-with-tobi.com._CNAME
terraform import 'aws_route53_record.main[0]' Z0263565359IBMRU1XEIY_tech-with-tobi.com_A

echo ""
echo "✅ Import complete!"
echo ""
echo "Now run: terraform plan to verify everything is in sync"

cd ..
