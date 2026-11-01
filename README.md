# DevOps Handbook — DevOps с нуля

Бесплатное пособие для самостоятельного изучения DevOps. Подходит тем, кто начинает с нуля.
Вы шаг за шагом обвешиваете одно небольшое веб-приложение инфраструктурой: облако AWS, Terraform, Docker, CI на Jenkins, Ansible, Kubernetes.

📖 **Читать как сайт:** `https://psyhod-github.github.io/devops-handbook/`. Там есть поиск, тёмная тема и вкладки Windows / macOS / Linux.

## Учебный проект

Через всё пособие проходит одно приложение — счётчик посещений:

```
Browser → Nginx :8080 → Node.js backend :3000 → Redis
```

| Endpoint | Что возвращает |
|----------|----------------|
| `GET /` | Фронтенд (статика через Nginx) |
| `GET /api/hits` | Счётчик, каждый запрос увеличивает его в Redis |
| `GET /health` | Healthcheck backend-а |
| `GET /info` | Hostname контейнера и версия приложения |
| `GET /metrics` | Метрики в формате Prometheus |

Код приложения писать не нужно, он готов и лежит в [`app/`](app). Ваша задача — инфраструктура: Dockerfile, Terraform, pipeline, плейбуки, манифесты. Эталонные версии этих файлов лежат в [`project/`](project).

## Как учиться

1. Начните с [главы 00](docs/00-setup/README.md): установите инструменты и настройте защиту от лишних расходов в AWS.
2. Проходите главы по порядку. Каждая опирается на предыдущие.
3. В каждой главе три файла:
   - `README.md` — теория и практика по шагам;
   - `commands.md` — шпаргалка с командами;
   - `exercises.md` — задания трёх уровней, ответы спрятаны под спойлер.
4. Не пропускайте блоки **✅ Проверь себя**. Если результат не совпал, загляните в [Типичные ошибки](docs/troubleshooting.md).
5. После каждой главы, где вы работали в AWS, **удаляйте ресурсы**. Это правило, а не совет.

## Оглавление

| № | Глава | Статус |
|---|-------|--------|
| 00 | [Подготовка: установка, AWS Free Tier, бюджет](docs/00-setup/README.md) | ✅ |
| 01 | [Что такое DevOps](docs/01-devops-intro/README.md) | ✅ |
| 02 | [AWS: VPC и EC2](docs/02-aws-vpc-ec2/README.md) | ✅ |
| 03 | [AWS CLI и жизненный цикл EC2](docs/03-aws-cli-ec2/README.md) | ✅ |
| 04 | [IAM: пользователи и политики](docs/04-iam-users-policies/README.md) | ✅ |
| 05 | [IAM: роли и instance profile](docs/05-iam-roles/README.md) | ✅ |
| 06 | [Terraform: введение](docs/06-terraform-intro/README.md) | ✅ |
| 07 | [Terraform: remote state и модули](docs/07-terraform-state-modules/README.md) | ✅ |
| 08 | [Terraform: User Data и проект](docs/08-terraform-userdata/README.md) | ✅ |
| 09 | [Docker](docs/09-docker/README.md) | ✅ |
| 10 | [Docker Compose](docs/10-docker-compose/README.md) | ✅ |
| 11 | [Jenkins](docs/11-jenkins/README.md) | ✅ |
| 12 | [Jenkins + Docker](docs/12-jenkins-docker/README.md) | ✅ |
| 13 | [Ansible: основы](docs/13-ansible-basics/README.md) | ✅ |
| 14 | [Ansible: роли и деплой](docs/14-ansible-roles-deploy/README.md) | ✅ |
| 15 | [Kubernetes: Pod и Deployment](docs/15-k8s-pods-deployments/README.md) | ✅ |
| 16 | [Kubernetes: Service и Ingress](docs/16-k8s-services-ingress/README.md) | ✅ |
| 17 | [Kubernetes: ConfigMap, Secret, RBAC](docs/17-k8s-config-secrets-rbac/README.md) | ✅ |
| 18 | [Kubernetes: ресурсы и HPA](docs/18-k8s-hpa/README.md) | ✅ |
| — | [Типичные ошибки](docs/troubleshooting.md) · [Глоссарий](docs/glossary.md) | ✅ |

## Безопасность

- Никогда не коммитьте `*.pem`, `*.tfstate`, `.env`, `terraform.tfvars`, `inventory.ini`. Они уже есть в [`.gitignore`](.gitignore).
- Настройте AWS Budget Alert на $10 в месяц ещё до первого ресурса (глава 00).
- В конце каждой сессии в AWS запускайте `terraform destroy` или удаляйте ресурсы вручную.

## Сборка сайта локально

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install "mkdocs-material>=9.5,<10"
mkdocs serve                       # → http://127.0.0.1:8000
```

## Об авторе

<!-- TODO: имя, пара строк об опыте, ссылки (GitHub / LinkedIn) -->
_Заполняется автором._

## Лицензии

- Текст и изображения (`docs/`, этот README) распространяются под [CC BY-NC-SA 4.0](LICENSE).
- Код (`app/`, `project/`) распространяется под [MIT](LICENSE-CODE).
