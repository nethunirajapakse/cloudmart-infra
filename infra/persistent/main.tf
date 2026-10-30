# Long-lived, near-free resources. Kept in their own state so that
# "terraform destroy" on the expensive platform never touches them.

module "ecr" {
  source   = "../modules/ecr"
  services = var.services
}

module "dynamodb" {
  source   = "../modules/dynamodb"
  for_each = toset(var.environments)

  environment = each.key
}

module "messaging" {
  source   = "../modules/messaging"
  for_each = toset(var.environments)

  environment = each.key
}
