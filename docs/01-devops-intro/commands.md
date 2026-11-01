# 01 · Что такое DevOps — шпаргалка

В этой главе нет команд. Здесь собраны термины и схемы, к которым удобно возвращаться.

## Термины

| Термин | Определение |
|--------|-------------|
| **DevOps** | Подход к частым и безопасным изменениям системы: культура общей ответственности + автоматизация + обратная связь |
| **CI** (Continuous Integration) | Каждое изменение кода автоматически собирается и тестируется после `git push` |
| **CD** (Continuous Delivery) | Проверенное изменение автоматически готовится к выкладке; финальное решение за человеком |
| **CD** (Continuous Deployment) | Проверенное изменение автоматически выкладывается в продакшен |
| **IaC** (Infrastructure as Code) | Инфраструктура описана в файлах, хранится в Git, создаётся инструментом |
| **Декларативный подход** | Описываете **что** должно быть (желаемое состояние), а не **как** этого добиться |
| **Pipeline** | Цепочка автоматических шагов: сборка → тесты → доставка |
| **Least privilege** | Каждый получает минимально необходимые права |
| **Blast radius** | Сколько всего пострадает, если один компонент взломан или сломан |
| **Observability** | Понимание состояния системы по её метрикам, логам и трассировкам |
| **Source of truth** | Единственное место, где описано, как должно быть. В DevOps это Git |

## Жизненный цикл

```text
Plan → Code → Build → Test → Release → Deploy → Operate → Monitor
  ↑                                                          │
  └──────────────────── обратная связь ──────────────────────┘
```

## Инструменты пособия по этапам

| Этап | Инструмент | Глава |
|------|------------|-------|
| Code | Git, GitHub | 00 |
| Build | Docker | 09 |
| Test / CI | Jenkins | 11–12 |
| Infrastructure | AWS, Terraform | 02–08 |
| Configuration | Ansible | 13–14 |
| Run / Orchestrate | Docker Compose, Kubernetes | 10, 15–18 |

## Учебный проект

```text
Browser → Nginx :8080 → Node.js backend :3000 → Redis
```

| Endpoint | Что возвращает |
|----------|----------------|
| `GET /` | Фронтенд |
| `GET /api/hits` | Счётчик (Redis) |
| `GET /health` | Healthcheck |
| `GET /info` | Hostname и версия |
| `GET /metrics` | Метрики Prometheus |

## Почитать

| Тема | Ссылка |
|------|--------|
| Что такое DevOps (AWS) | [aws.amazon.com/devops/what-is-devops](https://aws.amazon.com/devops/what-is-devops/) |
| Infrastructure as Code (Terraform) | [developer.hashicorp.com/terraform/intro](https://developer.hashicorp.com/terraform/intro) |
| Что такое контейнер (Docker) | [docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) |
| Continuous Delivery — Martin Fowler | [martinfowler.com/bliki/ContinuousDelivery.html](https://martinfowler.com/bliki/ContinuousDelivery.html) |
| DORA — метрики эффективности доставки | [dora.dev](https://dora.dev/) |
