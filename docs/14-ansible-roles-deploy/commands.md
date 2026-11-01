# 14 · Ansible: роли и деплой — шпаргалка

## Что добавляем в проект

```text
project/ansible/
├── requirements.yml              ← community.docker 5.4.0
├── site.yml                      ← assert + роли docker, app
├── group_vars/web.yml            ← docker_hub_user, app_version
└── roles/
    ├── docker/{defaults,tasks}/main.yml
    └── app/
        ├── defaults/main.yml
        ├── tasks/main.yml
        ├── handlers/main.yml
        └── templates/docker-compose.yml.j2
```

## Полный цикл

```bash
# 1. Сервер (там, где Terraform)
cd project/terraform && terraform apply -var="install_nginx=false" && terraform output -raw public_ip

# 2. Ansible (WSL / macOS / Linux)
cd project/ansible
vi inventory.ini                                   # новый IP
ssh-keygen -R <IP>                                 # если IP уже встречался
ansible-galaxy collection install -r requirements.yml
ansible all -m ping
ansible-playbook site.yml -e "app_version=1"       # установка + деплой

# 3. Релизы
ansible-playbook site.yml --tags deploy -e "app_version=2" --check --diff
ansible-playbook site.yml --tags deploy -e "app_version=2"
ansible-playbook site.yml --tags deploy -e "app_version=1"   # откат

# 4. Уборка
cd ../terraform && terraform destroy
```

## Роли

```bash
ansible-galaxy role init roles/monitoring     # создать скелет роли
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list
ansible-doc community.docker.docker_compose_v2
```

```yaml
# site.yml
- hosts: web
  become: true
  pre_tasks:
    - ansible.builtin.assert:
        that: [docker_hub_user is defined]
      tags: always
  roles:
    - docker
    - app
    - role: monitoring
      tags: monitoring
```

## Шаблон, handler, проверка

```yaml
- name: Конфиг из шаблона
  ansible.builtin.template:
    src: app.conf.j2                  # ищется в roles/<роль>/templates/
    dest: /etc/app/app.conf
  notify: Restart app

- name: Проверить HTTP
  ansible.builtin.uri:
    url: http://localhost/health
  register: app_health
  retries: 10
  delay: 3
  until: app_health.status == 200

# handlers/main.yml
- name: Restart app
  ansible.builtin.service:
    name: app
    state: restarted
```

Принудительно выполнить накопленные handlers посреди play: `- ansible.builtin.meta: flush_handlers`.

## Jinja2

```jinja
{{ variable }}
{{ variable | default('value') }}
{{ list | join(',') }}
{% if env == 'prod' %}replicas: 3{% else %}replicas: 1{% endif %}
{% for host in groups['web'] %}{{ host }}
{% endfor %}
{{ ansible_managed }}                 {# комментарий «файл управляется Ansible» #}
```

## Docker Compose через модуль

```yaml
- community.docker.docker_compose_v2:
    project_src: /opt/devops-handbook
    state: present            # up -d     | absent = down | restarted | stopped
    pull: missing             # always | missing | never | policy
    services: [backend]       # только эти сервисы (необязательно)
    recreate: auto            # auto | always | never
```

## Приоритет переменных (упрощённо, слабые → сильные)

```text
roles/*/defaults → group_vars/all → group_vars/<группа> → host_vars/<хост>
→ vars: в плейбуке → roles/*/vars → -e (extra vars)
```

## Теги

```bash
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags deploy
ansible-playbook site.yml --skip-tags install
ansible-playbook site.yml --list-tasks --tags deploy
```

## На сервере

```bash
ansible web -b -m ansible.builtin.command -a "docker compose -f /opt/devops-handbook/docker-compose.yml ps"
ansible web -b -m ansible.builtin.command -a "docker compose -f /opt/devops-handbook/docker-compose.yml logs --tail 20 backend"
ansible web -m ansible.builtin.command -a "docker compose version"
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `Укажите свой docker_hub_user` (assert) | Не задан логин в `group_vars/web.yml` |
| `couldn't resolve module/action 'community.docker.docker_compose_v2'` | Не установлена коллекция — `ansible-galaxy collection install -r requirements.yml` |
| `Cannot find docker CLI in path` | Роль `docker` не выполнялась (`--tags deploy` на чистом сервере) |
| `manifest unknown` / `pull access denied` | Нет такого тега на Docker Hub или опечатка в `docker_hub_user` |
| `bind: address already in use` (порт 80) | На сервере работает nginx из главы 08/13 — пересоздайте сервер с `install_nginx=false` |
| `Status code was -1 ... Connection refused` (проверка `/health`) | Стек стартует — увеличьте `retries`; смотрите логи backend |
| Новый `index.html` не виден | Bind mount одиночного файла держит старый inode — нужен handler `Restart nginx` |
| `checksum mismatch` у `get_url` | Файл повреждён или подменён — проверьте версию в `docker_compose_version` |
| После смены `app_version=latest` ничего не обновилось | `pull: missing` не скачивает существующий тег — деплойте номерами |

## ✅ Самопроверка

```bash
ansible-playbook site.yml -e "app_version=1"        # → failed=0
ansible-playbook site.yml -e "app_version=1"        # → changed=0
curl http://<IP>/info                               # → "version":"1"
ansible-playbook site.yml --tags deploy -e "app_version=2" && curl http://<IP>/info   # → "version":"2"
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Ansible — документация | [docs.ansible.com](https://docs.ansible.com/) |
| Роли | [docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) |
| Переменные и их приоритет | [docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence) |
| Handlers | [docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html) |
| Шаблоны Jinja2 | [docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) |
| Теги | [docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html) |
| Коллекции и requirements.yml | [docs.ansible.com/ansible/latest/collections_guide](https://docs.ansible.com/ansible/latest/collections_guide/index.html) |
| `docker_compose_v2` | [docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html) |
| Ansible Galaxy | [galaxy.ansible.com](https://galaxy.ansible.com) |
