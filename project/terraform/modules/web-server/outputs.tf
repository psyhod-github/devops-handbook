output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.this.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.this.id
}
