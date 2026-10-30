resource "aws_ecr_repository" "service" {
  for_each = toset(var.services)

  name = "${var.project}/${each.key}"

  # Tags are commit SHAs, so a tag must never be re-pointed to different content.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep only the 10 most recent images per repository (brief section 3.2).
resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  for_each = aws_ecr_repository.service

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
