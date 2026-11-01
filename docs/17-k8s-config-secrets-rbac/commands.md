# 17 · Kubernetes: ConfigMap, Secret, RBAC — шпаргалка

## Что добавляем

```text
k8s-lab/  (финальные версии — project/k8s/)
├── configmap.yaml     ← backend-config: PORT, APP_VERSION, LOG_LEVEL
├── secret.yaml        ← backend-secret: REDIS_URL (учебный, без пароля)
├── rbac.yaml          ← ServiceAccount backend-sa + Role pod-reader + RoleBinding
└── backend.yaml       ← serviceAccountName, envFrom, secretKeyRef
```

## ConfigMap

```bash
kubectl apply -f k8s-lab/configmap.yaml
kubectl get configmap -n bootcamp
kubectl describe configmap backend-config -n bootcamp
kubectl create configmap frontend --from-file=index.html --from-file=nginx.conf \
  -n bootcamp --dry-run=client -o yaml > frontend-configmap.yaml     # из файлов
kubectl create configmap app --from-literal=LOG_LEVEL=debug -n bootcamp --dry-run=client -o yaml
kubectl patch configmap backend-config -n bootcamp --type merge -p '{"data":{"LOG_LEVEL":"debug"}}'
```

## Secret

```bash
kubectl apply -f k8s-lab/secret.yaml
kubectl create secret generic app-secret --from-literal=API_KEY=xxx -n bootcamp   # без файла в git
kubectl get secret -n bootcamp
kubectl describe secret backend-secret -n bootcamp            # только размеры
kubectl get secret backend-secret -n bootcamp -o jsonpath='{.data.REDIS_URL}' | base64 -d
echo -n 'value' | base64                                      # закодировать (-n — без перевода строки!)
```

## Подключение к поду

```yaml
spec:
  serviceAccountName: backend-sa
  containers:
    - name: backend
      envFrom:
        - configMapRef:
            name: backend-config            # все ключи → переменные
      env:
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: backend-secret
              key: REDIS_URL                # один ключ
      volumeMounts:
        - name: config
          mountPath: /etc/app               # файлы, обновляются сами
  volumes:
    - name: config
      configMap:
        name: backend-config
```

```bash
kubectl rollout restart deploy/backend -n bootcamp          # подхватить новые env
kubectl exec -n bootcamp deploy/backend -- env | sort
```

## RBAC

```bash
kubectl apply -f k8s-lab/rbac.yaml
kubectl get serviceaccount,role,rolebinding -n bootcamp
kubectl describe role pod-reader -n bootcamp

SA=system:serviceaccount:bootcamp:backend-sa
kubectl auth can-i list pods -n bootcamp --as=$SA          # → yes
kubectl auth can-i get secrets -n bootcamp --as=$SA        # → no
kubectl auth can-i --list -n bootcamp --as=$SA             # все права
kubectl auth can-i '*' '*'                                  # а вы — админ кластера?

kubectl get clusterroles | grep -E "^(view|edit|admin|cluster-admin) "   # встроенные роли
```

```yaml
rules:
  - apiGroups: [""]                 # core: pods, services, configmaps, secrets
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]             # deployments, replicasets
    resources: ["deployments"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["backend-secret"]   # только конкретный объект
    verbs: ["get"]
```

| verb | Что разрешает |
|------|---------------|
| `get` | Прочитать один объект |
| `list` | Список (для secrets — фактически чтение всех!) |
| `watch` | Подписка на изменения |
| `create`, `update`, `patch`, `delete` | Изменения |

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `CreateContainerConfigError` | Нет ConfigMap/Secret или ключа — `describe pod` |
| Изменили ConfigMap, а приложение не видит | Нужен `kubectl rollout restart` |
| Значение Secret с лишним `\n` | Закодировали `echo` без `-n`; используйте `stringData` |
| `Forbidden: User "system:serviceaccount:..." cannot list resource` | Нет Role/RoleBinding или не тот namespace |
| `Error from server (NotFound): serviceaccounts "backend-sa" not found` | RBAC не применён раньше Deployment — `kubectl apply -f k8s-lab/` |
| Ключи в `data:` не принимаются | В `data:` нужен base64; для открытого текста — `stringData:` |

## ✅ Самопроверка

```bash
kubectl exec -n bootcamp deploy/backend -- sh -c 'echo $LOG_LEVEL $REDIS_URL'   # → info redis://redis:6379
kubectl auth can-i delete pods -n bootcamp --as=system:serviceaccount:bootcamp:backend-sa   # → no
kubectl get pod -n bootcamp -l app=backend -o jsonpath='{.items[0].spec.serviceAccountName}' # → backend-sa
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Kubernetes — документация | [kubernetes.io/docs](https://kubernetes.io/docs/) |
| ConfigMap | [kubernetes.io/docs/concepts/configuration/configmap](https://kubernetes.io/docs/concepts/configuration/configmap/) |
| Secret | [kubernetes.io/docs/concepts/configuration/secret](https://kubernetes.io/docs/concepts/configuration/secret/) |
| Good practices для Secret | [kubernetes.io/docs/concepts/security/secrets-good-practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) |
| Шифрование данных в etcd | [kubernetes.io/docs/tasks/administer-cluster/encrypt-data](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) |
| RBAC | [kubernetes.io/docs/reference/access-authn-authz/rbac](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) |
| ServiceAccount | [kubernetes.io/docs/concepts/security/service-accounts](https://kubernetes.io/docs/concepts/security/service-accounts/) |
| External Secrets Operator | [external-secrets.io](https://external-secrets.io/) |
| Sealed Secrets | [github.com/bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) |
| SOPS | [getsops.io](https://getsops.io/) |
