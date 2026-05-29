locals {
  common_tags = {
    Project     = var.project_name
    Owner       = var.owner
    Environment = var.environment
    Purpose     = "tgw-segmentation-routing-study"
  }

  vpcs = {
    prod = {
      name   = "prod-app-vpc"
      cidr   = "10.10.0.0/16"
      subnet = "10.10.10.0/24"
    }
    shared = {
      name   = "shared-services-vpc"
      cidr   = "10.20.0.0/16"
      subnet = "10.20.10.0/24"
    }
    dev = {
      name   = "dev-app-vpc"
      cidr   = "10.30.0.0/16"
      subnet = "10.30.10.0/24"
    }
  }

  # VPC route tables send remote lab CIDRs to TGW.
  # TGW route tables then decide whether the destination is allowed or blackholed.
  vpc_tgw_routes = {
    prod   = ["10.20.0.0/16", "10.30.0.0/16"]
    shared = ["10.10.0.0/16", "10.30.0.0/16"]
    dev    = ["10.10.0.0/16", "10.20.0.0/16"]
  }

  vpc_tgw_route_entries = flatten([
    for vpc_key, cidrs in local.vpc_tgw_routes : [
      for cidr in cidrs : {
        key     = "${vpc_key}-${replace(cidr, "/", "-")}"
        vpc_key = vpc_key
        cidr    = cidr
      }
    ]
  ])

  tgw_propagations = {
    shared_to_prod_rt = {
      attachment_key  = "shared"
      route_table_key = "prod"
    }
    shared_to_dev_rt = {
      attachment_key  = "shared"
      route_table_key = "dev"
    }
    prod_to_shared_rt = {
      attachment_key  = "prod"
      route_table_key = "shared"
    }
    dev_to_shared_rt = {
      attachment_key  = "dev"
      route_table_key = "shared"
    }
  }

  endpoint_services = toset([
    "ssm",
    "ssmmessages",
    "ec2messages"
  ])

  validation_pairs = {
    prod_to_shared = {
      source = "prod"
      target = "shared"
      expect = "allowed"
    }
    dev_to_shared = {
      source = "dev"
      target = "shared"
      expect = "allowed"
    }
    shared_to_prod = {
      source = "shared"
      target = "prod"
      expect = "allowed"
    }
    shared_to_dev = {
      source = "shared"
      target = "dev"
      expect = "allowed"
    }
    prod_to_dev = {
      source = "prod"
      target = "dev"
      expect = "blocked"
    }
    dev_to_prod = {
      source = "dev"
      target = "prod"
      expect = "blocked"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "this" {
  for_each = local.vpcs

  cidr_block           = each.value.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-${each.value.name}"
    Segment = each.key
  }
}

resource "aws_subnet" "workload" {
  for_each = local.vpcs

  vpc_id                  = aws_vpc.this[each.key].id
  cidr_block              = each.value.subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.project_name}-${each.key}-workload-private-1"
    Segment = each.key
    Role    = "workload"
  }
}

resource "aws_route_table" "workload" {
  for_each = local.vpcs

  vpc_id = aws_vpc.this[each.key].id

  tags = {
    Name    = "${var.project_name}-${each.key}-workload-rt"
    Segment = each.key
    Role    = "workload"
  }
}

resource "aws_route_table_association" "workload" {
  for_each = local.vpcs

  subnet_id      = aws_subnet.workload[each.key].id
  route_table_id = aws_route_table.workload[each.key].id
}

resource "aws_ec2_transit_gateway" "core" {
  description                     = "${var.project_name} core TGW"
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "${var.project_name}-core-tgw"
  }
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = local.vpcs

  transit_gateway_id = aws_ec2_transit_gateway.core.id

  tags = {
    Name    = "${var.project_name}-tgw-${each.key}-rt"
    Segment = each.key
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = local.vpcs

  subnet_ids                                      = [aws_subnet.workload[each.key].id]
  transit_gateway_id                              = aws_ec2_transit_gateway.core.id
  vpc_id                                          = aws_vpc.this[each.key].id
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name    = "${var.project_name}-${each.key}-tgw-attachment"
    Segment = each.key
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.key].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.tgw_propagations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table_key].id
}

resource "aws_ec2_transit_gateway_route" "prod_to_dev_blackhole" {
  destination_cidr_block         = local.vpcs.dev.cidr
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this["prod"].id
}

resource "aws_ec2_transit_gateway_route" "dev_to_prod_blackhole" {
  destination_cidr_block         = local.vpcs.prod.cidr
  blackhole                      = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this["dev"].id
}

resource "aws_route" "vpc_to_tgw" {
  for_each = {
    for route in local.vpc_tgw_route_entries : route.key => route
  }

  route_table_id         = aws_route_table.workload[each.value.vpc_key].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.core.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this
  ]
}

resource "aws_security_group" "endpoint" {
  for_each = local.vpcs

  name        = "${var.project_name}-${each.key}-ssm-endpoint-sg"
  description = "Allow private validation instances to reach SSM interface endpoints"
  vpc_id      = aws_vpc.this[each.key].id

  ingress {
    description = "HTTPS from local VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [each.value.cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-${each.key}-ssm-endpoint-sg"
    Segment = each.key
  }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = {
    for pair in setproduct(keys(local.vpcs), local.endpoint_services) :
    "${pair[0]}-${pair[1]}" => {
      vpc_key = pair[0]
      service = pair[1]
    }
  }

  vpc_id              = aws_vpc.this[each.value.vpc_key].id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.workload[each.value.vpc_key].id]
  security_group_ids  = [aws_security_group.endpoint[each.value.vpc_key].id]
  private_dns_enabled = true

  tags = {
    Name    = "${var.project_name}-${each.value.vpc_key}-${each.value.service}-endpoint"
    Segment = each.value.vpc_key
    Service = each.value.service
  }
}

resource "aws_security_group" "validation" {
  for_each = var.enable_validation_instances ? local.vpcs : {}

  name        = "${var.project_name}-${each.key}-validation-sg"
  description = "Allow lab validation traffic through TGW"
  vpc_id      = aws_vpc.this[each.key].id

  ingress {
    description = "ICMP from lab CIDRs"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [for vpc in values(local.vpcs) : vpc.cidr]
  }

  ingress {
    description = "HTTP test service from lab CIDRs"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [for vpc in values(local.vpcs) : vpc.cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-${each.key}-validation-sg"
    Segment = each.key
  }
}

resource "aws_iam_role" "ssm" {
  count = var.enable_validation_instances ? 1 : 0

  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_validation_instances ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_validation_instances ? 1 : 0

  name = "${var.project_name}-ssm-instance-profile"
  role = aws_iam_role.ssm[0].name
}

resource "aws_instance" "validation" {
  for_each = var.enable_validation_instances ? local.vpcs : {}

  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.workload[each.key].id
  vpc_security_group_ids      = [aws_security_group.validation[each.key].id]
  iam_instance_profile        = aws_iam_instance_profile.ssm[0].name
  associate_public_ip_address = false

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    mkdir -p /opt/tgw-lab
    cat > /opt/tgw-lab/index.html <<'EOF'
    ${each.key} validation host responding through ${var.project_name}
    EOF
    nohup python3 -m http.server 8080 --directory /opt/tgw-lab --bind 0.0.0.0 >/var/log/tgw-lab-http.log 2>&1 &
  USERDATA

  metadata_options {
    http_tokens = "required"
  }

  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_iam_role_policy_attachment.ssm
  ]

  tags = {
    Name    = "${var.project_name}-${each.key}-validation-host"
    Segment = each.key
    Role    = "validation"
  }
}

