output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.easytrade.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.easytrade.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.easytrade.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.easytrade.public_ip}"
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.easytrade_sg.id
}

