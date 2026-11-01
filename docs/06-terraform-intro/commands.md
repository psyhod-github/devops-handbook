# 06 · Terraform: введение — шпаргалка

## Что создаём (и удаляем в конце)

```text
tf-06/
├── versions.tf          ← required_version, required_providers
├── variables.tf         ← aws_profile, region, ssh_cidr (+ validation), instance_type
├── main.tf              ← provider, data aws_ami, key pair, SG + правила, aws_instance
├── outputs.tf           ← public_ip, ssh_command
├── terraform.tfvars     ← ssh_cidr = "<ваш IP>/32"     (НЕ коммитить)
├── .gitignore
├── .terraform.lock.hcl  ← коммитить
├── .terraform/          ← кеш провайдеров (НЕ коммитить)
└── terraform.tfstate    ← state (НЕ коммитить)
```

## Основной цикл

```bash
terraform init                  # ← скачать провайдеры, создать lock-файл
terraform fmt                   # ← отформатировать код
terraform fmt -check -recursive # ← проверить формат (для CI)
terraform validate              # ← синтаксис и ссылки
terraform plan                  # ← что изменится (ничего не меняет)
terraform plan -out=tfplan      # ← сохранить план в файл
terraform apply                 # ← план + подтверждение yes + применение
terraform apply tfplan          # ← применить ровно сохранённый план
terraform plan -destroy         # ← что удалит destroy (ничего не удаляет)
terraform destroy               # ← удалить всё из state
```

## Переменные

```bash
terraform plan -var="instance_type=t3.small"        # ← из командной строки
terraform plan -var-file="dev.tfvars"                # ← из файла
export TF_VAR_ssh_cidr="203.0.113.10/32"             # ← из окружения (bash)
$env:TF_VAR_ssh_cidr = "203.0.113.10/32"             # ← из окружения (PowerShell)
```

Приоритет (последний побеждает): `default` → `TF_VAR_*` → `terraform.tfvars` → `*.auto.tfvars` → `-var-file` / `-var`.

## Outputs

```bash
terraform output                    # ← все
terraform output public_ip          # ← один (в кавычках)
terraform output -raw public_ip     # ← без кавычек, для скриптов
terraform output -json              # ← JSON
ssh -i ~/.ssh/id_ed25519 ec2-user@$(terraform output -raw public_ip)
```

## State

```bash
terraform state list                       # ← все ресурсы в state
terraform state show aws_instance.web      # ← атрибуты одного ресурса
terraform show                             # ← весь state в читаемом виде
terraform apply -replace="aws_instance.web"   # ← пересоздать ресурс (вместо устаревшего taint)
terraform apply -refresh-only              # ← принять ручные изменения в state, не меняя AWS
```

## Символы плана

| Символ | Значение |
|--------|----------|
| `+` | create |
| `~` | update in-place |
| `-/+` | destroy and recreate (replace) — **данные на ресурсе пропадут** |
| `-` | destroy |
| `<=` | read (data source) |

## Синтаксис HCL

```hcl
resource "aws_instance" "web" {        # resource "<ТИП>" "<ИМЯ>"
  ami           = data.aws_ami.al2023.id     # ссылка на data source
  instance_type = var.instance_type          # переменная
  key_name      = aws_key_pair.lab.key_name  # ссылка на ресурс → неявная зависимость
  tags = {
    Name = "web-${var.region}"               # интерполяция
  }
}

locals {
  name = "tf-lab"                            # local.name
}

variable "ssh_cidr" {
  type = string
  validation {
    condition     = var.ssh_cidr != "0.0.0.0/0"
    error_message = "No SSH for the whole internet."
  }
}
```

| Функция | Пример | Результат |
|---------|--------|-----------|
| `file()` | `file(pathexpand("~/.ssh/id_ed25519.pub"))` | содержимое файла |
| `pathexpand()` | `pathexpand("~/.ssh")` | `/home/you/.ssh` |
| `cidrhost()` | `cidrhost("10.0.1.0/24", 5)` | `10.0.1.5` |
| `contains()` | `contains(["a","b"], "a")` | `true` |
| `can()` | `can(cidrhost(var.x, 0))` | `true`, если нет ошибки |

Попробовать функции: `terraform console`.

## .gitignore

```gitignore
.terraform/
*.tfstate
*.tfstate.*
terraform.tfvars
*.auto.tfvars
crash.log
# .terraform.lock.hcl — коммитим
```

## Частые ошибки

| Ошибка | Причина |
|--------|---------|
| `Inconsistent dependency lock file` | Изменили `required_providers` — выполните `terraform init -upgrade` |
| `No valid credential sources found` | Нет профиля: проверьте `aws_profile` и `aws sts get-caller-identity --profile ...` |
| `InvalidKeyPair.Duplicate` / `InvalidGroup.Duplicate` | Ресурс с таким именем уже есть (создан вручную или в другом state) |
| `Invalid value for variable` | Сработала `validation` |
| `Error: Reference to undeclared resource` | Опечатка в имени ресурса или не тот тип |
| `-/+` там, где ожидали `~` | Изменён аргумент, который нельзя поменять на месте (`ami`, `user_data` с `replace_on_change`) |

## ✅ Самопроверка

```bash
terraform validate              # → Success!
terraform plan                  # → No changes (после apply)
terraform state list            # → 5 ресурсов + data source
terraform destroy && terraform state list   # → пусто
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Terraform — документация | [developer.hashicorp.com/terraform/docs](https://developer.hashicorp.com/terraform/docs) |
| Учебник: Get Started — AWS | [developer.hashicorp.com/terraform/tutorials/aws-get-started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started) |
| Язык HCL: ресурсы, переменные, outputs | [developer.hashicorp.com/terraform/language](https://developer.hashicorp.com/terraform/language) |
| Lock-файл зависимостей | [developer.hashicorp.com/terraform/language/files/dependency-lock](https://developer.hashicorp.com/terraform/language/files/dependency-lock) |
| State | [developer.hashicorp.com/terraform/language/state](https://developer.hashicorp.com/terraform/language/state) |
| Провайдер AWS | [registry.terraform.io/providers/hashicorp/aws/latest/docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| `aws_instance` | [registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) |
| Правила Security Group | [registry.terraform.io/.../vpc_security_group_ingress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) |
| OpenTofu | [opentofu.org/docs](https://opentofu.org/docs/) |
