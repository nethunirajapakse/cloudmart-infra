# =============================================================================
# CloudMart EKS Module
# Provisions:
#   - EKS cluster (managed control plane)
#   - Fargate profiles (no EC2 nodes — avoids EC2 Fleet quota limits)
#   - OIDC provider for IRSA/workload identity
# =============================================================================

# --- EKS Cluster IAM Role ---

resource "aws_iam_role" "cluster" {
  name = "${var.project}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# --- EKS Cluster ---

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_app_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [var.eks_nodes_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = var.tags
}

# --- Fargate Pod Execution Role ---
# Fargate nodes assume this role to pull images from ECR and write logs.

resource "aws_iam_role" "fargate" {
  name = "${var.project}-${var.environment}-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

# Grants application pods access to DynamoDB, SQS, Secrets Manager, and KMS.
# Day 5 (IRSA) will replace this with per-service scoped roles.
# --- Fargate Profiles ---
# One profile per namespace. Pods in these namespaces run serverlessly on Fargate.
# No EC2 instances are provisioned — eliminates Fleet Request quota issues.

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project}-${var.environment}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_app_subnet_ids

  selector {
    namespace = "kube-system"
  }

  depends_on = [aws_iam_role_policy_attachment.fargate]

  tags = var.tags
}

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project}-${var.environment}-default"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_app_subnet_ids

  selector {
    namespace = "default"
  }

  depends_on = [aws_iam_role_policy_attachment.fargate]

  tags = var.tags
}

# --- OIDC Provider ---
# Enables IRSA (IAM Roles for Service Accounts) — each pod gets a scoped IAM role.

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# --- Fargate → RDS Connectivity ---
# Fargate pod ENIs are not members of the EC2 node security group, so user-service
# needs this explicit PostgreSQL ingress path to RDS.

resource "aws_security_group_rule" "rds_from_fargate" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = var.rds_security_group_id
  description       = "PostgreSQL from VPC (Fargate pods in private app subnets)"
}

# --- IRSA Roles for Application Pods (Least-Privilege) ---

locals {
  oidc_issuer = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")
}

# 1. Product Service Role
resource "aws_iam_role" "product_service" {
  name = "${var.project}-${var.environment}-product-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:*:product-service"
        }
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "product_service" {
  name = "${var.project}-${var.environment}-product-service-policy"
  role = aws_iam_role.product_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/cloudmart-products",
          "arn:aws:dynamodb:*:*:table/cloudmart-products/index/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# 2. Order Service Role
resource "aws_iam_role" "order_service" {
  name = "${var.project}-${var.environment}-order-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:*:order-service"
        }
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "order_service" {
  name = "${var.project}-${var.environment}-order-service-policy"
  role = aws_iam_role.order_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage", "sqs:ReceiveMessage",
          "sqs:DeleteMessage", "sqs:GetQueueAttributes",
        ]
        Resource = "arn:aws:sqs:*:*:cloudmart-orders"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# 3. Notification Service Role
resource "aws_iam_role" "notification_service" {
  name = "${var.project}-${var.environment}-notification-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:*:notification-service"
        }
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "notification_service" {
  name = "${var.project}-${var.environment}-notification-service-policy"
  role = aws_iam_role.notification_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage", "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = "arn:aws:sqs:*:*:cloudmart-orders"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# 4. User Service Role
resource "aws_iam_role" "user_service" {
  name = "${var.project}-${var.environment}-user-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:*:user-service"
        }
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "user_service" {
  name = "${var.project}-${var.environment}-user-service-policy"
  role = aws_iam_role.user_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:*:*:secret:cloudmart/${var.environment}/db-credentials-*",
          "arn:aws:secretsmanager:*:*:secret:cloudmart/${var.environment}/jwt-secret-*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# --- Fargate Profiles for application namespaces ---
# cloudmart-prod is the production namespace required by the assignment.
# cloudmart-staging is used for staging deployments from the CI/CD pipeline.

resource "aws_eks_fargate_profile" "cloudmart_prod" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project}-${var.environment}-cloudmart-prod"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_app_subnet_ids

  selector {
    namespace = "cloudmart-prod"
  }

  depends_on = [aws_iam_role_policy_attachment.fargate]

  tags = var.tags
}

resource "aws_eks_fargate_profile" "cloudmart_staging" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project}-${var.environment}-cloudmart-staging"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_app_subnet_ids

  selector {
    namespace = "cloudmart-staging"
  }

  depends_on = [aws_iam_role_policy_attachment.fargate]

  tags = var.tags
}

# --- SES Sender Email Identity ---
# After `terraform apply` AWS sends a verification link to this address.
# Click it before switching EMAIL_BACKEND=ses in configmap.yaml.
# In SES sandbox mode recipients must also be verified — set
# NOTIFICATION_EMAIL_OVERRIDE in configmap.yaml to your verified inbox.

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

# EKS Fargate Profile for External Secrets Operator
resource "aws_eks_fargate_profile" "external_secrets" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project}-${var.environment}-external-secrets-profile"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_app_subnet_ids

  selector {
    namespace = "external-secrets"
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate
  ]
}
