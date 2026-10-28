# =============================================================================
# CloudMart Security Module
# Creates the KMS key used to encrypt RDS, DynamoDB, SQS, Secrets Manager,
# and ECR images. Also creates the JWT secret in Secrets Manager.
# =============================================================================

# --- KMS Key ---
# Single key for the entire project (cost: ~$1/month).
# Key rotation is enabled — AWS rotates the backing key annually.

resource "aws_kms_key" "main" {
  description             = "CloudMart ${var.environment} - encrypts RDS, DynamoDB, SQS, Secrets Manager, ECR"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# --- JWT Secret ---
# Used by user-service to sign and verify JWT tokens.
# user-service pods read this via workload identity (IRSA) in Day 5.

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name       = "${var.project}/${var.environment}/jwt-secret"
  kms_key_id = aws_kms_key.main.key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}

# --- GuardDuty Threat Detection ---
# Enables GuardDuty monitoring for the AWS account and region.
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  tags = var.tags
}

# --- WAFv2 Web ACL ---
# Regional WAF Web ACL associated with ALB Ingress.
# Protects against SQL injection, XSS, and common vulnerabilities using Core Rule Set.
resource "aws_wafv2_web_acl" "alb" {
  name        = "${var.project}-${var.environment}-waf-acl"
  description = "WAF for CloudMart ALB containing AWS Managed Rules"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-${var.environment}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

locals {
  use_existing_alb_certificate = trimspace(var.acm_certificate_arn) != ""
  create_public_alb_certificate = (
    !local.use_existing_alb_certificate &&
    trimspace(var.custom_domain_name) != "" &&
    trimspace(var.route53_zone_id) != ""
  )

  alb_certificate_arn = (
    local.use_existing_alb_certificate ? var.acm_certificate_arn :
    local.create_public_alb_certificate ? aws_acm_certificate_validation.alb_public[0].certificate_arn :
    aws_acm_certificate.alb.arn
  )
}

# --- ACM Certificate for ALB HTTPS ---
# The self-signed fallback keeps SSL termination reproducible without a domain,
# but browsers will warn. For trusted HTTPS, set custom_domain_name plus
# route53_zone_id, or provide an issued acm_certificate_arn.

resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "*.us-east-1.elb.amazonaws.com"
    organization = "CloudMart"
  }

  dns_names = [
    "*.us-east-1.elb.amazonaws.com",
    "cloudmart.local",
  ]

  validity_period_hours = 8760
  early_renewal_hours   = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem

  tags = var.tags
}

resource "aws_acm_certificate" "alb_public" {
  count = local.create_public_alb_certificate ? 1 : 0

  domain_name       = var.custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "alb_certificate_validation" {
  for_each = local.create_public_alb_certificate ? {
    for dvo in aws_acm_certificate.alb_public[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "alb_public" {
  count = local.create_public_alb_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb_public[0].arn
  validation_record_fqdns = [for record in aws_route53_record.alb_certificate_validation : record.fqdn]
}
