data "aws_acm_certificate" "this" {
  arn = var.certificate_arn
}
