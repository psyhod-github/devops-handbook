variable "name" {
  description = "Name prefix for the key pair, security group and instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR allowed to connect via SSH"
  type        = string
}

variable "install_nginx" {
  description = "Install nginx via User Data (false = bare server, e.g. for Ansible in chapters 13-14)"
  type        = bool
  default     = true
}

variable "page_message" {
  description = "Text for the nginx index page"
  type        = string
  default     = "Hello from Terraform!"
}
