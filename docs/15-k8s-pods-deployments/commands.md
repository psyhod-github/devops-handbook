# 15 · Kubernetes: Pod и Deployment — шпаргалка

## Что добавляем

```text
k8s-lab/                      (финальная версия — project/k8s/)
├── namespace.yaml            ← Namespace bootcamp
├── redis.yaml                ← Deployment + Service redis
└── backend.yaml              ← Deployment backend: env REDIS_URL, readiness/liveness
```

## minikube

```bash
minikube start --driver=docker           # запустить (первый раз — несколько минут)
minikube status
minikube stop                            # остановить, объекты сохранятся
minikube delete                          # удалить кластер полностью
minikube image build -t devops-bootcamp-backend:local app/backend   # собрать образ внутри кластера
minikube image ls
minikube dashboard                       # веб-интерфейс (откроется в браузере)
```

## Контекст и namespace

```bash
kubectl config current-context           # ← С КАКИМ КЛАСТЕРОМ Я РАБОТАЮ
kubectl config get-contexts
kubectl config use-context minikube
kubectl config set-context --current --namespace=bootcamp   # namespace по умолчанию
kubectl get namespaces
```

## Применить и посмотреть

```bash
kubectl apply -f k8s-lab/                # все файлы папки
kubectl apply -f k8s-lab/backend.yaml
kubectl diff -f k8s-lab/backend.yaml     # что изменится (как terraform plan)

kubectl get pods -n bootcamp
kubectl get pods -n bootcamp -o wide     # + IP и нода
kubectl get pods -n bootcamp -w          # следить (Ctrl+C)
kubectl get pods -n bootcamp -l app=backend
kubectl get all -n bootcamp
kubectl get deploy,rs,pods -n bootcamp   # цепочка Deployment → ReplicaSet → Pod
kubectl get pod <pod> -n bootcamp -o yaml
```

## Диагностика

```bash
kubectl describe pod <pod> -n bootcamp            # Events внизу — первое, что смотреть
kubectl describe deployment backend -n bootcamp
kubectl logs <pod> -n bootcamp
kubectl logs -f deploy/backend -n bootcamp        # следить за логами
kubectl logs -l app=backend -n bootcamp --prefix --tail=20
kubectl logs <pod> -n bootcamp --previous         # логи упавшего контейнера (CrashLoopBackOff)
kubectl get events -n bootcamp --sort-by=.lastTimestamp
kubectl exec -it deploy/backend -n bootcamp -- sh
kubectl port-forward deploy/backend 3000:3000 -n bootcamp
```

## Изменения и откат

```bash
kubectl scale deploy/backend --replicas=3 -n bootcamp      # императивно (файл не меняется)
kubectl set image deploy/backend backend=<user>/devops-bootcamp-backend:2 -n bootcamp
kubectl rollout status deploy/backend -n bootcamp
kubectl rollout history deploy/backend -n bootcamp
kubectl rollout undo deploy/backend -n bootcamp
kubectl rollout restart deploy/backend -n bootcamp         # пересоздать поды
kubectl delete pod -l app=backend -n bootcamp              # self-healing: создастся новый
kubectl delete -f k8s-lab/backend.yaml                     # удалить Deployment совсем
```

## Шаблон Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: bootcamp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend           # == template.metadata.labels
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: <your-dockerhub-user>/devops-bootcamp-backend:1
          ports:
            - containerPort: 3000
          env:
            - name: REDIS_URL
              value: redis://redis:6379
          readinessProbe:
            httpGet: { path: /health, port: 3000 }
          livenessProbe:
            httpGet: { path: /health, port: 3000 }
            initialDelaySeconds: 10
```

## Статусы пода

| Статус | Что делать |
|--------|-----------|
| `Pending` | `describe` → Events: нет ресурсов, ждёт том |
| `ContainerCreating` | Ждать; долго — `describe` |
| `ErrImagePull` / `ImagePullBackOff` | Имя/тег образа, доступ к реестру — `describe` |
| `CrashLoopBackOff` | `logs --previous` — почему падает процесс |
| `Running`, `READY 0/1` | Не проходит readiness — `describe`, `logs` |
| `CreateContainerConfigError` | Нет ConfigMap/Secret (глава 17) |
| `OOMKilled` (в `describe`) | Превышен лимит памяти (глава 18) |
| `Terminating` долго | Ждёт завершения процесса; потом убьют принудительно |

## ✅ Самопроверка

```bash
kubectl get nodes                                  # → minikube Ready
kubectl get pods -n bootcamp                       # → backend и redis 1/1 Running
kubectl port-forward deploy/backend 3000:3000 -n bootcamp &
curl localhost:3000/api/hits                       # → {"hits":N}
kubectl delete pod -l app=backend -n bootcamp && kubectl get pods -n bootcamp   # → новый под
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Kubernetes — документация | [kubernetes.io/docs](https://kubernetes.io/docs/) |
| Компоненты кластера | [kubernetes.io/docs/concepts/overview/components](https://kubernetes.io/docs/concepts/overview/components/) |
| Pods | [kubernetes.io/docs/concepts/workloads/pods](https://kubernetes.io/docs/concepts/workloads/pods/) |
| Deployments | [kubernetes.io/docs/concepts/workloads/controllers/deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) |
| Labels и selectors | [kubernetes.io/docs/concepts/overview/working-with-objects/labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) |
| Probes | [kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) |
| Шпаргалка kubectl | [kubernetes.io/docs/reference/kubectl/quick-reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) |
| Отладка подов | [kubernetes.io/docs/tasks/debug/debug-application/debug-pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) |
| minikube | [minikube.sigs.k8s.io/docs/start](https://minikube.sigs.k8s.io/docs/start/) |
