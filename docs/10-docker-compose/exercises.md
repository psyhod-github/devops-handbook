# 10 · Docker Compose — задания

## Уровень 1 — повторение главы

1. Поднимите стек из `project/docker-compose.yml`, нажмите **Hit me!** 5 раз.
2. Найдите значение счётчика прямо в Redis: `docker compose exec redis redis-cli get hits`.
3. Проверьте, что счётчик переживает `down` / `up` и сбрасывается после `down -v`.
4. Остановите Redis и убедитесь, что `/health` работает, а `/api/hits` зависает.
5. Запустите три копии backend и увидите смену `hostname` в `/info`.
6. Уберите за собой.

!!! success "✅ Как проверить себя"
    - `redis-cli get hits` и `curl /api/hits` показывают согласованные значения.
    - После `--scale backend=3` и `restart nginx` в шести запросах к `/info` встречаются три разных `hostname`.
    - После уборки `docker compose ls` не показывает проект `devops-handbook`.

## Уровень 2 — мини-проект: healthcheck и веб-интерфейс Redis

Сделайте стек надёжнее и добавьте инструмент для наблюдения за данными. Работайте в копии файла, например `docker-compose.dev.yml`, или в своём репозитории.

**Требования:**

1. У Redis есть `healthcheck` (команда `redis-cli ping`).
2. Backend ждёт не просто запуска Redis, а его **готовности**.
3. У всех сервисов `restart: unless-stopped`.
4. Четвёртый сервис — `redis-commander` (образ `rediscommander/redis-commander`) на порту `8081`, подключённый к Redis.
5. Порт `8081` открыт только для вашей машины: `127.0.0.1:8081:8081`.

<details markdown="1">
<summary>💡 Подсказки</summary>

```yaml
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  backend:
    # ...
    depends_on:
      redis:
        condition: service_healthy

  redis-commander:
    image: rediscommander/redis-commander:latest
    restart: unless-stopped
    environment:
      - REDIS_HOSTS=local:redis:6379
    ports:
      - "127.0.0.1:8081:8081"
    depends_on:
      redis:
        condition: service_healthy
```

- Запуск другого файла: `docker compose -f docker-compose.dev.yml up -d`.
- Статус здоровья виден в `docker compose ps`: `Up 10 seconds (healthy)`.
- `127.0.0.1:` перед портом публикует его только на loopback-интерфейсе: с других компьютеров в вашей сети UI будет недоступен.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `docker compose ps` показывает Redis как `(healthy)`.
- [ ] В выводе `up` backend стартует только после строки `Healthy` у Redis.
- [ ] `http://localhost:8081` открывает redis-commander, в нём виден ключ `hits`; после **Hit me!** значение меняется.
- [ ] `docker compose ps` в колонке портов показывает `127.0.0.1:8081->8081/tcp`.
- [ ] После `docker kill devops-handbook-redis-1` Redis поднимается сам (`restart: unless-stopped`).
- [ ] Всё удалено (`down -v`).
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как передать в стек секрет (например, пароль Redis), чтобы он не попал в git?</summary>

Через файл `.env` рядом с `docker-compose.yml`, который в `.gitignore`:

```bash
# .env (не коммитить)
REDIS_PASSWORD=s3cr3t
```

```yaml
  redis:
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
  backend:
    environment:
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
```

Compose автоматически читает `.env` и подставляет `${...}`. В репозиторий кладут `.env.example` без реальных значений. Ограничение: переменные окружения видны через `docker inspect` и могут попасть в логи. Для серьёзных случаев есть `secrets:` в Compose и менеджеры секретов (глава 17 — Secrets в Kubernetes).
</details>

<details markdown="1">
<summary>2. Как запускать один и тот же стек для разработки (с bind mount кода и отладкой) и для сервера (только образы), не дублируя весь файл?</summary>

Через несколько файлов Compose, которые накладываются друг на друга:

- `compose.yaml` — общая часть;
- `compose.override.yaml` — для разработки: bind mount кода, открытые порты для отладки. Compose подхватывает его **автоматически**;
- `compose.prod.yaml` — для сервера: готовые образы из реестра (`image: user/backend:42` вместо `build`), `restart`, без лишних портов.

Запуск на сервере: `docker compose -f compose.yaml -f compose.prod.yaml up -d`. Итоговый результат слияния всегда можно посмотреть через `docker compose ... config`. Именно такой подход вы увидите в главе 14, когда Ansible будет разворачивать стек на EC2 из шаблона.
</details>

<details markdown="1">
<summary>3. В шаге 7 nginx не видел новые копии backend, пока его не перезапустили. Как настроить nginx, чтобы он сам находил новые копии?</summary>

Nginx разрешает имя в `proxy_pass` один раз при старте. Чтобы он переспрашивал DNS, нужно указать резолвер и использовать переменную:

```nginx
resolver 127.0.0.11 valid=10s;   # встроенный DNS Docker
location /api/ {
    set $backend http://backend:3000;
    proxy_pass $backend;
}
```

Теперь nginx обновляет адреса каждые 10 секунд. Но это уже «самодельный балансировщик». Оркестраторы решают задачу иначе: в Kubernetes у сервиса есть стабильный виртуальный IP (Service, глава 16), а за ним меняются поды, и nginx-у не нужно ничего знать о копиях.
</details>
