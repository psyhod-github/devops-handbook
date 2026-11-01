# 05 · IAM: роли — шпаргалка

## Что создаём (и удаляем в конце)

```text
S3      roles-lab-<account-id>/hello.txt
IAM     policy  s3-read-roles-lab   (ListBucket + GetObject на один бакет)
        role    ec2-s3-read-role    (trust: ec2.amazonaws.com)
                └── instance profile ec2-s3-read-role (создан консолью)
EC2     t3.micro + roles-lab-key + roles-lab-sg (SSH ← My IP), IMDSv2 required
```

## Trust policy для EC2

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Роль через CLI (в CloudShell под admin)

```bash
aws iam create-role --role-name ec2-s3-read-role \
  --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name ec2-s3-read-role \
  --policy-arn arn:aws:iam::123456789012:policy/s3-read-roles-lab

# В CLI instance profile НЕ создаётся автоматически
aws iam create-instance-profile --instance-profile-name ec2-s3-read-role
aws iam add-role-to-instance-profile \
  --instance-profile-name ec2-s3-read-role --role-name ec2-s3-read-role

# Запуск инстанса с ролью (нужно право iam:PassRole на эту роль)
aws ec2 run-instances ... \
  --iam-instance-profile Name=ec2-s3-read-role \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled

# Прикрепить роль к уже работающему инстансу
aws ec2 associate-iam-instance-profile --instance-id i-0abc... \
  --iam-instance-profile Name=ec2-s3-read-role
```

## На инстансе

```bash
aws sts get-caller-identity
# → Arn: arn:aws:sts::123456789012:assumed-role/ec2-s3-read-role/i-0abc...
# → UserId: AROA...:i-0abc...

aws s3 ls s3://roles-lab-123456789012
aws s3 cp s3://roles-lab-123456789012/hello.txt -
aws configure list          # → Type: iam-role
```

## IMDSv2

```bash
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
MD() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; echo; }

MD instance-id
MD placement/region
MD iam/security-credentials/                      # → имя роли
MD iam/security-credentials/ec2-s3-read-role      # → ASIA..., Token, Expiration
```

```bash
# Включить обязательный IMDSv2 на существующем инстансе (снаружи)
aws ec2 modify-instance-metadata-options --instance-id i-0abc... \
  --http-tokens required --http-endpoint enabled
```

## Роль для человека (assume role)

```bash
# Разово
aws sts assume-role --role-arn arn:aws:iam::123456789012:role/my-role \
  --role-session-name anna --duration-seconds 3600

# Через профиль в ~/.aws/config
[profile my-role]
role_arn = arn:aws:iam::123456789012:role/my-role
source_profile = devops-course
region = us-west-2

aws sts get-caller-identity --profile my-role
```

## Префиксы ID

| Префикс | Что это |
|---------|---------|
| `AKIA` | Постоянный access key пользователя |
| `ASIA` | Временный access key (роль, STS) — нужен ещё session token |
| `AIDA` | UserId IAM-пользователя |
| `AROA` | UserId роли |

## Уборка

```bash
# EC2: terminate → удалить SG и Key Pair (консоль или команды главы 03)
aws s3 rb s3://roles-lab-123456789012 --force
# Роль, созданная в консоли, удаляется в консоли вместе с instance profile.
# Роль, созданная через CLI:
aws iam remove-role-from-instance-profile --instance-profile-name ec2-s3-read-role --role-name ec2-s3-read-role
aws iam delete-instance-profile --instance-profile-name ec2-s3-read-role
aws iam detach-role-policy --role-name ec2-s3-read-role --policy-arn arn:aws:iam::123456789012:policy/s3-read-roles-lab
aws iam delete-role --role-name ec2-s3-read-role
aws iam delete-policy --policy-arn arn:aws:iam::123456789012:policy/s3-read-roles-lab
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| На инстансе `Unable to locate credentials` | Instance profile не прикреплён или в trust policy не `ec2.amazonaws.com` |
| `You are not authorized to perform: iam:PassRole` при запуске | У запускающего нет права передавать роль сервису EC2 |
| Роль не видна в списке *IAM instance profile* | Роль создана через CLI без instance profile |
| `curl 169.254.169.254` → `401` | IMDSv2: сначала получите токен (`PUT /latest/api/token`) |
| `AccessDenied` на `s3:ListBucket`, хотя `GetObject` работает | В `Resource` нет ARN самого бакета (без `/*`) |
| `DeleteConflict` при удалении роли | Роль ещё в instance profile или к ней прикреплены политики |

## ✅ Самопроверка

```bash
# На инстансе
aws sts get-caller-identity --query Arn --output text     # → ...assumed-role/ec2-s3-read-role/i-...
ls ~/.aws 2>/dev/null || echo "no local keys"              # → no local keys
curl -s -o /dev/null -w "%{http_code}\n" http://169.254.169.254/latest/meta-data/   # → 401
```

## Почитать

| Тема | Ссылка |
|------|--------|
| IAM roles | [docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) |
| Роли для EC2 | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) |
| Instance profiles | [docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) |
| IMDSv2 | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html) |
| AWS STS | [docs.aws.amazon.com/STS/latest/APIReference/welcome.html](https://docs.aws.amazon.com/STS/latest/APIReference/welcome.html) |
| Роль через профиль CLI | [docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html) |
| Префиксы уникальных ID | [docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-unique-ids](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-unique-ids) |
