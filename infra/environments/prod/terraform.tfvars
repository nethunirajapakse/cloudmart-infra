# =============================================================================
# Production Environment Variables
# =============================================================================

aws_region  = "us-east-1"
environment = "prod"

team_id     = "your-team-id"
owner_email = "you@example.com"

# --- Trusted HTTPS ---
# The raw *.elb.amazonaws.com URL cannot show a browser-trusted lock with your
# own certificate. For a secure browser URL, buy/use a real domain, create a
# public Route 53 hosted zone for it, then set these two values.
custom_domain_name = ""
route53_zone_id    = ""

# Optional alternative: paste an existing ISSUED ACM certificate ARN for the
# custom domain instead of letting Terraform create and validate one.
acm_certificate_arn = ""

# --- Networking ---
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]
private_data_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]

cluster_name = "cloudmart-prod"
admin_cidr   = "0.0.0.0/0"

# --- Database ---
db_instance_class           = "db.t3.micro"
rds_backup_retention_period = 0
enable_guardduty            = false

# --- EKS (ADR-001: t3.medium chosen over t3.large and t4g.medium) ---
node_instance_type = "t3.medium"
node_min_count     = 2
node_desired_count = 2
node_max_count     = 3
