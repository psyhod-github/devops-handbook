# 12 · Jenkins + Docker — задания

## Уровень 1 — повторение главы

1. Создайте токен Docker Hub и credentials `docker-hub-creds` в Jenkins.
2. Укажите свой логин в `project/Jenkinsfile`, закоммитьте в fork.
3. Создайте job `devops-handbook` (*Pipeline script from SCM*, Script Path `project/Jenkinsfile`) и получите зелёную сборку.
4. Скачайте образ из Docker Hub на свой компьютер и проверьте `/health`.
5. Включите Poll SCM и получите сборку от коммита.

!!! success "✅ Как проверить себя"
    - На Docker Hub есть минимум два номерных тега и `latest`.
    - Сборка от коммита помечена *Started by an SCM change*.
    - В логе `Push` нет вашего токена — только `****`.

## Уровень 2 — мини-проект: сканирование уязвимостей и тег из коммита

Улучшите pipeline:

1. Добавьте stage `Scan` между `Test` и `Push`: сканер **Trivy** проверяет образ на уязвимости уровня HIGH и CRITICAL. Сначала сборка не должна падать от найденных уязвимостей, только показывать отчёт.
2. Добавьте третий тег — короткий хеш коммита (`a1b2c3d`), и публикуйте его тоже.
3. Переключите `Scan` в строгий режим: сборка падает, если найдены CRITICAL. Посмотрите, что найдётся.

<details markdown="1">
<summary>💡 Подсказки</summary>

- Trivy не нужно ставить в Jenkins: запустите его как контейнер через тот же сокет.

  ```groovy
  stage('Scan') {
      steps {
          sh '''
              docker run --rm \
                -v /var/run/docker.sock:/var/run/docker.sock \
                aquasec/trivy:latest image \
                --severity HIGH,CRITICAL --exit-code 0 --no-progress \
                "$IMAGE_NAME:$BUILD_NUMBER"
          '''
      }
  }
  ```

  Строгий режим — `--exit-code 1 --severity CRITICAL`.
- Хеш коммита после `checkout scm` доступен как `GIT_COMMIT`. Короткий вариант в shell: `GIT_SHA=$(git rev-parse --short HEAD)`.
- Тегов может быть сколько угодно: `docker build -t a -t b -t c`.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] В логе `Scan` таблица уязвимостей (или `Total: 0`) по пакетам ОС и `node_modules`.
- [ ] На Docker Hub три тега одного digest: номер сборки, хеш коммита, `latest`.
- [ ] В строгом режиме вы знаете, падает ли сборка, и почему. Если падает — какой пакет и есть ли исправленная версия (колонка *Fixed Version*).
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Разработчики делают 20 коммитов в день в feature-ветки. Каждая сборка — 3 минуты и push в Docker Hub. Что здесь не так и как перестроить pipeline?</summary>

Публиковать образ из каждой feature-ветки незачем: реестр засоряется непроверенными образами, агенты заняты. Обычная схема:

- **Multibranch Pipeline** в Jenkins: отдельный job на каждую ветку и pull request из одного Jenkinsfile;
- для всех веток — `Build` и `Test`, быстрая обратная связь;
- `Push` (и дальнейший деплой) — только для `main`: `when { branch 'main' }`;
- изменения только в документации можно пропускать: `when { changeset "app/**" }`.

Так каждая ветка проверяется, а в реестр попадает только то, что прошло ревью и слито.
</details>

<details markdown="1">
<summary>2. Злоумышленник отправил pull request, в котором Jenkinsfile печатает <code>env</code> в лог и отправляет credentials на свой сервер. Что может пойти не так и как от этого защищаются?</summary>

Если Jenkins автоматически собирает PR из форков с тем же Jenkinsfile и теми же credentials, атакующий получит токен Docker Hub (маскировка в логе не мешает отправить значение по сети), а через доступ к docker.sock — root на агенте.

Защита:

- сборки PR из форков не получают секретов и запускаются в изолированной среде (настройка *Trust* в GitHub Branch Source: доверять только коллабораторам);
- секреты выдаются только для доверенных веток (`main`);
- для PR из форков Jenkinsfile берётся из целевой ветки, а не из PR;
- агенты эфемерные и без доступа к Docker хоста.

Та же проблема есть во всех CI-системах (`pull_request_target` в GitHub Actions — известный источник уязвимостей).
</details>

<details markdown="1">
<summary>3. Как сделать так, чтобы Jenkins и его настройки (credentials, jobs, плагины) можно было поднять с нуля одной командой — без кликов в интерфейсе?</summary>

Описать Jenkins кодом:

- **Плагины** — список в Dockerfile: `RUN jenkins-plugin-cli --plugins git workflow-aggregator ...`;
- **Настройки и credentials** — плагин **Configuration as Code (JCasC)**: YAML-файл с конфигурацией, секреты подставляются из переменных окружения или менеджера секретов;
- **Jobs** — плагин **Job DSL** или Multibranch/Organization Folder, которые сами находят репозитории с Jenkinsfile;
- отключить мастер настройки: `-Djenkins.install.runSetupWizard=false`.

Тогда `jenkins_home` перестаёт быть «уникальной снежинкой», и Jenkins становится такой же воспроизводимой инфраструктурой, как сервер из Terraform.
</details>
