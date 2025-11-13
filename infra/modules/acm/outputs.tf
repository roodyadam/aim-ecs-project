output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = data.aws_acm_certificate.this.arn
}
