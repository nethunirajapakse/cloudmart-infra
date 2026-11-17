# cloudmart-infra

Infrastructure and deployment configuration for **CloudMart**, a five-service e-commerce platform running on Amazon EKS. Terraform builds the AWS environment, Kubernetes manifests describe the workloads, and GitHub Actions deploys them. Application code and Dockerfiles live in a separate repo, `cloudmart-app-source`.

## What it provisions

- **Network and compute:** VPC and an EKS cluster
- **Data and messaging:** RDS, DynamoDB, SQS
- **Security:** KMS, WAF, GuardDuty, IAM roles for service accounts (IRSA)
- **Operations:** CloudWatch dashboards, metric filters and alarms, AWS Budgets
- **Delivery:** GitHub Actions with OIDC login to AWS, so no long-lived keys are stored

## Architecture

![Architecture diagram](docs/architecture.png)

*Diagram to be added.*

## Two repos, two pipelines

| Repo | Contains | Pipeline |
|------|----------|----------|
| `cloudmart-app-source` | Service code, Dockerfiles | Test, build, Trivy scan, push to ECR |
| `cloudmart-infra` (this repo) | Terraform, Kubernetes manifests, IAM, observability, docs | Validate, deploy to EKS |

The app repo publishes images tagged with the commit SHA. This repo deploys a chosen tag through the `image_tag` input of the CD workflow.

## Repository layout

```
infra/          Terraform: remote-state bootstrap, reusable modules, prod and staging environments
k8s/            Kustomize base and overlays, network policies, logging and RBAC config
iam/            GitHub OIDC trust policy and deploy role permissions
observability/  CloudWatch dashboard and metric definitions
docs/           Architecture decision records and disaster recovery plan
.github/        CI and CD workflows
```

## CI/CD

| Branch | Environment | Result |
|--------|-------------|--------|
| `feature/*` | None | Terraform and manifests are validated |
| `develop` | Staging | Deployed automatically |
| `main` | Production | Deployed after manual approval |

Each deploy waits for rollouts to finish, smoke-tests every `/health` endpoint, and runs `kubectl rollout undo` if anything fails. Manifests are checked with kubeconform, and deploy tools are installed as pinned binaries.

## Getting started

Requires the AWS CLI, Terraform 1.5+, kubectl and Helm. Replace the placeholders (`AWS_ACCOUNT_ID`, `GITHUB_OWNER`, contact email) in the Terraform backend, IAM and manifest files first.

```bash
# 1. Remote state backend (once)
cd infra/bootstrap && terraform init && terraform apply -var account_id=<account-id>

# 2. Platform
cd ../environments/prod && terraform init && terraform apply

# 3. Connect to the cluster
aws eks update-kubeconfig --name cloudmart-prod --region us-east-1
kubectl get pods -n cloudmart-prod
```

## Design decisions

Architecture decisions are recorded in `docs/adr/` (node instance type, user-service database, deployment strategy). Recovery targets and restore steps are in `docs/disaster-recovery-plan.md`.

## Status and roadmap

- `terraform validate` and `kubeconform` pass in CI. The Terraform has not yet been applied to my AWS account.
- Next: move from Fargate to an EKS managed node group on EC2, as discussed in ADR-001.
- Three `local-exec` steps in `prod/main.tf` need PowerShell, so `apply` currently works only on Windows or with PowerShell installed.
- Cluster backup exports need regenerating from the new cluster.
- The app repo does not yet trigger `cd.yml` automatically, so run it manually with an `image_tag`.
