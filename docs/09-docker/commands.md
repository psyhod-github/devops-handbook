# 09 · Docker — шпаргалка

Упаковываем Node.js backend в контейнер. Всё запускается локально, AWS не нужен.

## Что добавляем в проект

```text
devops-handbook/
└── app/
    └── backend/
        ├── app.js
        ├── package.json
        ├── Dockerfile       ← рецепт образа
        └── .dockerignore    ← что НЕ отправлять в сборку
```

## Dockerfile

```dockerfile
FROM node:22-alpine            # ← базовый образ: Alpine Linux + Node.js 22 LTS
WORKDIR /app                   # ← рабочая папка внутри образа

COPY package*.json ./          # ← сначала только зависимости (для кеша)
RUN npm install --omit=dev     # ← без dev-зависимостей

COPY . .                       # ← код — последним

EXPOSE 3000                    # ← документация: приложение слушает 3000
CMD ["node", "app.js"]         # ← команда запуска контейнера
```

## .dockerignore

```text
node_modules
npm-debug.log*
.env
*.pem
```

## Проверить установку

```bash
docker --version               # → Docker version 2x.x.x
docker run hello-world         # → Hello from Docker!
docker info                    # ← если ошибка — Docker Engine не запущен
```

## Сборка образа

```bash
cd app/backend
docker build -t devops-bootcamp-backend .        # ← "." = build context (текущая папка)
docker build -t devops-bootcamp-backend:1.0 .    # ← с явным тегом версии
docker build -t devops-bootcamp-backend app/backend   # ← из корня репозитория
docker build --no-cache -t devops-bootcamp-backend .  # ← собрать без кеша

docker images                                    # ← список образов
docker images devops-bootcamp-backend            # ← только наш
docker history devops-bootcamp-backend           # ← слои образа и их размер
```

## Запуск контейнера

```bash
# В фоне, с именем и пробросом порта ХОСТ:КОНТЕЙНЕР
docker run -d -p 3000:3000 --name backend devops-bootcamp-backend

# В foreground: логи прямо в терминале, Ctrl+C — остановить
docker run --rm -p 3000:3000 devops-bootcamp-backend     # ← --rm: удалить контейнер после остановки

# Другой порт на хосте
docker run -d -p 8080:3000 --name backend2 devops-bootcamp-backend   # → http://localhost:8080

# С переменной окружения
docker run -d -p 3001:3000 -e APP_VERSION=2.0.0 --name backend-v2 devops-bootcamp-backend
```

## Проверить приложение

=== "macOS / Linux"

    ```bash
    curl http://localhost:3000/health     # → {"status":"ok","uptime":12}
    curl http://localhost:3000/info       # → {"hostname":"c0a4a51cbe87","version":"1.0.0","node":"v22.x.x"}
    ```

=== "Windows (PowerShell)"

    ```powershell
    curl.exe http://localhost:3000/health     # ← именно curl.exe, не curl
    curl.exe http://localhost:3000/info
    ```

`/api/hits` без Redis зависает. Это ожидаемо, Redis появится в главе 10.

## Управление контейнерами

```bash
docker ps                      # ← запущенные
docker ps -a                   # ← все, включая остановленные

docker logs backend            # ← логи
docker logs -f backend         # ← следить за логами (Ctrl+C — выйти)
docker logs --tail 20 backend  # ← последние 20 строк

docker exec -it backend sh     # ← shell внутри контейнера (exit — выйти)
docker exec backend env        # ← выполнить одну команду: переменные окружения

docker stop backend            # ← остановить (SIGTERM, потом SIGKILL через 10 с)
docker start backend           # ← запустить тот же контейнер снова
docker restart backend         # ← stop + start

docker inspect backend         # ← вся конфигурация контейнера в JSON
```

## Уборка

```bash
docker stop backend
docker rm backend                      # ← удалить контейнер (должен быть остановлен)
docker rm -f backend                   # ← stop + rm одной командой
docker rmi devops-bootcamp-backend     # ← удалить образ

docker system df                       # ← сколько места занимает Docker
docker image prune                     # ← удалить образы без тегов (спросит подтверждение)
```

## ✅ Самопроверка

```bash
# 1. Образ собран
docker images devops-bootcamp-backend
# → devops-bootcamp-backend   latest   ...   ~270MB

# 2. Контейнер работает
docker ps --filter name=backend
# → ... Up 10 seconds   0.0.0.0:3000->3000/tcp   backend

# 3. Приложение отвечает
curl http://localhost:3000/health
# → {"status":"ok","uptime":...}

# 4. После уборки ничего не осталось
docker ps -a --filter name=backend     # → пусто
docker images devops-bootcamp-backend  # → пусто
```

Ошибки и их решения собраны в разделе [Типичные ошибки → Docker](../troubleshooting.md#docker).

## Почитать

| Тема | Ссылка |
|------|--------|
| Docker — документация | [docs.docker.com](https://docs.docker.com/) |
| Что такое контейнер | [docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) |
| Dockerfile reference | [docs.docker.com/reference/dockerfile](https://docs.docker.com/reference/dockerfile/) |
| Best practices для Dockerfile | [docs.docker.com/build/building/best-practices](https://docs.docker.com/build/building/best-practices/) |
| Кеш сборки | [docs.docker.com/build/cache](https://docs.docker.com/build/cache/) |
| .dockerignore и build context | [docs.docker.com/build/concepts/context](https://docs.docker.com/build/concepts/context/) |
| docker run — все флаги | [docs.docker.com/reference/cli/docker/container/run](https://docs.docker.com/reference/cli/docker/container/run/) |
| Образы Node.js: alpine, slim, полный | [hub.docker.com/_/node](https://hub.docker.com/_/node) |
