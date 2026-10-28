# =============================================================================
# CloudMart Database Module
# Provisions:
#   - RDS PostgreSQL (user-service data store)
#   - DynamoDB (product-service catalogue)
#   - Secrets Manager entry for DB credentials
# =============================================================================

# --- Random password for RDS ---
# Generated once; stored in Secrets Manager. Never appears in K8s manifests.

resource "random_password" "db" {
  length  = 20
  special = false # Avoids chars that break PostgreSQL connection strings
}

# --- RDS Subnet Group ---
# Places RDS in the private data subnets (no internet route).

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

# --- RDS Parameter Group ---
# Enforces SSL for all connections to PostgreSQL (assignment security requirement).

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project}-${var.environment}-postgres15"
  family = "postgres15"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

# --- RDS PostgreSQL Instance ---
# db.t3.micro = smallest available instance (~$15/month, within free tier for new accounts).
# Encrypted at rest with the project KMS key.
# 7-day automated backup retention (assignment DR requirement).

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "15.10"
  instance_class = var.db_instance_class

  db_name  = "cloudmart"
  username = "cloudmart"
  password = random_password.db.result

  allocated_storage     = 20
  max_allocated_storage = 50 # Allows autoscaling storage up to 50GB

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  # Encryption at rest (assignment security requirement)
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backup and recovery (assignment DR requirement — 7-day retention)
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Assignment environment settings
  deletion_protection = false # Set true for real production
  skip_final_snapshot = true  # Allows clean terraform destroy

  publicly_accessible = false # RDS stays in private data subnet

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-postgres"
  })
}

# --- DynamoDB Table — Product Catalogue ---
# product-service reads/writes product data here.
# on-demand billing = no capacity planning needed, pay per request.
# Hash key is "id" (string) — matches the product ID format in the existing code (prod-001, etc.)

resource "aws_dynamodb_table" "products" {
  name         = "${var.project}-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # GSI for category-based queries (product-service filters by category)
  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    projection_type = "ALL"
  }

  attribute {
    name = "category"
    type = "S"
  }

  # Encryption at rest with project KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # Point-In-Time Recovery (assignment DR requirement)
  # Allows restore to any second within the last 35 days at no storage cost
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project}-products"
  })
}

# --- Secrets Manager — DB Credentials ---
# user-service pods read this via IRSA (workload identity) in Day 5.
# Contains everything needed to construct a psycopg2 connection string.

resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "${var.project}/${var.environment}/db-credentials"
  kms_key_id = var.kms_key_arn

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = "cloudmart"
    username = "cloudmart"
    password = random_password.db.result
  })
}
