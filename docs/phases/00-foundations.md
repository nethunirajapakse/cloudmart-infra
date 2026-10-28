# Phase 0: Foundations and state bootstrap

## Concepts (read first)
- **IAM least privilege:** every identity (you, CI, each pod later) gets only what it needs. Root account is for billing and recovery only.
- **Budgets first:** EKS control plane alone is about $0.10/hour. A forgotten stack is the most common way to get a surprise bill.
- **Terraform state:** a JSON file mapping your code to real resource IDs. It can hold secrets, so it is never committed. Remote state (S3) + lock (DynamoDB) lets you and CI share it safely.
- **Chicken-and-egg:** the bucket for state cannot be created by a stack whose state is in that bucket, hence `infra/bootstrap` uses local state, once.

## Your tasks (these need your AWS account, so I can't do them for you)
1. In your own AWS account: root MFA on, create an admin IAM Identity Center user (or IAM user with MFA), stop using root.
2. Billing: create a monthly budget ($50) with email alerts at 80% and 100% actual and 100% forecast. Enable Cost Explorer.
3. Install: AWS CLI v2, Terraform >= 1.5, kubectl, Helm, Docker, pre-commit. Run `aws sts get-caller-identity` and confirm the account is **yours**.
4. Create the two GitHub repos (infra already exists). Copy this scaffold into the infra repo, run `pre-commit install`.
5. Bootstrap:
   ```bash
   cd infra/bootstrap
   terraform init
   terraform plan  -var owner_email=you@example.com
   terraform apply -var owner_email=you@example.com
   ```
   Note the two outputs; Phase 2 uses them in `backend.tf`.
6. Commit `.terraform.lock.hcl`, not state.

## Explain back (answer in your own words before Phase 1)
1. Why does `bootstrap` use local state, and what could go wrong with that?
2. What does the DynamoDB table actually store, and when?
3. Why is `prevent_destroy` set on the bucket, and why is versioning on?
4. Why look up the account ID with a data source instead of hard-coding it?
5. If two people run `terraform apply` at once, what happens?

## Evidence to save (for README/LinkedIn)
Budget screenshot, `terraform apply` output, bucket with versioning enabled.
