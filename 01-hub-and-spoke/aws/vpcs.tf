# Inspection VPC and workload spokes. No subnet assigns public addresses.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "hub" {
  cidr_block           = var.hub_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-inspection-${var.prefix}" }
}

resource "aws_subnet" "hub_tgw" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = var.hub_tgw_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "snet-inspection-tgw-${var.prefix}" }
}

resource "aws_subnet" "hub_nva" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = var.hub_nva_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "snet-inspection-nva-${var.prefix}" }
}

resource "aws_vpc" "spoke1" {
  cidr_block           = var.spoke1_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-spoke1-${var.prefix}" }
}

resource "aws_subnet" "spoke1" {
  vpc_id            = aws_vpc.spoke1.id
  cidr_block        = var.spoke1_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "snet-spoke1-${var.prefix}" }
}

resource "aws_vpc" "spoke2" {
  cidr_block           = var.spoke2_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-spoke2-${var.prefix}" }
}

resource "aws_subnet" "spoke2" {
  vpc_id            = aws_vpc.spoke2.id
  cidr_block        = var.spoke2_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "snet-spoke2-${var.prefix}" }
}

# The spoke route tables have no default route. Only remote-spoke destinations
# enter the TGW; SSM uses PrivateLink endpoints in the local VPC.
resource "aws_route_table" "spoke1" {
  vpc_id = aws_vpc.spoke1.id
  route {
    cidr_block         = var.spoke2_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
  tags = { Name = "rt-spoke1-${var.prefix}" }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke1]
}

resource "aws_route_table_association" "spoke1" {
  subnet_id      = aws_subnet.spoke1.id
  route_table_id = aws_route_table.spoke1.id
}

resource "aws_route_table" "spoke2" {
  vpc_id = aws_vpc.spoke2.id
  route {
    cidr_block         = var.spoke1_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
  tags = { Name = "rt-spoke2-${var.prefix}" }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke2]
}

resource "aws_route_table_association" "spoke2" {
  subnet_id      = aws_subnet.spoke2.id
  route_table_id = aws_route_table.spoke2.id
}

# A packet arriving from the TGW is sent to the NVA. A packet forwarded by the
# NVA returns to the TGW, which delivers it to the destination spoke.
resource "aws_route_table" "hub_tgw" {
  vpc_id = aws_vpc.hub.id
  tags   = { Name = "rt-inspection-tgw-${var.prefix}" }
}

resource "aws_route_table_association" "hub_tgw" {
  subnet_id      = aws_subnet.hub_tgw.id
  route_table_id = aws_route_table.hub_tgw.id
}

resource "aws_route_table" "hub_nva" {
  vpc_id = aws_vpc.hub.id
  route {
    cidr_block         = var.spoke1_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
  route {
    cidr_block         = var.spoke2_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }
  tags = { Name = "rt-inspection-nva-${var.prefix}" }
}

resource "aws_route_table_association" "hub_nva" {
  subnet_id      = aws_subnet.hub_nva.id
  route_table_id = aws_route_table.hub_nva.id
}

