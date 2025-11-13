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

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

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

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*",
          "ecr:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "logs:*",
          "acm:DescribeCertificate",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "elasticloadbalancing:*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:HeadBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateItem"
        ]
        Resource = "*"
      }
    ]
  })
}
