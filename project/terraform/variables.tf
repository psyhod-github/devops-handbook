variable "aws_profile" {
  description = "AWS CLI profile (chapter 03-04)"
  type        = string
  default     = "devops-course"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "web-server"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Use t3.micro or t3.small for the course."
  }
}

variable "public_key_path" {
  description = "Path to your SSH public key (ssh-keygen -t ed25519)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_cidr" {
  description = "Who may connect via SSH, e.g. 203.0.113.10/32 (your IP)"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0)) && var.ssh_cidr != "0.0.0.0/0"
    error_message = "ssh_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "install_nginx" {
  description = "Install nginx via User Data. Chapters 13-14: false — the server is configured by Ansible"
  type        = bool
  default     = true
}

variable "page_message" {
  description = "Text shown on the web page"
  type        = string
  default     = "Hello from Terraform!"
}
