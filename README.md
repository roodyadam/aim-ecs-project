# Aim ECS Deployment Project

A production-ready infrastructure-as-code project for deploying [Aim](https://github.com/aimhubio/aim) (an open-source ML experiment tracking tool) on AWS ECS using Terraform and GitHub Actions CI/CD.

## 🏗️ Architecture Diagram

![AWS Architecture Diagram](docs/Screenshot 2025-11-20 at 9.19.35 PM.png)

*Architecture diagram showing the complete AWS infrastructure setup for the Aim application deployment on ECS Fargate.*

## 📋 Description of the Project

This project provides a complete infrastructure setup for running Aim on AWS Elastic Container Service (ECS) with:

- **Infrastructure as Code**: Modular Terraform configuration for AWS resources
- **CI/CD Pipeline**: Automated deployment via GitHub Actions
- **Containerized Application**: Docker-based deployment of Aim
- **Production-Ready**: Load balancing, SSL/TLS, high availability, and security best practices
- **Scalable Architecture**: ECS Fargate with auto-scaling capabilities

### Key Features

- 🚀 **Automated Deployments**: Push to main branch triggers automatic deployment
- 🔒 **Secure**: HTTPS with ACM certificates, private subnets, security groups
- 📊 **Monitoring**: CloudWatch logs and Container Insights enabled
- 🔄 **CI/CD**: GitHub Actions with OIDC authentication
- 🏗️ **Modular Design**: Reusable Terraform modules for VPC, ECS, ALB, ECR, Route53, IAM
- 🛡️ **Security Scanning**: Trivy and TfSec security scans in pipeline

## 🎬 Demo of the Application

### Live Application
- **URL**: https://tm.roodyadamsapp.com
- **Status**: Production deployment on AWS ECS

### What is Aim?
Aim is an open-source, self-hostable experiment tracking tool for machine learning. It provides:
- Experiment tracking and visualization
- Metrics, parameters, and artifacts logging
- Web-based UI for exploring experiments
- Integration with popular ML frameworks (PyTorch, TensorFlow, Keras, etc.)

### Application Features
- Track ML experiments and runs
- Visualize metrics and compare runs
- Search and filter experiments
- Store artifacts and model checkpoints
- Real-time experiment monitoring

## 🏗️ Architecture Diagram

The infrastructure follows AWS best practices with a multi-tier architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    AWS Cloud (eu-west-2)                │
│                                                          │
│  ┌─────────────┐                                        │
│  │  Route53    │ (DNS Resolution)                       │
│  └──────┬──────┘                                        │
│         │                                                │
│         ↓                                                │
│  ┌─────────────┐                                        │
│  │     ACM     │ (SSL/TLS Certificate)                  │
│  └──────┬──────┘                                        │
│         │                                                │
│         ↓                                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │              VPC                                 │  │
│  │                                                  │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │   PUBLIC SUBNETS (AZ-1, AZ-2)              │ │  │
│  │  │   ┌─────────────────────┐                  │ │  │
│  │  │   │   ALB               │ (Port 80/443)    │ │  │
│  │  │   │   (Load Balancer)   │                  │ │  │
│  │  │   └──────┬──────────────┘                  │ │  │
│  │  │          │                                 │ │  │
│  │  │   ┌──────┴──────────────┐                 │ │  │
│  │  │   │   NAT Gateway       │                 │ │  │
│  │  │   └─────────────────────┘                 │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │          │                                       │  │
│  │          ↓                                       │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │   PRIVATE SUBNETS (AZ-1, AZ-2)            │ │  │
│  │  │   ┌─────────────────────┐                  │ │  │
│  │  │   │   ECS Fargate Tasks │                  │ │  │
│  │  │   │   (Aim Application)  │                  │ │  │
│  │  │   └─────────────────────┘                  │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─────────────┐                                        │
│  │     ECR     │ (Container Registry)                   │
│  └─────────────┘                                        │
│                                                          │
│  ┌─────────────┐                                        │
│  │ CloudWatch  │ (Logging & Monitoring)                 │
│  └─────────────┘                                        │
└─────────────────────────────────────────────────────────┘
```

### Architecture Components

- **Route53**: DNS service for domain routing
- **ACM**: SSL/TLS certificate management
- **VPC**: Isolated network environment with public/private subnets
- **ALB**: Application Load Balancer for traffic distribution
- **ECS Fargate**: Serverless container hosting for Aim
- **ECR**: Docker container image registry
- **CloudWatch**: Logging and monitoring
- **NAT Gateway**: Outbound internet access for private subnets

## 🚀 Local Setup

### Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.6.0
- **AWS CLI** configured with credentials
- **Docker** (for local development)
- **Python 3.11+** (for local Aim development)
- **Git**

### 1. Clone the Repository

```bash
git clone https://github.com/roodyadam/aim-ecs-project.git
cd aim-ecs-project
```

### 2. Configure Terraform Variables

Create a `terraform.tfvars` file in the `infra/` directory:

```hcl
aws_region = "eu-west-2"
project_name = "aimapp"
domain_name = "your-domain.com"
subdomain = "tm"
container_port = 80
container_cpu = 256
container_memory = 512
desired_count = 1
github_repo = "your-username/aim-ecs-project"
certificate_arn = "arn:aws:acm:region:account:certificate/cert-id"
hosted_zone_id = "Z1234567890ABC"
```

**Note**: `terraform.tfvars` is in `.gitignore` for security. Never commit sensitive values.

### 3. Set Up AWS Backend (One-time)

Before running Terraform, ensure you have:
- S3 bucket for Terraform state (update `infra/main.tf` backend config)
- DynamoDB table for state locking (update `infra/main.tf` backend config)

### 4. Initialize and Deploy Infrastructure

```bash
cd infra

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply
```

### 5. Local Development with Aim

For local development of the Aim application:

```bash
cd aim

# Install dependencies
pip install -r requirements.txt

# Run Aim locally
aim up --host 0.0.0.0 --port 8080
```

Access Aim UI at: http://localhost:8080

### 6. Build and Test Docker Image Locally

```bash
cd aim

# Build Docker image
docker build -t aim-app:local -f docker/Dockerfile .

# Run container locally
docker run -p 8080:80 aim-app:local
```

### 7. CI/CD Setup

#### GitHub Actions Secrets

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `AWS_GITHUB_ACTIONS_ROLE_ARN`: ARN of the IAM role for GitHub Actions OIDC

The workflow environment variables are already configured in `.github/workflows/deploy.yml` and `.github/workflows/destroy.yml`.

#### Deploy via GitHub Actions

1. **Automatic**: Push to `main` branch triggers deployment
2. **Manual**: Go to Actions → Deploy → Run workflow

#### Destroy Infrastructure

Go to Actions → Destroy Infrastructure → Run workflow → Type "destroy" to confirm

## 📁 Project Structure

```
aim-ecs-project/
├── .github/
│   └── workflows/
│       ├── deploy.yml          # CI/CD deployment pipeline
│       └── destroy.yml          # Infrastructure destruction workflow
├── aim/                         # Aim application code
│   ├── aim/                     # Aim Python package
│   ├── docker/
│   │   └── Dockerfile          # Container image definition
│   └── main.py                 # Application entry point
├── infra/                       # Terraform infrastructure
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output values
│   ├── terraform.tfvars         # Local variable values (gitignored)
│   └── modules/                 # Reusable Terraform modules
│       ├── vpc/                 # VPC and networking
│       ├── ecs/                 # ECS cluster and service
│       ├── alb/                 # Application Load Balancer
│       ├── ecr/                 # Container registry
│       ├── iam/                 # IAM roles and policies
│       ├── route53/             # DNS configuration
│       └── acm/                 # SSL certificate
└── README.md                    # This file
```

## 🔧 Configuration

### Environment Variables (Workflows)

The following environment variables are configured in GitHub Actions workflows:

- `AWS_REGION`: AWS region (eu-west-2)
- `DOMAIN_NAME`: Your domain name
- `GITHUB_REPO`: GitHub repository in format 'owner/repo'
- `CERTIFICATE_ARN`: ACM certificate ARN for HTTPS
- `HOSTED_ZONE_ID`: Route53 hosted zone ID

### Terraform Variables

Key variables you can customize:

- `container_cpu`: CPU units for ECS tasks (default: 256)
- `container_memory`: Memory in MB for ECS tasks (default: 512)
- `desired_count`: Number of ECS tasks to run (default: 1)
- `subdomain`: Subdomain for the application (default: "tm")

## 🛠️ Development

### Running Tests

```bash
cd aim
pytest tests/
```

### Linting

```bash
# Terraform
cd infra
terraform fmt -check
tflint

# Python
cd aim
ruff check .
```

### Security Scanning

The CI/CD pipeline automatically runs:
- **TfSec**: Terraform security scanning
- **Trivy**: Docker image vulnerability scanning

## 📚 Additional Resources

- [Aim Documentation](https://aimstack.readthedocs.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)

## 🔐 Security

- Terraform state stored in encrypted S3 bucket
- State locking via DynamoDB
- Private subnets for ECS tasks
- Security groups with least privilege access
- HTTPS/TLS encryption for all traffic
- OIDC authentication for GitHub Actions (no long-lived credentials)

## 📝 License

This project uses the Aim open-source license. See `aim/LICENSE` for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📧 Contact

For issues and questions, please open an issue on GitHub.

---

**Note**: This is an infrastructure project. The Aim application code is included as a subdirectory. For Aim-specific contributions, refer to the [Aim repository](https://github.com/aimhubio/aim).

