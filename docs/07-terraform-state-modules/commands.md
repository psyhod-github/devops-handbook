# 07 · Terraform: remote state и модули — шпаргалка

## Что добавляем

```text
AWS (живёт долго):
  S3 bucket   tf-state-<account-id>     ← versioning, шифрование, без публичного доступа
  IAM policy  terraform-state-access    ← прикреплена к группе ec2-admins

tf-07/
├── versions.tf  variables.tf  terraform.tfvars
├── backend.tf          ← backend "s3" + use_lockfile
├── main.tf             ← provider + module "web" + module "web2"
├── outputs.tf          ← module.web.public_ip …
├── moved.tf            ← перенос ресурсов в модуль без пересоздания
└── modules/
    └── ec2/
        ├── variables.tf    ← входы: name, instance_type, public_key_path, ssh_cidr
        ├── main.tf         ← data ami, key pair, SG + правила, instance "this"
        └── outputs.tf      ← public_ip, instance_id
```

## Бакет для state (один раз, CloudShell под admin)

```bash
BUCKET=tf-state-$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket --bucket $BUCKET --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api get-bucket-versioning --bucket $BUCKET          # → Enabled
aws s3api get-public-access-block --bucket $BUCKET        # → все true
```

## Backend

```hcl
terraform {
  backend "s3" {
    bucket       = "tf-state-123456789012"
    key          = "tf-07/terraform.tfstate"   # путь внутри бакета: проект/окружение
    region       = "us-west-2"
    profile      = "devops-course"
    use_lockfile = true                        # нативная блокировка, Terraform >= 1.11
    encrypt      = true
  }
}
```

Минимальные права: `s3:ListBucket` на бакет; `s3:GetObject`, `s3:PutObject` на `key`; `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` на `key.tflock`.

## Команды backend и state

```bash
terraform init                         # ← подключиться к backend
terraform init -migrate-state          # ← перенести state в новый backend
terraform init -reconfigure            # ← переподключиться, НЕ перенося state
terraform init -backend-config="bucket=tf-state-123456789012"   # ← значения backend снаружи

terraform state list
terraform state show module.web.aws_instance.this
terraform state pull > backup.tfstate  # ← скачать state (содержит секреты — не коммитить!)
terraform force-unlock <LOCK_ID>       # ← снять зависшую блокировку (только если никто не делает apply)

aws s3 ls s3://tf-state-123456789012/tf-07/
aws s3api list-object-versions --bucket tf-state-123456789012 --prefix tf-07/terraform.tfstate \
  --query 'Versions[].{V:VersionId,At:LastModified,Latest:IsLatest}' --output table
```

## Модули

```hcl
module "web" {
  source        = "./modules/ec2"   # локально
  name          = "tf-lab"
  instance_type = "t3.micro"
  ssh_cidr      = var.ssh_cidr
}

output "ip" {
  value = module.web.public_ip      # ← только то, что объявлено в outputs.tf модуля
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"   # из Registry
  version = "~> 6.0"                           # фиксировать версию обязательно
}

module "ec2" {
  source = "git::https://github.com/org/tf-modules.git//ec2?ref=v1.2.0"   # из git по тегу
}
```

```bash
terraform init            # ← после добавления/изменения source модуля
terraform get -update     # ← обновить модули
```

## moved — переезд без пересоздания

```hcl
moved {
  from = aws_instance.web
  to   = module.web.aws_instance.this
}
```

Также для переименования: `from = aws_instance.web`, `to = aws_instance.app`.

## Устаревшее (встретите в старом коде)

| Было | Стало |
|------|-------|
| `dynamodb_table = "terraform-state-lock"` | `use_lockfile = true` |
| `terraform taint aws_instance.web` | `terraform apply -replace=aws_instance.web` |
| `terraform state mv` для рефакторинга | блок `moved` |
| `terraform import aws_x.y id` (команда) | блок `import { to = ..., id = ... }` |

## Частые ошибки

| Ошибка | Причина |
|--------|---------|
| `Error acquiring the state lock` | Кто-то (или вы в другом окне) выполняет plan/apply. Подождите. Зависла — `force-unlock` |
| `Backend configuration changed` | Изменили `backend` — `terraform init -migrate-state` или `-reconfigure` |
| `S3 bucket does not exist` / `NoSuchBucket` | Опечатка в имени бакета или другой регион |
| `AccessDenied` при init/plan | Нет прав на бакет: политика `terraform-state-access` не прикреплена |
| `Variables may not be used here` | `var.` в блоке `backend` — нельзя; используйте `-backend-config` |
| `Module not installed` | Добавили модуль — выполните `terraform init` |
| `Unsupported attribute` на `module.x.y` | В `outputs.tf` модуля нет output `y` |
| План: `N to add, N to destroy` после рефакторинга | Нужны блоки `moved` |

## ✅ Самопроверка

```bash
aws s3 ls s3://tf-state-123456789012/tf-07/      # → terraform.tfstate
ls terraform.tfstate 2>/dev/null || echo "no local state"   # → no local state
terraform plan                                     # → No changes (после apply)
terraform state list | grep module.web2            # → ресурсы второго вызова модуля
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Backend S3 | [developer.hashicorp.com/terraform/language/backend/s3](https://developer.hashicorp.com/terraform/language/backend/s3) |
| State: locking | [developer.hashicorp.com/terraform/language/state/locking](https://developer.hashicorp.com/terraform/language/state/locking) |
| Модули | [developer.hashicorp.com/terraform/language/modules](https://developer.hashicorp.com/terraform/language/modules) |
| Учебник по модулям | [developer.hashicorp.com/terraform/tutorials/modules/module](https://developer.hashicorp.com/terraform/tutorials/modules/module) |
| Рефакторинг с `moved` | [developer.hashicorp.com/terraform/language/modules/develop/refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) |
| Импорт с блоком `import` | [developer.hashicorp.com/terraform/language/import](https://developer.hashicorp.com/terraform/language/import) |
| Модули AWS в Registry | [registry.terraform.io/namespaces/terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules) |
| HCP Terraform | [developer.hashicorp.com/terraform/cloud-docs](https://developer.hashicorp.com/terraform/cloud-docs) |
