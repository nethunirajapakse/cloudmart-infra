# =============================================================================
# Run: terraform output
# Copy these values — you need them for kubectl, CI/CD secrets, and K8s ConfigMaps.
# =============================================================================

# --- Networking ---
output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.networking.private_app_subnet_ids
}

output "nat_gateway_public_ip" {
  value = module.networking.nat_gateway_public_ip
}

# --- EKS ---
output "eks_cluster_name" {
  description = "Set as EKS_CLUSTER_NAME in GitHub Actions secrets"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_issuer" {
  description = "Used to create IRSA trust policies in Day 5"
  value       = module.eks.cluster_oidc_issuer
}

output "eks_oidc_provider_arn" {
  description = "Used to create IRSA trust policies in Day 5"
  value       = module.eks.oidc_provider_arn
}

output "product_service_role_arn" {
  description = "IRSA role ARN for product-service"
  value       = module.eks.product_service_role_arn
}

output "order_service_role_arn" {
  description = "IRSA role ARN for order-service"
  value       = module.eks.order_service_role_arn
}

output "notification_service_role_arn" {
  description = "IRSA role ARN for notification-service"
  value       = module.eks.notification_service_role_arn
}

output "user_service_role_arn" {
  description = "IRSA role ARN for user-service"
  value       = module.eks.user_service_role_arn
}

# --- ECR ---
# ECR repos are pre-existing and managed outside Terraform (see prod/main.tf note).
# Hardcoded URLs: AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cloudmart/<service>:latest
# output "ecr_repository_urls" {
#   description = "Map of service name to ECR URL — update K8s manifests with these"
#   value       = module.ecr.repository_urls
# }
#
# output "ecr_registry_id" {
#   description = "Set as ECR_REGISTRY in GitHub Actions secrets"
#   value       = module.ecr.registry_id
# }

# --- Database ---
output "db_endpoint" {
  description = "RDS hostname — goes into K8s ConfigMap"
  value       = module.database.db_endpoint
}

output "db_secret_name" {
  description = "Secrets Manager secret name for DB credentials"
  value       = module.database.db_secret_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name — goes into K8s ConfigMap as DYNAMODB_TABLE"
  value       = module.database.dynamodb_table_name
}

# --- Messaging ---
output "sqs_queue_url" {
  description = "SQS orders queue URL — goes into K8s ConfigMap as SQS_QUEUE_URL"
  value       = module.messaging.orders_queue_url
}

output "sqs_queue_arn" {
  description = "SQS orders queue ARN — used in IRSA policies"
  value       = module.messaging.orders_queue_arn
}

# --- Security ---
output "kms_key_arn" {
  description = "KMS key ARN"
  value       = module.security.kms_key_arn
}

output "jwt_secret_name" {
  description = "Secrets Manager secret name for JWT secret"
  value       = module.security.jwt_secret_name
}

output "waf_acl_arn" {
  description = "WAFv2 Web ACL ARN — set as alb.ingress.kubernetes.io/wafv2-acl-arn in frontend.yaml"
  value       = module.security.waf_acl_arn
}

output "alb_certificate_arn" {
  description = "ACM certificate ARN used by ALB HTTPS listener"
  value       = module.security.alb_certificate_arn
}

output "frontend_custom_domain" {
  description = "Browser-trusted HTTPS URL when custom_domain_name and route53_zone_id are configured"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : ""
}
