# Глава 07 — remote state в S3 с нативной блокировкой (use_lockfile, Terraform >= 1.11).
# В backend нельзя использовать переменные: замените YOUR_ACCOUNT_ID на свой Account ID
# или передайте значение при init: terraform init -backend-config="bucket=tf-state-123456789012"

terraform {
  backend "s3" {
    bucket       = "tf-state-YOUR_ACCOUNT_ID"
    key          = "web-server/terraform.tfstate"
    region       = "us-west-2"
    profile      = "devops-course"
    use_lockfile = true
    encrypt      = true
  }
}
