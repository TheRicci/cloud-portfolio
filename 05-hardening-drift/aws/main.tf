data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  user_data = templatefile("${path.module}/../common/cloud-init.yaml.tftpl", {
    repo_url           = var.repo_url
    repo_sha           = var.repo_sha
    project_dir        = var.project_dir
    pull_interval_min  = var.pull_interval_min
    weak_baseline      = var.weak_baseline
    ansible_bundle_b64 = var.ansible_bundle_b64
  })
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.77.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "hardening-lab-${var.session_id}" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = "hardening-lab-${var.session_id}" }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.lab.id
  cidr_block = "10.77.0.0/25"

  tags = { Name = "hardening-lab-public-${var.session_id}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "hardening-lab-public-${var.session_id}" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "lab" {
  name        = "hardening-lab-${var.session_id}"
  description = "SSH and the decoy port from one address only"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from the tester"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Decoy listener, to show the host firewall closes it"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Outbound for packages and git"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hardening-lab-${var.session_id}" }
}

resource "aws_key_pair" "lab" {
  key_name   = "hardening-lab-${var.session_id}"
  public_key = var.ssh_public_key
}

resource "aws_instance" "lab" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.lab.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = true

  volume_tags = {
    project = "hardening-lab"
    session = var.session_id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "hardening-lab-${var.session_id}" }
}
