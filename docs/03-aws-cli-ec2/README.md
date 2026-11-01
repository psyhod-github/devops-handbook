# 03 · AWS CLI и жизненный цикл EC2

!!! abstract "В этой главе"
    **Что вы узнаете:** как настроить AWS CLI и профили, как проверить, под кем вы работаете, как создать Key Pair, Security Group и EC2 командами, как фильтровать вывод через `--query`, через какие состояния проходит инстанс и за что AWS берёт деньги в каждом из них.

    **Что нужно до начала:**

    - [Глава 02](../02-aws-vpc-ec2/README.md): вы понимаете VPC, подсети, Security Group и Key Pair.
    - Установлен AWS CLI v2 ([глава 00](../00-setup/README.md)).

    **Стоимость:** как в главе 02, центы за час работы `t3.micro`. Удалите ресурсы в конце.

## Зачем это нужно

В главе 02 вы потратили минут двадцать на клики в консоли. Теперь представьте, что серверов нужно десять. Или что коллега просит «сделай такой же, как вчера». Или что те же шаги нужно выполнить в CI-pipeline в три часа ночи.

Клики в консоли не повторить точно, не сохранить в Git и не автоматизировать. **AWS CLI** — это та же консоль, но в виде команд: их можно скопировать, записать в скрипт, запустить в цикле. Всё, что делает консоль, делается через API AWS, а CLI — самый прямой способ вызвать этот API.

CLI — промежуточный шаг. В главе 06 вы перейдёте к Terraform, который описывает не команды, а желаемый результат. Но и после этого CLI останется главным инструментом для проверки и диагностики.

## Концепция

### Как CLI разговаривает с AWS

```mermaid
flowchart LR
    T["Терминал<br/>aws ec2 run-instances ..."] --> CLI[AWS CLI]
    F["~/.aws/credentials<br/>~/.aws/config"] -->|ключи, регион| CLI
    CLI -->|HTTPS-запрос,<br/>подписанный ключом| API["AWS API<br/>ec2.us-west-2.amazonaws.com"]
    API --> IAM{IAM: есть ли<br/>у пользователя право?}
    IAM -->|да| R[Ресурс создан]
    IAM -.->|нет| E["AccessDenied /<br/>UnauthorizedOperation"]
```

Каждая команда CLI — это HTTPS-запрос к API AWS, подписанный вашим **access key**. AWS проверяет подпись (кто вы) и права в IAM (что вам можно). Отсюда два вида ошибок, которые важно различать:

- **кто вы** — `InvalidClientTokenId`, `SignatureDoesNotMatch`, `Unable to locate credentials`: проблема с ключами;
- **что вам можно** — `AccessDenied`, `UnauthorizedOperation`: ключи в порядке, но у пользователя нет прав.

### Access key — это не Key Pair

Новички часто путают два вида ключей:

| | Access key (IAM) | Key Pair (EC2) |
|---|---|---|
| Для чего | Вызывать API AWS: CLI, Terraform, SDK | Входить на Linux-сервер по SSH |
| Как выглядит | `AKIA...` + секрет из 40 символов | Файл `.pem` с приватным ключом |
| Где хранится | `~/.aws/credentials` | `~/.ssh/` |
| Кто проверяет | AWS API | SSH-сервер на инстансе |
| Если утёк | Атакующий управляет вашим аккаунтом в пределах прав | Атакующий входит на сервер (если ему открыт порт 22) |

### Профили

**Профиль** — именованный набор ключей и настроек. У одного человека их может быть несколько: учебный аккаунт, рабочий, тестовый. Профили хранятся в двух файлах в домашней папке:

```ini
# ~/.aws/credentials — секреты
[devops-course]
aws_access_key_id = AKIA****************
aws_secret_access_key = ****************************************

# ~/.aws/config — настройки
[profile devops-course]
region = us-west-2
output = json
```

На Windows это `C:\Users\<имя>\.aws\`. Какой профиль использовать, CLI решает так: флаг `--profile` → переменная `AWS_PROFILE` → профиль `default`.

### Жизненный цикл EC2

```mermaid
stateDiagram-v2
    [*] --> pending: run-instances
    pending --> running
    running --> stopping: stop-instances
    stopping --> stopped
    stopped --> pending: start-instances
    running --> running: reboot-instances
    running --> shutting_down: terminate-instances
    stopped --> shutting_down: terminate-instances
    shutting_down --> terminated
    terminated --> [*]
```

| Состояние | Платите за compute | Платите за диск (EBS) | Публичный IP | Данные на диске |
|-----------|-------------------|-----------------------|--------------|-----------------|
| `running` | да | да | есть | сохраняются |
| `stopped` | **нет** | **да** | **освобождается** | сохраняются |
| `terminated` | нет | нет (диск удалён) | — | **удалены навсегда** |

- **Stop** — выключить компьютер: диск остаётся, за него вы продолжаете платить. После Start инстанс может оказаться на другом физическом сервере и получит **новый публичный IP**.
- **Reboot** — перезагрузка ОС. Ничего не меняется, IP тот же.
- **Terminate** — удалить. Корневой диск удаляется вместе с инстансом (по умолчанию), отменить нельзя.

!!! example "Плохо / Хорошо: «выключу, чтобы не платить»"

    === "❌ Плохо"

        «Закончил на сегодня — сделаю Stop, завтра продолжу». Через месяц в аккаунте десяток остановленных инстансов, их диски и Elastic IP, о которых никто не помнит, и ежемесячный счёт за хранение.

    === "✅ Хорошо"

        Учебные ресурсы — **Terminate** в конце сессии. Если нужно продолжить завтра, ресурсы создаются заново скриптом (эта глава) или Terraform (глава 06) за минуту. Остановленный инстанс оправдан, только когда на диске есть ценное состояние, которое долго воссоздавать.

## Практика

Команды ниже даны для bash (macOS, Linux, Git Bash на Windows) и PowerShell. Отличаются они в основном переменными (`VAR=...` против `$VAR = ...`) и переносом строк (`\` против `` ` ``).

### Шаг 1. Создать IAM-пользователя для CLI

Root user ключей не получает (глава 00). Создайте отдельного пользователя. Подробно IAM разбирается в главе 04, пока минимально:

1. Консоль → **IAM** → **Users** → **Create user**.
2. *User name*: `devops-course`. Галочку *Provide user access to the AWS Management Console* **не ставьте**: этот пользователь только для CLI.
3. *Permissions options* → **Attach policies directly** → найдите и отметьте **AmazonEC2FullAccess** → **Next** → **Create user**.
4. Откройте пользователя → вкладка **Security credentials** → **Access keys** → **Create access key**.
5. *Use case*: **Command Line Interface (CLI)** → отметьте подтверждение → **Next** → **Create access key**.
6. Скопируйте **Access key ID** и **Secret access key**. Секрет показывается **один раз**.

!!! info "Почему AWS отговаривает от access keys"
    На шаге 5 AWS предложит альтернативы: IAM Identity Center, CloudShell. Долгоживущие ключи действительно рискованны: они не истекают сами. Для учёбы и для понимания основ ключи подходят, а о более безопасных способах поговорим в главах 04–05.

### Шаг 2. Настроить профиль

```bash
aws configure --profile devops-course
```

```text
AWS Access Key ID [None]: AKIA................
AWS Secret Access Key [None]: ........................................
Default region name [None]: us-west-2
Default output format [None]: json
```

Сделайте профиль активным для текущего окна терминала:

=== "bash"

    ```bash
    export AWS_PROFILE=devops-course
    ```

=== "PowerShell"

    ```powershell
    $env:AWS_PROFILE = "devops-course"
    ```

Переменная живёт, пока открыт терминал. В новом окне её нужно задать снова или добавлять `--profile devops-course` к командам.

!!! success "✅ Проверь себя — обязательно"
    ```bash
    aws sts get-caller-identity
    ```
    ```json
    {
        "UserId": "AIDA...",
        "Account": "123456789012",
        "Arn": "arn:aws:iam::123456789012:user/devops-course"
    }
    ```
    В `Account` — **ваш** Account ID (12 цифр), в `Arn` — `user/devops-course`. Если там другой пользователь или другой аккаунт, вы работаете не тем профилем: остановитесь и разберитесь, прежде чем создавать ресурсы.

    `aws configure list` показывает, откуда CLI взял ключи и регион.

### Шаг 3. Осмотреть сеть командами

```bash
aws ec2 describe-vpcs \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock,Default:IsDefault}' \
  --output table
```

```text
-------------------------------------------------------
|                    DescribeVpcs                     |
+-----------------+----------+------------------------+
|      CIDR       | Default  |          ID            |
+-----------------+----------+------------------------+
|  172.31.0.0/16  |  True    |  vpc-0a1b2c3d4e5f67890 |
+-----------------+----------+------------------------+
```

```bash
aws ec2 describe-subnets \
  --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch}' \
  --output table
```

`MapPublicIpOnLaunch = True` означает, что инстансы в этой подсети автоматически получают публичный IP.

!!! tip "`--query` — главный навык CLI"
    Без `--query` команды `describe-*` выводят сотни строк JSON. `--query` фильтрует их языком JMESPath:

    - `Vpcs[]` — каждый элемент списка;
    - `.{Имя:Поле}` — выбрать поля и переименовать;
    - `[0]` — первый элемент;
    - `sort_by(Images,&CreationDate)[-1]` — отсортировать и взять последний.

    `--output table` — удобно читать глазами, `--output text` — удобно сохранять в переменную.

### Шаг 4. Key Pair

=== "bash"

    ```bash
    aws ec2 create-key-pair \
      --key-name lesson-key \
      --key-type ed25519 \
      --query 'KeyMaterial' \
      --output text > ~/.ssh/lesson-key.pem

    chmod 400 ~/.ssh/lesson-key.pem
    ```

=== "PowerShell"

    ```powershell
    $key = aws ec2 create-key-pair `
      --key-name lesson-key `
      --key-type ed25519 `
      --query 'KeyMaterial' `
      --output text
    # Не используйте > или Out-File: в Windows PowerShell 5.1 они пишут UTF-16, и ssh не прочитает ключ
    [IO.File]::WriteAllText("$HOME\.ssh\lesson-key.pem", ($key -join "`n") + "`n")

    icacls "$HOME\.ssh\lesson-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
    ```

`chmod 400` оставляет право только на чтение и только владельцу: `4` — read для owner, `0` — ничего для группы, `0` — ничего для остальных. SSH откажется работать с ключом, который могут читать другие (`Permissions 0644 ... are too open`).

!!! success "✅ Проверь себя"
    ```bash
    aws ec2 describe-key-pairs --key-names lesson-key --query 'KeyPairs[].KeyName' --output text
    # → lesson-key
    head -1 ~/.ssh/lesson-key.pem
    # → -----BEGIN OPENSSH PRIVATE KEY-----
    ```

### Шаг 5. Security Group только для вашего IP

=== "bash"

    ```bash
    MY_IP=$(curl -s https://checkip.amazonaws.com)

    SG_ID=$(aws ec2 create-security-group \
      --group-name lesson-sg \
      --description "SSH from my IP only" \
      --query 'GroupId' --output text)

    aws ec2 authorize-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp --port 22 \
      --cidr "$MY_IP/32"

    echo "$SG_ID $MY_IP"
    ```

=== "PowerShell"

    ```powershell
    $MY_IP = (curl.exe -s https://checkip.amazonaws.com).Trim()

    $SG_ID = aws ec2 create-security-group `
      --group-name lesson-sg `
      --description "SSH from my IP only" `
      --query 'GroupId' --output text

    aws ec2 authorize-security-group-ingress `
      --group-id $SG_ID `
      --protocol tcp --port 22 `
      --cidr "$MY_IP/32"

    "$SG_ID $MY_IP"
    ```

Без флага `--vpc-id` группа создаётся в default VPC.

!!! example "Плохо / Хорошо"

    === "❌ Плохо"

        ```bash
        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
          --protocol tcp --port 22 --cidr 0.0.0.0/0
        ```
        «Для учёбы сойдёт» — так и появляются привычки, которые потом переезжают в продакшен.

    === "✅ Хорошо"

        ```bash
        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
          --protocol tcp --port 22 --cidr "$MY_IP/32"
        ```
        Одна лишняя строка в скрипте — и порт 22 закрыт для всего интернета, кроме вас.

### Шаг 6. Найти AMI

**AMI (Amazon Machine Image)** — шаблон диска с ОС, из которого создаётся инстанс. Аналог ISO-образа в обычной виртуализации. ID образов разные в каждом регионе и меняются с каждым обновлением, поэтому **не копируйте AMI ID из чужих инструкций**, а ищите актуальный:

=== "bash"

    ```bash
    AMI_ID=$(aws ec2 describe-images \
      --owners amazon \
      --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
      --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
      --output text)
    echo "$AMI_ID"
    ```

=== "PowerShell"

    ```powershell
    $AMI_ID = aws ec2 describe-images `
      --owners amazon `
      --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" `
      --query 'sort_by(Images,&CreationDate)[-1].ImageId' `
      --output text
    $AMI_ID
    ```

`--owners amazon` гарантирует, что образ опубликован Amazon, а не кем-то, кто назвал свой образ похоже. Результат — ID вида `ami-0abc...`.

!!! tip "Ещё короче: публичный параметр SSM"
    AWS публикует ID последнего образа Amazon Linux в Parameter Store: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`. Его можно передать прямо в `run-instances` как `--image-id resolve:ssm:/aws/service/...`. Для этого пользователю нужно право `ssm:GetParameters`, которого нет в `AmazonEC2FullAccess`. Вернёмся к этому в Terraform.

### Шаг 7. Запустить инстанс

=== "bash"

    ```bash
    INSTANCE_ID=$(aws ec2 run-instances \
      --image-id "$AMI_ID" \
      --instance-type t3.micro \
      --key-name lesson-key \
      --security-group-ids "$SG_ID" \
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lesson-ec2}]' \
      --query 'Instances[0].InstanceId' --output text)
    echo "$INSTANCE_ID"

    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"   # ← ждёт, пока не станет running

    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "$PUBLIC_IP"
    ```

=== "PowerShell"

    ```powershell
    $INSTANCE_ID = aws ec2 run-instances `
      --image-id $AMI_ID `
      --instance-type t3.micro `
      --key-name lesson-key `
      --security-group-ids $SG_ID `
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lesson-ec2}]' `
      --query 'Instances[0].InstanceId' --output text
    $INSTANCE_ID

    aws ec2 wait instance-running --instance-ids $INSTANCE_ID

    $PUBLIC_IP = aws ec2 describe-instances --instance-ids $INSTANCE_ID `
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
    $PUBLIC_IP
    ```

!!! success "✅ Проверь себя"
    ```bash
    aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=lesson-ec2" \
      --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,IP:PublicIpAddress}' \
      --output table
    ```
    `State` = `running`, `Type` = `t3.micro`, есть `IP`. Тот же инстанс виден в консоли **EC2 → Instances**.

### Шаг 8. Подключиться

```bash
ssh -i ~/.ssh/lesson-key.pem ec2-user@$PUBLIC_IP        # PowerShell: ec2-user@$PUBLIC_IP работает так же
```

Если `Connection refused` — подождите минуту: `running` означает, что виртуальная машина включилась, но SSH-сервер внутри ещё может загружаться. Выйти — `exit`.

### Шаг 9. Пройти жизненный цикл

Запишите текущий публичный IP, затем остановите и снова запустите инстанс:

```bash
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" \
  --query 'StoppingInstances[0].{Was:PreviousState.Name,Now:CurrentState.Name}'
# → {"Was": "running", "Now": "stopping"}

aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

aws ec2 start-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{IP:PublicIpAddress,PrivateIP:PrivateIpAddress}'
```

!!! success "✅ Проверь себя"
    Публичный IP после Start **другой**, приватный — **тот же**. Подключение по старому IP не работает, по новому — работает. Именно поэтому в продакшене к серверам обращаются по DNS-имени или через балансировщик, а не по IP.

### Шаг 10. Уборка

!!! success "✅ Проверь себя перед удалением"
    ```bash
    aws ec2 describe-instances \
      --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name}' \
      --output table
    ```
    Убедитесь, что `$INSTANCE_ID` — это `lesson-ec2`, а не что-то другое. `terminate` не спрашивает подтверждения и не отменяется.

=== "bash"

    ```bash
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
    aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"   # ← SG нельзя удалить, пока инстанс жив

    aws ec2 delete-security-group --group-id "$SG_ID"
    aws ec2 delete-key-pair --key-name lesson-key
    rm -f ~/.ssh/lesson-key.pem
    ```

=== "PowerShell"

    ```powershell
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID

    aws ec2 delete-security-group --group-id $SG_ID
    aws ec2 delete-key-pair --key-name lesson-key
    Remove-Item "$HOME\.ssh\lesson-key.pem" -Force
    ```

!!! success "✅ Проверь себя"
    ```bash
    aws ec2 describe-instances --filters "Name=tag:Name,Values=lesson-ec2" \
      --query 'Reservations[].Instances[].State.Name' --output text    # → terminated
    aws ec2 describe-security-groups --filters "Name=group-name,Values=lesson-sg" \
      --query 'SecurityGroups[].GroupId' --output text                  # → пусто
    aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text   # → нет lesson-key
    ```

Пользователя `devops-course` и его профиль **не удаляйте**: они понадобятся в следующих главах.

!!! quote "Реальный кейс"
    Инженер чистил тестовое окружение скриптом с `terminate-instances`, в который список ID подставлялся из `describe-instances` по фильтру. Профиль по ошибке остался от продакшен-аккаунта, а тег-фильтр совпал с продакшен-серверами. Три сервера удалены за секунду. Восстанавливались из бэкапов полдня. С тех пор в команде правило: **`aws sts get-caller-identity` перед любой деструктивной операцией**, а в продакшен-аккаунт доступ только через отдельную роль.

## Вопросы для самопроверки

<details markdown="1">
<summary>1. Чем access key отличается от Key Pair?</summary>

Access key — учётные данные IAM-пользователя для вызова **API AWS** (CLI, Terraform). Key Pair — пара SSH-ключей для входа **на сервер**. Они никак не связаны: имея access key, можно создать сервер, но нельзя на него зайти без Key Pair. Имея `.pem`, можно зайти на сервер, но нельзя управлять аккаунтом.
</details>

<details markdown="1">
<summary>2. Команда вернула <code>Unable to locate credentials</code>, а у коллеги с тем же пользователем — <code>UnauthorizedOperation</code>. Чем различаются проблемы?</summary>

`Unable to locate credentials` — CLI вообще не нашёл ключей: не выполнен `aws configure`, профиль назван иначе, не задан `AWS_PROFILE`. Запрос даже не дошёл до AWS.

`UnauthorizedOperation` — ключи найдены и верны, AWS знает, кто вы, но у пользователя нет права на это действие. Решается в IAM, добавлением прав (глава 04).
</details>

<details markdown="1">
<summary>3. Инстанс в состоянии <code>stopped</code>. Вы платите за него?</summary>

За вычисления — нет. За диск EBS — да, он продолжает хранить данные. Если к инстансу привязан Elastic IP, за него тоже. Поэтому для учебных ресурсов правильное действие — terminate, а не stop.
</details>

<details markdown="1">
<summary>4. Зачем <code>aws ec2 wait instance-terminated</code> перед <code>delete-security-group</code>?</summary>

Security Group нельзя удалить, пока она прикреплена к сетевому интерфейсу. `terminate-instances` возвращается сразу, а инстанс ещё секунд 30–60 в состоянии `shutting-down` и держит SG. Без ожидания удаление SG упадёт с `DependencyViolation`.
</details>

<details markdown="1">
<summary>5. Почему нельзя скопировать AMI ID из статьи в интернете?</summary>

AMI ID свои в каждом регионе: один и тот же Amazon Linux в `us-east-1` и `us-west-2` имеет разные ID. Кроме того, образы регулярно обновляются, старые устаревают и могут содержать уязвимости. И главное — по ID не видно, кто опубликовал образ. Безопасно искать образ по имени с фильтром `--owners amazon`.
</details>

## Итоги

- [x] AWS CLI вызывает тот же API, что и консоль; ключи — в `~/.aws/credentials`, настройки — в `~/.aws/config`
- [x] Профиль выбирается через `--profile` или `AWS_PROFILE`; `aws sts get-caller-identity` — первая команда сессии
- [x] Создали Key Pair, Security Group (только ваш IP) и EC2 командами; AMI нашли по фильтру, а не хардкодом
- [x] `--query` и `--output` превращают JSON в нужное значение
- [x] Stop сохраняет диск и меняет публичный IP, Terminate удаляет навсегда
- [x] Убрали всё, кроме пользователя `devops-course`

**Что дальше.** Пользователь `devops-course` сейчас может делать с EC2 всё, но больше ничего. Почему так, как устроены права в AWS и как дать ровно столько прав, сколько нужно, — в [главе 04](../04-iam-users-policies/README.md).

- 📋 [Шпаргалка](commands.md)
- 🏋️ [Задания к главе](exercises.md)
