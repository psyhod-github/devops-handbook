# Глава 08 — веб-сервер одной командой: модуль + User Data + remote state

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "devops-handbook"
      ManagedBy = "terraform"
    }
  }
}

module "web_server" {
  source = "./modules/web-server"

  name            = var.name
  instance_type   = var.instance_type
  public_key_path = var.public_key_path
  ssh_cidr        = var.ssh_cidr
  page_message    = var.page_message
  install_nginx   = var.install_nginx
}
