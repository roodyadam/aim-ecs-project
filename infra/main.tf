# VPC Module
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

# ECR Module
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

# ACM Certificate Module
module "acm" {
  source                   = "./modules/acm"
  domain_name              = var.domain_name
  subdomain                = var.subdomain
  existing_certificate_arn = "arn:aws:acm:eu-west-2:147923156682:certificate/afd13bd7-da22-443a-a567-8ae7f04c7009" 
}

# ALB Module
module "alb" {
  source          = "./modules/alb"
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  certificate_arn = module.acm.certificate_arn
  enable_https    = true
}

# IAM Module
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  github_repo  = var.github_repo
}

# ECS Module
module "ecs" {
  source             = "./modules/ecs"
  project_name       = var.project_name
  ecr_repo_url       = module.ecr.repository_url
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_sg_id          = module.alb.sg_id
  aws_region         = var.aws_region
  container_port     = var.container_port
  container_cpu      = var.container_cpu
  container_memory   = var.container_memory
  desired_count      = var.desired_count
  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn
  image_tag          = var.image_tag
}

# Route53 Module
module "route53" {
  source                                = "./modules/route53"
  domain_name                           = var.domain_name
  subdomain                             = var.subdomain
  hosted_zone_id                        = "Z06988621L4AI5LXY4AF3" 
  alb_dns_name                          = module.alb.alb_dns_name
  alb_zone_id                           = module.alb.alb_zone_id
  certificate_arn                       = module.acm.certificate_arn
  certificate_domain_validation_options = module.acm.certificate_domain_validation_options
}
