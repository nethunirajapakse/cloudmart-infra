# =============================================================================
# CloudMart ECR Module
# One private repository per service. All images are scanned on push.
# Lifecycle policy retains only the last 10 images (assignment requirement).
# =============================================================================

locals {
  services = toset([
    "product-service",
    "order-service",
    "user-service",
    "notification-service",
    "frontend",
  ])
}

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Trivy-compatible; also runs AWS native scanner
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

# Lifecycle policy: expire images when the repo has more than 10
resource "aws_ecr_lifecycle_policy" "services" {
  for_each = aws_ecr_repository.services

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images per repository"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
