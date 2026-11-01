# 11 · Jenkins — задания

## Уровень 1 — повторение главы

1. Запустите Jenkins из `project/jenkins/`, пройдите первичную настройку, поставьте *Pipeline: Stage View*.
2. Создайте job `hello-pipeline` с тремя stages из главы и получите зелёную сборку.
3. Сломайте сборку через `sh 'exit 1'`, найдите в логе причину, почините.
4. Остановите Jenkins (`docker compose stop`), не удаляя volume.

!!! success "✅ Как проверить себя"
    - `docker compose exec jenkins docker ps` работает без `permission denied`.
    - В истории job есть зелёная, красная и снова зелёная сборки.
    - У красной сборки в Stage View `Done` не выполнялся, а в Console Output есть вывод `post { always }`.

## Уровень 2 — мини-проект: параметры и параллельные проверки

Расширьте `hello-pipeline`:

1. Добавьте **параметр** сборки `GREETING` (строка, по умолчанию `Hello`) и выведите его в stage `Info`.
2. Добавьте stage `Checks`, в котором **параллельно** выполняются два вложенных stage:
    - `Lint` — `sleep 5` и `echo lint ok`;
    - `Unit` — `sleep 5` и `echo unit ok`.
3. Добавьте `options { timeout(time: 2, unit: 'MINUTES') }` и проверьте, что сборка с `sh 'sleep 300'` прерывается по таймауту.
4. Выведите в `post { always }` длительность сборки.

<details markdown="1">
<summary>💡 Подсказки</summary>

```groovy
pipeline {
    agent any
    parameters {
        string(name: 'GREETING', defaultValue: 'Hello', description: 'What to say')
    }
    options {
        timeout(time: 2, unit: 'MINUTES')
    }
    stages {
        stage('Info') {
            steps { echo "${params.GREETING} from build #${env.BUILD_NUMBER}" }
        }
        stage('Checks') {
            parallel {
                stage('Lint') { steps { sh 'sleep 5 && echo lint ok' } }
                stage('Unit') { steps { sh 'sleep 5 && echo unit ok' } }
            }
        }
    }
    post {
        always { echo "Took ${currentBuild.durationString}" }
    }
}
```

- После первой сборки с блоком `parameters` кнопка **Build Now** превратится в **Build with Parameters**.
- Если две параллельные проверки по 5 секунд заняли около 5, а не 10 секунд — параллельность работает.
</details>

<details markdown="1">
<summary>✅ Критерии готовности</summary>

- [ ] Сборка с параметром `GREETING=Привет` выводит `Привет from build #N`.
- [ ] Stage `Checks` занимает около 5 секунд, `Lint` и `Unit` выполняются одновременно.
- [ ] Сборка с `sleep 300` прерывается через 2 минуты со статусом `ABORTED`.
- [ ] В конце лога — `Took ...`.
</details>

## Уровень 3 — подумайте сами

<details markdown="1">
<summary>1. Чем pipeline в окне «Pipeline script» хуже <code>Jenkinsfile</code> в репозитории?</summary>

Код pipeline хранится только в настройках Jenkins: нет истории изменений, нет ревью, нет связи с версией кода. Переустановили Jenkins или потеряли volume — pipeline пропал. Разработчики не видят, как собирается их код, и не могут изменить сборку вместе с кодом в одном pull request. Принцип «всё важное — в git» относится и к pipeline: в главе 12 job будет читать `Jenkinsfile` из репозитория (*Pipeline script from SCM*).
</details>

<details markdown="1">
<summary>2. Ваш Jenkins на сервере, сборки запускаются прямо на controller с доступом к docker.sock. Почему это плохая архитектура и как её улучшают?</summary>

- **Безопасность:** любой, кто может изменить Jenkinsfile, получает root на controller, где хранятся все credentials всех проектов.
- **Стабильность:** тяжёлая сборка съедает CPU и диск controller — тормозит интерфейс и все остальные сборки.
- **Чистота:** сборки оставляют мусор, конфликтуют по версиям инструментов.

Улучшают так: у controller 0 executor-ов, он только управляет. Сборки идут на **агентах** — отдельных VM или эфемерных контейнерах/подах в Kubernetes, которые создаются под одну сборку и удаляются после. Для сборки образов без доступа к Docker-демону используют инструменты вроде BuildKit rootless или Kaniko.
</details>

<details markdown="1">
<summary>3. Jenkins, GitHub Actions, GitLab CI — в чём принципиальное сходство и разница?</summary>

Сходство: pipeline как код в репозитории, этапы и шаги, секреты, триггеры по событиям git, артефакты. Всё, что вы изучили, переносится.

Разница:

- **Jenkins** — сервер, который вы разворачиваете и обслуживаете сами: обновления, плагины, безопасность, агенты. Максимальная гибкость, любая инфраструктура.
- **GitHub Actions / GitLab CI** — встроены в платформу хранения кода. Не нужно поддерживать сервер, есть готовые облачные исполнители, YAML вместо Groovy. Но меньше контроля, и нужно платить за минуты сверх бесплатного лимита (или ставить свои runners).

Многие компании, начавшие с Jenkins, переходят на встроенные CI. Но в больших организациях Jenkins по-прежнему очень распространён.
</details>
