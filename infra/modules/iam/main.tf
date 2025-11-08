# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_logs" {
  name = "${var.project_name}-ecs-task-logs-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# OIDC Provider 
resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_repo != "" ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", 
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  count = var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions"
  }
}


resource "aws_iam_role_policy" "github_actions_full_access" {
  count = var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-full-access"
  role  = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ECR permissions
          "ecr:*",
          # ECS permissions
          "ecs:*",
          # IAM permissions (for creating roles, OIDC provider)
          "iam:*",
          # EC2/VPC permissions
          "ec2:*",
          # CloudWatch Logs permissions
          "logs:*",
          # ALB/ELB permissions
          "elasticloadbalancing:*",
          # ACM permissions
          "acm:*",
          # Route53 permissions
          "route53:*"
        ]
        Resource = "*"
      }
    ]
  })
}
