# Normalize domain name - ensure it has trailing dot for Route53 lookup
locals {
  # Remove trailing dot if present, then add it back to ensure consistency
  domain_clean = replace(var.domain_name, "/\\.$/", "")
  domain_name_normalized = "${local.domain_clean}."
  
  # Use provided zone_id if available, otherwise lookup by name
  zone_id = var.hosted_zone_id != "" ? var.hosted_zone_id : data.aws_route53_zone.main[0].zone_id
}

# Try to find the hosted zone - it must exist before running Terraform
# Only lookup if zone_id is not provided
data "aws_route53_zone" "main" {
  count        = var.hosted_zone_id == "" ? 1 : 0
  name         = local.domain_name_normalized
  private_zone = false
}

# ACM Certificate Validation Records
# Note: Certificate validation will be handled manually or via a second apply
# The validation options are only known after the certificate is created
# For now, we'll skip automatic validation record creation to avoid count/for_each issues
# You can manually create the validation records or run terraform apply twice

# ACM Certificate Validation - commented out to avoid dependency issues
# Uncomment after first apply when certificate_domain_validation_options are known
# resource "aws_route53_record" "cert_validation" {
#   count = length(var.certificate_domain_validation_options)
# 
#   allow_overwrite = true
#   name            = var.certificate_domain_validation_options[count.index].resource_record_name
#   records         = [var.certificate_domain_validation_options[count.index].resource_record_value]
#   ttl             = 60
#   type            = var.certificate_domain_validation_options[count.index].resource_record_type
#   zone_id         = local.zone_id
# }
# 
# resource "aws_acm_certificate_validation" "this" {
#   count           = var.certificate_arn != "" && length(var.certificate_domain_validation_options) > 0 ? 1 : 0
#   certificate_arn = var.certificate_arn
#   validation_record_fqdns = [
#     for i in range(length(aws_route53_record.cert_validation)) : aws_route53_record.cert_validation[i].fqdn
#   ]
# 
#   timeouts {
#     create = "5m"
#   }
# }

resource "aws_route53_record" "alb" {
  zone_id         = local.zone_id
  name            = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type            = "A"
  allow_overwrite = true  # Allow overwriting existing records in case of duplicate zones

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

