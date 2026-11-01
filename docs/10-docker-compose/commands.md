# 10 · Docker Compose — шпаргалка

## Что добавляем в проект

```text
devops-handbook/
├── app/
│   ├── backend/        ← Dockerfile из главы 09
│   └── frontend/       ← index.html + nginx.conf (bind mount в nginx)
└── project/
    └── docker-compose.yml   ← весь стек: nginx + backend + redis + volume
```

## Запуск и остановка

```bash
cd project
docker compose config --quiet          # ← проверить файл (без вывода = OK)
docker compose config                  # ← итоговый конфиг со всеми подстановками
docker compose up -d --build           # ← собрать и запустить в фоне
docker compose up                      # ← в foreground, логи в терминал (Ctrl+C — стоп)
docker compose ps                      # ← статус сервисов
docker compose ls                      # ← все проекты Compose на машине
docker compose stop                    # ← остановить, не удаляя
docker compose start                   # ← запустить остановленные
docker compose down                    # ← удалить контейнеры и сеть (volume остаётся)
docker compose down -v                 # ← + удалить named volumes (данные!)
```

## Отдельные сервисы

```bash
docker compose up -d --build backend   # ← пересобрать и обновить только backend
docker compose restart backend
docker compose stop redis
docker compose start redis
docker compose up -d --scale backend=3 # ← три копии backend
docker compose restart nginx           # ← nginx перечитает адреса backend
```

## Логи и отладка

```bash
docker compose logs                    # ← все сервисы
docker compose logs -f backend         # ← следить за одним
docker compose logs --tail 20 nginx
docker compose exec backend sh         # ← shell в работающем контейнере
docker compose exec backend sh -c 'env | grep REDIS'
docker compose exec nginx getent hosts backend      # ← как nginx видит backend
docker compose exec redis redis-cli get hits        # ← значение счётчика в Redis
docker compose top                     # ← процессы во всех контейнерах
```

## Проверить приложение

=== "macOS / Linux"

    ```bash
    curl http://localhost:8080/api/hits    # → {"hits":N}
    curl http://localhost:8080/health      # → {"status":"ok",...}
    curl http://localhost:8080/info        # → {"hostname":"...","version":"1.0.0",...}
    ```

=== "Windows (PowerShell)"

    ```powershell
    curl.exe http://localhost:8080/api/hits
    curl.exe http://localhost:8080/health
    curl.exe http://localhost:8080/info
    ```

## Шпаргалка по ключам

```yaml
name: my-project                 # имя проекта (иначе — имя папки)

services:
  app:
    build: ./path                # собрать из Dockerfile
    image: nginx:alpine          # или готовый образ
    ports: ["8080:80"]           # ХОСТ:КОНТЕЙНЕР
    environment:
      - KEY=value
    env_file: .env               # переменные из файла (.env не коммитить)
    volumes:
      - ./conf:/etc/app:ro       # bind mount, только чтение
      - data:/var/lib/app        # named volume
    depends_on:
      db:
        condition: service_healthy   # ждать healthcheck
    restart: unless-stopped      # перезапуск при падении
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  data:
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `port is already allocated` | Порт 8080 занят — `docker ps`, найдите и остановите, или смените порт хоста |
| `/api/hits` зависает | Redis не запущен — `docker compose ps redis` |
| `502 Bad Gateway` | Backend стартует или упал (`docker compose logs backend`); после пересоздания/масштабирования — `docker compose restart nginx` |
| `no configuration file provided` | Команда запущена не в папке с `docker-compose.yml` — `cd project` или `-f path/docker-compose.yml` |
| `invalid mount config` / пустой файл в контейнере | Неверный путь bind mount — пути относительны файлу compose |
| Изменения в коде не видны | Нужен `--build`: `docker compose up -d --build` |
| Счётчик не сбрасывается | Данные в volume — `docker compose down -v` |
| `docker-compose: command not found` | Старая утилита v1 — пишите `docker compose` через пробел |

## ✅ Самопроверка

```bash
docker compose ps                         # → 3 сервиса Up, порт 8080 только у nginx
curl -s localhost:8080/api/hits           # → растёт
docker compose down && docker compose up -d && curl -s localhost:8080/api/hits   # → продолжает
docker compose down -v && docker compose ps   # → пусто
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Docker Compose — обзор | [docs.docker.com/compose](https://docs.docker.com/compose/) |
| Справочник compose-файла | [docs.docker.com/reference/compose-file](https://docs.docker.com/reference/compose-file/) |
| Команды `docker compose` | [docs.docker.com/reference/cli/docker/compose](https://docs.docker.com/reference/cli/docker/compose/) |
| Сети в Compose | [docs.docker.com/compose/how-tos/networking](https://docs.docker.com/compose/how-tos/networking/) |
| Порядок запуска и healthcheck | [docs.docker.com/compose/how-tos/startup-order](https://docs.docker.com/compose/how-tos/startup-order/) |
| Volumes | [docs.docker.com/engine/storage/volumes](https://docs.docker.com/engine/storage/volumes/) |
| Образ Redis | [hub.docker.com/_/redis](https://hub.docker.com/_/redis) |
