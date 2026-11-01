# 09 · Docker — задания

## Уровень 1 — повторение главы

Соберите образ backend-а и запустите контейнер самостоятельно, не подглядывая в текст главы. Если застрянете, загляните в [шпаргалку](commands.md).

1. Перейдите в `app/backend` и соберите образ `devops-bootcamp-backend`.
2. Запустите контейнер в фоне с именем `backend` на порту 3000.
3. Проверьте `/health` и `/info` через `curl` или браузер.
4. Посмотрите логи контейнера и зайдите внутрь через `docker exec`.
5. Уберите за собой: контейнер и образ.

!!! success "✅ Как проверить себя"
    - `docker images devops-bootcamp-backend` → образ в списке.
    - `docker ps` → контейнер `backend` в статусе `Up`, порт `0.0.0.0:3000->3000/tcp`.
    - `http://localhost:3000/health` → `{"status":"ok", ...}`.
    - `http://localhost:3000/info` → `hostname` совпадает с `CONTAINER ID` из `docker ps`.
    - После уборки `docker ps -a --filter name=backend` и `docker images devops-bootcamp-backend` выводят пустые таблицы.

## Уровень 2 — мини-проект: упакуйте чужое приложение

Найдите на GitHub простое веб-приложение и напишите для него `Dockerfile` и `.dockerignore` с нуля.

**Где искать.** Подойдёт любое приложение, которое запускается одной командой и отвечает на HTTP-запросы. Поисковые запросы для GitHub:

- `flask hello world` — Python;
- `fastapi example` — Python;
- `express starter` — Node.js;
- `go http server` — Go.

**Что сделать:**

1. Прочитать README выбранного репозитория: как приложение устанавливается и запускается, на каком порту слушает.
2. Клонировать репозиторий к себе.
3. Написать `Dockerfile` и `.dockerignore`.
4. Собрать образ: `docker build -t my-app .`
5. Запустить: `docker run -d -p ПОРТ:ПОРТ --name my-app my-app`
6. Убедиться, что приложение отвечает.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Ищите в README команду запуска (`python app.py`, `npm start`, `go run .`): это будущий `CMD`.
- Файл зависимостей (`requirements.txt`, `package.json`, `go.mod`) копируйте **до** установки зависимостей, код — после. Как в главе.
- Берите официальные базовые образы с Docker Hub: `python:3.12-slim`, `node:22-alpine`, `golang:1.23-alpine`.
- Приложение внутри контейнера должно слушать `0.0.0.0`, а не `127.0.0.1`. Иначе проброс порта не сработает: Flask по умолчанию слушает только localhost, поэтому запускайте его с `--host=0.0.0.0`.
- Контейнер сразу завершился? Первая команда — `docker logs my-app`.

Пример для Flask:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["flask", "--app", "app", "run", "--host=0.0.0.0"]
```
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `docker build` проходит без ошибок.
- [ ] `docker ps` показывает контейнер в статусе `Up` (а не `Exited`).
- [ ] Приложение отвечает в браузере или через `curl`.
- [ ] Файл зависимостей копируется отдельно от кода; повторная сборка после правки кода показывает `CACHED` у шага установки зависимостей.
- [ ] В `.dockerignore` есть как минимум `.git`, `.env` и папка зависимостей (`node_modules`, `venv`, `__pycache__`).
- [ ] Бонус: размер образа не больше 300 МБ (`docker images my-app`).
</details>

## Уровень 3 — подумайте сами

Эти вопросы проверяют, насколько вы поняли материал. Сначала подумайте и проверьте гипотезу в терминале, потом откройте разбор.

<details markdown="1">
<summary>1. Запустите второй контейнер из того же образа с тем же <code>-p 3000:3000</code>, пока первый работает. Что произойдёт и как запустить две копии одновременно?</summary>

Второй `docker run` упадёт с ошибкой:

```text
Bind for 0.0.0.0:3000 failed: port is already allocated
```

Порт **на хосте** уже занят первым контейнером. Внутри контейнеров конфликта нет: у каждого своя сеть, и оба могут слушать свой 3000. Решение — разные порты хоста:

```bash
docker run -d -p 3000:3000 --name backend1 devops-bootcamp-backend
docker run -d -p 3001:3000 --name backend2 devops-bootcamp-backend
```

`curl` на `localhost:3000/info` и `localhost:3001/info` вернёт **разные** `hostname`: это два независимых контейнера. Ровно так, но автоматически, Kubernetes запускает реплики в главах 15–18.
</details>

<details markdown="1">
<summary>2. Как сделать, чтобы <code>/info</code> вернул <code>"version":"2.0.0"</code>, не меняя ни код, ни Dockerfile?</summary>

Приложение читает версию из переменной окружения `APP_VERSION` (по умолчанию `1.0.0`). Передайте переменную при запуске:

```bash
docker run -d -p 3000:3000 -e APP_VERSION=2.0.0 --name backend devops-bootcamp-backend
curl http://localhost:3000/info
# → {"hostname":"...","version":"2.0.0","node":"v22..."}
```

Это важный принцип: **один образ — разные настройки через окружение**. Один и тот же образ уходит в test и в production, отличаются только переменные. В Kubernetes для этого есть ConfigMap и Secret (глава 17).
</details>

<details markdown="1">
<summary>3. Соберите тот же backend на базе <code>node:22</code> вместо <code>node:22-alpine</code> и сравните размеры. Почему разница такая большая, и всегда ли alpine лучше?</summary>

Подсказка, как собрать второй вариант, не трогая основной Dockerfile:

```bash
sed 's/node:22-alpine/node:22/' Dockerfile > Dockerfile.full     # Windows: отредактируйте копию вручную
docker build -f Dockerfile.full -t backend-full .
docker images | grep backend
```

`node:22` построен на полном Debian с компиляторами, git, curl и сотнями пакетов: больше 1 ГБ. Alpine — минимальный Linux на несколько мегабайт. Меньший образ быстрее скачивается, меньше места занимает и содержит меньше пакетов с потенциальными уязвимостями.

Но alpine не всегда лучше. В нём библиотека `musl` вместо привычной `glibc`, и некоторые нативные модули (часть пакетов Python и Node.js с кодом на C) не собираются или ведут себя иначе. Компромисс — `-slim` образы (`node:22-slim`): Debian с `glibc`, но без лишнего.

Не забудьте удалить `Dockerfile.full` и образ `backend-full`.
</details>

<details markdown="1">
<summary>4. Почему в <code>.dockerignore</code> стоят <code>.env</code> и <code>*.pem</code>, если в Dockerfile нет ни одной инструкции, которая их копирует?</summary>

Есть: `COPY . .` копирует **всю** папку. Если бы рядом с `app.js` лежал `.env` с паролями или ключ `.pem`, он оказался бы внутри образа. Образ потом пушится в реестр (глава 12), и любой, кто может скачать образ, может достать оттуда файл: `docker run --rm образ cat /app/.env`.

Даже если удалить файл следующей инструкцией `RUN rm .env`, он останется в предыдущем слое: слои неизменяемы и их можно извлечь. Поэтому секреты в образ не должны попадать вообще: `.dockerignore` срабатывает **до** сборки.
</details>
