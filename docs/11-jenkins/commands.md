# 11 · Jenkins — шпаргалка

## Что добавляем в проект

```text
project/
└── jenkins/
    ├── Dockerfile           ← jenkins/jenkins:lts-jdk21 + docker-ce-cli + buildx
    └── docker-compose.yml   ← порт 9090, volume jenkins_home, docker.sock, group_add
```

## Запуск и управление

```bash
cd project/jenkins
docker compose up -d --build                     # Windows / macOS
DOCKER_GID=$(getent group docker | cut -d: -f3) docker compose up -d --build   # Linux

docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
docker compose logs -f jenkins                   # логи Jenkins (Ctrl+C — выход)
docker compose exec jenkins bash                 # shell внутри
docker compose restart jenkins                   # перезапуск без потери данных
docker compose stop                              # остановить (данные в volume)
docker compose start                             # продолжить
docker compose down -v                           # удалить ВСЁ, включая jobs и настройки
```

## Проверки

```bash
docker compose exec jenkins id                   # → groups=...,0(root) или группа docker
docker compose exec jenkins docker ps            # → контейнеры хоста (доступ к сокету есть)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:9090/login   # → 200
```

## Адреса

| URL | Что там |
|-----|---------|
| `http://localhost:9090` | Главная |
| `http://localhost:9090/manage` | Manage Jenkins |
| `http://localhost:9090/manage/pluginManager` | Плагины |
| `http://localhost:9090/env-vars.html` | Все переменные окружения сборки |
| `http://localhost:9090/job/<job>/<N>/console` | Лог сборки N |
| `http://localhost:9090/job/<job>/pipeline-syntax` | Генератор шагов pipeline (Snippet Generator) |

## Шаблон декларативного pipeline

```groovy
pipeline {
    agent any                                        // обязательно

    environment { IMAGE_NAME = 'my-app' }            // необязательно

    options {                                        // необязательно
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    stages {                                         // обязательно
        stage('Build') {
            steps {
                sh 'docker build -t "$IMAGE_NAME:$BUILD_NUMBER" .'
            }
        }
        stage('Parallel checks') {
            parallel {
                stage('Lint')  { steps { sh 'echo lint' } }
                stage('Unit')  { steps { sh 'echo unit' } }
            }
        }
        stage('Deploy') {
            when { branch 'main' }                   // только для ветки main (multibranch)
            steps { echo 'deploy' }
        }
    }

    post {                                           // необязательно
        always  { echo "Result: ${currentBuild.currentResult}" }
        success { echo 'OK' }
        failure { echo 'FAILED' }
    }
}
```

## Переменные сборки

| Переменная | Пример |
|------------|--------|
| `BUILD_NUMBER` | `42` |
| `JOB_NAME` | `hello-pipeline` |
| `BUILD_URL` | `http://localhost:9090/job/hello-pipeline/42/` |
| `WORKSPACE` | `/var/jenkins_home/workspace/hello-pipeline` |
| `NODE_NAME` | `built-in` |
| `GIT_COMMIT` | хеш коммита (при checkout из git) |

В Groovy: `"${env.BUILD_NUMBER}"`. В `sh '''...'''`: `$BUILD_NUMBER`.

## Шаги, которые нужны чаще всего

```groovy
echo 'text'                              // вывести в лог
sh 'command'                             // shell-команда, падает при коде ≠ 0
sh(script: 'cmd', returnStdout: true).trim()   // получить вывод в переменную
sh 'cleanup || true'                     // не падать при ошибке
checkout scm                             // взять код из настроек job (глава 12)
withCredentials([...]) { ... }           // секреты (глава 12)
```

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `docker: not found` | В образе нет Docker CLI — соберите образ из `project/jenkins/Dockerfile` |
| `permission denied ... docker.sock` | У пользователя `jenkins` нет группы сокета — `group_add` / `DOCKER_GID` |
| `Bind for 0.0.0.0:9090 failed` | Порт занят — смените левую часть `ports` |
| Нет таблицы Stage View | Плагин *Pipeline: Stage View* не установлен |
| `No such DSL method` | Опечатка в шаге или не установлен нужный плагин |
| `WorkflowScript: … expecting '}'` | Синтаксическая ошибка в Jenkinsfile — проверьте скобки |
| Jenkins не открывается после `up` | Он стартует 30–60 секунд — `docker compose logs -f jenkins`, ждите `Jenkins is fully up and running` |
| Сборки «потерялись» | Удалили volume (`down -v`) — всё состояние Jenkins было в нём |

## ✅ Самопроверка

```bash
docker compose exec jenkins docker ps            # → работает без permission denied
```

- [ ] Job `hello-pipeline`: сборка зелёная, три колонки в Stage View.
- [ ] Сломанная сборка красная, следующий stage не выполнялся, `post { always }` выполнился.

## Почитать

| Тема | Ссылка |
|------|--------|
| Jenkins — документация | [www.jenkins.io/doc](https://www.jenkins.io/doc/) |
| Pipeline — руководство | [www.jenkins.io/doc/book/pipeline](https://www.jenkins.io/doc/book/pipeline/) |
| Синтаксис декларативного pipeline | [www.jenkins.io/doc/book/pipeline/syntax](https://www.jenkins.io/doc/book/pipeline/syntax/) |
| Jenkinsfile и переменные | [www.jenkins.io/doc/book/pipeline/jenkinsfile](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/) |
| Установка в Docker (вариант с DinD) | [www.jenkins.io/doc/book/installing/docker](https://www.jenkins.io/doc/book/installing/docker/) |
| Защита Docker-сокета | [docs.docker.com/engine/security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface) |
| Образ Jenkins | [hub.docker.com/r/jenkins/jenkins](https://hub.docker.com/r/jenkins/jenkins) |
