# 🚀 AWS ECS Automated Deployment Pipeline

A production-ready CI/CD pipeline for deploying containerized applications to AWS ECS using GitHub Actions, Terraform, and modern DevOps best practices.

[![CI/CD Pipeline](https://github.com/tobiakinlade/attendance-app/actions/workflows/deploy.yml/badge.svg)](https://github.com/tobiakinlade/attendance-app/actions/workflows/deploy.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.6.0-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS-orange.svg)](https://aws.amazon.com/ecs/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![CI/CD Pipeline](docs/architecture-diagram.png)

## 📋 Overview

This project demonstrates a complete infrastructure-as-code and continuous deployment solution for a Flask attendance application running on AWS ECS Fargate. It showcases enterprise-grade practices including zero-downtime deployments, automated testing, security scanning, and infrastructure automation.

## ✨ Features

- 🔄 **Automated CI/CD Pipeline** - Push to `main` triggers automatic deployment
- 🧪 **Quality Assurance** - Automated linting, testing, and code coverage
- 🔒 **Security First** - Trivy vulnerability scanning + AWS OIDC authentication (no access keys!)
- 🐳 **Container Orchestration** - ECS Fargate with Application Load Balancer
- 🏗️ **Infrastructure as Code** - Complete AWS infrastructure managed with Terraform
- ⏪ **One-Click Rollback** - Quick recovery to previous stable versions
- 📊 **Deployment Summaries** - Real-time status and metrics in GitHub Actions
- 🌐 **Zero Downtime** - Blue-green deployments with health checks

## 🏗️ Architecture

### Infrastructure Components
- **Compute**: AWS ECS Fargate
- **Networking**: VPC with public/private subnets across 2 AZs
- **Load Balancing**: Application Load Balancer with SSL/TLS
- **Database**: RDS PostgreSQL
- **Container Registry**: Amazon ECR
- **DNS**: Route53 (optional)
- **Monitoring**: CloudWatch Logs & Metrics

### CI/CD Pipeline Stages
1. **Test** → Flake8, Pytest, Coverage
2. **Security Scan** → Trivy vulnerability detection  
3. **Build** → Docker image with commit SHA tagging
4. **Deploy** → ECS service update with health checks

## 📦 Prerequisites

- AWS Account with appropriate permissions
- GitHub Account
- Terraform >= 1.6.0
- AWS CLI configured
- Domain name (optional, for Route53)

**Required Tools:**
```bash
terraform --version  # >= 1.6.0
aws --version        # >= 2.x
git --version        # >= 2.x
```

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/tobiakinlade/attendance-app.git
cd attendance-app
```

### 2. Set Up AWS OIDC Authentication

Create OIDC Identity Provider:
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create IAM Role:
```bash
# Create trust policy
cat > github-oidc-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/attendance-app:*"
      }
    }
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name GitHubActionsECSDeployRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json
```

Attach permissions policy (see [docs/iam-policies.md](docs/iam-policies.md))

### 3. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::123456789:role/GitHubActionsECSDeployRole` |
| `AWS_REGION` | AWS region | `eu-west-2` |
| `ECR_REPOSITORY` | ECR repository name | `attendance-app-dev` |
| `ECS_CLUSTER` | ECS cluster name | `attendance-app-dev-cluster` |
| `ECS_SERVICE` | ECS service name | `attendance-app-dev-service` |
| `CONTAINER_NAME` | Container name | `attendance-app-container` |
| `DB_USERNAME` | Database username | `dbadmin` |
| `DB_PASSWORD` | Database password | `YourSecurePassword123!` |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state | `attendance-app-s3-backend` |

### 4. Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init \
  -backend-config="bucket=attendance-app-s3-backend" \
  -backend-config="key=attendance-app/terraform.tfstate" \
  -backend-config="region=eu-west-2"

# Review changes
terraform plan \
  -var="environment=dev" \
  -var="project_name=attendance-app" \
  -var="db_username=dbadmin" \
  -var="db_password=YourSecurePassword123!"

# Apply infrastructure
terraform apply -auto-approve
```

### 5. Deploy Application

Push to `main` branch to trigger automatic deployment:
```bash
git checkout -b feature/initial-deployment
git add .
git commit -m "Initial deployment"
git push origin feature/initial-deployment

# Create PR and merge to main
# Pipeline will automatically deploy!
```

## 📁 Project Structure
```
attendance-app/
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Main CI/CD pipeline
│       ├── rollback.yml            # Rollback workflow
│       ├── terraform-apply.yml     # Infrastructure deployment
│       └── terraform-destroy.yml   # Infrastructure teardown
├── app/
│   ├── templates/                  # Flask HTML templates
│   ├── static/                     # CSS, JS, images
│   ├── __init__.py
│   ├── models.py                   # Database models
│   ├── routes.py                   # Application routes
│   └── config.py                   # App configuration
├── terraform/
│   ├── main.tf                     # Main infrastructure
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── vpc.tf                      # VPC configuration
│   ├── ecs.tf                      # ECS cluster & services
│   ├── alb.tf                      # Load balancer
│   ├── rds.tf                      # Database
│   └── ecr.tf                      # Container registry
├── tests/
│   └── test_app.py                 # Unit tests
├── Dockerfile                       # Container definition
├── requirements.txt                 # Python dependencies
├── docker-compose.yml              # Local development
└── README.md                        # This file
```

## 🔄 CI/CD Workflows

### Main Deployment Pipeline
**Trigger:** Push to `main` branch  
**File:** `.github/workflows/deploy.yml`

**Stages:**
1. **Test** - Linting with Flake8, unit tests with Pytest
2. **Security Scan** - Trivy vulnerability scanning
3. **Build & Deploy** - Docker build, ECR push, ECS deployment

### Rollback Workflow
**Trigger:** Manual via GitHub Actions UI  
**File:** `.github/workflows/rollback.yml`

**Usage:**
1. Go to **Actions → Rollback Deployment**
2. Click **Run workflow**
3. Enter task definition revision number
4. Confirm rollback

### Terraform Workflows
**Apply:** `.github/workflows/terraform-apply.yml`  
**Destroy:** `.github/workflows/terraform-destroy.yml`

## 🎯 Usage

### Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
python -m flask run

# Or use Docker Compose
docker-compose up
```

### Access the Application

After deployment, get the URL:
```bash
terraform output app_url
# or
terraform output alb_dns_name
```

### View Logs
```bash
# ECS logs
aws logs tail /ecs/attendance-app-dev --follow

# Deployment logs
# Check GitHub Actions tab in your repository
```

### Manual Deployment

Force a new deployment without code changes:
```bash
aws ecs update-service \
  --cluster attendance-app-dev-cluster \
  --service attendance-app-dev-service \
  --force-new-deployment
```

## ⏪ Rollback Procedures

### Via GitHub Actions (Recommended)
1. Navigate to **Actions** tab
2. Select **Rollback Deployment** workflow
3. Click **Run workflow**
4. Enter previous task revision (e.g., `18`)
5. Confirm

### Via AWS CLI
```bash
# List task definitions
aws ecs list-task-definitions \
  --family-prefix attendance-app-dev \
  --sort DESC

# Rollback to specific revision
aws ecs update-service \
  --cluster attendance-app-dev-cluster \
  --service attendance-app-dev-service \
  --task-definition attendance-app-dev:18 \
  --force-new-deployment
```

## 🔧 Configuration

### Environment Variables

Configure in ECS Task Definition or `.env`:
```bash
FLASK_APP=app
FLASK_ENV=production
DATABASE_URL=postgresql://user:pass@host:5432/db
SECRET_KEY=your-secret-key
```

### Terraform Variables

Edit `terraform/terraform.tfvars`:
```hcl
environment         = "dev"
project_name        = "attendance-app"
domain_name         = "yourdomain.com"
route53_zone_name   = "yourdomain.com"
create_route53_record = true
```

## 🐛 Troubleshooting

### Pipeline Fails at Test Stage
```bash
# Run tests locally
pytest tests/ -v --cov=app

# Check linting
flake8 app --count --show-source --statistics
```

### Deployment Fails
```bash
# Check ECS service events
aws ecs describe-services \
  --cluster attendance-app-dev-cluster \
  --services attendance-app-dev-service \
  --query 'services[0].events[:5]'

# Check task logs
aws logs tail /ecs/attendance-app-dev --follow
```

### Container Won't Start
```bash
# Check task definition
aws ecs describe-task-definition \
  --task-definition attendance-app-dev \
  --query 'taskDefinition.containerDefinitions[0]'

# Test locally
docker build -t test .
docker run -p 5000:5000 test
```

### Database Connection Issues
```bash
# Verify RDS endpoint
terraform output rds_endpoint

# Test connection from ECS task
aws ecs execute-command \
  --cluster attendance-app-dev-cluster \
  --task TASK_ID \
  --container attendance-app-container \
  --interactive \
  --command "/bin/sh"
```



> **Tip:** Use `terraform destroy` when not in use to avoid costs.

## 📚 Documentation

- [Part 1: Infrastructure as Code with Terraform](https://medium.com/@yourhandle/part1)
- [Part 2: CI/CD Pipeline with GitHub Actions](https://medium.com/@yourhandle/part2)
- [Part 3: Advanced Monitoring (Coming Soon)](https://medium.com/@yourhandle/part3)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 👤 Author

**Tobi Akinlade**

- LinkedIn: [linkedin.com/in/tobiakinlade](https://linkedin.com/in/tobiakinlade)
- Medium: [@tobiakinlade](https://medium.com/@tobiakinlade)
- GitHub: [@tobiakinlade](https://github.com/tobiakinlade)

## 🙏 Acknowledgments

- AWS for comprehensive documentation
- GitHub Actions community
- HashiCorp for Terraform
- The DevOps community

## 📞 Support

If you encounter issues:
1. Check [Troubleshooting](#-troubleshooting) section
2. Search [existing issues](https://github.com/tobiakinlade/attendance-app/issues)
3. Create a [new issue](https://github.com/tobiakinlade/attendance-app/issues/new)

---

⭐ **Star this repo** if you find it helpful!

🚀 **Happy Deploying!**
