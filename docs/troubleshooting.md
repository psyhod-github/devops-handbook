# Типичные ошибки

Справочник по ошибкам, которые встречаются чаще всего, сгруппирован по инструментам.
Как пользоваться: найдите текст ошибки через поиск (Ctrl+F или поиск по сайту).

## AWS

### Консоль и регионы

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| «Пропал» инстанс или другой ресурс | Консоль открыта в другом регионе | Переключатель региона справа сверху; все регионы сразу — **EC2 → EC2 Global View** |
| Пришло письмо от AWS Budgets | Расходы или прогноз превысили порог | **Billing → Bills** — найти сервис и регион; удалить лишнее. Budgets сам ничего не останавливает |

### AWS CLI и учётные данные

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Unable to locate credentials` | CLI не нашёл ключей | `aws configure --profile ...`, задайте `AWS_PROFILE` или добавьте `--profile` |
| `InvalidClientTokenId` | Access key удалён, деактивирован или из другого аккаунта | `aws configure list` — какой ключ используется; создайте новый ключ в IAM |
| `SignatureDoesNotMatch` | Неверный secret key (ошибка при копировании) | Повторите `aws configure` для профиля |
| CLI работает «не от того» пользователя | Переменные `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` перекрывают профиль | `aws configure list` → колонка `Type`; удалите переменные окружения |
| `You must specify a region` | В профиле нет региона | `aws configure set region us-west-2 --profile ...` |
| `bash: --filters: command not found` | Перенос строки без `\` (bash) или `` ` `` (PowerShell) | Проверьте символ переноса в конце предыдущей строки |

### IAM и права

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `UnauthorizedOperation ... Encoded authorization failure message` | EC2: нет права на действие | Расшифровать в CloudShell: `aws sts decode-authorization-message --encoded-message '...'` |
| `AccessDenied ... because no identity-based policy allows` | Implicit deny: нет Allow | Добавьте право в политику пользователя, группы или роли |
| `AccessDenied ... with an explicit deny` | Сработал явный Deny | Allow не поможет — найдите и уберите запрет |
| `AccessDenied` на `s3:GetObject` при работающем `ListBucket` | В `Resource` нет `arn:aws:s3:::bucket/*` | Нужны оба ARN: бакет и `бакет/*` |
| `not authorized to perform: iam:PassRole` | Запуск EC2 с ролью без права передавать роль | Добавьте `iam:PassRole` на ARN роли |
| На EC2 `Unable to locate credentials` при прикреплённой роли | Нет instance profile или trust policy не для `ec2.amazonaws.com` | **EC2 → Instance → Security → IAM Role**; проверьте trust policy роли |
| `DeleteConflict` при удалении роли или пользователя | Остались ключи, политики или instance profile | Сначала удалить зависимости: ключи, политики, `remove-role-from-instance-profile` |

### EC2 и SSH

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Connection timed out` | Security Group не пускает ваш IP, нет public IP, нет маршрута на IGW, не тот IP | `curl https://checkip.amazonaws.com` и сравнить с правилом SG; проверить public IP инстанса |
| `Connection refused` | Сеть в порядке, но порт никто не слушает | Подождите минуту после запуска; проверьте сервис на сервере |
| `Permission denied (publickey)` | Не тот ключ или пользователь | Amazon Linux — `ec2-user`, Ubuntu — `ubuntu`; ключ того Key Pair, с которым запущен инстанс |
| `UNPROTECTED PRIVATE KEY FILE` / `Permissions ... are too open` | Права на `.pem` слишком широкие | macOS/Linux: `chmod 400 key.pem`; Windows: `icacls key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"` |
| `Load key ...: invalid format` (Windows) | Ключ сохранён в UTF-16 через `>` или `Out-File` | Пересоздайте ключ и сохраните через `[IO.File]::WriteAllText` (глава 03) |
| `Host key verification failed` / `REMOTE HOST IDENTIFICATION HAS CHANGED` | IP достался новому серверу | `ssh-keygen -R <IP>` |
| После Stop/Start не подключиться по старому IP | Публичный IP освобождается при остановке | Возьмите новый IP из `describe-instances` или консоли |
| `DependencyViolation` при удалении Security Group | Группа ещё прикреплена к инстансу | Дождитесь `terminated`: `aws ec2 wait instance-terminated` |
| `InvalidAMIID.NotFound` | AMI из другого региона или устарел | Искать AMI по имени с `--owners amazon` (глава 03) |
| `InsufficientInstanceCapacity` | В AZ временно нет свободных инстансов этого типа | Повторите позже или укажите другую подсеть (AZ) |

## Terraform

### Инициализация и провайдеры

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Inconsistent dependency lock file` | Изменили `required_providers` или lock-файл от другой версии | `terraform init -upgrade`, затем закоммитить новый `.terraform.lock.hcl` |
| `Failed to install provider` / таймаут при `init` | Сетевой сбой при скачивании провайдера | Повторить `terraform init`; при постоянной проблеме — прокси или `plugin_cache_dir` |
| `Module not installed` | Добавили или изменили `module` | `terraform init` |
| `Unsupported Terraform Core version` | Terraform старее, чем `required_version` | Обновить Terraform (глава 00) |
| `No valid credential sources found` | Terraform не нашёл ключи AWS | Проверьте `profile` / `AWS_PROFILE` и `aws sts get-caller-identity --profile ...` |

### Plan и apply

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Invalid value for variable` | Сработала `validation` | Исправьте значение в `terraform.tfvars` или `-var` |
| `No value for required variable` | Нет значения для переменной без `default` | Добавьте в `terraform.tfvars` |
| `InvalidKeyPair.Duplicate` / `InvalidGroup.Duplicate` | Ресурс с таким именем уже есть вне этого state | Удалите старый ресурс, смените имя или импортируйте (`import`) |
| `-/+` (replace) там, где ждали `~` | Изменён аргумент, который нельзя поменять на месте (`ami`, `user_data` с `replace_on_change`, имя SG) | Решите, допустимо ли пересоздание; для AMI — см. задания главы 06 |
| `N to add, N to destroy` после переименования или переноса в модуль | Terraform считает ресурс новым | Блок `moved { from = … to = … }` |
| План хочет изменить то, что вы не трогали | Drift: ресурс изменили вручную | Вернуть через `apply` или внести изменение в код |
| `DependencyViolation` при `destroy` Security Group | К группе прикреплён ресурс вне этого state | Найдите ресурс (**EC2 → Network interfaces**) и удалите его |

### State и backend

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Error acquiring the state lock` | Кто-то выполняет plan/apply | Подождите. Если процесс точно мёртв — `terraform force-unlock <ID>` |
| `Backend configuration changed` | Изменили блок `backend` | `terraform init -migrate-state` (перенести) или `-reconfigure` |
| `Variables may not be used here` в `backend` | Переменные в `backend` запрещены | Константы или `terraform init -backend-config="bucket=..."` |
| `NoSuchBucket` при `init` | Опечатка в имени бакета или он в другом регионе | `aws s3 ls`, сверьте `bucket` и `region` |
| `AccessDenied` при `init`/`plan` с S3 backend | Нет прав на бакет или `.tflock` | Политика с `s3:ListBucket` + `Get/Put/DeleteObject` (глава 07) |
| После удаления `terraform.tfstate` план хочет создать всё заново | Terraform «забыл» ресурсы | Восстановите state (версии в S3) или импортируйте ресурсы |

### User Data

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| Сайт не открывается сразу после `apply` | Скрипт ещё выполняется | Подождите 1–2 минуты; `cloud-init status --wait` |
| `cloud-init status` → `error` | Скрипт упал | `/var/log/cloud-init-output.log` или `aws ec2 get-console-output` |
| `vars map does not contain key` | `${VAR}` в шаблоне без экранирования | `$${VAR}` или `$VAR` |
| Изменили скрипт, а сервер старый | User Data выполняется только при первом запуске | `user_data_replace_on_change = true` или `apply -replace` |

## Docker

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Cannot connect to the Docker daemon` / `failed to connect to the docker API` | Docker Engine не запущен | Запустите Docker Desktop и дождитесь статуса *Engine running*. На Linux выполните `sudo systemctl start docker` |
| `permission denied while trying to connect to the Docker daemon socket` (Linux) | Пользователя нет в группе `docker` | `sudo usermod -aG docker $USER`, затем перелогиньтесь |
| `Bind for 0.0.0.0:3000 failed: port is already allocated` | Порт хоста уже занят другим контейнером или программой | `docker ps` → остановите лишний контейнер или используйте другой порт хоста: `-p 3001:3000` |
| `Conflict. The container name "/backend" is already in use` | Контейнер с таким именем уже существует, возможно остановленный | `docker rm -f backend` или выберите другое имя |
| `pull access denied` / `repository does not exist` | Опечатка в имени образа или образ не собран | `docker images` — проверьте имя. Соберите образ: `docker build -t ...` |
| `failed to read dockerfile: open Dockerfile: no such file or directory` | Команда запущена не из той папки | Перейдите в папку с `Dockerfile` или укажите путь к контексту: `docker build -t name app/backend` |
| Контейнер сразу переходит в `Exited` | Процесс внутри упал | `docker logs <имя>` — первая команда диагностики |
| `curl` в PowerShell выдаёт таблицу или ошибку `Invoke-WebRequest` | В Windows PowerShell `curl` — это алиас `Invoke-WebRequest` | Используйте `curl.exe` или откройте адрес в браузере |
| `Redis error: ... ECONNREFUSED` в логах backend-а (глава 09) | Redis ещё не запущен, это ожидаемо | `/health` и `/info` работают без Redis. Весь стек запускается в главе 10 |

## Docker Compose

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `no configuration file provided: not found` | Команда запущена не в папке с `docker-compose.yml` | `cd project` или `docker compose -f path/docker-compose.yml ...` |
| `/api/hits` зависает | Redis не запущен или недоступен | `docker compose ps redis`, `docker compose logs redis` |
| `502 Bad Gateway` от nginx | Backend ещё стартует или упал | Подождите; `docker compose logs backend` |
| `502` после пересоздания или `--scale` backend | Nginx запомнил старые IP backend при старте | `docker compose restart nginx` |
| После `--scale` hostname в `/info` не меняется | Та же причина: nginx знает только адреса на момент старта | `docker compose restart nginx` |
| Изменения в коде не видны | Образ не пересобран | `docker compose up -d --build` |
| Счётчик не сбрасывается после `down` | Данные в named volume | `docker compose down -v` |
| Bind mount: в контейнере пустая папка вместо файла | Неверный путь — пути считаются от файла compose | Проверьте путь, `docker compose config` |
| `docker-compose: command not found` | Устаревшая утилита v1 | Пишите `docker compose` (через пробел) |

## Jenkins

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `docker: not found` в сборке | В образе Jenkins нет Docker CLI | Соберите образ из `project/jenkins/Dockerfile` |
| `permission denied while trying to connect to the docker API` | У пользователя `jenkins` нет группы-владельца сокета | `group_add` в compose; на Linux — `DOCKER_GID=$(getent group docker \| cut -d: -f3)` и `up -d --force-recreate`. Не используйте `chmod 666` |
| Jenkins не открывается сразу после запуска | Стартует 30–60 секунд | `docker compose logs -f jenkins`, ждите `Jenkins is fully up and running` |
| Порт 8080 занят | Работает стек из главы 10 | Jenkins пособия слушает на хосте 9090 |
| Нет таблицы Stage View | Плагин не установлен | **Manage Jenkins → Plugins** → *Pipeline: Stage View* |
| `No such DSL method '...'` | Опечатка или не установлен плагин | Snippet Generator: `/job/<job>/pipeline-syntax` |
| `Could not find credentials entry with ID` | ID в Jenkins и в Jenkinsfile не совпадают | Credentials → проверить ID (`docker-hub-creds`) |
| `A secret was passed to "sh" using Groovy String interpolation` | Секрет в строке с двойными кавычками | `sh '''... "$SECRET" ...'''` |
| `unauthorized` / `denied` при `docker push` | Неверный токен, права только на чтение, чужой namespace | Новый токен *Read & Write*, свой логин в `DOCKER_HUB_REPO` |
| `invalid reference format` | В имени образа плейсхолдер `<...>` или заглавные буквы | Исправьте `DOCKER_HUB_REPO` |
| `Couldn't find any revision to build` | Неверная ветка в job | *Branch Specifier* `*/main` |
| Сборка зелёная, хотя в логе ошибка | Jenkins смотрит на код возврата, а не на текст | `set -o pipefail`; уберите лишние `\|\| true` |
| Сборка не стартует по коммиту | Poll SCM выключен или коммит в другой ветке | **Polling Log** job |
| `no space left on device` на агенте | Копятся образы и слои | Уборка в `post { always }`, `docker system prune` по расписанию |

## Ansible

### Установка и окружение

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `ansible: command not found` после `pipx install` | `~/.local/bin` не в `PATH` | `pipx ensurepath` и новый терминал |
| Старая версия Ansible | Установлен пакет из `apt` | `sudo apt remove ansible`, затем `pipx install --include-deps "ansible==14.5.0"` |
| `[WARNING]: Ansible is being run in a world writable directory` (WSL) | Проект лежит на `/mnt/c/...` — `ansible.cfg` игнорируется | Клонируйте репозиторий в `~` внутри WSL |
| `UNPROTECTED PRIVATE KEY FILE` (WSL) | Ключ на диске Windows | `cp /mnt/c/Users/<имя>/.ssh/id_ed25519* ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519` |
| `couldn't resolve module/action 'community.docker...'` | Коллекция не установлена | `ansible-galaxy collection install -r requirements.yml` |

### Подключение

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `UNREACHABLE ... Connection timed out` | Security Group, IP или сервер выключен | Проверьте IP в `inventory.ini`, правило SSH (глава 02) |
| `UNREACHABLE ... Permission denied (publickey)` | Не тот ключ или пользователь | `ansible_ssh_private_key_file`, `remote_user = ec2-user` |
| `Host key verification failed` / `REMOTE HOST IDENTIFICATION HAS CHANGED` | IP достался новому серверу | `ssh-keygen -R <IP>`. Не отключайте `host_key_checking` |
| `Missing sudo password` / `Permission denied` при установке | Нет `become: true` | Добавьте `become: true` в play или `-b` в ad-hoc команду |

### Плейбуки и роли

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `mapping values are not allowed here` / `did not find expected key` | Отступы YAML | Только пробелы, одинаковый отступ; `--syntax-check` |
| `'xxx' is undefined` | Переменная не задана | Проверьте `group_vars`, `defaults` роли, `-e` |
| Задача всегда `changed` | `command`/`shell` вместо модуля | Используйте модуль; иначе `changed_when` / `creates` |
| Пакет остался после удаления задачи | Ansible не хранит state | Задача с `state: absent` |
| Handler не выполнился | Уведомившая задача вернула `ok`, или play упал раньше | Это норма при отсутствии изменений; при падении — `--force-handlers` |
| `--check` падает на сервисе, которого «ещё нет» | Предыдущая задача в check-режиме ничего не установила | Ожидаемо на чистом сервере; используйте `--check` для обновлений |
| Новый `index.html` не виден в nginx-контейнере | Bind mount одиночного файла держит старый inode | Перезапуск контейнера (handler `Restart nginx`) |
| `bind: address already in use` на порту 80 | На сервере работает nginx из User Data или главы 13 | Пересоздайте сервер с `install_nginx=false` |
| `manifest unknown` при запуске стека | Нет такого тега образа на Docker Hub | Проверьте `docker_hub_user` и номер сборки |
| После `app_version=latest` версия не обновилась | `pull: missing` не скачивает существующий тег | Деплойте номерами сборок |

## Kubernetes

### Кластер и kubectl

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| `The connection to the server localhost:8080 was refused` | У kubectl нет текущего контекста (кластер остановлен или удалён) | `minikube start`; `kubectl config current-context` |
| Команды действуют «не на тот» кластер | Другой текущий контекст | `kubectl config current-context`, `kubectl config use-context minikube` |
| `minikube start` падает / зависает | Docker не запущен, мало памяти | Запустите Docker Desktop; `minikube delete && minikube start` |
| `No resources found in default namespace` | Забыли `-n bootcamp` | `-n bootcamp` или `kubectl config set-context --current --namespace=bootcamp` |
| `ContainerCannotRun` у пода с `/bin/sh -c ...` (Git Bash) | Git Bash превратил `/bin/sh` в путь Windows | PowerShell, `sh` без пути или `MSYS_NO_PATHCONV=1` |

### Поды

| Статус / симптом | Причина | Что делать |
|------------------|---------|------------|
| `Pending` | Нет ноды с нужными ресурсами или ждёт том | `kubectl describe pod` → Events (`Insufficient cpu/memory`) |
| `ErrImagePull` / `ImagePullBackOff` | Опечатка в образе, нет тега, приватный реестр | `describe pod`; образ локально — `minikube image build`, тег не `latest` |
| `CrashLoopBackOff` | Процесс падает при старте | `kubectl logs <pod> --previous` |
| `Running`, но `READY 0/1` | Не проходит readiness probe | `describe pod`, `logs`; проверьте путь и порт пробы |
| `CreateContainerConfigError` | Нет ConfigMap/Secret или ключа | `describe pod`; примените объекты: `kubectl apply -f k8s-lab/` |
| `OOMKilled`, `Exit Code: 137` | Превышен лимит памяти | Увеличьте `limits.memory` или ищите утечку |
| Удалил под — появился снова | Под принадлежит Deployment | Удаляйте Deployment или `replicas: 0` |
| Данные Redis пропали после перезапуска пода | Нет постоянного тома | PersistentVolumeClaim (задания главы 15) |

### Service и Ingress

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| Service не отвечает, `endpoints` пустые | `selector` не совпадает с метками подов, или поды не Ready | `kubectl get endpointslices -n bootcamp`, сравните метки |
| NodePort недоступен по `$(minikube ip):30080` (Windows/macOS) | Драйвер docker не пробрасывает IP ноды | `minikube service <svc> -n bootcamp --url` |
| `404 Not Found` от nginx | Нет правила для этого Host/пути | Проверьте `host` в Ingress и строку в `hosts` |
| `503 Service Temporarily Unavailable` | У Service нет готовых подов | `endpointslices`, readiness подов |
| `bootcamp.local` не открывается | Нет записи в `hosts` или трафик не доходит до контроллера | `hosts`: `127.0.0.1 bootcamp.local` + `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8088:80` |
| Ingress создан, но не работает | Нет Ingress Controller или не тот `ingressClassName` | `kubectl get pods -n ingress-nginx`, `kubectl get ingressclass` |

### Конфигурация, RBAC, HPA

| Ошибка / симптом | Причина | Что делать |
|------------------|---------|------------|
| Изменили ConfigMap/Secret — приложение не видит | Переменные окружения фиксируются при старте | `kubectl rollout restart deploy/<name>` |
| `Forbidden: ... cannot list resource "pods"` | У ServiceAccount нет прав | Role + RoleBinding; проверка `kubectl auth can-i ... --as=system:serviceaccount:<ns>:<sa>` |
| HPA `TARGETS: <unknown>` | Нет metrics-server или `requests.cpu` | `minikube addons enable metrics-server`; добавьте requests |
| HPA не масштабирует под нагрузкой | Нагрузка слишком слабая | Генератор нагрузки внутри кластера (глава 18) |
| Реплики не уменьшаются | Окно стабилизации 5 минут | Подождите или настройте `behavior.scaleDown` |
| После `kubectl apply` реплик стало меньше | В Deployment указан `replicas` при включённом HPA | Уберите `replicas` из манифеста |
