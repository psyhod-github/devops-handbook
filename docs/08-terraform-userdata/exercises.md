# 08 · Terraform: User Data и проект — задания

## Уровень 1 — повторение главы

1. Соберите проект `tf-08` по шагам главы и сверьте с `project/terraform/`.
2. `terraform apply`, откройте `server_url` в браузере.
3. По SSH проверьте `cloud-init status` и лог `/var/log/cloud-init-output.log`.
4. Измените `page_message`, убедитесь, что план показывает `-/+` с `# forces replacement`, примените.
5. `terraform destroy`.

!!! success "✅ Как проверить себя"
    - Страница открывается без единой команды на сервере, `instance:` совпадает с output `instance_id`.
    - `cloud-init status` → `done`.
    - После смены текста у сервера новый ID и IP.
    - После `destroy` — пустой `terraform state list`.

## Уровень 2 — мини-проект: сломать и починить

User Data чаще всего ломается тихо: `apply` проходит, а сайта нет. Научитесь находить причину.

**Что сделать:**

1. Внесите в шаблон ошибку: замените `dnf install -y nginx` на `dnf install -y nginxx`.
2. `terraform apply` (сервер пересоздастся). Убедитесь, что `apply` прошёл успешно, а сайт не открывается.
3. Найдите причину **двумя способами**: по SSH (статус и лог cloud-init) и **без SSH** (`aws ec2 get-console-output`).
4. Исправьте шаблон, примените, проверьте сайт.
5. Добавьте в шаблон блок, который пишет страницу по-разному в зависимости от новой переменной `show_debug` (bool): если `true` — на странице выводится ещё и `hostname` сервера.

<details markdown="1">
<summary>💡 Подсказки</summary>

- С `set -e` скрипт остановится на ошибочной команде, и nginx даже не будет установлен. `cloud-init status --long` покажет `status: error`.
- `get-console-output` возвращает вывод консоли инстанса; ищите строки `+ dnf install` и `No match for argument`.
- Условие в шаблоне:

  ```text
  %{ if show_debug ~}
    <p>hostname: $(hostname)</p>
  %{ endif ~}
  ```

  Не забудьте передать `show_debug` в `templatefile()` и объявить переменную в модуле и в корне.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] Вы нашли строку с ошибкой в `/var/log/cloud-init-output.log` и в выводе `get-console-output`.
- [ ] После исправления `cloud-init status` → `done`, сайт работает.
- [ ] С `show_debug = true` на странице есть `hostname`, с `false` — нет.
- [ ] Ресурсы удалены.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Нужно, чтобы сервер из User Data скачивал файл из приватного S3-бакета. Как дать ему доступ средствами Terraform? Почему это может не сработать с правами <code>devops-course</code>?</summary>

Как в главе 05, но кодом: `aws_iam_role` (trust policy для `ec2.amazonaws.com`) + `aws_iam_role_policy` (`s3:GetObject` на бакет) + **`aws_iam_instance_profile`** (в Terraform его создают явно) + `iam_instance_profile = aws_iam_instance_profile.this.name` в `aws_instance`. В User Data — `aws s3 cp s3://bucket/file /path`.

С текущими правами `devops-course` не сработает: нужны права на IAM (`iam:CreateRole`, `iam:PutRolePolicy`, `iam:CreateInstanceProfile`, `iam:AddRoleToInstanceProfile`) и `iam:PassRole`. Давать CI-пользователю полный IAM опасно: он сможет выдать себе любые права. Безопасный вариант — разрешить эти действия только для ролей с определённым префиксом (`arn:aws:iam::123456789012:role/tf-lab-*`) и задать **permissions boundary**, которая ограничивает максимальные права создаваемых ролей.
</details>

<details markdown="1">
<summary>2. Сервер должен пережить отказ одной зоны доступности и выдерживать нагрузку. Хватит ли одного <code>aws_instance</code> с User Data? Что изменится в архитектуре?</summary>

Нет: один инстанс живёт в одной AZ и не масштабируется. Типовая схема:

- **Launch Template** (`aws_launch_template`) — шаблон инстанса с AMI, типом и тем же User Data;
- **Auto Scaling Group** (`aws_autoscaling_group`) — держит нужное число инстансов в нескольких подсетях разных AZ, заменяет упавшие, масштабируется по нагрузке;
- **Application Load Balancer** — единая точка входа, распределяет трафик и проверяет здоровье инстансов.

Здесь неизменяемые серверы и User Data раскрываются полностью: ASG создаёт новые инстансы сама, и каждый должен настроить себя без участия человека.
</details>

<details markdown="1">
<summary>3. Почему для production-сайта на nginx User Data с <code>dnf install</code> при каждом запуске считается слабым решением, и что используют вместо этого?</summary>

- **Скорость:** установка пакетов при каждом запуске добавляет минуты. При автомасштабировании под нагрузкой это критично.
- **Воспроизводимость:** `dnf install` ставит актуальную на сегодня версию. Серверы, созданные в разные дни, могут отличаться.
- **Зависимость от внешних репозиториев:** если репозиторий недоступен, сервер не поднимется.

Вместо этого настройку «запекают» заранее: **готовый AMI** (Packer собирает образ один раз, сервер стартует уже настроенным) или **контейнер** (Docker-образ со всеми зависимостями, а User Data только запускает его). К контейнерам вы перейдёте в главе 09.
</details>
