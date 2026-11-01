# 17 · Kubernetes: ConfigMap, Secret, RBAC — задания

## Уровень 1 — повторение главы

1. Создайте ConfigMap, Secret и RBAC из главы.
2. Переведите Deployment backend на `envFrom`, `secretKeyRef` и `serviceAccountName: backend-sa`.
3. Убедитесь, что переменные попали в под.
4. Раскодируйте значение Secret.
5. Измените `APP_VERSION` в ConfigMap и увидьте новую версию в `/info` только после `rollout restart`.
6. Проверьте права `backend-sa` через `kubectl auth can-i`.

!!! success "✅ Как проверить себя"
    - `env` в поде показывает `PORT`, `LOG_LEVEL`, `APP_VERSION`, `REDIS_URL`.
    - `/info` меняет версию только после перезапуска.
    - `can-i list pods` → `yes`, `can-i get secrets` → `no`.

## Уровень 2 — мини-проект: конфиг файлом и секрет без git

1. **Секрет без файла.** Создайте Secret `app-secret` с ключом `API_KEY` **командой** (`kubectl create secret generic ...`), а не файлом в репозитории. Подключите `API_KEY` к backend через `secretKeyRef`.
2. **Конфиг файлом.** Создайте ConfigMap `backend-files` с ключом `app.json` (произвольный JSON: `{"feature_x": true}`) и смонтируйте его в под backend как файл `/etc/app/app.json`.
3. Измените `app.json` в ConfigMap и, **не перезапуская под**, дождитесь, пока файл в поде обновится.
4. Дайте `backend-sa` право читать **только** Secret `app-secret` (через `resourceNames`) и проверьте, что `backend-secret` он читать не может.

<details markdown="1">
<summary>💡 Подсказки</summary>

- `kubectl create secret generic app-secret -n bootcamp --from-literal=API_KEY=my-secret-token`.
- Том из ConfigMap:

  ```yaml
          volumeMounts:
            - name: files
              mountPath: /etc/app
              readOnly: true
      volumes:
        - name: files
          configMap:
            name: backend-files
  ```
- Следить за файлом: `kubectl exec -n bootcamp deploy/backend -- cat /etc/app/app.json` раз в 15–20 секунд. Обновление занимает до минуты.
- Правило Role:

  ```yaml
    - apiGroups: [""]
      resources: ["secrets"]
      resourceNames: ["app-secret"]
      verbs: ["get"]
  ```
  `resourceNames` работает с `get`, но не с `list` — список выдал бы все секреты.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `kubectl exec ... -- printenv API_KEY` → `my-secret-token`; в репозитории нет файла с этим значением.
- [ ] `cat /etc/app/app.json` показывает новое содержимое без перезапуска пода (`RESTARTS` и `AGE` пода не изменились).
- [ ] `kubectl auth can-i get secret/app-secret --as=...backend-sa -n bootcamp` → `yes`, `get secret/backend-secret` → `no`.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как хранить секреты приложения в AWS Secrets Manager и получать их в Kubernetes, не кладя значения в git и не давая подам ключей AWS?</summary>

Связка **External Secrets Operator + IAM-роль для ServiceAccount**:

1. Секрет лежит в AWS Secrets Manager.
2. Оператор External Secrets работает в кластере от имени ServiceAccount, связанного с IAM-ролью (в EKS — IRSA или EKS Pod Identity: тот же принцип временных учётных данных, что instance profile в главе 05).
3. В git — только объект `ExternalSecret`: «возьми `prod/db` из Secrets Manager и создай Secret `db-secret`».
4. Оператор создаёт и периодически обновляет обычный Secret, под использует его как обычно.

Значения нет ни в git, ни в образе, ротация секрета в AWS доходит до кластера сама.
</details>

<details markdown="1">
<summary>2. Разработчику нужно смотреть логи и поды в namespace <code>bootcamp</code>, но не читать секреты и ничего не менять. Как это выдать?</summary>

Встроенная ClusterRole `view` подходит почти идеально: она даёт чтение большинства ресурсов, **кроме Secret**. Привязать её RoleBinding в нужном namespace:

```bash
kubectl create rolebinding dev-view -n bootcamp --clusterrole=view --user=anna
```

Для логов нужен `get` на `pods/log` — он входит в `view`. Проверка: `kubectl auth can-i get secrets -n bootcamp --as=anna` → `no`, `kubectl auth can-i get pods/log -n bootcamp --as=anna` → `yes`.
</details>

<details markdown="1">
<summary>3. Почему право <code>list</code> на <code>secrets</code> так же опасно, как <code>get</code> на все секреты?</summary>

Ответ на `list` содержит объекты целиком, со значениями. `kubectl get secrets -o yaml` с правом `list` вернёт все секреты namespace с данными. Поэтому `list`/`watch` на secrets выдают только системным компонентам, которым это действительно нужно, а приложениям — `get` с `resourceNames` на конкретные объекты.
</details>
