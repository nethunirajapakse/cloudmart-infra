# ADR-003: Deployment Strategy

## Status
Accepted

## Context
CloudMart runs a suite of microservices deployed onto Amazon EKS. As developers merge code, updates must be pushed to staging and production.
We need to define a deployment strategy that:
- Ensures high availability and zero downtime during updates.
- Minimizes compute resource spikes during rollouts (to stay within cost limits).
- Remains simple to configure and manage (low operational complexity).
- Ensures traffic is only directed to healthy, fully initialized application pods.

## Decision
We selected the native Kubernetes **Rolling Update** deployment strategy for all production microservices.

Our standard deployment configuration includes:
- **Replica Count**: A minimum of 2 replicas per deployment to support rolling updates and avoid single points of failure.
- **Max Unavailable (`maxUnavailable`)**: Set to `0`. This guarantees that 100% of the desired replica capacity remains online and serving traffic throughout the update.
- **Max Surge (`maxSurge`)**: Set to `1`. This limits the creation of temporary extra pods during updates to a single pod, minimizing resource spikes.
- **Health Probes**: Mandatory `livenessProbe` and `readinessProbe` on all containers. Probes ensure that traffic is not routed to a new pod until it is fully started and ready, and that old pods are only terminated once the new ones are functional.

## Consequences

### Positive
- **Zero-Downtime Rollouts**: New containers are started and verified ready before any old containers are terminated.
- **Resource & Cost Efficiency**: The surge limit of `1` ensures that we only request minimal extra CPU and memory from our EKS nodes/Fargate profile during rollouts, avoiding cluster auto-scaling spikes and extra costs.
- **Low Complexity**: Native Kubernetes functionality requires no extra service meshes, ingress controllers, or custom deployment engines (like ArgoCD or Flagger).

### Negative
- **Mixed-Version Window**: During the rollout process, both the old and new versions of the service are active and receiving traffic simultaneously. The APIs and database schemas must remain backward-compatible to prevent user-facing errors during this transition.
- **Deployment Duration**: Replacing replicas sequentially takes longer than a brute-force recreate, though this remains well within acceptable limits (usually less than 3 minutes per service).

## Alternatives Considered

### Alternative 1: Recreate Strategy
- **Pros**: Simplest rollout mechanism. Guarantees that only one version of the application code is running at any given time, eliminating mixed-version compatibility risks.
- **Cons**: Terminates all existing pods before starting new ones, resulting in absolute service downtime during updates.
- **Rejected because**: Zero-downtime is a fundamental production requirement for the CloudMart e-commerce app.

### Alternative 2: Blue/Green Deployment
- **Pros**: Instantaneous traffic cutover, clean separation of versions, and rapid rollback capability.
- **Cons**: Requires provisioning a complete duplicate environment (another 100% compute capacity) during the deployment window. This would temporarily double EKS worker node/Fargate costs and trigger resource limits.
- **Rejected because**: The cost and configuration complexity of managing a duplicate cluster state is unjustified for the scale of CloudMart.

### Alternative 3: Canary Deployment (via Argo Rollouts / Linkerd)
- **Pros**: Advanced safety; routes a tiny fraction of live traffic (e.g., 5%) to the new version to monitor metrics before full rollout.
- **Cons**: Requires importing custom resource definitions (CRDs), deploying a service mesh or ingress controller with traffic splitting capabilities, and maintaining complex rollback logic.
- **Rejected because**: The operational complexity and resource overhead of a canary rollout engine exceed our team's maintenance capacity and the requirements of the project.
