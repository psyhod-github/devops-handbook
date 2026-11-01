# 18 · Kubernetes: ресурсы и HPA — шпаргалка

## Что добавляем

```text
k8s-lab/  (финальные версии — project/k8s/)
├── backend.yaml       ← resources.requests/limits; без поля replicas
└── hpa.yaml           ← HPA: CPU 50%, 1–5 реплик
```

## metrics-server и потребление

```bash
minikube addons enable metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top nodes
kubectl top pods -n bootcamp
kubectl top pods -n bootcamp --containers
kubectl describe node | grep -A6 "Allocated resources"
```

## Ресурсы

```yaml
resources:
  requests:
    cpu: "100m"       # 0,1 ядра — гарантия, основа для scheduler и HPA
    memory: "128Mi"
  limits:
    cpu: "500m"       # больше — throttling
    memory: "256Mi"   # больше — OOMKilled
```

| Единица | Значение |
|---------|----------|
| `1`, `1000m` | одно ядро CPU |
| `100m` | 0,1 ядра |
| `128Mi` | 128 × 2²⁰ байт ≈ 134 МБ |
| `1Gi` | 2³⁰ байт ≈ 1,07 ГБ |

## HPA

```bash
kubectl apply -f k8s-lab/hpa.yaml
kubectl get hpa -n bootcamp
kubectl get hpa -n bootcamp -w
kubectl describe hpa backend-hpa -n bootcamp          # Events: почему масштабировал
kubectl autoscale deploy/backend --cpu-percent=50 --min=1 --max=5 -n bootcamp   # императивно
```

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: bootcamp
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: backend }
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 50 }
  behavior:                                   # необязательно
    scaleDown:
      stabilizationWindowSeconds: 300         # по умолчанию 5 минут
```

Формула: `нужно = ⌈текущие × текущая загрузка / цель⌉`, в пределах min–max.

## Нагрузка

```bash
# Генератор внутри кластера (4 параллельных цикла)
kubectl run load -n bootcamp --image=busybox:1.37 --restart=Never -- \
  sh -c 'for w in 1 2 3 4; do (while true; do wget -q -O /dev/null http://backend:3000/api/hits; done) & done; wait'
kubectl delete pod load -n bootcamp            # остановить

# Распределение по подам (через Ingress, port-forward из главы 16)
for i in $(seq 1 10); do curl -s http://bootcamp.local:8088/info; echo; done
```

## Уборка

```bash
kubectl config current-context        # → minikube
kubectl delete namespace bootcamp
minikube stop                         # или minikube delete
minikube addons disable metrics-server
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `TARGETS: <unknown>/50%` | Нет metrics-server, он ещё стартует, или у контейнера нет `requests.cpu` |
| `error: Metrics API not available` | metrics-server не готов — подождите минуту |
| HPA не масштабирует под нагрузкой | Нагрузка слабая (генератор снаружи через port-forward) — нагружайте изнутри кластера |
| Новые поды `Pending` | На нодах нет места под requests — `describe pod` → `Insufficient cpu` |
| Под перезапускается, `OOMKilled` в `describe` | Превышен лимит памяти |
| Реплики не уменьшаются после нагрузки | Окно стабилизации 5 минут — подождите |
| После `kubectl apply` реплик стало 1 под нагрузкой | В Deployment указан `replicas` — уберите при использовании HPA |
| `ContainerCannotRun` у пода с `sh -c` в Git Bash | Git Bash переделал путь `/bin/sh` — PowerShell или `MSYS_NO_PATHCONV=1` |

## ✅ Самопроверка

```bash
kubectl top pods -n bootcamp                          # → цифры
kubectl get hpa -n bootcamp                           # → TARGETS с процентом
# под нагрузкой:
kubectl get hpa -n bootcamp                           # → REPLICAS > 1
for i in $(seq 1 10); do curl -s http://bootcamp.local:8088/info; echo; done   # → разные hostname
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Kubernetes — документация | [kubernetes.io/docs](https://kubernetes.io/docs/) |
| Requests и limits | [kubernetes.io/docs/concepts/configuration/manage-resources-containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) |
| HPA | [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) |
| HPA — пошаговое руководство | [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) |
| metrics-server | [github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server) |
| Cluster Autoscaler | [github.com/kubernetes/autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) |
| Karpenter | [karpenter.sh](https://karpenter.sh/) |
| KEDA | [keda.sh](https://keda.sh/) |
| Helm (следующий шаг) | [helm.sh/docs](https://helm.sh/docs/) |
