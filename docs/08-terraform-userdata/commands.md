# 08 · Terraform: User Data и проект — шпаргалка

## Что добавляем в проект

Эталон — `project/terraform/` в репозитории пособия.

```text
project/terraform/
├── versions.tf               ← Terraform >= 1.11, aws ~> 6.0
├── backend.tf                ← S3: key = "web-server/terraform.tfstate", use_lockfile
├── main.tf                   ← provider (default_tags) + module "web_server"
├── variables.tf              ← name, instance_type (+validation), public_key_path, ssh_cidr (+validation), page_message
├── outputs.tf                ← server_url, ssh_command, instance_id
├── terraform.tfvars.example  ← скопировать в terraform.tfvars
├── .terraform.lock.hcl       ← коммитится
└── modules/
    └── web-server/
        ├── main.tf               ← data ami, key pair, SG + ssh/http/egress, aws_instance + user_data
        ├── variables.tf
        ├── outputs.tf            ← public_ip, instance_id, security_group_id
        └── user-data.sh.tftpl    ← скрипт первого запуска
```

## Запуск проекта с нуля

```bash
cd project/terraform                       # или ваша папка tf-08
cp terraform.tfvars.example terraform.tfvars
# впишите ssh_cidr = "<ваш IP>/32"; в backend.tf замените YOUR_ACCOUNT_ID
export AWS_PROFILE=devops-course
terraform init
terraform apply
curl -s $(terraform output -raw server_url)    # через 1–2 минуты
terraform destroy
```

## User Data в Terraform

```hcl
resource "aws_instance" "this" {
  # ...
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    name    = var.name          # → ${name} в шаблоне
    message = var.page_message  # → ${message} в шаблоне
  })
  user_data_replace_on_change = true   # изменили скрипт → новый инстанс
}
```

Короткий скрипт без шаблона — heredoc:

```hcl
user_data = <<-EOF
  #!/bin/bash
  dnf install -y nginx
  systemctl enable --now nginx
EOF
```

## Шаблон `.tftpl`

| В шаблоне | Кто подставляет |
|-----------|-----------------|
| `${name}` | Terraform (ключ из `templatefile(..., {name = ...})`) |
| `$${HOME}` | bash (экранированное `${HOME}`) |
| `$HOME`, `$(date)` | bash |
| `%{ if cond }…%{ endif }`, `%{ for x in list }…%{ endfor }` | Terraform (условия и циклы) |

Посмотреть результат шаблона без apply:

```bash
echo 'templatefile("modules/web-server/user-data.sh.tftpl", {name="web-server", message="hi"})' | terraform console
```

## Отладка на сервере

```bash
terraform output -raw ssh_command               # ← команда для подключения
cloud-init status --long                         # → status: done | running | error
cloud-init status --wait                         # ← дождаться окончания
sudo cat /var/log/cloud-init-output.log          # ← вывод скрипта (с set -x — каждая команда)
sudo cat /var/log/cloud-init.log                 # ← подробный лог cloud-init
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/user-data   # ← какой скрипт получил инстанс
systemctl status nginx
curl -s localhost
```

Снаружи, без SSH:

```bash
aws ec2 get-console-output --instance-id $(terraform output -raw instance_id) --latest --output text | tail -30
```

## Когда выполняется User Data

| Событие | Выполнится? |
|---------|-------------|
| Первый запуск инстанса | да |
| `reboot` | нет |
| `stop` + `start` | нет |
| Изменён `user_data`, `replace_on_change = false` | нет (drift!) |
| Изменён `user_data`, `replace_on_change = true` | да — новый инстанс |
| `terraform apply -replace=...` | да — новый инстанс |

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `Connection refused` на `http://IP` сразу после apply | Скрипт ещё работает — подождите 1–2 минуты |
| Таймаут на `http://IP` | Нет правила HTTP 80 в SG или открываете `https://` |
| `cloud-init status` → `error` | Скрипт упал — смотрите `/var/log/cloud-init-output.log` |
| `vars map does not contain key "X"` | В шаблоне `${X}` без экранирования — пишите `$${X}` или `$X` |
| `Invalid function argument ... no file exists` | Неверный путь в `templatefile` — используйте `${path.module}/...` |
| Изменили скрипт, а страница старая | Нет `user_data_replace_on_change = true` |
| `exceeds the maximum size of 16384 bytes` | User Data больше 16 КБ — выносите настройку в Ansible/образ |

## ✅ Самопроверка

```bash
terraform output server_url                      # → "http://54.x.x.x"
curl -s $(terraform output -raw server_url) | grep instance   # → instance: i-0...
terraform plan                                   # → No changes
terraform destroy && terraform state list        # → пусто
```

## Почитать

| Тема | Ссылка |
|------|--------|
| User Data на EC2 | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) |
| cloud-init | [cloudinit.readthedocs.io](https://cloudinit.readthedocs.io/en/latest/) |
| `aws_instance`: `user_data`, `user_data_replace_on_change` | [registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#user_data) |
| `templatefile()` | [developer.hashicorp.com/terraform/language/functions/templatefile](https://developer.hashicorp.com/terraform/language/functions/templatefile) |
| Строки и heredoc | [developer.hashicorp.com/terraform/language/expressions/strings](https://developer.hashicorp.com/terraform/language/expressions/strings) |
| Terraform — документация | [developer.hashicorp.com/terraform/docs](https://developer.hashicorp.com/terraform/docs) |
| Packer — сборка образов | [developer.hashicorp.com/packer/docs](https://developer.hashicorp.com/packer/docs) |
