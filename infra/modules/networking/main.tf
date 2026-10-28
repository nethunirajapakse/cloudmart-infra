# =============================================================================
# CloudMart Networking Module
# Provisions a three-tier VPC across 2 Availability Zones.
#
# Tier layout (per AZ):
#   Public      — ALB, NAT Gateway, Bastion host
#   Private App — EKS worker nodes
#   Private Data— RDS PostgreSQL (no internet route)
#
# Security group design follows principle of least privilege:
#   alb         → internet (80, 443 in only)
#   eks_nodes   → from ALB + self (pod-to-pod), all egress
#   rds         → from EKS nodes on 5432 only, no egress
#   bastion     → SSH from admin CIDR only
# =============================================================================

# --- VPC ---

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Required for EKS and private DNS resolution
  enable_dns_hostnames = true # Required for RDS endpoint resolution

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# --- Public Subnets ---
# One per AZ. Houses the ALB, NAT Gateway, and optional bastion host.
# map_public_ip_on_launch allows bastion to get a public IP automatically.

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                        = "${var.project}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/role/elb"                    = "1" # ALB controller uses this tag to place external load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# --- Private Application Subnets ---
# One per AZ. Houses EKS worker nodes.
# No public IPs — egress goes through NAT Gateway.

resource "aws_subnet" "private_app" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.project}-${var.environment}-private-app-${var.availability_zones[count.index]}"
    Tier                                        = "private-app"
    "kubernetes.io/role/internal-elb"           = "1" # ALB controller uses this for internal load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# --- Private Data Subnets ---
# One per AZ. Houses RDS PostgreSQL.
# No internet route at all — completely isolated from public internet.

resource "aws_subnet" "private_data" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-data-${var.availability_zones[count.index]}"
    Tier = "private-data"
  })
}

# --- Internet Gateway ---
# Enables two-way internet access for resources in public subnets.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# --- NAT Gateway ---
# Single NAT GW in the first public subnet (cost optimisation).
# Private App subnets use this for outbound-only internet access
# (pulling container images from ECR, reaching AWS APIs).

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # First public subnet

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat"
  })
}

# --- Route Tables ---

# Public Route Table
# Default route → Internet Gateway. Subnets in this tier can reach and be reached from internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-public-rt"
    Tier = "public"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private App Route Table
# Default route → NAT Gateway. Nodes can reach internet (outbound only) for image pulls.
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-app-rt"
    Tier = "private-app"
  })
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# Private Data Route Table
# No default route — RDS has zero internet access. Traffic stays within the VPC only.
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-private-data-rt"
    Tier = "private-data"
  })
}

resource "aws_route_table_association" "private_data" {
  count          = length(aws_subnet.private_data)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# =============================================================================
# Security Groups
# All groups follow principle of least privilege — only ports and sources
# required for the service to function are explicitly allowed.
# =============================================================================

# --- ALB Security Group ---
# Justification: The internet-facing load balancer must accept HTTP (for
# redirect to HTTPS) and HTTPS. All other inbound traffic is blocked.
# Egress is unrestricted so it can forward requests to any pod IP in the VPC.

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "ALB: inbound 80+443 from internet; egress to EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP - redirects to HTTPS at ALB level"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS - TLS terminated at ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to pod IPs on EKS nodes (IP target mode)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-alb-sg"
  })
}

# --- EKS Worker Nodes Security Group ---
# Justification: Nodes accept traffic from the ALB (for pod requests) and from
# each other (for CNI pod networking and Kubernetes control plane traffic).
# Egress is unrestricted: nodes must pull images from ECR, call SQS/DynamoDB
# APIs, and reach the EKS control plane.
# Note: EKS managed node groups automatically add the cluster API SG rules.

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-${var.environment}-eks-nodes-sg"
  description = "EKS nodes: inbound from ALB + node-to-node; unrestricted egress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "All traffic from ALB (routes to pods in IP target mode)"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Node-to-node: pod networking (CNI) and Kubernetes internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Unrestricted egress: ECR pulls, AWS API calls, DNS, SQS, DynamoDB"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eks-nodes-sg"
  })
}

# --- RDS Security Group ---
# Justification: Only user-service (running on EKS nodes) needs PostgreSQL
# access on port 5432. The EKS module adds a separate Fargate ingress rule for
# pod ENIs. RDS never initiates connections so no egress rules are required.

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "RDS PostgreSQL: port 5432 from EKS nodes only; no egress"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EKS nodes (user-service to RDS)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-rds-sg"
  })

  lifecycle {
    ignore_changes = [ingress]
  }
}

# --- Bastion Host Security Group ---
# Justification: Bastion provides emergency SSH access to private resources.
# Restricted to admin_cidr only. Set admin_cidr to your specific IP (/32)
# rather than 0.0.0.0/0 in production.

resource "aws_security_group" "bastion" {
  name        = "${var.project}-${var.environment}-bastion-sg"
  description = "Bastion: SSH from admin CIDR only; egress into VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator IP/CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Allow bastion to reach internal VPC resources (RDS, nodes)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-bastion-sg"
  })
}

# =============================================================================
# VPC Endpoints (Recommended requirement — private connectivity)
# =============================================================================

# DynamoDB Gateway Endpoint (FREE — no hourly charge, no data-processing charge)
# Routes all DynamoDB traffic through the AWS backbone instead of NAT Gateway.
# This eliminates NAT data-transfer costs for product-service ↔ DynamoDB traffic.

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app.id,
    aws_route_table.private_data.id,
    aws_route_table.public.id,
  ]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-dynamodb-endpoint"
  })
}

