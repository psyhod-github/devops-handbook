output "server_url" {
  description = "Open in browser (nginx needs 1-2 minutes after apply)"
  value       = "http://${module.web_server.public_ip}"
}

output "ssh_command" {
  description = "Connect via SSH"
  value       = "ssh -i ${trimsuffix(var.public_key_path, ".pub")} ec2-user@${module.web_server.public_ip}"
}

output "public_ip" {
  description = "Public IP (for Ansible inventory, chapters 13-14)"
  value       = module.web_server.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.web_server.instance_id
}
