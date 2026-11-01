# project/ — эталонные инфраструктурные файлы

Здесь лежат готовые версии файлов, которые вы пишете по ходу пособия. Сверяйтесь с ними, если что-то не работает.
Код приложения лежит в [`../app`](../app); его вы не меняете, только упаковываете и разворачиваете.

| Путь | Глава | Что это |
|------|-------|---------|
| `terraform/` | 06–08 | EC2 + Security Group + Key Pair + User Data, модуль `modules/web-server`, state в S3 |
| `../app/backend/Dockerfile` | 09 | Образ backend-а |
| `docker-compose.yml` | 10 | Весь стек: nginx + backend + redis + volume (запуск из `project/`) |
| `jenkins/` | 11 | Jenkins в Docker: Dockerfile с Docker CLI + compose (порт 9090) |
| `Jenkinsfile` | 12 | CI pipeline: build → smoke test → push на Docker Hub (Script Path: `project/Jenkinsfile`) |
| `ansible/` | 13–14 | `playbook.yml` (nginx, глава 13) и `site.yml` + роли `docker`, `app` (деплой стека из Docker Hub, глава 14) |
| `k8s/` | 15–18 | Манифесты Kubernetes (финальное состояние главы 18): namespace, redis, backend (ConfigMap, Secret, ServiceAccount, resources, probes), Service, Ingress, RBAC, HPA |

## Плейсхолдеры

Перед запуском замените значения на свои:

| Плейсхолдер | Где | На что заменить |
|-------------|-----|-----------------|
| `<your-dockerhub-user>` | `Jenkinsfile`, `ansible/group_vars/web.yml`, `k8s/backend-deployment.yaml` | Ваш логин на Docker Hub |
| `devops-course` | `terraform/` | Имя вашего профиля AWS CLI (глава 04) |
| `YOUR_ACCOUNT_ID` | `terraform/backend.tf` | Ваш AWS Account ID (12 цифр) — имя бакета со state |
| `ssh_cidr` | `terraform/terraform.tfvars` (из `.example`) | Ваш IP с `/32` |
| `203.0.113.10` | `ansible/inventory.ini.example` | Публичный IP вашего EC2 |

Файлы с реальными значениями (`terraform.tfvars`, `inventory.ini`, `*.pem`, `.env`) не коммитьте. Они уже есть в `.gitignore`.
