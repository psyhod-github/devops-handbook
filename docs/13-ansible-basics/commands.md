# 13 · Ansible: основы — шпаргалка

## Что добавляем в проект

```text
project/
├── terraform/              ← terraform apply -var="install_nginx=false"
└── ansible/
    ├── ansible.cfg         ← inventory, remote_user, ssh_args (accept-new)
    ├── inventory.ini.example
    ├── inventory.ini       ← ваш IP (НЕ коммитить)
    └── playbook.yml        ← nginx + страница из фактов
```

## Установка

```bash
# Ubuntu / WSL (Ubuntu 24.04)
sudo apt update && sudo apt install -y pipx
pipx ensurepath && source ~/.bashrc
pipx install --include-deps "ansible==14.5.0"

# macOS
brew install ansible

ansible --version | head -1        # → ansible [core 2.21.x]
```

WSL: работайте в `~/...`, а не в `/mnt/c/...`; ключ — в `~/.ssh/` с `chmod 600`.

## Inventory

```ini
[web]
203.0.113.10
203.0.113.11 ansible_user=ubuntu        # переменная для одного хоста

[db]
203.0.113.20

[web:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

```bash
ansible-inventory --graph              # дерево групп
ansible-inventory --list               # всё в JSON, с переменными
ansible all --list-hosts
```

## Ad-hoc команды

```bash
ansible all -m ping                                            # SSH + Python → pong
ansible web -m ansible.builtin.command -a "uptime"
ansible web -m ansible.builtin.setup -a "filter=ansible_distribution*"
ansible web -b -m ansible.builtin.dnf -a "name=htop state=present"     # -b = become (sudo)
ansible web -b -m ansible.builtin.service -a "name=nginx state=restarted"
ansible web -m ansible.builtin.copy -a "src=./file dest=/tmp/file"
```

## Плейбук

```bash
ansible-playbook playbook.yml --syntax-check   # синтаксис, без подключения
ansible-playbook playbook.yml --check          # что изменится (dry run)
ansible-playbook playbook.yml --check --diff   # + разница в файлах
ansible-playbook playbook.yml                  # применить
ansible-playbook playbook.yml -e "server_env=staging"   # переменная (наивысший приоритет)
ansible-playbook playbook.yml --limit 203.0.113.10      # только один хост
ansible-playbook playbook.yml -v / -vv / -vvv           # подробнее
ansible-playbook playbook.yml --list-tasks
```

## Шаблон плейбука

```yaml
---
- name: Описание play
  hosts: web
  become: true
  vars:
    app_name: "My App"

  tasks:
    - name: Установить пакет
      ansible.builtin.dnf:
        name: nginx
        state: present            # present | absent | latest

    - name: Положить файл
      ansible.builtin.copy:
        content: "Hello from {{ ansible_facts['hostname'] }}\n"
        dest: /usr/share/nginx/html/index.html
        mode: "0644"

    - name: Сервис
      ansible.builtin.service:
        name: nginx
        state: started            # started | stopped | restarted
        enabled: true

    - name: Проверить HTTP
      ansible.builtin.uri:
        url: http://localhost
        status_code: 200
```

## Модули, которые нужны чаще всего

| Модуль | Для чего |
|--------|----------|
| `ansible.builtin.dnf` / `apt` / `package` | Пакеты (Amazon Linux, RHEL / Debian, Ubuntu / любой) |
| `ansible.builtin.service` | Сервисы systemd |
| `ansible.builtin.copy` | Файл с control node или `content:` |
| `ansible.builtin.template` | Файл из шаблона Jinja2 (глава 14) |
| `ansible.builtin.file` | Папки, права, ссылки, удаление |
| `ansible.builtin.lineinfile` | Одна строка в конфиге |
| `ansible.builtin.user` / `group` | Пользователи и группы |
| `ansible.builtin.uri` | HTTP-запрос, проверка ответа |
| `ansible.builtin.command` / `shell` | Крайний случай: нет подходящего модуля |

Документация модуля в терминале: `ansible-doc ansible.builtin.dnf`.

## Факты

```text
ansible_facts['hostname']               ip-172-31-5-10
ansible_facts['distribution']           Amazon
ansible_facts['distribution_version']   2023
ansible_facts['default_ipv4']['address']  172.31.5.10
ansible_facts['memtotal_mb']            916
ansible_facts['architecture']           x86_64
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `UNREACHABLE ... Connection timed out` | Security Group / IP / сервер не запущен |
| `UNREACHABLE ... Permission denied (publickey)` | Ключ или пользователь (`ec2-user` для Amazon Linux) |
| `Host key verification failed` | IP достался новому серверу — `ssh-keygen -R <IP>` |
| `UNPROTECTED PRIVATE KEY FILE` (WSL) | Ключ на `/mnt/c` — скопируйте в `~/.ssh`, `chmod 600` |
| `[WARNING]: Ansible is being run in a world writable directory` | Проект на `/mnt/c` — `ansible.cfg` игнорируется; клонируйте в `~` |
| `Missing sudo password` / `permission denied` | Не указан `become: true` |
| `No package nginx available` | Опечатка или пакет из другого дистрибутива |
| `mapping values are not allowed here` | Ошибка отступов в YAML — только пробелы, без табуляции |
| `couldn't resolve module/action` | Опечатка в имени модуля или не установлена коллекция |

## ✅ Самопроверка

```bash
ansible all -m ping                        # → SUCCESS, pong
ansible-playbook playbook.yml              # → failed=0
ansible-playbook playbook.yml              # → changed=0 (идемпотентность)
curl -s http://<IP> | grep h1              # → <h1>DevOps Handbook</h1>
```

## Почитать

| Тема | Ссылка |
|------|--------|
| Ansible — документация | [docs.ansible.com](https://docs.ansible.com/) |
| Начало работы | [docs.ansible.com/ansible/latest/getting_started](https://docs.ansible.com/ansible/latest/getting_started/index.html) |
| Установка | [docs.ansible.com/ansible/latest/installation_guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html) |
| Inventory | [docs.ansible.com/ansible/latest/inventory_guide](https://docs.ansible.com/ansible/latest/inventory_guide/index.html) |
| Плейбуки | [docs.ansible.com/ansible/latest/playbook_guide](https://docs.ansible.com/ansible/latest/playbook_guide/index.html) |
| Встроенные модули | [docs.ansible.com/ansible/latest/collections/ansible/builtin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html) |
| Проверка ключей хостов | [docs.ansible.com/ansible/latest/inventory_guide/connection_details.html](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html#managing-host-key-checking) |
| ansible-lint | [ansible.readthedocs.io/projects/lint](https://ansible.readthedocs.io/projects/lint/) |
