# ADR-002: Database for user-service

## Status
Accepted

## Context
CloudMart's `user-service` manages user registration, user profiles, credentials, and roles. The workload requires:
- Relational integrity (e.g., uniqueness constraints on email addresses).
- Standard ACID transaction guarantees for secure authentication.
- Seamless integration with standard authentication libraries and ORMs.
- Strict data security (credentials encryption at rest and in transit).

We need to select a database technology and hosting model on AWS that satisfies these technical requirements while staying within student/demo budget constraints.

## Decision
We selected **Amazon RDS PostgreSQL** (using a `db.t3.micro` instance class) as the database engine for `user-service`.

To support this choice, we:
- Provisioned a Single-AZ RDS instance in our private data subnets, securing it behind specific security groups.
- Configured data-at-rest encryption using a Customer Managed Key (CMK) in AWS KMS.
- Enabled SSL enforcement for all client connections.
- Set a 7-day backup retention period to meet disaster recovery goals.

## Consequences

### Positive
- **Relational Integrity**: PostgreSQL provides native support for structured schemas, relational joins, unique indexes, and ACID compliance, which are critical for robust authentication.
- **Developer Familiarity & Ecosystem**: PostgreSQL is an industry standard; Python's `psycopg2` driver is highly mature and reliable.
- **Cost Efficiency**: At ~$15/month for `db.t3.micro`, the cost is manageable within our demo environment and is eligible for the AWS Free Tier.
- **Integrated Backups**: Supports automatic daily snapshots and continuous transaction log archiving (write-ahead logs) to S3, enabling Point-in-Time Recovery (PITR).

### Negative
- **Network Complexity**: Being a relational database in a private subnet, it requires a database subnet group, security groups, and routing tables, which increases IaC configuration compared to a public serverless database.
- **Fixed Infrastructure Cost**: Unlike NoSQL on-demand billing, RDS incurs a flat hourly charge regardless of actual usage or traffic.
- **Single-AZ Limitation**: Due to cost limitations, the primary deployment is Single-AZ. An AZ outage would require restoring the database from snapshots, resulting in a longer recovery time compared to a Multi-AZ deployment.

## Alternatives Considered

### Alternative 1: Amazon DynamoDB (NoSQL)
- **Monthly Cost**: On-demand / Pay-per-request pricing (estimated <$0.50/month for our traffic).
- **Pros**: Extremely low cost, zero database server management, instant serverless scaling.
- **Cons**: Lacks structured schema enforcement and native relational constraints. Implementing unique constraint checks (e.g., ensuring an email address is only registered once) requires complex transaction write requests (`TransactWriteItems`) or duplicate tracking tables.
- **Rejected because**: The application-level development complexity required to safely manage user credentials and uniqueness constraints in a NoSQL store outweighs the small monthly savings.

### Alternative 2: Amazon Aurora Serverless v2 (PostgreSQL Compatible)
- **Monthly Cost**: Scale of 0.5 to 128 ACUs (Aurora Capacity Units) starts at ~$40-50/month.
- **Pros**: Instant, automatic vertical scaling based on CPU and memory usage, built-in storage replication.
- **Cons**: High minimum cost (~3x the cost of a standard `db.t3.micro` instance) even when completely idle.
- **Rejected because**: The scaling capabilities of Aurora Serverless are unnecessary for our light demo traffic, and the cost exceeds our project budget.
