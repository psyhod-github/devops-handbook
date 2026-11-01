# 13 · Ansible: основы — задания

## Уровень 1 — повторение главы

1. Установите Ansible (на Windows — в WSL) и проверьте версию.
2. Создайте EC2 через `project/terraform` с `install_nginx=false`.
3. Настройте `inventory.ini`, получите `pong`.
4. Запустите `playbook.yml` дважды: первый раз `changed>0`, второй `changed=0`.
5. Остановите nginx ad-hoc командой и восстановите его плейбуком.
6. Установите и удалите `htop` через `state: present` / `state: absent`.
7. `terraform destroy`.

!!! success "✅ Как проверить себя"
    - `ansible all -m ping` → `SUCCESS`.
    - Страница `http://<IP>` показывает hostname и `Amazon 2023`.
    - После уборки `terraform state list` пуст.

## Уровень 2 — мини-проект: проверка и обслуживание сервера

Напишите плейбук `maintenance.yml`, который можно запускать регулярно:

1. Ставит набор утилит из списка в переменной `admin_packages` (`htop`, `git`, `jq`) — **одной** задачей.
2. Создаёт пользователя `deploy` без пароля и кладёт ему ваш публичный ключ.
3. Добавляет в `/etc/motd` строку `Managed by Ansible — manual changes will be overwritten`.
4. Проверяет, что nginx отвечает `200` на `http://localhost`.
5. Выводит в конце свободное место на `/` из фактов.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Модуль `dnf` принимает список: `name: "{{ admin_packages }}"`.
- Пользователь — `ansible.builtin.user`, ключ — `ansible.posix.authorized_key` с `key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"`. Коллекция `ansible.posix` входит в пакет `ansible`.
- Одна строка в файле — `ansible.builtin.lineinfile` (идемпотентно, в отличие от `echo >>`).
- Проверка HTTP — `ansible.builtin.uri`.
- Место на диске: факты `ansible_facts['mounts']` — список, найдите элемент с `mount == '/'`. Вывести — `ansible.builtin.debug: msg=...`.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] Второй запуск `maintenance.yml` — `changed=0`.
- [ ] `ssh -i ~/.ssh/id_ed25519 deploy@<IP>` пускает на сервер.
- [ ] При входе по SSH видна строка из `motd`.
- [ ] В выводе плейбука — свободное место на `/` в гигабайтах.
- [ ] `ansible-lint maintenance.yml` (установите: `pipx install ansible-lint`) не находит ошибок.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Как сделать, чтобы на dev-сервере страница показывала «DEV», а на prod — «PROD», не меняя плейбук?</summary>

Разнести серверы по группам в inventory и задать переменные на уровне групп:

```ini
[dev]
203.0.113.10
[prod]
203.0.113.20
[web:children]
dev
prod
```

```yaml
# group_vars/dev.yml
server_env: DEV
# group_vars/prod.yml
server_env: PROD
```

Папка `group_vars/` рядом с плейбуком или inventory подхватывается автоматически. Ещё варианты: отдельный inventory на окружение (`inventories/dev`, `inventories/prod`) или `-e` при запуске. Убрать `server_env` из `vars:` плейбука обязательно: переменные play имеют приоритет выше, чем `group_vars`.
</details>

<details markdown="1">
<summary>2. Серверов сотни, и их IP постоянно меняются (автомасштабирование). Как вести inventory?</summary>

Не вести вручную, а использовать **динамический inventory**: плагин `amazon.aws.aws_ec2` спрашивает AWS API, какие инстансы сейчас есть, и группирует их по тегам:

```yaml
# inventory.aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions: [us-west-2]
filters:
  tag:Project: devops-handbook
keyed_groups:
  - key: tags.Role
    prefix: role
```

Серверы с тегом `Role=web` окажутся в группе `role_web`. Теги задаёт Terraform — так Terraform и Ansible связываются без ручного копирования IP.
</details>

<details markdown="1">
<summary>3. Ansible работает по SSH. Как настраивать серверы в приватной подсети без публичного IP и без открытого порта 22?</summary>

- **Bastion (jump host)**: один сервер в публичной подсети, через него — SSH к приватным: `ansible_ssh_common_args='-o ProxyJump=ec2-user@bastion'`.
- **AWS Systems Manager**: connection-плагин `amazon.aws.aws_ssm` подключается через агент SSM на инстансе по IAM-правам (глава 05). Порт 22 не нужен вообще, доступ контролируется политиками и пишется в CloudTrail.
- **Pull-модель**: `ansible-pull` на самом сервере забирает плейбук из git и применяет к себе по расписанию.

В продакшене всё чаще выбирают SSM: нет открытых портов, нет SSH-ключей, есть аудит.
</details>
