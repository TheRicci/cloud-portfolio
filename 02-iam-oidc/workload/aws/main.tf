data "aws_caller_identity" "current" {}

# Minimal isolated VPC for the showcase VM
resource "aws_vpc" "showcase" {
  cidr_block           = "10.42.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "oidc-showcase-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "showcase" {
  vpc_id            = aws_vpc.showcase.id
  cidr_block        = "10.42.0.0/28"
  availability_zone = "${var.region}a"

  tags = {
    Name        = "oidc-showcase-subnet"
    Environment = var.environment
  }
}

resource "aws_security_group" "showcase" {
  name        = "oidc-showcase-sg"
  description = "Security group for OIDC showcase VM"
  vpc_id      = aws_vpc.showcase.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "oidc-showcase-sg"
    Environment = var.environment
  }
}

# Lookup Amazon Linux 2023 AMI via SSM parameter (standard AWS official image)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "showcase_vm" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.nano"
  subnet_id              = aws_subnet.showcase.id
  vpc_security_group_ids = [aws_security_group.showcase.id]

  tags = {
    Name        = "oidc-showcase-vm"
    Environment = var.environment
    DeployedBy  = data.aws_caller_identity.current.arn
  }
}
