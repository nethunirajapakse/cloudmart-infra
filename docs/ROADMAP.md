> **Revision (8 Oct 2026):** The evaluation is already done, so this is now a portfolio build (CV + LinkedIn). Decisions: EC2 managed node group; I draft and you explain back; scope = all [M] + [R] then 2-3 [D]; speed matters.
> Viva/report framing is dropped. In its place: a strong README, 5 diagrams, 3+ ADRs and a short LinkedIn write-up. The "explain back" step stays, because interviewers ask the same questions a viva would.
> **CV honesty:** describe this as "rebuilt the group project solo, in my own AWS account" and keep your original owned sections (CI/CD, observability) accurate. Don't present the group's design as solely yours.

# CloudMart: Solo Takeover Roadmap

IS 4630, DevOps repo (`cloudmart-infra`) + app repo (`cloudmart-app-source`)
Goal: deliver the whole brief alone, **and be able to explain every part of it in the viva (40% of the mark).**

---

## 1. What exists today (audit of the three zips)

| Zip | What it really is |
|---|---|
| `CloudMart-main` | The group repo. A near-complete **AWS EKS Fargate** build: 6 Terraform modules, Kustomize base + prod/staging overlays, CI + CD workflows, 3 ADRs, DR plan, `docs/k8s-backup/`. |
| `cloudmart-app-source-main` | The **starter code**: 5 services, Dockerfiles, compose, and cloud adapters already included. The group repo's services are this + unit tests + one CVE patch in the frontend Dockerfile. |
| `cloudmart-infra-main` | Your new, **empty** DevOps repo (README + LICENSE only). |

Consequence: the real work is not "write everything". It is **re-build it cleanly in your own AWS account, understand each piece, close the gaps, and add the missing evidence** (diagrams, report, demo script).

### Coverage vs the brief (verified from the files; `?` = could not verify from the zips)

| Brief item | Group repo | Notes |
|---|---|---|
| 3.1 VPC, 3-tier subnets, IGW, NAT, route tables, SGs | ✅ | Bastion SG allows SSH from `admin_cidr = 0.0.0.0/0` (violates least privilege) |
| 3.1 [R] Private endpoint for NoSQL | ✅ | DynamoDB gateway endpoint |
| 3.1 [R] Private endpoint for secrets | ❌ | Only the DynamoDB endpoint exists |
| 3.1 [D] VPC flow logs + Logs Insights query | ❌ | README mentions flow logs; no flow-log resource in the networking module |
| 3.2 Dockerfiles (multi-stage, non-root, healthcheck) | ✅ | From the starter |
| 3.2 ECR lifecycle (keep last 10) | ⚠️ | ECR module is commented out in prod (managed by hand) |
| 3.2 [D] Trivy fails on CRITICAL | ✅ | In CI |
| 3.3 Deployments, probes, limits, rolling update, HPA, ConfigMap, ESO | ✅ | 2 HPAs, 4 PDBs |
| 3.3 [R] Cluster autoscaler / [D] KEDA | ❌ | Not possible in the usual way on Fargate |
| 3.4 Default-deny + allow NetworkPolicies | ⚠️ | Written, but **I believe the VPC CNI does not enforce NetworkPolicy on Fargate pods. Must be tested, not assumed.** |
| 3.4 Workload identity (4 least-privilege roles) | ✅ | IRSA |
| 3.4 Node IAM role / IMDSv2 hardening | ⚠️ | Claimed "N/A on Fargate"; weak answer in a viva |
| 3.4 [R] GuardDuty with a finding | ⚠️ | `enable_guardduty = false` in tfvars |
| 3.4 [D] Policy engine (Kyverno/Gatekeeper) | ❌ | |
| 3.5 CI (lint, test, build, Trivy, kubeconform), CD staging/prod, approval gate, smoke test | ✅ | Solid. Lint only selects syntax errors. Images also tagged `:latest`, and the base manifests reference `:latest` |
| 3.5 [D] Canary | ❌ | |
| 3.6 Logs, dashboard, alarm | ⚠️ | Alarm is 10%/1 min, brief says >5% over 5 min [M]. No per-service CPU/mem on the dashboard. Container Insights not available on Fargate |
| 3.6 [R] custom metric, [D] tracing | ❌ | |
| 3.7 Terraform, remote state + lock, env vars | ✅ | `local-exec` uses **PowerShell** (Windows-only), which blocks running Terraform in Linux CI |
| 3.7 [R] Helm, [D] ArgoCD | ❌ | Kustomize used instead |
| 3.8 Tags, budget, ADR, unit economics | ✅ | |
| 3.8 [R] Compute Optimizer review, [D] savings-plan model | ? | |
| 3.9 RTO/RPO doc | ✅ | |
| 3.9 **[M] RDS backups, 7-day retention** | ❌ | `rds_backup_retention_period = 0` in tfvars, while ADR-002, the DR plan and README all claim 7 days. A mandatory item with a contradicting doc |
| 3.9 [M] Velero or manifest export | ⚠️ | Export exists; demo checkpoint 9 says "restore from Velero" |
| 3.9 [R] Multi-AZ DB failover, [D] DNS failover | ❌ | ADR-002 says Single-AZ |
| Section 4: diagrams D1–D5 | ? | Not in the zips |
| Section 5.2: 10-15 page report | ? | Not in the zips |
| Repo hygiene | ⚠️ | `tfplan` binary committed (plans can embed secrets); account ID, teammate email and old repo name hard-coded in workflows, trust policy and backend |

### The one architecture decision that changes everything: Fargate vs EC2 node groups

The brief assumes **worker nodes**: `kubectl get nodes` shows 2+, ADR on instance type, node IAM role must be least-privilege, IMDSv2, cluster autoscaler, KEDA, Velero, Container Insights. The group built Fargate-only, so ADR-001 (t3.medium, Cluster Autoscaler 1-4 nodes) describes something that was never built. **Recommendation: EKS managed node group on EC2 (2x t3.medium).** It matches the rubric directly, makes ADR-001 true, enables the Recommended/Distinction items, and teaches far more (nodes, taints, SGs, IMDS, autoscaling).

---

## 2. Target repo split

```
cloudmart-app-source/            (app repo, CI builds images)
  services/<5 services>/  docker-compose.yml  .github/workflows/ci.yml

cloudmart-infra/                 (DevOps repo, evaluated by lecturer)
  infra/bootstrap/               state bucket + lock (local state, run once)
  infra/modules/{networking,security,data,messaging,eks,ecr,observability}
  infra/environments/{prod,staging}/
  k8s/  (base + overlays, later Helm/Argo)
  .github/workflows/             terraform plan/apply, deploy
  docs/adr/  docs/diagrams/  docs/report/  docs/runbooks/
  README.md  ROADMAP.md
```

**Pipeline shape (a good viva topic):** app-repo CI test → build → Trivy → push image tagged with commit SHA → opens/updates the image tag in the infra repo → infra-repo CD (or ArgoCD later) deploys. Rule: nothing ever deploys `:latest`.

---

## 3. How we work (this is how you learn it, not just finish it)

Every phase runs the same loop:

1. **Learn**: I explain the concept in ~10 minutes of reading with a diagram, tied to a specific AWS/K8s object.
2. **Predict**: you answer 2-3 questions *before* we build ("what happens to a pod in a private subnet that tries to reach the internet?").
3. **Build**: small Terraform/YAML steps. You write or modify it, I review (or I draft and you explain it back; your call).
4. **Break it**: we deliberately cause a failure (block a route, kill a pod, bad image) and read the symptoms.
5. **Explain back**: a viva-style question set per phase. If you can't answer it, we don't move on.

Every phase ends with an **evidence folder** (screenshots, command output) mapped to a demo checkpoint, so the report and demo are built as we go, not crammed at the end.

---

## 4. Phases

Cost note: with EKS + 2 nodes + NAT + ALB + RDS, expect roughly **$0.25-0.30 per hour while the stack is up** (about $170-200/month if left on). Apply when you work, destroy when you stop. Budget alert goes in first.

### Phase 0: Foundations (before any infra)
- Your own AWS account hygiene: no root usage, MFA, an admin IAM Identity Center/IAM user, billing alerts, **budget created first**.
- Tooling: AWS CLI, Terraform, kubectl, Helm, Docker, kubeconform, Trivy; pre-commit with `gitleaks`.
- Create both repos, branch strategy (`main`, `develop`, `feature/*`), `.gitignore` (state, plans, tfvars with secrets), branch protection.
- **Concepts:** IAM principals/policies, least privilege, why not to commit state/plans, branching ↔ environments.
- **Evidence:** budget screenshot, repo structure.

### Phase 1: App repo + containers (Brief 3.2)
- Consolidate app repo = starter + group's unit tests + CVE patch. Run `docker compose up`, hit every health endpoint.
- Read each Dockerfile line by line. Add/verify `.dockerignore`, non-root user, HEALTHCHECK.
- **Concepts:** image layers, multi-stage builds, why non-root, PID 1, healthcheck vs K8s probes, 12-factor config via env vars, the adapter pattern in the services.
- **Break it:** run as root, remove HEALTHCHECK, bloat the image; compare sizes and Trivy output.
- **Demo/ADR link:** feeds checkpoint 2 (end-to-end flow).

### Phase 2: Terraform foundations + Networking (3.1, 3.7)
- Bootstrap S3 state bucket + lock (explain the chicken-and-egg problem). Then modules: VPC /16, 2 AZs, public / private-app / private-data subnets, IGW, NAT, route tables, SGs (ALB, nodes, RDS, bastion with **your** IP only), DynamoDB gateway endpoint, Secrets Manager interface endpoint [R], flow logs → CloudWatch + Logs Insights query for REJECTs [D].
- **Concepts:** CIDR math, what makes a subnet "public", route tables, NAT vs IGW, SG (stateful) vs NACL (stateless), gateway vs interface endpoints and why they save NAT cost, remote state + locking, modules and variables.
- **Break it:** remove the NAT route, observe the failure; try to reach the DB from outside (this is checkpoint 3).
- **Diagram:** D1.

### Phase 3: Data, messaging, encryption (3.4, 3.9 part)
- KMS CMK, RDS PostgreSQL (private, SSL enforced, encrypted, **7-day backups**), DynamoDB (PITR), SQS + DLQ, Secrets Manager, SES sandbox identity.
- **Concepts:** envelope encryption, key policies, why RDS parameter group enforces SSL, at-rest vs in-transit, queue visibility timeout and DLQs, PITR vs snapshots.
- **ADR-002** (DB choice) written here with real reasoning.

### Phase 4: EKS cluster (3.3, 3.4)
- EKS control plane, **managed node group (EC2)**, node IAM role with only the 3 standard managed policies, IMDSv2 required with hop limit 1, OIDC provider, core add-ons, AWS Load Balancer Controller, External Secrets Operator.
- Replace PowerShell `local-exec` with portable logic (Helm provider / `kubectl` in CI).
- **Concepts:** control plane vs data plane, how nodes join, IRSA token exchange step by step, why IMDS exposure is dangerous, how an Ingress becomes an ALB.
- **ADR-001** (instance type) with real numbers for t3.medium / c6i.large / t4g.medium.
- **Evidence:** checkpoint 1 (`kubectl get nodes`).

### Phase 5: Workloads, scaling, network security (3.3, 3.4)
- Kustomize base + overlays (later optionally Helm [R]): Deployments (2 replicas, requests/limits, probes, maxSurge 1 / maxUnavailable 0), Services, Ingress + ACM + WAF, HPA, PDB, ConfigMaps, ExternalSecrets, ServiceAccounts with IRSA.
- NetworkPolicy: default-deny + each allowed path from the brief. **Enable and verify enforcement** (VPC CNI network policy or Calico) with a test pod that must be blocked.
- Cluster Autoscaler [R]; load test with `hey`/`k6` to watch HPA and node scale-out.
- **Concepts:** requests vs limits vs QoS, probe types and the restart/ready distinction, rollout math, HPA formula, PDB vs HPA vs autoscaler, NetworkPolicy semantics (additive allow, DNS egress gotcha).
- **Break it:** bad image tag (watch rolling update protect you), failing readiness probe, drain a node (PDB in action).
- **Diagrams:** D2, D3. **Checkpoints:** 4, 6.

### Phase 6: CI/CD (3.5)
- App repo CI: lint (proper flake8/eslint), unit tests, build, Trivy (fail on CRITICAL), push `:<sha>` to ECR (lifecycle: keep 10).
- Infra repo: `terraform fmt/validate/plan` on PR, manual-approved `apply`, kubeconform, deploy to staging on `develop` and prod on `main` with an Environment approval, rollout-status gate, smoke test, automatic rollback.
- GitHub OIDC → AWS with trust policies scoped to **your** repos/branches/environments.
- **Concepts:** OIDC federation vs long-lived keys, supply-chain risk (why the group pinned binaries), immutable tags, promotion vs rebuild, rollout semantics.
- **Diagram:** D4. **Checkpoint:** 5 (change homepage text → staging).

### Phase 7: Observability (3.6)
- Container Insights (works with EC2 nodes) or Prometheus + Grafana; Fluent Bit/CloudWatch logs per service; dashboard with CPU/mem per service, request rate, error rate, queue depth, DB connections; **alarm: product-service error rate > 5% over 5 min** → SNS email; custom `OrdersPerMinute` metric [R]; tracing with OpenTelemetry/X-Ray [D].
- **Concepts:** the four golden signals, metrics vs logs vs traces, metric filters, alarm evaluation periods, cardinality and cost.
- **Checkpoint:** 7 (trigger a 404, find it in Logs Insights).

### Phase 8: FinOps + DR (3.8, 3.9)
- Tags enforced via `default_tags`, cost allocation tags activated, Cost Explorer daily-by-tag report, budget, Compute Optimizer review [R], unit economics per 1,000 orders [R], 1-year savings-plan model [D].
- RTO/RPO with justification, **PITR restore into a test instance**, manifest backup via **Velero** (S3 + IRSA) and restore drill, RDS Multi-AZ failover [R], Route 53 health-check failover to a static S3 page [D].
- **Concepts:** RTO vs RPO, backup vs HA vs DR, shared-responsibility, on-demand vs savings plans vs spot.
- **Diagram:** D5. **Checkpoints:** 8, 9.

### Phase 9: Distinction items (pick by marginal value, not all)
Ordered by value per effort: (1) VPC flow logs + query (done in Phase 2), (2) Kyverno policies (no root, no privileged, registry allow-list), (3) KEDA on SQS depth for notification-service, (4) ArgoCD GitOps (fits the two-repo design), (5) Argo Rollouts canary with 1% error-rate gate, (6) savings-plan model, (7) DNS failover.

### Phase 10: Deliverables and viva readiness
- 3+ ADRs (Nygard format), 5 diagrams, 10-15 page report (8 sections), README with team/contribution statement written honestly (see below), AI-tool disclosure.
- Demo script rehearsal against the 10 checkpoints (timed to 20 min). Full viva question bank: every phase's "explain back" set, plus cross-cutting "why X instead of Y".

---

## 5. Things to settle early (flag to your lecturer/group where needed)

- **Contribution statement.** The group README lists four named owners per section. If you're submitting this alone, say so plainly in the README and keep the AI-tool disclosure accurate. Don't copy teammates' attributions onto work you redo.
- **Reuse vs rebuild.** Reusing teammates' code is a different thing from rebuilding it in your own account with your own understanding. Check with your lecturer whether solo submission and reuse of group artifacts are allowed.
- **Secrets/identifiers.** Nothing from the old repo should remain: account `939365917449`, the old state bucket name, `isuruij/CloudMart` in IAM trust, the teammate email in tags.

---

## 6. Order of attack if time gets tight
Mandatory first (Phases 0-8 cover all [M]), then Recommended, then at most 2-3 Distinction items. Evidence and diagrams are produced per phase, so a half-finished plan is still presentable.
