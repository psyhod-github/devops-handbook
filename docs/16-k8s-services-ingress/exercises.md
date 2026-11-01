# 16 · Kubernetes: Service и Ingress — задания

## Уровень 1 — повторение главы

1. Создайте Service `backend` и убедитесь, что его endpoints — IP пода.
2. Масштабируйте backend до 3 реплик и увидьте разные `hostname` при запросах к `http://backend:3000/info` изнутри кластера.
3. Включите аддон ingress, создайте Ingress для `bootcamp.local`, откройте приложение по имени.
4. Добавьте `whoami` на путь `/whoami`.

!!! success "✅ Как проверить себя"
    - `http://bootcamp.local:8088/info` → backend, `/whoami` → whoami.
    - Запрос по `127.0.0.1` без имени → `404`.
    - Redis и whoami — `ClusterIP` в `kubectl get svc`.

## Уровень 2 — мини-проект: фронтенд в кластере

Сейчас в Kubernetes живут только backend и Redis, а страница со счётчиком (nginx + `index.html`) — нет. Перенесите фронтенд, чтобы `http://bootcamp.local:8088/` открывал ту же страницу, что в главе 10.

1. Создайте **ConfigMap** `frontend` из двух файлов `app/frontend/index.html` и `app/frontend/nginx.conf`.
2. Deployment `frontend` на образе `nginx:alpine`: смонтируйте ConfigMap как файлы — `index.html` в `/usr/share/nginx/html/`, `nginx.conf` как `/etc/nginx/conf.d/default.conf`.
3. Service `frontend` (ClusterIP, порт 80).
4. Ingress: `/` → `frontend`. Пути API (`/api`, `/health`, `/info`) nginx фронтенда уже проксирует на `http://backend:3000` — проверьте `nginx.conf`.

<details markdown="1">
<summary>💡 Подсказки</summary>

- ConfigMap из файлов: `kubectl create configmap frontend -n bootcamp --from-file=devops-handbook/app/frontend/index.html --from-file=devops-handbook/app/frontend/nginx.conf --dry-run=client -o yaml > k8s-lab/frontend-configmap.yaml`.
- Монтирование отдельных файлов — `subPath`:

  ```yaml
          volumeMounts:
            - name: site
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
            - name: site
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: nginx.conf
      volumes:
        - name: site
          configMap:
            name: frontend
  ```
- `nginx.conf` проксирует на `backend:3000` — то же DNS-имя Service, что было именем сервиса в Compose. Ничего менять не нужно.
- В Ingress оставьте один путь `/` → `frontend` (и `/whoami`, если хотите).
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `http://bootcamp.local:8088/` в браузере — страница со счётчиком и кнопкой **Hit me!**.
- [ ] Внизу страницы — `hostname` пода backend; при 3 репликах он меняется после обновления страницы.
- [ ] `kubectl get svc -n bootcamp` — все Service, кроме, возможно, backend, имеют тип `ClusterIP`.
- [ ] Вы можете объяснить, почему стек из главы 10 переехал в Kubernetes без единой правки `nginx.conf`.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как включить HTTPS для <code>bootcamp.example.com</code> в настоящем кластере?</summary>

Установить **cert-manager** и описать `ClusterIssuer` для Let's Encrypt. В Ingress добавить аннотацию и секцию `tls`:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts: [bootcamp.example.com]
      secretName: bootcamp-tls
```

cert-manager сам пройдёт проверку владения доменом, получит сертификат, положит его в Secret `bootcamp-tls` и будет продлевать. Контроллер берёт сертификат из Secret. Условие — настоящий домен, указывающий на балансировщик перед контроллером: Let's Encrypt не выдаст сертификат для `.local`.
</details>

<details markdown="1">
<summary>2. Как запретить backend-подам ходить куда угодно, а Redis — принимать подключения от кого угодно в кластере?</summary>

По умолчанию в Kubernetes любой под может обратиться к любому. Ограничивают это **NetworkPolicy**:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-only-from-backend
  namespace: bootcamp
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - port: 6379
```

Это аналог Security Group из главы 02, только для подов и по меткам. Политики работают, только если сетевой плагин кластера их поддерживает (Calico, Cilium; в minikube — `minikube start --cni=calico`).
</details>

<details markdown="1">
<summary>3. Как перевести маршрутизацию этой главы на Gateway API?</summary>

Вместо одного объекта Ingress — два уровня:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: bootcamp
spec:
  gatewayClassName: <класс контроллера>
  listeners:
    - name: http
      port: 80
      protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bootcamp
  namespace: bootcamp
spec:
  parentRefs: [{ name: web }]
  hostnames: [bootcamp.local]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /whoami } }]
      backendRefs: [{ name: whoami, port: 80 }]
    - backendRefs: [{ name: backend, port: 3000 }]
```

`Gateway` (вход, порты, TLS) обычно принадлежит команде платформы, `HTTPRoute` (маршруты) — командам сервисов. Нужен контроллер с поддержкой Gateway API (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric и др.) и установленные CRD Gateway API.
</details>
