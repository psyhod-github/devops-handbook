# 04 · IAM: пользователи и политики — шпаргалка

## Что получится в аккаунте

```text
IAM
├── User   admin            ← консоль + MFA, AdministratorAccess (вместо root)
├── User   devops-course    ← только CLI (access key)
└── Group  ec2-admins       ← AmazonEC2FullAccess; участник: devops-course
```

Временные объекты практики (удаляются): user `devops-readonly`, group `ec2-readonly`, policy `sg-manage-us-west-2`, inline `deny-sg-delete`.

## Кто я и откуда ключи

```bash
aws sts get-caller-identity                  # ← работает всегда, права не нужны
aws sts get-caller-identity --query Arn --output text
aws configure list                           # ← колонка Type: env / shared-credentials-file / iam-role
aws configure list-profiles
```

Порядок поиска учётных данных: `--profile` → переменные `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` → `AWS_PROFILE` или `[default]` в `~/.aws/` → роль контейнера / EC2.

```bash
# Сбросить переменные, которые могут перекрывать профиль
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN          # bash
Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue   # PowerShell
```

## Шаблон политики

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "HumanReadableName",
      "Effect": "Allow",
      "Action": ["service:Action", "service:Describe*"],
      "Resource": "arn:aws:service:region:account:resource",
      "Condition": { "StringEquals": { "aws:RequestedRegion": "us-west-2" } }
    }
  ]
}
```

## Логика решения

```text
явный Deny?  → ❌ запрещено
иначе Allow? → ✅ разрешено
иначе        → ❌ запрещено (implicit deny)
```

## Полезные условия (Condition)

| Ключ | Пример | Зачем |
|------|--------|-------|
| `aws:RequestedRegion` | `"StringEquals": {"aws:RequestedRegion": "us-west-2"}` | Работать только в одном регионе |
| `aws:SourceIp` | `"IpAddress": {"aws:SourceIp": "203.0.113.0/24"}` | Только из офисной сети |
| `aws:MultiFactorAuthPresent` | `"Bool": {"aws:MultiFactorAuthPresent": "true"}` | Только с MFA |
| `aws:ResourceTag/<key>` | `"StringEquals": {"aws:ResourceTag/Env": "lab"}` | Только ресурсы с тегом |

## ARN — примеры

```text
arn:aws:iam::123456789012:user/devops-course
arn:aws:iam::123456789012:role/ec2-app-role
arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess          ← AWS managed
arn:aws:iam::123456789012:policy/sg-manage-us-west-2     ← customer managed
arn:aws:ec2:us-west-2:123456789012:instance/i-0abc...
arn:aws:s3:::my-bucket          ← бакет (для s3:ListBucket)
arn:aws:s3:::my-bucket/*        ← объекты (для s3:GetObject)
```

## Расшифровать ошибку EC2 (в CloudShell под admin)

```bash
aws sts decode-authorization-message --encoded-message '<строка из ошибки>' \
  --query DecodedMessage --output text \
  | jq '{allowed, explicitDeny, action: .context.action, who: .context.principal.arn}'
```

## IAM через CLI (для справки)

Пользователь `devops-course` не имеет прав на IAM. Эти команды выполняйте в CloudShell под `admin`.

```bash
aws iam list-users --query 'Users[].UserName'
aws iam list-groups-for-user --user-name devops-course
aws iam list-attached-group-policies --group-name ec2-admins
aws iam list-access-keys --user-name devops-course
aws iam get-access-key-last-used --access-key-id AKIA...

aws iam create-policy --policy-name my-policy --policy-document file://policy.json
aws iam attach-group-policy --group-name ec2-admins --policy-arn arn:aws:iam::123456789012:policy/my-policy

# Ротация ключа
aws iam create-access-key --user-name devops-course
aws iam update-access-key --user-name devops-course --access-key-id AKIAOLD... --status Inactive
aws iam delete-access-key --user-name devops-course --access-key-id AKIAOLD...
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `UnauthorizedOperation` (EC2) с `Encoded authorization failure message` | Нет права; расшифровать через `decode-authorization-message` |
| `AccessDenied ... because no identity-based policy allows` | Implicit deny — нужен Allow |
| `AccessDenied ... with an explicit deny` | Где-то есть Deny — Allow не поможет, ищите запрет |
| `s3:ListBucket` разрешён, но `AccessDenied` при чтении | Не указан ARN объектов `bucket/*` |
| Изменил политику, а права не появились | Подождите несколько секунд; проверьте, к тому ли user/group прикреплено |
| CLI работает «не от того» пользователя | Переменные `AWS_ACCESS_KEY_ID` перекрывают профиль — `aws configure list` |

## ✅ Самопроверка

- [ ] Консоль: справа сверху `admin @ ...`, при входе спрашивается MFA.
- [ ] `aws sts get-caller-identity --profile devops-course` → `user/devops-course`.
- [ ] **IAM → Users → devops-course → Permissions**: `AmazonEC2FullAccess` с пометкой *Group ec2-admins*, прямых политик нет.
- [ ] `devops-readonly`, `ec2-readonly`, `sg-manage-us-west-2` удалены.

## Почитать

| Тема | Ссылка |
|------|--------|
| IAM — документация | [docs.aws.amazon.com/IAM/latest/UserGuide](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) |
| Best practices IAM | [docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) |
| Синтаксис политик | [docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html) |
| Логика вычисления политик | [docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html) |
| Глобальные ключи условий | [docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html) |
| Действия, ресурсы и ключи по сервисам | [docs.aws.amazon.com/service-authorization/latest/reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html) |
| Порядок поиска credentials в CLI | [docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) |
| IAM Identity Center | [docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html) |
| Policy Simulator | [policysim.aws.amazon.com](https://policysim.aws.amazon.com) |
