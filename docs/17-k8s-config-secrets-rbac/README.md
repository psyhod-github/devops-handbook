# 17 · Kubernetes: ConfigMap, Secret, RBAC

!!! abstract "В этой главе"
    **Что вы узнаете:** как отделить конфигурацию от описания деплоя (ConfigMap), где хранить пароли и токены (Secret) и почему base64 — не шифрование, как подключать их к подам переменными и файлами, когда изменения доходят до пода, что такое ServiceAccount, Role и RoleBinding и как проверить права командой `kubectl auth can-i`.

    **Что нужно до начала:**

    - [Глава 16](../16-k8s-services-ingress/README.md): работают Service и Ingress, `bootcamp.local` открывается.
    - [Глава 05](../05-iam-roles/README.md): вы понимаете роли и least privilege в AWS — RBAC устроен похоже.

    **Проверено на:** minikube 1.38 (Kubernetes 1.35).

## Зачем это нужно

Посмотрите на Deployment backend из главы 15:

```yaml
          env:
            - name: REDIS_URL
              value: redis://redis:6379
```

Что не так:

- **Конфигурация смешана с описанием деплоя.** Для dev, staging и prod нужны три копии манифеста, отличающиеся парой строк.
- **Секреты окажутся в git.** Добавьте Redis пароль — и он будет открытым текстом в репозитории вместе с остальным манифестом.
- **Права по умолчанию.** Каждый под получает учётную запись для доступа к API Kubernetes. Какие у неё права и нужны ли они вообще?

Принцип из [12-factor app](https://12factor.net/config): конфигурация хранится **в окружении**, а не в коде и не в образе. Один и тот же образ `:1` работает везде, отличаются только настройки. Kubernetes даёт для этого ConfigMap и Secret, а для прав — RBAC.

## Концепция

### ConfigMap

**ConfigMap** — объект с парами «ключ — значение» для обычной, несекретной конфигурации: порты, адреса сервисов, уровни логирования, флаги функций.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: bootcamp
data:
  PORT: "3000"
  APP_VERSION: "1.0.0"
  LOG_LEVEL: "info"
```

Значения — всегда строки, поэтому числа в кавычках.

### Secret

**Secret** выглядит так же, но предназначен для чувствительных данных: пароли, токены, ключи, TLS-сертификаты.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: bootcamp
type: Opaque
stringData:                       # пишем открытым текстом — K8s сам закодирует
  REDIS_URL: "redis://redis:6379"
```

В кластере значение хранится в поле `data` в **base64**:

```bash
kubectl get secret backend-secret -n bootcamp -o jsonpath='{.data.REDIS_URL}'
# → cmVkaXM6Ly9yZWRpczo2Mzc5
echo cmVkaXM6Ly9yZWRpczo2Mzc5 | base64 -d
# → redis://redis:6379
```

!!! danger "base64 — это кодировка, а не шифрование"
    Любой, кто прочитал Secret, за секунду получит исходное значение. Чем Secret лучше ConfigMap на самом деле:

    - **RBAC**: права на чтение Secret выдаются отдельно от остального, и по умолчанию их ни у кого лишнего нет;
    - `kubectl describe` не показывает значения, они не мелькают в выводе случайно;
    - секреты можно шифровать в etcd (**encryption at rest** — включается в настройках API server; в облачных кластерах — ключом KMS);
    - Secret не попадает в образ и в git — если вы не положили его туда сами.

### Как передать в под

| Способ | Пример | Когда |
|--------|--------|-------|
| Все ключи как переменные | `envFrom: - configMapRef: {name: backend-config}` | Много несекретных настроек |
| Один ключ как переменная | `env: - name: REDIS_URL, valueFrom: secretKeyRef: {name, key}` | Секреты — точечно, видно, что именно получает под |
| Файлами в томе | `volumes: - configMap: {name: frontend}` + `volumeMounts` | Конфиги целиком (`nginx.conf`), сертификаты |

Финальный Deployment backend (`project/k8s/backend-deployment.yaml`, фрагмент):

```yaml
    spec:
      serviceAccountName: backend-sa        # RBAC — ниже
      containers:
        - name: backend
          image: <your-dockerhub-user>/devops-bootcamp-backend:1
          envFrom:
            - configMapRef:
                name: backend-config        # PORT, APP_VERSION, LOG_LEVEL
          env:
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: backend-secret
                  key: REDIS_URL
```

### Когда изменения доходят до пода

| Способ подключения | Изменили ConfigMap/Secret — что с подом? |
|---|---|
| Переменные окружения (`env`, `envFrom`) | **Ничего.** Переменные задаются при старте процесса. Нужен перезапуск: `kubectl rollout restart deploy/backend` |
| Файлы в томе | Файлы обновятся сами через ~1 минуту. Приложение должно уметь перечитать файл |

Если ConfigMap или Secret, на который ссылается под, не существует — под не запустится: статус `CreateContainerConfigError`, причина в `kubectl describe pod`.

!!! example "Плохо / Хорошо: секрет в git"

    === "❌ Плохо"

        ```yaml
        # k8s/secret.yaml в репозитории
        stringData:
          DB_PASSWORD: "Pr0d-P@ssw0rd!"
        ```
        Пароль в истории git навсегда, у всех, кто клонировал репозиторий.

    === "✅ Хорошо"

        Секрет в git не хранится вообще, а создаётся в кластере из надёжного источника:

        - **External Secrets Operator** — синхронизирует Secret из AWS Secrets Manager, Vault и других хранилищ;
        - **Sealed Secrets** — в git лежит зашифрованный `SealedSecret`, расшифровать его может только контроллер в кластере;
        - **SOPS** — файл в git зашифрован ключом KMS, расшифровывается при деплое.

        В учебном проекте `project/k8s/secret.yaml` лежит в репозитории только потому, что `REDIS_URL` без пароля ничего не раскрывает. В файле об этом есть предупреждение.

### RBAC — кто что может делать в кластере

**RBAC (Role-Based Access Control)** — права на API Kubernetes. Те же идеи, что IAM в AWS (главы 04–05):

| Kubernetes | AWS IAM (аналогия) | Что это |
|------------|---------------------|---------|
| **ServiceAccount** | Роль для EC2 (instance profile) | Учётная запись **пода** для обращения к API Kubernetes |
| User / Group | IAM user / group | Люди. В Kubernetes нет объекта User — пользователей выдаёт внешняя аутентификация (сертификаты, OIDC, IAM в EKS) |
| **Role** | Политика | Набор разрешений в **одном namespace**: какие действия (`verbs`) над какими ресурсами |
| **ClusterRole** | Политика на весь аккаунт | То же, но на весь кластер или для ресурсов вне namespace (ноды) |
| **RoleBinding** / ClusterRoleBinding | Прикрепление политики | Кому выдана роль |

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: bootcamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: bootcamp
rules:
  - apiGroups: [""]               # "" — основная группа API: pods, services, secrets…
    resources: ["pods"]
    verbs: ["get", "list"]        # get — один объект, list — список
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-pod-reader
  namespace: bootcamp
subjects:
  - kind: ServiceAccount
    name: backend-sa
    namespace: bootcamp
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Всё, что не разрешено явно, запрещено: в RBAC нет запрещающих правил, только разрешающие (в отличие от IAM с `Deny`).

!!! example "Плохо / Хорошо"

    === "❌ Плохо"

        ```yaml
        rules:
          - apiGroups: ["*"]
            resources: ["*"]
            verbs: ["*"]
        ```
        Или `ClusterRoleBinding` на встроенную роль `cluster-admin`. Взлом приложения = захват всего кластера, включая все секреты.

    === "✅ Хорошо"

        ```yaml
        rules:
          - apiGroups: [""]
            resources: ["pods"]
            verbs: ["get", "list"]
        ```
        Ровно то, что нужно приложению. Если приложению API Kubernetes не нужен вовсе (как нашему backend), безопаснее отключить монтирование токена: `automountServiceAccountToken: false`.

!!! quote "Реальный кейс"
    Команда поставила в кластер инструмент мониторинга из чужого Helm-чарта, не глядя на RBAC. Чарт создавал ServiceAccount с `ClusterRole`, разрешающей читать **все** Secret во всех namespace — «на всякий случай, для автообнаружения». Через полгода в веб-интерфейсе этого инструмента нашли уязвимость. Атакующему не понадобилось ничего взламывать дальше: токен пода давал доступ ко всем паролям баз данных и ключам облака, лежавшим в Secret. После разбора в команде появилось правило: RBAC сторонних чартов проверяется на ревью, а права на Secret выдаются только конкретным ServiceAccount на конкретные имена (`resourceNames`).

## Практика

```bash
minikube start
kubectl get pods -n bootcamp            # backend и redis Running
```

### Шаг 1. ConfigMap

`k8s-lab/configmap.yaml` — манифест из раздела «ConfigMap» выше.

```bash
kubectl apply -f k8s-lab/configmap.yaml
kubectl describe configmap backend-config -n bootcamp
```

### Шаг 2. Secret

`k8s-lab/secret.yaml` — манифест из раздела «Secret».

```bash
kubectl apply -f k8s-lab/secret.yaml
kubectl describe secret backend-secret -n bootcamp
# → REDIS_URL:  18 bytes        ← размер, но не значение
kubectl get secret backend-secret -n bootcamp -o jsonpath='{.data.REDIS_URL}' | base64 -d; echo
# → redis://redis:6379           ← у кого есть право get secrets, тот видит всё
```

!!! success "✅ Проверь себя"
    `describe` скрывает значение, `get -o jsonpath` + `base64 -d` — показывает. Защита Secret — в правах на чтение, а не в кодировке.

    PowerShell: `[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((kubectl get secret backend-secret -n bootcamp -o jsonpath='{.data.REDIS_URL}')))`.

### Шаг 3. RBAC

`k8s-lab/rbac.yaml` — три объекта из раздела «RBAC» через `---`.

```bash
kubectl apply -f k8s-lab/rbac.yaml
kubectl get serviceaccount,role,rolebinding -n bootcamp
```

Проверьте права ServiceAccount, не запуская никаких подов, — от его имени:

```bash
SA=system:serviceaccount:bootcamp:backend-sa
kubectl auth can-i list pods        -n bootcamp --as=$SA     # → yes
kubectl auth can-i get pods         -n bootcamp --as=$SA     # → yes
kubectl auth can-i delete pods      -n bootcamp --as=$SA     # → no
kubectl auth can-i get secrets      -n bootcamp --as=$SA     # → no
kubectl auth can-i create deployments -n bootcamp --as=$SA   # → no
kubectl auth can-i list pods -n bootcamp --as=system:serviceaccount:bootcamp:default   # → no
```

(PowerShell: `$SA = "system:serviceaccount:bootcamp:backend-sa"` и `--as=$SA`.)

!!! success "✅ Проверь себя"
    `backend-sa` может только читать поды в `bootcamp`. Удалять поды, читать секреты, создавать Deployment — нельзя. ServiceAccount `default`, который получает каждый под без явного указания, не может даже читать поды. `kubectl auth can-i` — то же, что Policy Simulator в AWS (глава 04).

### Шаг 4. Обновить Deployment

Перенесите настройки в `k8s-lab/backend.yaml`: добавьте `serviceAccountName`, замените `env` с явным `REDIS_URL` на `envFrom` и `secretKeyRef` (фрагмент из раздела «Как передать в под»). Готовая версия — `project/k8s/backend-deployment.yaml` (в ней ещё есть `resources` из главы 18 — их можно добавить сразу).

```bash
kubectl apply -f k8s-lab/backend.yaml
kubectl rollout status deploy/backend -n bootcamp
kubectl exec -n bootcamp deploy/backend -- sh -c 'env | grep -E "^(PORT|LOG_LEVEL|APP_VERSION|REDIS_URL)=" | sort'
```

```text
APP_VERSION=1.0.0
LOG_LEVEL=info
PORT=3000
REDIS_URL=redis://redis:6379
```

!!! success "✅ Проверь себя"
    Все четыре переменные на месте, хотя в манифесте Deployment нет ни одного значения. `curl http://bootcamp.local:8088/api/hits` (port-forward к ingress из главы 16) — счётчик работает. `kubectl get pod -n bootcamp -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}'` → `backend-sa`.

### Шаг 5. Изменение конфигурации

Поменяйте версию в ConfigMap и посмотрите, когда изменение дойдёт до пода:

```bash
kubectl patch configmap backend-config -n bootcamp --type merge -p '{"data":{"APP_VERSION":"1.1.0"}}'
curl http://bootcamp.local:8088/info          # → "version":"1.0.0"  — под не знает об изменении
kubectl rollout restart deploy/backend -n bootcamp
kubectl rollout status deploy/backend -n bootcamp
curl http://bootcamp.local:8088/info          # → "version":"1.1.0"
```

(PowerShell: `-p '{\"data\":{\"APP_VERSION\":\"1.1.0\"}}'` — кавычки внутри нужно экранировать.)

!!! success "✅ Проверь себя"
    До `rollout restart` — старая версия, после — новая. Переменные окружения читаются только при старте контейнера. Образ при этом не менялся, менялась только конфигурация.

Верните значение: `kubectl apply -f k8s-lab/configmap.yaml` и снова `rollout restart`.

!!! tip "Автоматический перезапуск при смене конфигурации"
    Частый приём — хеш ConfigMap в аннотации шаблона пода: изменилась конфигурация → изменилась аннотация → Deployment сам делает rolling update. Helm делает это одной строкой (`checksum/config`). Без этого легко забыть перезапуск, и поды будут работать со старыми настройками.

### Шаг 6. Если ConfigMap нет

```bash
kubectl delete configmap backend-config -n bootcamp
kubectl rollout restart deploy/backend -n bootcamp
kubectl get pods -n bootcamp -l app=backend
```

```text
NAME                       READY   STATUS                       RESTARTS   AGE
backend-5d8f7c9b6-abcde    1/1     Running                      0          3m
backend-7f6b5d4c8-xyz12    0/1     CreateContainerConfigError   0          10s
```

`kubectl describe pod` → `Error: configmap "backend-config" not found`. Старый под продолжает работать (rolling update не убрал его). Верните ConfigMap: `kubectl apply -f k8s-lab/configmap.yaml` — новый под запустится сам.

### Шаг 7. Остановить

```bash
minikube stop
```

## Вопросы для самопроверки

<details markdown="1">
<summary>1. Чем Secret отличается от ConfigMap, если значения всё равно в base64?</summary>

Отдельными правами (RBAC на `secrets` выдают осторожно, а `configmaps` — свободнее), скрытием значений в `describe`, возможностью шифрования в etcd и тем, что инструменты экосистемы (External Secrets, Sealed Secrets, CSI Secrets Store) работают именно с Secret. Base64 нужен для хранения произвольных байтов (сертификатов, бинарных ключей) в текстовом формате, защиты он не даёт.
</details>

<details markdown="1">
<summary>2. Вы изменили ConfigMap. Почему приложение продолжает работать со старыми значениями?</summary>

Значения пришли в контейнер переменными окружения, а они фиксируются при старте процесса. Нужно перезапустить поды (`kubectl rollout restart`). Файлы из ConfigMap, смонтированные как том, обновляются сами примерно за минуту, но приложение должно уметь перечитать файл. Аннотация с хешем конфигурации в шаблоне пода превращает изменение ConfigMap в автоматический rolling update.
</details>

<details markdown="1">
<summary>3. Под получил статус <code>CreateContainerConfigError</code>. Где искать причину?</summary>

`kubectl describe pod <name>` → Events. Обычно это отсутствующий ConfigMap или Secret, на который ссылается под, или отсутствующий ключ в `secretKeyRef`/`configMapKeyRef`. Ссылки проверяются при создании контейнера, и под не запустится, пока объекта нет. Объекты проекта лучше применять одной командой `kubectl apply -f k8s-lab/`, тогда порядок не важен: Kubernetes дождётся.
</details>

<details markdown="1">
<summary>4. Какие права у пода, если не указать <code>serviceAccountName</code>?</summary>

Под получает ServiceAccount `default` своего namespace. По умолчанию у него нет прав на ресурсы API (только базовое обнаружение API), но токен в под монтируется. Если в namespace кто-то выдал права `default` (частая ошибка «чтобы заработало»), их получат **все** поды без явного ServiceAccount. Правильно: отдельный ServiceAccount на приложение с минимальной Role и `automountServiceAccountToken: false` для приложений, которым API не нужен.
</details>

<details markdown="1">
<summary>5. Чем Role отличается от ClusterRole и когда нужна ClusterRole?</summary>

Role действует в одном namespace. ClusterRole — на весь кластер: для ресурсов, у которых нет namespace (ноды, PersistentVolume, сами namespace), или для прав во всех namespace (мониторинг, Ingress Controller). ClusterRole можно привязать и обычным RoleBinding — тогда её права действуют только в namespace этого RoleBinding. Так переиспользуют стандартные роли `view`, `edit`, `admin`.
</details>

## Итоги

- [x] ConfigMap — несекретная конфигурация, Secret — чувствительная; обе отдельно от Deployment
- [x] base64 — не шифрование; защита Secret — RBAC, шифрование etcd, хранение вне git
- [x] `envFrom`/`env` фиксируются при старте — после изменений нужен `rollout restart`; тома обновляются сами
- [x] Нет ConfigMap/Secret → `CreateContainerConfigError`
- [x] ServiceAccount — учётная запись пода; Role + RoleBinding — минимальные права; проверка `kubectl auth can-i --as`

**Что дальше.** Backend работает в одной реплике. В [главе 18](../18-k8s-hpa/README.md) вы зададите ему ресурсы, а Kubernetes сам начнёт добавлять поды под нагрузкой и убирать их, когда нагрузка спадёт.

- 📋 [Шпаргалка](commands.md)
- 🏋️ [Задания к главе](exercises.md)
