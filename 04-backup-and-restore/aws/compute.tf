data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# --- Data disk (separate EBS for Postgres) ---

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 4
  type              = "gp3"
  encrypted         = true

  tags = {
    Name    = "${var.name_prefix}-data"
    project = "backup-lab"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.vm.id

  # Let Terraform detach on destroy even if the instance is gone.
  force_detach = true
}

# --- EC2 instance ---

resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/../workload/cloud-init.yaml.tftpl", {
    data_disk_device = "/dev/nvme1n1"
    writer_go_source = file("${path.module}/../workload/writer/main.go")
    writer_go_mod    = file("${path.module}/../workload/writer/go.mod")
    writer_go_sum    = file("${path.module}/../workload/writer/go.sum")
    cli_install_cmd  = "curl -s 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o '/tmp/awscliv2.zip' && unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/awscliv2.zip /tmp/aws"
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = 8
  }

  tags = {
    Name    = "${var.name_prefix}-vm"
    project = "backup-lab"
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
