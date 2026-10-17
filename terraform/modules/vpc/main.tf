locals {
  az_count             = length(var.azs)
  public_subnet_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.cidr_block, 4, i)]
  private_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.cidr_block, 4, i + local.az_count)]

  common_tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

# --- Public subnets ---
resource "aws_subnet" "public" {
  for_each                = { for idx, az in var.azs : az => idx }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[each.value]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"                    = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- Private subnets ---
resource "aws_subnet" "private" {
  for_each          = { for idx, az in var.azs : az => idx }
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[each.value]
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name                                        = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  })
}

# --- NAT Gateway(s) ---
resource "aws_eip" "nat" {
  for_each = var.single_nat_gateway ? { primary = tolist(var.azs)[0] } : { for az in var.azs : az => az }
  domain   = "vpc"

  tags = merge(local.common_tags, { Name = "${var.name}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each      = var.single_nat_gateway ? { primary = tolist(var.azs)[0] } : { for az in var.azs : az => az }
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = merge(local.common_tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  for_each = { for idx, az in var.azs : az => idx }
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this["primary"].id : aws_nat_gateway.this[each.key].id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-private-rt-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# --- VPC Endpoints ---
data "aws_region" "current" {}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpce-sg"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name}-vpce-sg" })
}

locals {
  interface_endpoints = ["ecr.api", "ecr.dkr", "sts", "ec2", "logs"]
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_endpoints)
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpce-${each.value}" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], [for rt in aws_route_table.private : rt.id])

  tags = merge(local.common_tags, { Name = "${var.name}-vpce-s3" })
}

# --- Flow Logs ---
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc-flow-logs/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-vpc-flow-logs-policy"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  tags = local.common_tags
}
