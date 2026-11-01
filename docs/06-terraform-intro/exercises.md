# 06 · Terraform: введение — задания

## Уровень 1 — повторение главы

1. Создайте проект `tf-06` из четырёх файлов главы, `terraform.tfvars` с вашим IP и `.gitignore`.
2. `init` → `fmt` → `validate` → `plan` → `apply`.
3. Подключитесь по SSH командой из output.
4. Добавьте тег и посмотрите `~` в плане; пересоздайте инстанс через `-replace` и посмотрите `-/+`.
5. Поменяйте тег в консоли и найдите drift в `plan`.
6. `terraform destroy`.

!!! success "✅ Как проверить себя"
    - Повторный `terraform plan` после `apply` → `No changes`.
    - После `-replace` у инстанса другой ID (`terraform state show aws_instance.web | grep -w id`).
    - Попробуйте `terraform plan -var="ssh_cidr=0.0.0.0/0"` — получите ошибку `validation`.
    - После `destroy` команда `terraform state list` ничего не выводит.

## Уровень 2 — мини-проект: окружения через переменные

Сделайте так, чтобы из одного и того же кода создавались «dev» и «prod» версии сервера с разными параметрами, без копирования `.tf` файлов.

**Требования:**

- Новая переменная `environment` со значениями только `dev` или `prod` (через `validation`).
- Имена Key Pair, Security Group и тег `Name` содержат окружение: `tf-lab-dev-web`, `tf-lab-prod-web`.
- Тег `Environment` на всех ресурсах (через `default_tags`).
- Файлы `dev.tfvars` (`t3.micro`) и `prod.tfvars` (`t3.small`).
- Запуск: `terraform apply -var-file=dev.tfvars`.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Удобно собрать префикс в `locals`:

  ```hcl
  locals {
    name = "tf-lab-${var.environment}"
  }
  ```

  и дальше писать `key_name = "${local.name}-key"`, `Name = "${local.name}-web"`.
- В `default_tags` можно использовать переменные: `Environment = var.environment`.
- Если выполнить `apply -var-file=dev.tfvars`, а потом `apply -var-file=prod.tfvars` **в той же папке**, Terraform не создаст второй сервер, а **переименует и пересоздаст** первый: state-то один. Посмотрите на план и подумайте, как это решить. Правильный ответ — разные state: разные папки или разные `key` в backend (глава 07), либо workspaces.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `terraform plan -var-file=dev.tfvars` создаёт ресурсы с `dev` в именах и `t3.micro`.
- [ ] `terraform plan -var-file=prod.tfvars` — с `prod` и `t3.small`.
- [ ] `terraform plan -var="environment=test"` падает на `validation`.
- [ ] Вы можете объяснить, почему переключение tfvars в одной папке ведёт к `-/+`, а не к созданию второго окружения.
- [ ] Ресурсы удалены.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Data source <code>aws_ami</code> с <code>most_recent = true</code>. Через месяц Amazon выпустил новый образ. Что покажет <code>terraform plan</code> и чем это опасно? Как этим управлять?</summary>

Data source вернёт новый AMI ID, `ami` у инстанса изменится, а этот аргумент нельзя поменять на месте. План покажет `-/+` — пересоздание сервера, хотя код никто не трогал.

Варианты:

- **Принять как норму:** серверы неизменяемые, вся настройка в User Data, данные вне сервера. Тогда пересоздание — это просто обновление ОС. Но делать его нужно осознанно, в окно обслуживания.
- **Зафиксировать AMI:** переменная с конкретным ID, которую обновляют явным коммитом.
- **`lifecycle { ignore_changes = [ami] }`** — Terraform перестанет пересоздавать инстанс из-за нового AMI. Существующий сервер останется на старом образе, новые будут на свежем.

Главное: пересоздание из-за data source должно быть решением, а не сюрпризом в плане.
</details>

<details markdown="1">
<summary>2. Коллега создал Security Group руками в консоли год назад. Теперь её нужно взять под управление Terraform, не пересоздавая. Как?</summary>

Через **импорт**. Опишите ресурс в коде так, как он настроен сейчас, и добавьте блок `import`:

```hcl
import {
  to = aws_security_group.legacy
  id = "sg-0abc123def4567890"
}

resource "aws_security_group" "legacy" {
  name        = "legacy-sg"
  description = "..."
}
```

`terraform plan` покажет `import`, а не создание. После `apply` ресурс в state. `terraform plan -generate-config-out=generated.tf` может даже сгенерировать код по существующему ресурсу. Дальше подгоните код, чтобы `plan` показывал `No changes`.
</details>

<details markdown="1">
<summary>3. Вы делаете <code>terraform apply</code>, и в плане 1 to add, 0 to change, <b>3 to destroy</b>, хотя вы «только добавили тег». Ваши действия?</summary>

Ответить `no`. Никогда не подтверждайте план, который не понимаете. Затем найти в плане строки `-` и `-/+` и понять причину. Частые причины:

- изменён аргумент, который требует пересоздания (имя SG, `ami`, `user_data`);
- вы запустили Terraform не в той папке или с другим tfvars;
- кто-то изменил state (или вы работаете с чужим state);
- изменился data source (новый AMI).

Привычка читать план целиком — главная защита от аварий с Terraform.
</details>
