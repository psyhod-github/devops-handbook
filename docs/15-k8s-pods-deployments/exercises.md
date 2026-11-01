# 15 · Kubernetes: Pod и Deployment — задания

## Уровень 1 — повторение главы

1. Запустите minikube, создайте namespace `bootcamp`, Redis и backend из манифестов главы.
2. Проверьте `/health`, `/info`, `/api/hits` через `port-forward`.
3. Удалите под backend и убедитесь, что появился новый с другим именем.
4. Сломайте образ через `kubectl set image`, найдите причину в `describe` и откатитесь через `rollout undo`.
5. Остановите кластер (`minikube stop`).

!!! success "✅ Как проверить себя"
    - `kubectl get pods -n bootcamp` — оба пода `1/1 Running`.
    - `hostname` в `/info` совпадает с именем пода.
    - Во время сломанного обновления старый под оставался `Running`.
    - `kubectl rollout history deploy/backend -n bootcamp` показывает несколько ревизий.

## Уровень 2 — мини-проект: свой сервис рядом

Разверните в namespace `bootcamp` сервис `whoami` (образ `traefik/whoami:v1.11`) — простой HTTP-сервер, который показывает имя пода и заголовки запроса.

1. Напишите `k8s-lab/whoami.yaml`: Deployment с 3 репликами, порт контейнера 80, readiness probe на `/health` (whoami её поддерживает).
2. Примените и проверьте через `kubectl port-forward deploy/whoami 8081:80 -n bootcamp`.
3. Сделайте 5 запросов `curl localhost:8081`. Меняется ли `Hostname`? Почему?
4. Удалите все три пода одной командой и засеките, за сколько секунд все три снова `Running`.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Скопируйте `backend.yaml`, замените имена, метки, образ, порт, уберите `env`.
- `kubectl delete pod -l app=whoami -n bootcamp` — удаление по метке.
- `kubectl get pods -n bootcamp -l app=whoami -w` — наблюдать восстановление.
</details>

<details markdown="1">
<summary>✅ Критерии готовности и разбор вопроса 3</summary>

- [ ] Три пода `whoami` в статусе `1/1 Running`.
- [ ] `curl localhost:8081` отвечает текстом с `Hostname: whoami-...`.
- [ ] После удаления всех подов они восстановились без вашего участия.

**Почему `Hostname` не меняется:** `kubectl port-forward deploy/whoami` выбирает **один** под из Deployment и держит туннель к нему. Балансировки нет. Чтобы запросы распределялись между подами, нужен **Service** — глава 16.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как сделать, чтобы счётчик Redis переживал удаление пода?</summary>

Подключить постоянное хранилище через **PersistentVolumeClaim**:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: bootcamp
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
```

и в шаблоне пода Redis:

```yaml
      containers:
        - name: redis
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: redis-data
```

В minikube PVC автоматически получит диск (StorageClass `standard`), в облаке — например, том EBS. Для баз с несколькими репликами используют **StatefulSet** (стабильные имена подов и свой диск у каждой реплики). Проверка: `redis-cli get hits` до и после `kubectl delete pod -l app=redis`.
</details>

<details markdown="1">
<summary>2. Под в <code>CrashLoopBackOff</code>, а <code>kubectl logs</code> пустой. Что делать?</summary>

Текущий контейнер только что перезапустился, и в нём ещё нет логов. Смотреть надо логи **предыдущего** запуска: `kubectl logs <pod> --previous`. Если и там пусто, процесс падает до того, как успевает что-то вывести: неверная команда запуска, нет исполняемого файла, не хватает памяти (в `kubectl describe pod` — `Last State: Terminated, Reason: OOMKilled` или `Exit Code`). Exit code подсказывает причину: `137` — убит (часто OOM), `1` — ошибка приложения, `127` — команда не найдена.
</details>

<details markdown="1">
<summary>3. В Deployment <code>replicas: 3</code>. Нода с двумя подами умерла. Что произойдёт и за какое время?</summary>

Control plane не сразу считает ноду мёртвой: kubelet перестал докладывать, и через ~40 секунд нода получит статус `NotReady`. Поды на ней ещё какое-то время числятся существующими, затем помечаются к удалению (по умолчанию примерно через 5 минут — так настроены tolerations `not-ready`/`unreachable`). После этого ReplicaSet видит «1 из 3» и создаёт два пода на живых нодах.

Выводы для продакшена: минимум 2–3 ноды в разных зонах доступности; реплики распределены по нодам (`topologySpreadConstraints` или `podAntiAffinity`), иначе все три копии могут оказаться на одной ноде и умереть вместе; и readiness probe, чтобы трафик не шёл на поды, которые ещё не готовы.
</details>
