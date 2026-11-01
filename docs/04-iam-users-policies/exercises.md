# 04 · IAM: пользователи и политики — задания

## Уровень 1 — повторение главы

1. Убедитесь, что работаете в консоли как `admin` с MFA, а не как root.
2. Создайте пользователя `devops-readonly` в группе `ec2-readonly` (`AmazonEC2ReadOnlyAccess`), профиль для CLI.
3. Получите `UnauthorizedOperation` при создании Security Group и расшифруйте сообщение в CloudShell.
4. Добавьте политику с условием `aws:RequestedRegion` и убедитесь, что в `us-west-2` создание работает, а в `us-east-1` — нет.
5. Уберите всё, кроме `admin`, `devops-course` и `ec2-admins`.

!!! success "✅ Как проверить себя"
    - Расшифрованное сообщение содержит `"allowed": false`, `action` и `who`.
    - Результат шага 4 различается по регионам.
    - После уборки **IAM → Users** содержит только `admin` и `devops-course`.

## Уровень 2 — мини-проект: политика для Terraform

В главах 06–08 Terraform будет создавать EC2, Security Groups и хранить состояние в S3. Напишите **customer managed** политику `terraform-lab`, которая разрешает ровно это:

- всё в EC2, но **только в регионе `us-west-2`**;
- чтение и запись объектов в одном бакете `tf-state-<ваш-account-id>`, а также список его содержимого;
- **запрет** запускать инстансы любых типов, кроме `t3.micro` и `t3.small`.

Политику пока не прикрепляйте. Проверьте её в Policy Simulator.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Три `Statement`: Allow для EC2 с условием региона, Allow для S3, Deny для типов инстансов.
- Для S3 нужны два ARN: бакет (для `s3:ListBucket`) и `бакет/*` (для `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`).
- Ключ условия для типа инстанса — `ec2:InstanceType`. Для запрета «всё, кроме» используйте оператор `StringNotEquals` со списком значений. Ресурс для такого Deny: `arn:aws:ec2:*:*:instance/*`, действие `ec2:RunInstances`.
- В Policy Simulator есть режим *New policy*: можно вставить JSON, не создавая политику.
</details>

<details markdown="1">
<summary>✅ Критерии готовности (и пример решения)</summary>

- [ ] Simulator: `ec2:RunInstances` в `us-west-2` — allowed; в `us-east-1` — denied.
- [ ] Simulator: `s3:PutObject` на `arn:aws:s3:::tf-state-<id>/x` — allowed; на другой бакет — denied.
- [ ] Simulator: `ec2:RunInstances` с `ec2:InstanceType = m5.large` — denied (explicit).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Ec2InOregon",
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:RequestedRegion": "us-west-2" } }
    },
    {
      "Sid": "StateBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::tf-state-123456789012",
        "arn:aws:s3:::tf-state-123456789012/*"
      ]
    },
    {
      "Sid": "OnlySmallInstances",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": { "StringNotEquals": { "ec2:InstanceType": ["t3.micro", "t3.small"] } }
    }
  ]
}
```
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как разрешить пользователю делать что угодно в EC2, но только если он вошёл с MFA? Почему это сложно для CLI?</summary>

Политика с условием:

```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
}
```

В консоли это работает просто: пользователь вводит MFA при входе. А запросы CLI, подписанные постоянным access key, никогда не содержат признака MFA, поэтому условие не выполнится. Для CLI нужно сначала получить **временные** учётные данные с MFA: `aws sts get-session-token --serial-number <arn MFA> --token-code 123456` — и работать с ними. Или использовать IAM Identity Center, где MFA встроена в вход. Это хороший пример, почему временные учётные данные удобнее постоянных.
</details>

<details markdown="1">
<summary>2. Как ограничить доступ к S3-бакету так, чтобы читать его мог только один конкретный EC2-инстанс?</summary>

Ключ на сервер класть нельзя (глава 05 объяснит почему). Правильная схема:

1. Создать **роль** с политикой `s3:GetObject` только на этот бакет и прикрепить её к инстансу через instance profile (глава 05).
2. Для надёжности добавить **bucket policy** на стороне бакета, которая запрещает доступ всем, кроме этой роли (условие `aws:PrincipalArn`).

Тогда даже администратор аккаунта с широкими правами не прочитает бакет «случайно», а утечка ключей других пользователей не откроет к нему доступ.
</details>

<details markdown="1">
<summary>3. Ключ пользователя утёк. Вы его удалили через 10 минут. Достаточно ли этого?</summary>

Нет. За 10 минут с правами пользователя атакующий мог:

- создать **другого** IAM-пользователя или новый access key — и продолжить уже с ним;
- запустить ресурсы (майнеры) в других регионах;
- прочитать данные.

Нужно проверить **CloudTrail → Event history** по этому access key: какие действия были сделаны после утечки. Особое внимание — `CreateUser`, `CreateAccessKey`, `AttachUserPolicy`, `RunInstances` во всех регионах. Чем уже были права ключа, тем короче этот список. Это и есть практический смысл least privilege.
</details>
