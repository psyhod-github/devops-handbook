# 02 · AWS: VPC и EC2 — шпаргалка

В этой главе вы работаете в консоли AWS. Здесь собраны пути по консоли, команды SSH и команды для сервера.

## Что создаём (и удаляем в конце)

```text
us-west-2 / default VPC (172.31.0.0/16)
├── Key Pair        devops-lab-key   (ED25519, .pem → ~/.ssh/)
├── Security Group  devops-lab-sg    (SSH ← My IP, HTTP ← 0.0.0.0/0)
└── EC2             devops-lab-ec2   (Amazon Linux 2023, t3.micro, public IP)
```

## Консоль: где что лежит

| Что | Путь в консоли |
|-----|----------------|
| VPC, подсети, маршруты, IGW | **VPC** → Your VPCs / Subnets / Route tables / Internet gateways |
| Key Pairs | **EC2** → Network & Security → Key Pairs |
| Security Groups | **EC2** → Network & Security → Security Groups |
| Инстансы | **EC2** → Instances |
| Диски | **EC2** → Elastic Block Store → Volumes |
| Все регионы сразу | **EC2** → EC2 Global View |

## Права на ключ

=== "macOS / Linux"

    ```bash
    mv ~/Downloads/devops-lab-key.pem ~/.ssh/
    chmod 400 ~/.ssh/devops-lab-key.pem
    ```

=== "Windows (PowerShell)"

    ```powershell
    Move-Item "$HOME\Downloads\devops-lab-key.pem" "$HOME\.ssh\"
    icacls "$HOME\.ssh\devops-lab-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
    ```

## SSH

```bash
ssh -i ~/.ssh/devops-lab-key.pem ec2-user@<PUBLIC_IP>     # ← Amazon Linux
ssh -i ~/.ssh/devops-lab-key.pem ubuntu@<PUBLIC_IP>       # ← Ubuntu
ssh -v -i ~/.ssh/devops-lab-key.pem ec2-user@<PUBLIC_IP>  # ← подробный вывод для диагностики
exit                                                      # ← выйти с сервера
```

| Пользователь по умолчанию | AMI |
|---------------------------|-----|
| `ec2-user` | Amazon Linux, RHEL, Fedora |
| `ubuntu` | Ubuntu |
| `admin` | Debian |

## На сервере

```bash
whoami                                  # → ec2-user
hostname                                # → ip-172-31-x-x.us-west-2.compute.internal
cat /etc/os-release | head -2           # → Amazon Linux 2023
ip -4 addr show                         # ← только приватный IP
curl -s https://checkip.amazonaws.com   # ← публичный IP (как вас видит интернет)
df -h /                                 # ← размер диска
free -h                                 # ← память
```

## Свой IP (для правила «My IP»)

```bash
curl https://checkip.amazonaws.com      # Windows: curl.exe https://checkip.amazonaws.com
```

## CIDR — быстрая таблица

| CIDR | Адресов | Типичное применение |
|------|---------|---------------------|
| `/32` | 1 | Один IP (ваш, для SSH) |
| `/24` | 256 (251 в AWS) | Подсеть |
| `/20` | 4 096 | Подсеть default VPC |
| `/16` | 65 536 | VPC |
| `/0` | все | «Весь интернет» |

## Диагностика SSH

| Симптом | Причина |
|---------|---------|
| `Connection timed out` | Security Group, нет public IP, нет маршрута на IGW, не тот IP или регион |
| `Connection refused` | Порт закрыт на самом сервере (сервис не слушает) |
| `Permission denied (publickey)` | Не тот ключ или пользователь |
| `UNPROTECTED PRIVATE KEY FILE` | Права на `.pem` слишком открытые |
| `Host key verification failed` | IP достался новому серверу; удалите старую запись: `ssh-keygen -R <PUBLIC_IP>` |

## Уборка — порядок

1. EC2 → Instances → **Terminate** → дождаться `Terminated`
2. Volumes → нет дисков в `available`
3. Security Groups → удалить `devops-lab-sg` (и `launch-wizard-*`)
4. Key Pairs → удалить `devops-lab-key`, удалить локальный `.pem`

## ✅ Самопроверка

- [ ] В route table default VPC есть `0.0.0.0/0 → igw-...`.
- [ ] Правило SSH в Security Group имеет источник `/32`, а не `0.0.0.0/0`.
- [ ] `ssh` пускает на сервер, `whoami` → `ec2-user`.
- [ ] После уборки: инстанс `Terminated`, нет учебных SG, Key Pair и дисков.

## Почитать

| Тема | Ссылка |
|------|--------|
| Регионы и зоны доступности | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) |
| Как работает VPC | [docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html](https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html) |
| Default VPC | [docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html) |
| Security Groups | [docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) |
| Network ACL | [docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html) |
| NAT Gateway | [docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html) |
| Подключение к EC2 по SSH | [docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-linux-inst-ssh.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-linux-inst-ssh.html) |
| AWS CLI (следующая глава) | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/) |
