# Root `main.tf` Explanation

The root `main.tf` file is the **orchestration layer** of your Terraform infrastructure. It's the entry point that coordinates all your modules and defines how they connect together.

---

## Structure Overview

The file has two main sections:
1. **Terraform Configuration** (backend and version requirements)
2. **Module Declarations** (instantiating all 7 modules)

---

## Part 1: Terraform Configuration (Lines 1-11)

```terraform
terraform {
  required_version = ">= 1.6.0"
  
  backend "s3" {
    bucket         = "aimapp-terraform-state-147923156682"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### What This Does:

- **`required_version`**: Ensures Terraform 1.6.0 or higher is used (prevents version compatibility issues)

- **`backend "s3"`**: Stores Terraform state remotely in S3 instead of locally
  - **Why?** Enables team collaboration, state versioning, and prevents state file loss
  - **`bucket`**: S3 bucket where state is stored
  - **`key`**: Path/filename of the state file
  - **`region`**: AWS region (eu-west-2 = London)
  - **`dynamodb_table`**: DynamoDB table for state locking
    - **Why?** Prevents two people from running `terraform apply` simultaneously (which could corrupt state)
  - **`encrypt`**: Encrypts state file at rest (security best practice)

---

## Part 2: Module Declarations (Lines 13-67)

This section instantiates **7 modules** that work together to create your infrastructure. Modules are called in dependency order.

### Module 1: VPC (Lines 13-16)

```terraform
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}
```

**Purpose**: Creates the networking foundation
- VPC (Virtual Private Cloud)
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- Internet Gateway
- NAT Gateway
- Route tables

**Dependencies**: None (foundation layer)

**Outputs Used By**: ALB, ECS modules

---

### Module 2: ECR (Lines 18-21)

```terraform
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}
```

**Purpose**: Creates Docker container registry
- ECR repository for storing Docker images
- Image scanning enabled
- Encryption enabled

**Dependencies**: None (independent)

**Outputs Used By**: ECS module (needs repository URL to pull images)

---

### Module 3: ACM (Lines 23-26)

```terraform
module "acm" {
  source          = "./modules/acm"
  certificate_arn = var.certificate_arn
}
```

**Purpose**: References existing SSL/TLS certificate
- Doesn't create a certificate (references one that already exists)
- Certificate must be validated beforehand (DNS or email)

**Dependencies**: None (just references existing resource)

**Outputs Used By**: ALB module (for HTTPS termination)

---

### Module 4: ALB (Lines 28-34)

```terraform
module "alb" {
  source          = "./modules/alb"
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id              # ← From VPC module
  subnet_ids      = module.vpc.public_subnet_ids   # ← From VPC module
  certificate_arn = module.acm.certificate_arn     # ← From ACM module
}
```

**Purpose**: Creates Application Load Balancer
- Distributes traffic to ECS tasks
- Terminates SSL/TLS (HTTPS → HTTP)
- Health checks
- Security group for ALB

**Dependencies**: 
- **VPC module**: Needs VPC ID and public subnet IDs (ALB must be in public subnets)
- **ACM module**: Needs certificate ARN for HTTPS

**Outputs Used By**: ECS module (target group ARN, security group ID), Route53 module (DNS name, zone ID)

---

### Module 5: IAM (Lines 36-40)

```terraform
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  github_repo  = var.github_repo
}
```

**Purpose**: Creates IAM roles and policies
- ECS execution role (for ECS agent to pull images, write logs)
- ECS task role (for application code to access AWS services)
- GitHub Actions OIDC provider (for CI/CD authentication)
- GitHub Actions role (for CI/CD to deploy)

**Dependencies**: None (independent)

**Outputs Used By**: ECS module (execution and task role ARNs)

---

### Module 6: ECS (Lines 42-58)

```terraform
module "ecs" {
  source             = "./modules/ecs"
  project_name       = var.project_name
  ecr_repo_url       = module.ecr.repository_url        # ← From ECR
  vpc_id             = module.vpc.vpc_id                # ← From VPC
  subnet_ids         = module.vpc.private_subnet_ids    # ← From VPC
  target_group_arn   = module.alb.target_group_arn      # ← From ALB
  alb_sg_id          = module.alb.sg_id                 # ← From ALB
  aws_region         = var.aws_region
  container_port     = var.container_port
  container_cpu      = var.container_cpu
  container_memory   = var.container_memory
  desired_count      = var.desired_count
  execution_role_arn = module.iam.ecs_execution_role_arn # ← From IAM
  task_role_arn      = module.iam.ecs_task_role_arn     # ← From IAM
  image_tag          = var.image_tag
}
```

**Purpose**: Creates containerized application infrastructure
- ECS cluster
- ECS task definition (container configuration)
- ECS service (runs and manages tasks)
- Security group for ECS tasks
- CloudWatch log group

**Dependencies**:
- **ECR module**: Needs repository URL to pull Docker images
- **VPC module**: Needs VPC ID and private subnet IDs (tasks run in private subnets)
- **ALB module**: Needs target group ARN (to register tasks) and ALB security group ID (for ingress rules)
- **IAM module**: Needs execution and task role ARNs (for permissions)

**Outputs Used By**: None (end of the chain)

---

### Module 7: Route53 (Lines 60-67)

```terraform
module "route53" {
  source         = "./modules/route53"
  domain_name    = var.domain_name
  subdomain      = var.subdomain
  hosted_zone_id = var.hosted_zone_id
  alb_dns_name   = module.alb.alb_dns_name    # ← From ALB
  alb_zone_id    = module.alb.alb_zone_id     # ← From ALB
}
```

**Purpose**: Creates DNS record
- A record pointing subdomain to ALB
- Enables access via custom domain (e.g., `tm.roodyadamsapp.com`)

**Dependencies**:
- **ALB module**: Needs ALB DNS name and zone ID (to create alias record)

**Outputs Used By**: None (end of the chain)

---

## Dependency Flow Diagram

```
VPC ──┐
      ├──> ALB ──┐
ECR ──┼──> ECS   │
      │          └──> Route53
ACM ──┘
IAM ──┘
```

**Execution Order** (Terraform determines this automatically):
1. VPC, ECR, ACM, IAM (no dependencies - run in parallel)
2. ALB (waits for VPC and ACM)
3. ECS (waits for ECR, VPC, ALB, IAM)
4. Route53 (waits for ALB)

---

## Key Concepts

### Variables (`var.*`)
- Defined in `variables.tf` in the root directory
- Passed into modules as inputs
- Examples: `var.project_name`, `var.domain_name`, `var.container_port`

### Module Outputs (`module.*.output_name`)
- Modules expose values via outputs (defined in each module's `outputs.tf`)
- Other modules reference these outputs
- Examples: `module.vpc.vpc_id`, `module.alb.target_group_arn`

### Why This Structure?
- **Modularity**: Each module is self-contained and reusable
- **Dependency Management**: Terraform automatically determines execution order
- **Maintainability**: Change one module without affecting others (if interfaces stay the same)
- **Clarity**: Easy to see how everything connects

---

## Summary

The root `main.tf` is the **conductor** of your infrastructure orchestra:
- It defines **where** state is stored (S3 backend)
- It **instantiates** all modules
- It **connects** modules together via outputs → inputs
- It **orchestrates** the entire infrastructure deployment

Without this file, Terraform wouldn't know what to create or how modules relate to each other.

