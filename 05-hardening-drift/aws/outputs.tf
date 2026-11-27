output "public_ip" {
  value = aws_instance.lab.public_ip
}

output "ssh_user" {
  value = "ubuntu"
}
