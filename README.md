# cloudmart-infra

Infrastructure and deployment configuration for CloudMart, a five-service e-commerce platform that runs on Amazon EKS. This repo holds everything needed to create the AWS environment and deploy the services onto it. The application code and Dockerfiles live in a separate repo, `cloudmart-app-source`.

CloudMart was the IS 4630 Cloud Infrastructure Management assignment at the University of Moratuwa. The first version of this infrastructure came out of the group project. This repo is my own copy of it, split away from the application code so I can rebuild and extend it on my own AWS account.

## Why two repos

| Repo | Contains | Pipeline |
|------|----------|----------|
| `cloudmart-app-source` | `services/*` source code, Dockerfiles, docker-compose | Test, build, Trivy scan, push image to ECR |
| `cloudmart-infra` (this repo) | Terraform, Kubernetes manifests, IAM policies, observability config, ADRs, DR plan | Validate Terraform and manifests, deploy to EKS |

Application changes and infrastructure changes now have separate histories, reviews and pipelines. The app repo publishes images to ECR tagged with the commit SHA. This repo deploys a chosen tag with the `image_tag` input of the CD workflow.

## Layout

```
infra/
  bootstrap/            S3 bucket + DynamoDB table for Terraform remote state (run once, local state)
  modules/              networking, security, database, messaging, ecr, eks
  environments/
    prod/               main entry point; creates the full platform
    staging/            optional separate state for staging metadata
k8s/
  base/                 Deployments, Services, Ingress, HPA/PDB, NetworkPolicies, ExternalSecret
  overlays/prod|staging Kustomize overlays (staging runs 1 replica per service)
  observability/        Fluent Bit / CloudWatch logging config
  rbac/                 RBAC for the External Secrets Operator
  *.yaml.tpl            Templates Terraform renders into k8s/base/
iam/                    GitHub OIDC trust policy, deploy role permissions, logging policy
observability/          CloudWatch dashboard, metric filters, alarm metric definitions
docs/
  adr/                  Architecture Decision Records
  disaster-recovery-plan.md
  dr/                   Test data used for the point-in-time restore demo
.github/workflows/
  infra-ci.yml          terraform fmt/validate, kustomize build + kubeconform
  cd.yml                OIDC login, kubectl apply -k, rollout gate, smoke test, rollback
```

## Placeholders to fill in before first use

The group project's AWS account ID, certificate and WAF ARNs, RDS endpoint and email address were removed. Replace these before running anything:

| Placeholder | Where | Value |
|-------------|-------|-------|
| `AWS_ACCOUNT_ID` | `infra/environments/*/backend.tf`, `k8s/base/*.yaml`, `iam/*.json`, `observability/dashboard.json` | Your 12-digit account ID |
| `GITHUB_OWNER` | `iam/deploy-trust.json` | Your GitHub username |
| `you@example.com`, `your-team-id` | `infra/environments/*/terraform.tfvars`, `k8s/base/configmap.yaml` | Used for the `Owner` and `Team` cost-allocation tags and the SES sender |
| `REPLACE_WITH_ACM_CERTIFICATE_ARN`, `REPLACE_WITH_WAF_ACL_ARN`, `REPLACE_WITH_RDS_ENDPOINT` | `k8s/base/frontend.yaml`, `k8s/base/configmap.yaml` | Rewritten by `terraform apply` from `k8s/*.tpl` using the real resource outputs |

The GitHub Actions workflows read the account ID from a repository variable named `AWS_ACCOUNT_ID` (Settings > Secrets and variables > Actions > Variables).

## Deploying

Prerequisites: AWS CLI, Terraform 1.5 or newer, kubectl, Helm.

```bash
# 1. One-time remote state backend
cd infra/bootstrap
terraform init && terraform apply -var account_id=<your-account-id>

# 2. Platform: VPC, EKS, RDS, DynamoDB, SQS, KMS, WAF, GuardDuty, budgets, IRSA roles
cd ../environments/prod
terraform init && terraform plan && terraform apply

# 3. Connect and check
aws eks update-kubeconfig --name cloudmart-prod --region us-east-1
kubectl get pods -n cloudmart-prod

# 4. Staging (shares the prod cluster, separate namespace)
kubectl apply -k k8s/overlays/staging
```

## CI/CD

| Branch | Environment | What happens |
|--------|-------------|--------------|
| `feature/*` | none | `infra-ci.yml` validates only |
| `develop` | `cloudmart-staging` | `cd.yml` applies `k8s/overlays/staging` |
| `main` | `cloudmart-prod` | `cd.yml` applies `k8s/overlays/prod` after approval on the `production` GitHub Environment |

Both deploy jobs wait for every rollout, run an in-cluster smoke test against each `/health` endpoint, and run `kubectl rollout undo` if anything fails. Tools are installed as pinned release binaries rather than third-party Actions.

The deploy role is assumed through GitHub OIDC. `iam/deploy-trust.json` allows the `develop` branch and the `production` environment. A job that uses `environment: production` presents an environment-based subject claim instead of a branch ref, so the trust policy has to list the environment.

## Status and known gaps

- The Terraform is still the group's design (EKS on Fargate profiles). Moving to an EKS managed node group on EC2, as ADR-001 discusses, is the next planned change.
- Three `local-exec` provisioners in `infra/environments/prod/main.tf` use PowerShell as the interpreter, so `terraform apply` currently only works from a Windows machine or one with PowerShell installed.
- `terraform validate` and `kubeconform` run in CI. The Terraform has not been applied to my account yet.
- The group's `docs/k8s-backup/` exports were left out because they were raw `kubectl get -o yaml` dumps with account IDs embedded. They should be regenerated from the new cluster.
- Cross-repo trigger from the app repo to `cd.yml` is not wired up. For now, run the workflow manually with an `image_tag`.

## Decisions

See `docs/adr/` for the node instance type, user-service database and deployment strategy decisions, and `docs/disaster-recovery-plan.md` for RTO/RPO targets and restore procedures.

## Provenance

The Terraform modules, Kubernetes manifests, ADRs and DR plan started as group work for IS 4630. The CI/CD pipeline and observability setup (OIDC authentication, Trivy and kubeconform scanning, CloudWatch metric filters and dashboards) are the parts I owned in that group. Changes made in this repo after the split are mine alone and are visible in the commit history.
