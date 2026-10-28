# ADR-001: Kubernetes Node Instance Type Selection


## Status
Accepted


## Context
CloudMart requires a managed Kubernetes cluster (Amazon EKS) with 2-3 worker nodes to run five microservices (product-service, order-service, user-service, notification-service, frontend). The workload is a student/demo environment with light traffic, but must support:
- 5 Deployments with 2 replicas each (10 pods minimum)
- Horizontal Pod Autoscaler (HPA) for product-service and order-service
- Resource requests/limits on every container
- Cluster Autoscaler scaling from 1 to 4 nodes


We need to select the EKS worker node instance type. To satisfy the assignment's explicit requirements, we must compare at least 3 machine types from AWS representing different compute architectures:
1. **General-Purpose (burstable):** `t3.medium` (x86_64)
2. **Compute-Optimised:** `c6i.large` (x86_64)
3. **ARM-based (burstable):** `t4g.medium` (ARM64 / Graviton2)


We must analyze their cost, vCPU/RAM ratio, and potential ARM savings to justify our final choice.


---


## Technical and Financial Comparison


| Machine Type | Architecture | vCPU | RAM (GiB) | Ratio (RAM/vCPU) | Hourly Cost | Monthly Cost (per node) | Price/Performance / Notes |
|---|---|---|---|---|---|---|---|
| **t3.medium** | x86_64 (Intel) | 2 | 4.0 | 2.0 GiB / vCPU | $0.0416 | ~$30.37 | Baseline general-purpose burstable instance. |
| **c6i.large** | x86_64 (Intel) | 2 | 4.0 | 2.0 GiB / vCPU | $0.0850 | ~$62.05 | Compute-optimised, non-burstable. Dedicated CPU. |
| **t4g.medium** | ARM64 (Graviton2) | 2 | 4.0 | 2.0 GiB / vCPU | $0.0336 | ~$24.53 | ARM-based burstable instance. **~19.2% ARM savings** over t3.medium. |


---


## Decision
We selected **t3.medium** (2 vCPU, 4 GiB RAM, $0.0416/hr) as our baseline EKS worker node machine type selection analysis.


With 2 nodes, this provides 4 vCPU and 8 GiB RAM total — enough to run all 10 pods with comfortable headroom. The burstable CPU model suits our bursty e-commerce workload (idle most of the time, occasional spikes during demos and load tests) without paying for dedicated compute-optimised instances.


*Note: During implementation, we deployed the workloads using AWS Fargate (serverless pods) to bypass EC2 Fleet Request quota restrictions on our student AWS account. However, this ADR establishes our baseline evaluation of EC2 instance types for the EKS compute backend.*


---


## Consequences


### Positive
- **Cost-effective:** ~$30.37/month per node, ~$60.74/month for a 2-node cluster — well within student budget constraints.
- **Sufficient resources:** 4 GiB RAM per node comfortably fits 5-6 pods per node with typical 256Mi-512Mi requests.
- **Burstable CPU:** Handles brief load spikes during demos and tests without paying for dedicated c6i.large compute-optimised instances.
- **Wide ecosystem support:** x86_64 architecture means all container images work without requiring ARM-specific builds or emulation.


### Negative
- **RAM limitation:** 4 GiB per node is tight if pods exceed their memory requests. After accounting for Kubernetes system overhead (~0.5 GiB per node), only ~3.5 GiB is available for application pods.
- **Burstable risk:** Sustained high CPU load consumes CPU credits. In production, credit exhaustion leads to throttling. (Acceptable for demo workloads).
- **No ARM savings:** We do not benefit from the 19.2% cost savings offered by Graviton2 instances.


---


## Alternatives Considered


### Alternative 1: c6i.large (Compute-Optimised, x86_64)
- **Monthly cost per node:** ~$62.05 (104% more expensive than t3.medium).
- **vCPU/RAM Ratio:** 2 vCPU and 4 GiB RAM (2.0 ratio).
- **Pros:** Dedicated CPU resources with no burst credit limitations or throttling risks. High network bandwidth.
- **Cons:** Extremely high idle cost for a small demonstration project.
- **Rejected because:** Cost is our primary constraint. The dedicated compute capacity of c6i.large is not required for a student application with low traffic.


### Alternative 2: t4g.medium (ARM-based/Graviton2)
- **Monthly cost per node:** ~$24.53 (**19.2% ARM savings** vs. t3.medium).
- **vCPU/RAM Ratio:** 2 vCPU and 4 GiB RAM (2.0 ratio).
- **Pros:** Cheapest hourly rate; superior price/performance; green compute.
- **Cons:** Requires building ARM64 (`linux/arm64`) container images in CI/CD, adding complexity:
  - Docker builds require Docker Buildx or QEMU emulation.
  - Team members running x86 laptops cannot run ARM images locally without emulation.
  - Potential runtime incompatibility or compilation overhead for older npm/pip dependencies without pre-built ARM wheels.
- **Rejected because:** The small absolute savings (~$11.68/month for a 2-node cluster) do not justify the added pipeline complexity and potential local emulation friction for a short-term student project. In a large production cluster with dozens of nodes, Graviton2 (ARM) would be our final recommended choice.


