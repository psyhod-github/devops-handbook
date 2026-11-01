# 03 · AWS CLI и EC2 — шпаргалка

## Что создаём (и удаляем в конце)

```text
IAM user     devops-course      ← остаётся (AmazonEC2FullAccess + access key)
~/.aws/      профиль devops-course
us-west-2 / default VPC
├── Key Pair        lesson-key  (ed25519 → ~/.ssh/lesson-key.pem)
├── Security Group  lesson-sg   (SSH ← ваш IP/32)
└── EC2             lesson-ec2  (AL2023, t3.micro)
```

## Настройка и профили

```bash
aws configure --profile devops-course     # ← ключ, секрет, us-west-2, json
aws configure list-profiles               # ← все профили
aws configure list                        # ← откуда взяты ключи и регион сейчас

export AWS_PROFILE=devops-course          # bash
$env:AWS_PROFILE = "devops-course"        # PowerShell

aws sts get-caller-identity               # ← КТО Я. Перед любым изменением
aws sts get-caller-identity --profile devops-course
```

Файлы: `~/.aws/credentials` (ключи), `~/.aws/config` (регион, формат). Windows: `C:\Users\<имя>\.aws\`.

## Сеть

```bash
aws ec2 describe-vpcs --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock,Default:IsDefault}' --output table
aws ec2 describe-subnets --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch}' --output table
aws ec2 describe-route-tables --query 'RouteTables[].Routes[]' --output table
```

## Key Pair

```bash
# bash
aws ec2 create-key-pair --key-name lesson-key --key-type ed25519 \
  --query 'KeyMaterial' --output text > ~/.ssh/lesson-key.pem
chmod 400 ~/.ssh/lesson-key.pem
```

```powershell
# PowerShell — не используйте > и Out-File для ключей
$key = aws ec2 create-key-pair --key-name lesson-key --key-type ed25519 --query 'KeyMaterial' --output text
[IO.File]::WriteAllText("$HOME\.ssh\lesson-key.pem", ($key -join "`n") + "`n")
icacls "$HOME\.ssh\lesson-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

```bash
aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text
aws ec2 delete-key-pair --key-name lesson-key
```

## Security Group

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
SG_ID=$(aws ec2 create-security-group --group-name lesson-sg \
  --description "SSH from my IP only" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32"
aws ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].IpPermissions'
aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32"
aws ec2 delete-security-group --group-id "$SG_ID"
```

## AMI

```bash
# Последний Amazon Linux 2023 x86_64 от Amazon
AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)

# Через публичный параметр SSM (нужно право ssm:GetParameters)
aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text
```

## Инстанс

```bash
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --key-name lesson-key --security-group-ids "$SG_ID" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lesson-ec2}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text

# Все инстансы с именами
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,IP:PublicIpAddress}' \
  --output table

# По тегу
aws ec2 describe-instances --filters "Name=tag:Name,Values=lesson-ec2" "Name=instance-state-name,Values=running"
```

## Жизненный цикл

```bash
aws ec2 stop-instances      --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped    --instance-ids "$INSTANCE_ID"
aws ec2 start-instances     --instance-ids "$INSTANCE_ID"
aws ec2 reboot-instances    --instance-ids "$INSTANCE_ID"
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"     # ← без подтверждения, необратимо
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
```

| Состояние | Compute | Диск EBS | Публичный IP |
|-----------|---------|----------|--------------|
| running | платите | платите | есть |
| stopped | нет | платите | освобождён |
| terminated | нет | удалён | — |

## Переносы строк

| Оболочка | Перенос | Переменная |
|----------|---------|------------|
| bash / Git Bash | `\` | `VAR=$(...)`, `"$VAR"` |
| PowerShell | `` ` `` (обратный апостроф) | `$VAR = ...`, `$VAR` |

## Уборка

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
aws ec2 delete-security-group --group-id "$SG_ID"
aws ec2 delete-key-pair --key-name lesson-key
rm -f ~/.ssh/lesson-key.pem
```

## Частые ошибки

| Ошибка | Причина |
|--------|---------|
| `Unable to locate credentials` | Нет `aws configure` или не задан профиль |
| `InvalidClientTokenId` | Ключ удалён, деактивирован или из другого аккаунта |
| `SignatureDoesNotMatch` | Неверный секретный ключ (опечатка при вставке) |
| `UnauthorizedOperation` / `AccessDenied` | У пользователя нет права на действие |
| `InvalidKeyPair.Duplicate` | Key Pair с таким именем уже есть |
| `InvalidGroup.Duplicate` | Security Group с таким именем уже есть в этой VPC |
| `DependencyViolation` при удалении SG | Инстанс ещё не завершился — `wait instance-terminated` |
| `InvalidAMIID.NotFound` | AMI из другого региона или устарел |
| `bash: --filters: command not found` | Перенос строки без `\` в конце предыдущей строки |

## ✅ Самопроверка

```bash
aws sts get-caller-identity                       # → Arn ...:user/devops-course
aws configure list                                # → region us-west-2
aws ec2 describe-instances --filters "Name=tag:Name,Values=lesson-ec2" \
  --query 'Reservations[].Instances[].State.Name' --output text   # → terminated (после уборки)
```

## Почитать

| Тема | Ссылка |
|------|--------|
| AWS CLI — документация | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/) |
| Настройка профилей | [docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) |
| Фильтрация вывода `--query` | [docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html) |
| JMESPath — учебник | [jmespath.org/tutorial.html](https://jmespath.org/tutorial.html) |
| Справочник `aws ec2` | [docs.aws.amazon.com/cli/latest/reference/ec2](https://docs.aws.amazon.com/cli/latest/reference/ec2/) |
| Жизненный цикл инстанса | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html) |
| Поиск AMI через SSM | [docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-public-parameters-ami.html](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-public-parameters-ami.html) |
