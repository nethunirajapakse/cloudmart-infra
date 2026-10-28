# =============================================================================
# CloudMart Production Environment
# Deploy from this directory: cd infra/environments/prod && terraform apply
#
# Module dependency order (Terraform resolves automatically via outputs):
#   1. networking  (VPC, subnets, SGs)
#   2. security    (KMS key — needed by all encrypted resources)
#   3. database    (RDS + DynamoDB — needs KMS + networking)
#   4. messaging   (SQS — needs KMS)
#   5. eks         (cluster + Fargate profiles + IRSA roles — needs networking)
#   6. coredns     (patch CoreDNS so it schedules on Fargate)
#   7. lbc         (IAM role + Helm release — needs EKS OIDC)
#   8. eso         (Helm release — needs EKS cluster DNS)
#   9. local_file  (k8s/base/*.yaml generation — needs RDS endpoint + WAF ARN)
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Helm provider connects to the EKS cluster using the AWS CLI token exec plugin.
# This matches how kubectl authenticates — no static credentials stored.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
      command     = "aws"
    }
  }
}

locals {
  common_tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team_id
    Owner       = var.owner_email
    ManagedBy   = "terraform"
  }

  # OIDC issuer without the https:// prefix — used in IAM trust policy conditions
  oidc_issuer = trimprefix(module.eks.cluster_oidc_issuer, "https://")

  custom_domain_enabled       = trimspace(var.custom_domain_name) != "" && trimspace(var.route53_zone_id) != ""
  frontend_load_balancer_name = "cloudmart-${var.environment}-alb"
}

# =============================================================================
# Networking — VPC, subnets, IGW, NAT, route tables, SGs, endpoints, flow logs
# =============================================================================

module "networking" {
  source = "../../modules/networking"

  project     = "cloudmart"
  environment = var.environment
  aws_region  = var.aws_region

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  cluster_name = var.cluster_name
  admin_cidr   = var.admin_cidr

  tags = local.common_tags
}

# =============================================================================
# Security — KMS key, JWT secret, GuardDuty, WAF
# =============================================================================

module "security" {
  source = "../../modules/security"

  project     = "cloudmart"
  environment = var.environment

  custom_domain_name  = var.custom_domain_name
  route53_zone_id     = var.route53_zone_id
  acm_certificate_arn = var.acm_certificate_arn
  enable_guardduty    = var.enable_guardduty

  tags = local.common_tags
}

# =============================================================================
# ECR — Container registries for all 5 services
# NOTE: ECR repos are pre-existing and managed outside Terraform to avoid
# KMS key drift forcing image deletion on terraform destroy.
# =============================================================================

# module "ecr" {
#   source = "../../modules/ecr"
#
#   project     = "cloudmart"
#   kms_key_arn = module.security.kms_key_arn
#
#   tags = local.common_tags
# }

# =============================================================================
# Database — RDS PostgreSQL + DynamoDB + DB credentials in Secrets Manager
# =============================================================================

module "database" {
  source = "../../modules/database"

  project     = "cloudmart"
  environment = var.environment

  private_data_subnet_ids = module.networking.private_data_subnet_ids
  rds_security_group_id   = module.networking.rds_security_group_id
  kms_key_arn             = module.security.kms_key_arn

  db_instance_class           = var.db_instance_class
  rds_backup_retention_period = var.rds_backup_retention_period

  tags = local.common_tags
}

# =============================================================================
# Messaging — SQS orders queue
# =============================================================================

module "messaging" {
  source = "../../modules/messaging"

  project     = "cloudmart"
  environment = var.environment
  kms_key_arn = module.security.kms_key_arn

  tags = local.common_tags
}

# =============================================================================
# EKS — Cluster, Fargate profiles, OIDC provider, IRSA roles
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  project      = "cloudmart"
  environment  = var.environment
  cluster_name = var.cluster_name

  private_app_subnet_ids      = module.networking.private_app_subnet_ids
  public_subnet_ids           = module.networking.public_subnet_ids
  eks_nodes_security_group_id = module.networking.eks_nodes_security_group_id
  rds_security_group_id       = module.networking.rds_security_group_id
  vpc_cidr                    = module.networking.vpc_cidr
  kms_key_arn                 = module.security.kms_key_arn

  node_instance_type = var.node_instance_type
  node_min_count     = var.node_min_count
  node_desired_count = var.node_desired_count
  node_max_count     = var.node_max_count

  ses_sender_email = var.ses_sender_email

  tags = local.common_tags
}

# =============================================================================
# CoreDNS on Fargate
# EKS creates the CoreDNS deployment without the Fargate taint toleration in
# some clusters. With Fargate-only compute, that leaves kube-dns with no
# endpoints and breaks service discovery plus External Secrets STS calls.
# =============================================================================

resource "terraform_data" "coredns_fargate_toleration" {
  triggers_replace = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}
      $deployment = kubectl get deployment coredns -n kube-system -o json | ConvertFrom-Json
      $hasToleration = $deployment.spec.template.spec.tolerations | Where-Object {
        $_.key -eq 'eks.amazonaws.com/compute-type' -and
        $_.operator -eq 'Equal' -and
        $_.value -eq 'fargate' -and
        $_.effect -eq 'NoSchedule'
      }

      if (-not $hasToleration) {
        $patchPath = Join-Path $env:TEMP 'cloudmart-coredns-fargate-toleration.json'
        Set-Content -LiteralPath $patchPath -Value '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"eks.amazonaws.com/compute-type","operator":"Equal","value":"fargate","effect":"NoSchedule"}}]' -NoNewline
        kubectl patch deployment coredns -n kube-system --type=json --patch-file $patchPath
      } else {
        Write-Host 'CoreDNS already has the Fargate toleration.'
      }

      kubectl rollout status deployment coredns -n kube-system --timeout=5m
    EOT
  }

  depends_on = [
    module.eks
  ]
}

# =============================================================================
# AWS Load Balancer Controller — IAM role + Helm release
# Required on EKS Fargate: ALB Ingress and NLB with IP target mode both need
# the LBC to provision load balancers and register Fargate pod IPs as targets.
# =============================================================================

# Fetch the LBC IAM policy from the official AWS GitHub repo
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name   = "cloudmart-${var.environment}-lbc-policy"
  policy = data.http.lbc_iam_policy.response_body
  tags   = local.common_tags
}

# IRSA role — binds the LBC Kubernetes ServiceAccount in kube-system to the IAM policy above
resource "aws_iam_role" "lbc" {
  name = "cloudmart-${var.environment}-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Install LBC via Helm — creates the ServiceAccount with IRSA annotation automatically
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.13.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc.arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  depends_on = [
    module.eks,
    terraform_data.coredns_fargate_toleration,
    aws_iam_role_policy_attachment.lbc,
  ]
}

# =============================================================================
# External Secrets Operator — Helm release
# Automatically syncs AWS Secrets Manager secrets into Kubernetes Secrets.
# Webhook and cert-controller disabled: known Fargate TLS issue where the
# cert-controller generates a certificate for the pod IP instead of the
# webhook service DNS name.
# =============================================================================

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "webhook.create"
    value = "false"
  }
  set {
    name  = "certController.create"
    value = "false"
  }

  depends_on = [
    module.eks,
    terraform_data.coredns_fargate_toleration,
  ]
}

# =============================================================================
# K8s Manifest Generation — inject Terraform outputs into base manifests
# These files are generated after terraform apply and consumed by Kustomize.
# Run: kubectl apply -k k8s/overlays/prod
# =============================================================================

# Generate configmap with real RDS endpoint and SQS URL from Terraform outputs.
# Without this, DB_HOST would be stale after every terraform destroy + apply
# (RDS endpoint suffix changes each time).
resource "local_file" "configmap" {
  content = templatefile("${path.module}/../../../k8s/configmap.yaml.tpl", {
    db_host       = module.database.db_endpoint
    sqs_queue_url = module.messaging.orders_queue_url
  })
  filename = "${path.module}/../../../k8s/base/configmap.yaml"
}

# Generate frontend manifest with the real WAF ACL ARN from Terraform outputs.
# The WAF ACL ARN contains a UUID that changes on every terraform destroy + apply.
resource "local_file" "frontend_manifest" {
  content = templatefile("${path.module}/../../../k8s/frontend.yaml.tpl", {
    waf_acl_arn         = module.security.waf_acl_arn
    acm_certificate_arn = module.security.alb_certificate_arn
    frontend_host       = var.custom_domain_name
    load_balancer_name  = local.custom_domain_enabled ? local.frontend_load_balancer_name : ""
  })
  filename = "${path.module}/../../../k8s/base/frontend.yaml"
}

# Apply the generated Kubernetes manifests so terraform apply produces a
# working ALB Ingress with WAF and HTTPS annotations.
resource "terraform_data" "kubernetes_manifests" {
  triggers_replace = {
    aws_region             = var.aws_region
    cluster_name           = module.eks.cluster_name
    cluster_endpoint       = module.eks.cluster_endpoint
    overlay_path           = abspath("${path.module}/../../../k8s/overlays/prod")
    configmap_hash         = sha256(local_file.configmap.content)
    frontend_manifest_hash = sha256(local_file.frontend_manifest.content)
    static_base_manifest_hash = sha256(join("", [
      filesha256("${path.module}/../../../k8s/base/external-secret.yaml"),
      filesha256("${path.module}/../../../k8s/base/networkpolicies.yaml"),
      filesha256("${path.module}/../../../k8s/base/notification-service.yaml"),
      filesha256("${path.module}/../../../k8s/base/order-service.yaml"),
      filesha256("${path.module}/../../../k8s/base/product-service.yaml"),
      filesha256("${path.module}/../../../k8s/base/serviceaccounts.yaml"),
      filesha256("${path.module}/../../../k8s/base/user-service.yaml"),
    ]))
    prod_overlay_hash = sha256(join("", [
      for file in sort(fileset("${path.module}/../../../k8s/overlays/prod", "*.yaml")) :
      filesha256("${path.module}/../../../k8s/overlays/prod/${file}")
    ]))
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}
      kubectl create namespace cloudmart-prod --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -k "${abspath("${path.module}/../../../k8s/overlays/prod")}"

      for ($i = 0; $i -lt 60; $i++) {
        $hostname = kubectl get ingress cloudmart-ingress -n cloudmart-prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
        if ($hostname) {
          Write-Host "ALB hostname: $hostname"
          exit 0
        }
        Start-Sleep -Seconds 10
      }

      throw 'Timed out waiting for cloudmart-ingress to receive an ALB hostname.'
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Continue'
      aws eks update-kubeconfig --name ${self.triggers_replace.cluster_name} --region ${self.triggers_replace.aws_region}
      kubectl delete -k "${self.triggers_replace.overlay_path}" --ignore-not-found=true
      Start-Sleep -Seconds 60
    EOT
  }

  depends_on = [
    helm_release.lbc,
    helm_release.external_secrets,
    local_file.configmap,
    local_file.frontend_manifest,
  ]
}

data "aws_lb" "frontend" {
  count = local.custom_domain_enabled ? 1 : 0

  name = local.frontend_load_balancer_name

  depends_on = [
    terraform_data.kubernetes_manifests
  ]
}

resource "aws_route53_record" "frontend" {
  count = local.custom_domain_enabled ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.custom_domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.frontend[0].dns_name
    zone_id                = data.aws_lb.frontend[0].zone_id
    evaluate_target_health = true
  }
}
