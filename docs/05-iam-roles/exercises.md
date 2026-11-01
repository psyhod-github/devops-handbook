# 05 · IAM: роли — задания

## Уровень 1 — повторение главы

1. Создайте бакет `roles-lab-<account-id>` с файлом `hello.txt`.
2. Создайте политику на чтение только этого бакета и роль для EC2 с ней.
3. Запустите инстанс с ролью и IMDSv2.
4. На инстансе: `aws sts get-caller-identity`, чтение файла, неудачная попытка записи.
5. Посмотрите ключи роли через IMDSv2.
6. Удалите всё.

!!! success "✅ Как проверить себя"
    - `get-caller-identity` → `assumed-role/ec2-s3-read-role/i-...`, `UserId` начинается с `AROA`.
    - Чтение `hello.txt` работает, `PutObject` → `AccessDenied`.
    - Ключ в IMDS начинается с `ASIA`, есть `Expiration`.
    - После уборки бакета, роли и инстанса нет.

## Уровень 2 — мини-проект: роль для человека

Сделайте так, чтобы `devops-course` мог **временно** получать права только на чтение S3, принимая роль, а постоянных прав на S3 у него не было.

**Что сделать:**

1. Создайте роль `s3-reader-for-humans` с trust policy, которая разрешает принимать её **только пользователю `devops-course`** вашего аккаунта.
2. Прикрепите к роли `AmazonS3ReadOnlyAccess`. Максимальную длительность сессии оставьте 1 час.
3. Добавьте в `~/.aws/config` профиль `s3-reader`, который принимает эту роль от имени `devops-course`.
4. Проверьте: `aws s3 ls --profile devops-course` падает, `aws s3 ls --profile s3-reader` работает.
5. Удалите роль и профиль после проверки.

<details markdown="1">
<summary>💡 Подсказки</summary>

- В консоли: **Create role → Custom trust policy** и вставьте:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:user/devops-course" },
      "Action": "sts:AssumeRole"
    }]
  }
  ```

  Когда в trust policy указан конкретный пользователь **того же** аккаунта, отдельное право `sts:AssumeRole` в его собственных политиках не требуется.
- Профиль:

  ```ini
  [profile s3-reader]
  role_arn = arn:aws:iam::123456789012:role/s3-reader-for-humans
  source_profile = devops-course
  region = us-west-2
  ```
- CLI сам вызовет `sts:AssumeRole` и закеширует временные ключи в `~/.aws/cli/cache/`.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `aws s3 ls --profile devops-course` → `AccessDenied`.
- [ ] `aws s3 ls --profile s3-reader` → список бакетов (или пусто, если бакетов нет — без ошибки).
- [ ] `aws sts get-caller-identity --profile s3-reader` → `assumed-role/s3-reader-for-humans/...`.
- [ ] В **CloudTrail → Event history** найдено событие `AssumeRole` от `devops-course`.
- [ ] Роль и профиль удалены.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как сделать так, чтобы S3-бакет мог читать только один конкретный EC2-инстанс, и никто больше — даже администратор с <code>AmazonS3FullAccess</code>?</summary>

Двумя слоями:

1. **Роль** для инстанса с `s3:GetObject` на этот бакет (как в главе).
2. **Bucket policy** на самом бакете с явным запретом для всех, кроме этой роли:

   ```json
   {
     "Effect": "Deny",
     "Principal": "*",
     "Action": "s3:*",
     "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"],
     "Condition": {
       "ArnNotEquals": { "aws:PrincipalArn": "arn:aws:iam::123456789012:role/ec2-s3-read-role" }
     }
   }
   ```

Явный Deny сильнее любого Allow, поэтому `AmazonS3FullAccess` у администратора не поможет. Осторожно: такая политика может запереть и вас самих — на практике в исключения добавляют ещё роль для аварийного доступа.
</details>

<details markdown="1">
<summary>2. Инстанс взломан, атакующий читает IMDS. Что вы сделаете в первые 5 минут, не останавливая сервер?</summary>

- **Отобрать права:** прикрепить к роли inline-политику `Deny *` на всё. Действует сразу для всех ключей роли, включая уже украденные.
- Для надёжности **отозвать активные сессии**: в консоли роли есть кнопка **Revoke active sessions** — она добавляет Deny для всех сессий, выданных раньше текущего момента.
- **Изолировать сеть:** заменить Security Group инстанса на группу без правил.
- **Сохранить улики:** снапшот диска для расследования.
- Посмотреть в CloudTrail, что успели сделать ключами роли.

Сервер не выключают сразу, чтобы не потерять следы в памяти, но лишают его прав и сети.
</details>

<details markdown="1">
<summary>3. Pipeline в GitHub Actions деплоит в AWS. Как обойтись без access key в секретах репозитория?</summary>

Через **OIDC**: GitHub выдаёт каждому запуску workflow подписанный токен, а в AWS создаётся IAM OIDC identity provider для `token.actions.githubusercontent.com` и роль, trust policy которой доверяет этому провайдеру с условием на конкретный репозиторий и ветку (`token.actions.githubusercontent.com:sub` = `repo:my-org/my-repo:ref:refs/heads/main`). Workflow обменивает токен на временные ключи роли (action `aws-actions/configure-aws-credentials`).

Постоянных ключей нет нигде, а чужой репозиторий или другая ветка роль принять не смогут.
</details>
