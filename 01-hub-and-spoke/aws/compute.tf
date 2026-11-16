# Private test workloads, a stateful inspection NVA, and the VPC endpoints
# required to manage every instance without internet access or public IPs.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_prefix_list" "s3" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.region}.s3"]
  }
}

resource "aws_iam_role" "ssm" {
  name = "role-ssm-${var.prefix}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "profile-ssm-${var.prefix}"
  role = aws_iam_role.ssm.name
}

resource "aws_security_group" "nva" {
  # AWS reserves the sg- prefix for generated security-group IDs.
  name   = "secgrp-nva-${var.prefix}"
  vpc_id = aws_vpc.hub.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.spoke1_cidr, var.spoke2_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.spoke1_cidr, var.spoke2_cidr]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.hub_cidr]
  }
  egress {
    description     = "Download AL2023 packages through the S3 gateway endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
  }
  tags = { Name = "sg-nva-${var.prefix}" }
}

resource "aws_security_group" "spoke1" {
  name   = "secgrp-spoke1-${var.prefix}"
  vpc_id = aws_vpc.spoke1.id
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.spoke2_cidr]
  }
  egress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.spoke2_cidr]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.spoke1_cidr]
  }
  tags = { Name = "sg-spoke1-${var.prefix}" }
}

resource "aws_security_group" "spoke2" {
  name   = "secgrp-spoke2-${var.prefix}"
  vpc_id = aws_vpc.spoke2.id
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.spoke1_cidr]
  }
  egress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.spoke1_cidr]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.spoke2_cidr]
  }
  tags = { Name = "sg-spoke2-${var.prefix}" }
}

locals {
  endpoint_vpcs = {
    hub    = { id = aws_vpc.hub.id, cidr = var.hub_cidr, subnet = aws_subnet.hub_nva.id }
    spoke1 = { id = aws_vpc.spoke1.id, cidr = var.spoke1_cidr, subnet = aws_subnet.spoke1.id }
    spoke2 = { id = aws_vpc.spoke2.id, cidr = var.spoke2_cidr, subnet = aws_subnet.spoke2.id }
  }
  ssm_services = toset(["ssm", "ssmmessages", "ec2messages"])
  endpoint_targets = merge([
    for name, vpc in local.endpoint_vpcs : {
      for service in local.ssm_services : "${name}-${service}" => merge(vpc, { service = service, name = name })
    }
  ]...)
}

resource "aws_security_group" "ssm_endpoint" {
  for_each = local.endpoint_vpcs
  name     = "secgrp-ssm-endpoint-${each.key}-${var.prefix}"
  vpc_id   = each.value.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [each.value.cidr]
  }
  tags = { Name = "sg-ssm-endpoint-${each.key}-${var.prefix}" }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each            = local.endpoint_targets
  vpc_id              = each.value.id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [each.value.subnet]
  security_group_ids  = [aws_security_group.ssm_endpoint[each.value.name].id]
  tags                = { Name = "vpce-${each.key}-${var.prefix}" }
}

# AL2023 repositories are hosted in S3. This gateway endpoint lets the private
# NVA install the firewall package without a NAT Gateway or public IP.
resource "aws_vpc_endpoint" "al2023_repository" {
  vpc_id            = aws_vpc.hub.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.hub_nva.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::al2023-repos-${var.region}-de612dc2",
        "arn:aws:s3:::al2023-repos-${var.region}-de612dc2/*"
      ]
    }]
  })

  tags = { Name = "vpce-al2023-repository-${var.prefix}" }
}

resource "aws_instance" "nva" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.hub_nva.id
  vpc_security_group_ids      = [aws_security_group.nva.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = false
  source_dest_check           = false
  user_data                   = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf install -y iptables-nft
    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    iptables -P INPUT DROP
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -F FORWARD
    iptables -P FORWARD DROP
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -s ${var.spoke1_cidr} -d ${var.spoke2_cidr} -p tcp --dport 8443 -m conntrack --ctstate NEW -j ACCEPT
    iptables -A FORWARD -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix 'NVA-FORWARD-DROP: ' --log-level 4
  EOF
  tags                        = { Name = "vm-nva-${var.prefix}" }

  depends_on = [aws_vpc_endpoint.al2023_repository]
}

resource "aws_route" "tgw_to_nva_spoke1" {
  route_table_id         = aws_route_table.hub_tgw.id
  destination_cidr_block = var.spoke1_cidr
  network_interface_id   = aws_instance.nva.primary_network_interface_id
}

resource "aws_route" "tgw_to_nva_spoke2" {
  route_table_id         = aws_route_table.hub_tgw.id
  destination_cidr_block = var.spoke2_cidr
  network_interface_id   = aws_instance.nva.primary_network_interface_id
}

resource "aws_instance" "spoke1" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.spoke1.id
  vpc_security_group_ids      = [aws_security_group.spoke1.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = false
  user_data                   = "#!/bin/bash\nnohup python3 -m http.server 8443 --bind 0.0.0.0 >/var/log/test-service.log 2>&1 &"
  tags                        = { Name = "vm-spoke1-${var.prefix}" }
}

resource "aws_instance" "spoke2" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.spoke2.id
  vpc_security_group_ids      = [aws_security_group.spoke2.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = false
  user_data                   = "#!/bin/bash\nnohup python3 -m http.server 8443 --bind 0.0.0.0 >/var/log/test-service.log 2>&1 &"
  tags                        = { Name = "vm-spoke2-${var.prefix}" }
}
