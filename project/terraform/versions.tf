# Глава 06 — фиксируем версии Terraform и провайдера.
# Точные версии провайдера записываются в .terraform.lock.hcl — его коммитят.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
