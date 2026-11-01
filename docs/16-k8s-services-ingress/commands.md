# 16 · Kubernetes: Service и Ingress — шпаргалка

## Что добавляем

```text
k8s-lab/
├── backend-service.yaml   ← Service backend (NodePort 30080)
├── ingress.yaml           ← Ingress bootcamp.local → backend (+ /whoami)
└── whoami.yaml            ← Deployment + Service whoami (ClusterIP)
```

## Service

```bash
kubectl get svc -n bootcamp
kubectl describe svc backend -n bootcamp
kubectl get endpointslices -n bootcamp -l kubernetes.io/service-name=backend
kubectl port-forward svc/backend 3000:3000 -n bootcamp    # через Service, а не под
minikube service backend -n bootcamp --url                 # NodePort с Docker Desktop
curl http://$(minikube ip):30080/health                    # NodePort на Linux
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: bootcamp
spec:
  type: ClusterIP            # ClusterIP (по умолчанию) | NodePort | LoadBalancer
  selector:
    app: backend
  ports:
    - port: 3000             # порт Service
      targetPort: 3000       # порт контейнера
      # nodePort: 30080      # только для NodePort, 30000–32767
```

DNS: `backend` (тот же namespace), `backend.bootcamp`, `backend.bootcamp.svc.cluster.local`.

## Ingress

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
kubectl get ingressclass
kubectl get ingress -n bootcamp
kubectl describe ingress bootcamp-ingress -n bootcamp
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=20

# Доступ к контроллеру (любая ОС)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8088:80
# hosts: 127.0.0.1 bootcamp.local
curl http://bootcamp.local:8088/health
curl -H "Host: bootcamp.local" http://127.0.0.1:8088/health   # без правки hosts
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bootcamp-ingress
  namespace: bootcamp
spec:
  ingressClassName: nginx
  rules:
    - host: bootcamp.local
      http:
        paths:
          - path: /whoami
            pathType: Prefix          # Prefix | Exact
            backend:
              service: { name: whoami, port: { number: 80 } }
          - path: /
            pathType: Prefix
            backend:
              service: { name: backend, port: { number: 3000 } }
```

## Файл hosts

| ОС | Файл | Строка |
|----|------|--------|
| Windows | `C:\Windows\System32\drivers\etc\hosts` (Блокнот от администратора) | `127.0.0.1 bootcamp.local` |
| macOS / Linux | `/etc/hosts` | `127.0.0.1 bootcamp.local` (через port-forward / tunnel) или `<minikube ip> bootcamp.local` (Linux) |

## Изнутри кластера

```bash
kubectl run probe -n bootcamp --rm -i --restart=Never --image=busybox:1.37 -- \
  sh -c 'wget -qO- http://backend:3000/info'
kubectl exec -it -n bootcamp deploy/redis -- redis-cli
```

## Ответы контроллера

| Ответ | Значит |
|-------|--------|
| `404 Not Found` (nginx) | Дошли до контроллера, но нет правила для этого Host/пути |
| `503 Service Temporarily Unavailable` | Правило есть, но у Service нет готовых endpoints |
| `502 Bad Gateway` | Под есть, но не отвечает на `targetPort` |
| Таймаут / connection refused | Трафик не доходит до контроллера: port-forward, tunnel, hosts |

## ✅ Самопроверка

```bash
kubectl get svc -n bootcamp                          # backend NodePort, redis/whoami ClusterIP
kubectl get pods -n ingress-nginx                    # controller 1/1 Running
curl http://bootcamp.local:8088/info                 # → backend
curl http://bootcamp.local:8088/whoami               # → whoami
curl -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8088/   # → 404
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Kubernetes — документация | [kubernetes.io/docs](https://kubernetes.io/docs/) |
| Service | [kubernetes.io/docs/concepts/services-networking/service](https://kubernetes.io/docs/concepts/services-networking/service/) |
| DNS для Services и Pods | [kubernetes.io/docs/concepts/services-networking/dns-pod-service](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) |
| Ingress | [kubernetes.io/docs/concepts/services-networking/ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) |
| Ingress Controllers | [kubernetes.io/docs/concepts/services-networking/ingress-controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) |
| Gateway API | [gateway-api.sigs.k8s.io](https://gateway-api.sigs.k8s.io/) |
| minikube: доступ к приложениям | [minikube.sigs.k8s.io/docs/handbook/accessing](https://minikube.sigs.k8s.io/docs/handbook/accessing/) |
| cert-manager (HTTPS) | [cert-manager.io/docs](https://cert-manager.io/docs/) |
