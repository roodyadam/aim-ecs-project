# Project Technical Documentation

This document provides a comprehensive explanation of the key technical components of the Aim ECS Deployment Project, including the Dockerfile, Trivy ignore configuration, infrastructure as code, and GitHub Actions CI/CD pipelines.

---

## Table of Contents

1. [Dockerfile](#dockerfile)
2. [Trivyignore Configuration](#trivyignore-configuration)
3. [Infrastructure (Terraform)](#infrastructure-terraform)
4. [GitHub Actions Pipelines](#github-actions-pipelines)

---

## Dockerfile

The Dockerfile uses a **multi-stage build** strategy to optimize the final image size and reduce security vulnerabilities.

### Location
`aim/docker/Dockerfile`

### Architecture

#### Stage 1: Builder Stage
```dockerfile
FROM python:3.11-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
RUN pip install --upgrade pip && \
    pip install --no-cache-dir "Cython==3.0.10" "aimrocks==0.5.*"
COPY . .
RUN pip install --no-cache-dir .
```

**Purpose:**
- Uses `python:3.11-slim-bookworm` as the base image (Debian-based, smaller than standard Python images)
- Installs `build-essential` to compile native dependencies (needed for Cython and aimrocks)
- Installs Cython 3.0.10 (required for compiling Python extensions)
- Installs aimrocks 0.5.* (RocksDB bindings for Aim, written in Cython)
- Copies the entire application code and installs the Aim package with all dependencies

**Why build-essential?**
- Cython and aimrocks require compilation of C extensions
- These build tools are removed in the final stage to reduce image size

#### Stage 2: Runtime Stage
```dockerfile
FROM python:3.11-slim-bookworm
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
EXPOSE 80
CMD ["aim", "up", "--host", "0.0.0.0", "--port", "80", "--yes"]
```

**Purpose:**
- Creates a clean runtime image without build tools
- Copies only the installed packages and binaries from the builder stage
- Exposes port 80 (HTTP)
- Runs the Aim web UI server on all network interfaces (`0.0.0.0`) on port 80
- `--yes` flag automatically confirms prompts

**Benefits of Multi-Stage Build:**
- **Smaller image size**: Final image doesn't contain build tools (~100MB+ savings)
- **Better security**: Fewer packages = smaller attack surface
- **Faster runtime**: Only runtime dependencies included

### Key Features
- **Platform**: Linux/amd64 (compatible with AWS ECS Fargate)
- **Base**: Debian Bookworm (stable, security-maintained)
- **Python**: 3.11 (modern, performant)
- **Port**: 80 (standard HTTP port, ALB routes to this)

---

## Trivyignore Configuration

Trivy is a security scanner that checks Docker images for known vulnerabilities (CVEs). The `.trivyignore` file specifies which CVEs should be ignored during scanning.

### Location
`.trivyignore` (in repository root)

### Current Configuration
```
CVE-2025-6020
CVE-2025-7458
CVE-2023-45853
```

### Purpose

These CVEs are ignored because they are either:
1. **False positives**: Not exploitable in the containerized context
2. **Low severity**: Don't affect the application's security posture
3. **No fixes available**: Waiting for upstream patches
4. **Accepted risk**: Assessed and determined acceptable for the use case

### How It Works

- Trivy scans the Docker image during the CI/CD pipeline (GitHub Actions)
- If any CRITICAL or HIGH severity CVEs are found, the build fails
- CVEs listed in `.trivyignore` are excluded from failure conditions
- The pipeline still reports them but doesn't block deployment

### Best Practices

- **Document why**: Each ignored CVE should have justification
- **Regular review**: Periodically reassess ignored CVEs
- **Minimal set**: Only ignore when absolutely necessary
- **Security team approval**: Critical CVEs should be reviewed before ignoring

---

## Infrastructure (Terraform)

The infrastructure is defined using Terraform with a modular architecture. All resources are deployed to AWS in the `eu-west-2` (London) region.

### Terraform Backend Configuration

**Location**: `infra/main.tf` (lines 1-11)

```terraform
backend "s3" {
  bucket         = "aimapp-terraform-state-147923156682"
  key            = "infrastructure/terraform.tfstate"
  region         = "eu-west-2"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

**Features:**
- **State Storage**: Terraform state stored in S3 bucket (encrypted)
- **State Locking**: DynamoDB table prevents concurrent modifications
- **Encryption**: State files encrypted at rest
- **Versioning**: S3 bucket versioning enabled for state history

### Module Structure

The infrastructure is organized into 7 reusable modules:

1. **VPC** (`modules/vpc/`)
2. **ECR** (`modules/ecr/`)
3. **ACM** (`modules/acm/`)
4. **ALB** (`modules/alb/`)
5. **IAM** (`modules/iam/`)
6. **ECS** (`modules/ecs/`)
7. **Route53** (`modules/route53/`)

---

### 1. VPC Module (`modules/vpc/`)

Creates a complete networking foundation for the application.

#### Resources Created:

**VPC** (`aws_vpc.main`):
- CIDR block: Configurable (default: `10.0.0.0/16`)
- DNS hostnames and DNS support enabled for internal DNS resolution

**Internet Gateway** (`aws_internet_gateway.igw`):
- Provides internet access for public subnets
- Attached to the VPC

**Public Subnets** (2 subnets):
- Span 2 availability zones for high availability
- Auto-assign public IP addresses
- Route traffic through Internet Gateway
- CIDR blocks: `/24` subnets (e.g., `10.0.0.0/24`, `10.0.1.0/24`)

**NAT Gateway** (`aws_nat_gateway.main`):
- Allows private subnets to access internet (for pulling images, updates)
- Elastic IP address associated
- Placed in first public subnet

**Private Subnets** (2 subnets):
- Span 2 availability zones for high availability
- No public IP addresses assigned
- Route traffic through NAT Gateway for outbound internet
- CIDR blocks: `/24` subnets (e.g., `10.0.2.0/24`, `10.0.3.0/24`)

**Route Tables**:
- Public route table: Routes `0.0.0.0/0` → Internet Gateway
- Private route table: Routes `0.0.0.0/0` → NAT Gateway

**Why This Architecture?**
- **Public subnets**: Host ALB (needs internet access)
- **Private subnets**: Host ECS tasks (security best practice)
- **Multi-AZ**: High availability, fault tolerance
- **NAT Gateway**: Allows containers to pull images without exposing them to internet

---

### 2. ECR Module (`modules/ecr/`)

Amazon Elastic Container Registry - stores Docker images.

#### Resources Created:

**ECR Repository** (`aws_ecr_repository.this`):
- Name: `{project_name}-repo` (e.g., `aimapp-repo`)
- **Image scanning**: `scan_on_push = true` (automatic vulnerability scanning)
- **Encryption**: AES256 encryption at rest
- **Image mutability**: MUTABLE (tags can be overwritten)
- **Force delete**: Enabled (allows repository deletion even with images)

**Features:**
- **Integrated scanning**: Uses AWS Inspector for vulnerability detection
- **Versioning**: Tags allow multiple versions (latest, git SHA)
- **Access control**: IAM-based permissions

---

### 3. ACM Module (`modules/acm/`)

AWS Certificate Manager - manages SSL/TLS certificates.

#### Note:
The ACM module is minimal - it references an existing certificate ARN rather than creating one. This is because:
- ACM certificates must be validated via DNS or email
- Validation often requires manual steps
- Certificates are long-lived resources (created once, reused)

#### Usage:
The certificate ARN is passed as a variable and used by the ALB for HTTPS termination.

---

### 4. ALB Module (`modules/alb/`)

Application Load Balancer - distributes traffic to ECS tasks.

#### Resources Created:

**Security Group** (`aws_security_group.alb_sg`):
- **Ingress**: 
  - Port 80 (HTTP) from anywhere (`0.0.0.0/0`)
  - Port 443 (HTTPS) from anywhere (`0.0.0.0/0`)
- **Egress**: All traffic allowed

**Application Load Balancer** (`aws_lb.this`):
- Type: Application Load Balancer (Layer 7)
- Deployed in public subnets (2 availability zones)
- **Drop invalid headers**: Enabled (security feature)

**Target Group** (`aws_lb_target_group.this`):
- Protocol: HTTP (internal communication, HTTPS terminated at ALB)
- Port: 80
- Target type: IP (for Fargate tasks)
- **Health check**:
  - Path: `/status`
  - Interval: 30 seconds
  - Timeout: 5 seconds
  - Healthy threshold: 2 consecutive successes
  - Unhealthy threshold: 3 consecutive failures

**HTTP Listener** (Port 80):
- **Redirects** all HTTP traffic to HTTPS (301 redirect)
- Enforces HTTPS-only access

**HTTPS Listener** (Port 443):
- **SSL Policy**: TLS 1.2 minimum
- **Certificate**: ACM certificate ARN
- **Default action**: Forwards to target group

**How It Works:**
1. User requests `https://tm.roodyadamsapp.com`
2. Route53 resolves to ALB DNS name
3. ALB terminates SSL/TLS using ACM certificate
4. ALB forwards HTTP request to healthy ECS task
5. ECS task responds, ALB encrypts and returns to user

---

### 5. IAM Module (`modules/iam/`)

Identity and Access Management - defines permissions and authentication.

#### Resources Created:

**ECS Execution Role** (`aws_iam_role.ecs_execution`):
- Used by ECS to pull images from ECR
- Attached policy: `AmazonECSTaskExecutionRolePolicy` (AWS managed)
- Permissions include:
  - ECR image pull
  - CloudWatch Logs write
  - Secrets Manager access (if needed)

**ECS Task Role** (`aws_iam_role.ecs_task`):
- Used by the application running in containers
- Custom policy for CloudWatch Logs:
  - `logs:CreateLogGroup`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`
- Can be extended for S3, DynamoDB, etc. if needed

**GitHub Actions OIDC Provider** (`aws_iam_openid_connect_provider.github`):
- Enables GitHub Actions to assume AWS roles without stored credentials
- Thumbprints: GitHub's OIDC certificate fingerprints
- URL: `https://token.actions.githubusercontent.com`

**GitHub Actions Role** (`aws_iam_role.github_actions`):
- Assumed by GitHub Actions workflows
- **Trust policy**: Only allows GitHub repository `roodyadam/aim-ecs-project`
- **Permissions** (via inline policy):
  - EC2, ECS, ECR: Full access (infrastructure management)
  - IAM: Limited role/policy management (for OIDC setup)
  - Logs: Full access
  - ACM, Route53: Certificate and DNS management
  - Elastic Load Balancing: Full access
  - S3, DynamoDB: Terraform state management
- **Lifecycle protection**: `prevent_destroy = true` (critical for CI/CD)

**Security Benefits:**
- **No long-lived credentials**: OIDC eliminates need for access keys
- **Principle of least privilege**: Minimal permissions required
- **Repository-scoped**: Only specific GitHub repo can assume role

---

### 6. ECS Module (`modules/ecs/`)

Elastic Container Service - runs containerized applications.

#### Resources Created:

**Security Group** (`aws_security_group.ecs_sg`):
- **Ingress**: Port 80 only from ALB security group (not from internet)
- **Egress**: All outbound traffic allowed

**ECS Cluster** (`aws_ecs_cluster.this`):
- **Container Insights**: Enabled
  - Collects CPU, memory, network metrics
  - Provides detailed container-level monitoring
  - Sends metrics to CloudWatch automatically

**ECS Task Definition** (`aws_ecs_task_definition.app`):
- **Family**: `{project_name}-task`
- **Network mode**: `awsvpc` (each task gets its own ENI)
- **Launch type**: FARGATE (serverless, no EC2 management)
- **Resources**:
  - CPU: 256 (0.25 vCPU)
  - Memory: 512 MB
- **Container**:
  - Image: ECR repository URL with tag
  - Port mapping: 80 (container) → 80 (host)
  - **Logging**: CloudWatch Logs driver
    - Log group: `/ecs/{project_name}`
    - Stream prefix: `ecs`
    - Region: AWS region

**ECS Service** (`aws_ecs_service.app`):
- **Desired count**: Configurable (default: 1)
- **Launch type**: FARGATE
- **Network**:
  - Subnets: Private subnets (2 AZs)
  - Security groups: ECS security group
  - Public IP: Disabled (tasks access internet via NAT Gateway)
- **Load balancer**:
  - Target group: ALB target group
  - Container: `app`
  - Port: 80

**CloudWatch Log Group** (`aws_cloudwatch_log_group.ecs_logs`):
- Name: `/ecs/{project_name}`
- Retention: 7 days (configurable)

**Key Features:**
- **High availability**: Tasks distributed across 2 AZs
- **Auto-scaling**: Can configure based on CPU/memory metrics
- **Health checks**: ALB monitors task health
- **Zero-downtime deployments**: Rolling updates with health checks

---

### 7. Route53 Module (`modules/route53/`)

Amazon Route 53 - DNS management.

#### Resources Created:

**A Record** (`aws_route53_record.alb`):
- **Name**: `{subdomain}.{domain_name}` (e.g., `tm.roodyadamsapp.com`)
- **Type**: A record (IPv4)
- **Alias**: Points to ALB
  - Evaluates target health
  - Automatically resolves to ALB IP addresses
- **Allow overwrite**: Enabled (updates existing records)

**How DNS Works:**
1. User enters `https://tm.roodyadamsapp.com`
2. DNS query resolves to ALB DNS name
3. ALB handles request with SSL termination
4. Health check ensures only healthy targets receive traffic

---

### Infrastructure Variables

**Location**: `infra/variables.tf`

Key variables:
- `project_name`: Resource naming prefix (default: `aimapp`)
- `aws_region`: AWS region (default: `eu-west-2`)
- `domain_name`: Root domain name (required)
- `subdomain`: Subdomain prefix (default: `tm`)
- `container_port`: Container listening port (default: 80)
- `container_cpu`: CPU units (default: 256 = 0.25 vCPU)
- `container_memory`: Memory in MB (default: 512)
- `desired_count`: Number of ECS tasks (default: 1)
- `github_repo`: GitHub repository for OIDC (required)
- `certificate_arn`: ACM certificate ARN (required)
- `hosted_zone_id`: Route53 hosted zone ID (required)
- `image_tag`: Docker image tag (default: `latest`)

---

## GitHub Actions Pipelines

Two workflows manage deployment and destruction of infrastructure.

---

### 1. Deploy Workflow (`deploy.yml`)

**Trigger:**
- Push to `main` branch
- Manual dispatch (`workflow_dispatch`)

**Environment Variables:**
- AWS region, account ID
- ECR repository, ECS cluster/service names
- Application URL
- Terraform/TFLint versions
- Domain and certificate details

**Jobs (Executed Sequentially):**

#### Job 1: `validate`
**Purpose**: Validate Terraform code before deployment

**Steps:**
1. Checkout code
2. Set up Terraform 1.6.0
3. Set up TFLint v0.50.0
4. **Terraform validation**:
   - Initialize without backend (fast validation)
   - Validate syntax and configuration
5. **TFLint**: Lint Terraform code for best practices
6. **TfSec**: Security scanning for misconfigurations

**Why separate validation?**
- Fast feedback on syntax errors
- No AWS credentials needed
- Runs before any infrastructure changes

#### Job 2: `terraform-ecr`
**Purpose**: Create ECR repository first (needed for Docker image push)

**Dependencies**: Runs after `validate`

**Steps:**
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Set up Terraform
4. **ECR import logic**:
   - Checks if ECR repository exists in AWS
   - If exists but not in Terraform state, imports it
   - Prevents errors on first run
5. **Terraform apply**:
   - Targets only ECR module (`-target=module.ecr`)
   - Creates ECR repository with scanning enabled

**Why separate ECR job?**
- ECR must exist before pushing Docker images
- Prevents race conditions in parallel jobs

#### Job 3: `build`
**Purpose**: Build, tag, and push Docker image to ECR

**Dependencies**: Runs after `terraform-ecr`

**Steps:**
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Set up Docker Buildx (multi-platform builds)
4. **Login to ECR**: Authenticates Docker with ECR
5. **Build and push**:
   - Build context: `./aim`
   - Dockerfile: `./aim/docker/Dockerfile`
   - Platform: `linux/amd64` (ECS Fargate compatible)
   - **Tags**:
     - `{SHA}`: Git commit SHA (immutable, specific version)
     - `latest`: Latest build (mutable, used for rollbacks)
6. **Trivy scan**:
   - Scans image for vulnerabilities
   - Severity: CRITICAL and HIGH only
   - Exit code 1 on failure (blocks deployment)
   - Ignored CVEs from `.trivyignore` excluded

**Image Tags Explained:**
- `${{ github.sha }}`: Unique per commit, allows rollback to specific version
- `latest`: Always points to most recent build, convenient but not recommended for production

#### Job 4: `terraform-infra`
**Purpose**: Deploy all infrastructure resources

**Dependencies**: Runs after `build`

**Steps:**
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Set up Terraform
4. **Terraform apply**:
   - Initializes with S3 backend
   - Plans infrastructure changes
   - Applies with `image_tag=${{ github.sha }}` (specific commit)
   - Creates/updates: VPC, ALB, ECS, Route53, IAM roles

**Infrastructure Created:**
- VPC with public/private subnets
- Application Load Balancer
- ECS cluster and service
- Route53 DNS record
- IAM roles and policies
- CloudWatch log groups

#### Job 5: `health-check`
**Purpose**: Verify deployment succeeded and service is healthy

**Dependencies**: Runs after `terraform-infra`

**Steps:**
1. Configure AWS credentials (OIDC)
2. **Wait for ECS service to stabilize**:
   - Uses `aws ecs wait services-stable`
   - Waits until all tasks are running and healthy
   - Times out if service doesn't stabilize
3. **Deployment summary**:
   - Outputs success message to GitHub Actions summary
   - Includes application URL

**Why health check?**
- Confirms deployment actually worked
- Catches runtime errors (e.g., app crashes)
- Provides feedback in GitHub UI

**Pipeline Flow:**
```
validate → terraform-ecr → build → terraform-infra → health-check
```

**Total Duration**: ~5-10 minutes (depending on Terraform apply time)

---

### 2. Destroy Workflow (`destroy.yml`)

**Trigger:**
- Manual dispatch only (`workflow_dispatch`)
- **Safety**: Requires typing "destroy" to confirm

**Purpose**: Tear down infrastructure while preserving CI/CD authentication

**Jobs:**

#### Job: `destroy`
**Steps:**
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Set up Terraform
4. **Terraform destroy**:
   - Targets specific resources (excludes protected IAM)
   - Destroys in order:
     1. Route53 record
     2. ECS service and cluster
     3. ALB and target groups
     4. VPC and networking
     5. ECR repository
     6. ECS IAM roles (execution and task)
   - **Preserves**:
     - OIDC provider (required for CI/CD)
     - GitHub Actions role (required for CI/CD)

**Safety Features:**
- **Manual trigger only**: Cannot accidentally destroy
- **Confirmation required**: Must type "destroy"
- **Protected resources**: Critical IAM resources preserved
- **Graceful failure**: Reports but doesn't fail on some errors

**What Gets Destroyed:**
- ✅ All application infrastructure
- ✅ ECS tasks and services
- ✅ Load balancers
- ✅ Networking (VPC, subnets, gateways)
- ✅ DNS records
- ❌ OIDC provider (must manually delete if needed)
- ❌ GitHub Actions role (must manually delete if needed)

**Post-Destroy:**
- OIDC provider and GitHub Actions role remain
- Can immediately redeploy without re-configuring CI/CD
- S3 Terraform state bucket remains (contains state history)

---

## Conclusion

This project demonstrates a production-ready infrastructure setup with:
- **Secure CI/CD**: OIDC-based authentication, no stored credentials
- **Infrastructure as Code**: Fully automated, version-controlled infrastructure
- **Security**: Multiple layers (network, IAM, scanning, encryption)
- **Observability**: Comprehensive logging and monitoring
- **Best Practices**: Modular design, multi-AZ, private subnets, HTTPS-only

The infrastructure is scalable, maintainable, and follows AWS Well-Architected Framework principles.
