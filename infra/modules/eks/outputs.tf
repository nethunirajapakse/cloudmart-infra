output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL — used to create IRSA roles"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used in IRSA trust policies"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "fargate_role_arn" {
  description = "Fargate pod execution role ARN"
  value       = aws_iam_role.fargate.arn
}

output "product_service_role_arn" {
  description = "IRSA role ARN for product-service"
  value       = aws_iam_role.product_service.arn
}

output "order_service_role_arn" {
  description = "IRSA role ARN for order-service"
  value       = aws_iam_role.order_service.arn
}

output "notification_service_role_arn" {
  description = "IRSA role ARN for notification-service"
  value       = aws_iam_role.notification_service.arn
}

output "user_service_role_arn" {
  description = "IRSA role ARN for user-service"
  value       = aws_iam_role.user_service.arn
}
