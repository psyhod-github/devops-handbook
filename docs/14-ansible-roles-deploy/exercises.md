# 14 · Ansible: роли и деплой — задания

## Уровень 1 — повторение главы

1. Создайте сервер (`install_nginx=false`), установите коллекции, укажите `docker_hub_user`.
2. Разверните стек: `ansible-playbook site.yml -e "app_version=1"`.
3. Убедитесь, что повторный запуск даёт `changed=0`.
4. Обновитесь на версию `2` с предварительным `--check --diff`, затем откатитесь на `1`.
5. `terraform destroy`.

!!! success "✅ Как проверить себя"
    - `http://<IP>` открывает фронтенд, счётчик растёт.
    - `/info` показывает версию, которую вы передали в `-e`.
    - При смене версии счётчик не сбрасывается.
    - После уборки `terraform state list` пуст.

## Уровень 2 — мини-проект: роль monitoring и окружения

1. Создайте роль `monitoring` (`ansible-galaxy role init roles/monitoring`), которая:
    - ставит `htop` и `sysstat`;
    - через модуль `cron` каждые 5 минут дописывает в `/var/log/server-stats.log` дату, `uptime` и `free -m`;
    - настраивает ротацию этого лога через файл в `/etc/logrotate.d/` из шаблона (хранить 7 дней).
2. Подключите роль в `site.yml` с тегом `monitoring`.
3. Добавьте в роль `app` переменную `app_env` (по умолчанию `dev`) и выводите её в `/info` через переменную окружения `APP_VERSION`, например `2-dev`.
4. Сделайте второй inventory `inventory-prod.ini`, где `app_env=prod`, и запустите плейбук с `-i inventory-prod.ini` (на тот же сервер).

<details markdown="1">
<summary>💡 Подсказки</summary>

- Cron:

  ```yaml
  - name: Сбор статистики каждые 5 минут
    ansible.builtin.cron:
      name: server-stats
      minute: "*/5"
      job: "{ date; uptime; free -m; } >> /var/log/server-stats.log"
  ```

  Параметр `name` делает задачу идемпотентной: Ansible найдёт запись по имени и не продублирует её.
- Шаблон logrotate:

  ```text
  /var/log/server-stats.log {
      daily
      rotate {{ monitoring_log_days }}
      compress
      missingok
  }
  ```
- Переменная в инвентаре: строка `[web:vars]` → `app_env=prod`. В шаблоне compose: `APP_VERSION={{ app_version }}-{{ app_env }}`.
- Не забывайте префикс имени роли у переменных (`monitoring_log_days`) — этого требует `ansible-lint`.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] `ansible web -b -m ansible.builtin.command -a "crontab -l"` показывает задачу `#Ansible: server-stats`.
- [ ] Через 5–10 минут в `/var/log/server-stats.log` появились записи.
- [ ] `/info` отдаёт `"version":"2-dev"`, а после запуска с prod-инвентарём — `"2-prod"`.
- [ ] Повторный запуск всего `site.yml` — `changed=0`.
- [ ] `ansible-lint site.yml roles` без ошибок.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как связать Jenkins (глава 12) и Ansible, чтобы каждая успешная сборка автоматически разворачивалась на сервере?</summary>

Добавить в Jenkinsfile stage `Deploy` после `Push`:

```groovy
stage('Deploy') {
    when { branch 'main' }
    steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')]) {
            sh '''
                cd project/ansible
                ansible-galaxy collection install -r requirements.yml
                ansible-playbook site.yml --tags deploy \
                  -e "app_version=$BUILD_NUMBER" \
                  --private-key "$SSH_KEY"
            '''
        }
    }
}
```

Нужно: Ansible в образе агента Jenkins, SSH-ключ сервера в Jenkins Credentials, inventory (лучше динамический, по тегам EC2). Версия деплоя совпадает с номером сборки, а в истории Jenkins видно, кто и когда развернул каждую версию. Это уже **Continuous Deployment**.
</details>

<details markdown="1">
<summary>2. Во время деплоя на 10 серверов новая версия оказалась сломанной. Как сделать, чтобы она не попала сразу на все серверы?</summary>

Катить партиями и останавливаться при ошибке:

```yaml
- hosts: web
  serial: 2                    # по 2 сервера за раз (можно "20%")
  max_fail_percentage: 0       # любой сбой — остановить весь деплой
  roles: [docker, app]
```

Проверка `/health` в конце роли `app` здесь критична: если новая версия не отвечает, задача падает на первых двух серверах, и остальные восемь остаются на старой версии. Перед деплоем сервер обычно выводят из балансировщика, после проверки — возвращают. Так устроен **rolling update**, который в Kubernetes (главы 15–18) делается автоматически.
</details>

<details markdown="1">
<summary>3. Где хранить пароль базы данных, который роль <code>app</code> должна положить в <code>.env</code> на сервере?</summary>

Не в `group_vars` открытым текстом. Варианты:

- **Ansible Vault**: `ansible-vault encrypt_string 's3cr3t' --name db_password` — в файле лежит зашифрованное значение, пароль от vault передаётся при запуске (`--ask-vault-pass` или файл вне репозитория).
- **Внешнее хранилище**: lookup-плагины читают секрет при запуске, например `{{ lookup('amazon.aws.aws_secret', 'prod/db') }}` из AWS Secrets Manager.

И в обоих случаях — `no_log: true` у задач, которые работают с секретами, иначе значение может попасть в вывод `-v`. Файл `.env` на сервере — с правами `0600`.
</details>
