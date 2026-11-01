# 12 · Jenkins + Docker — шпаргалка

## Что добавляем в проект

```text
project/
├── Jenkinsfile          ← Checkout → Build → Test (smoke) → Push; post: cleanup
└── jenkins/             ← из главы 11
```

Job `devops-handbook`: *Pipeline script from SCM*, Git, `*/main`, Script Path `project/Jenkinsfile`.
Credentials: `docker-hub-creds` (Username with password, пароль — токен Docker Hub).

## Jenkinsfile — ключевые части

```groovy
environment {
    IMAGE_NAME      = 'devops-bootcamp-backend'
    DOCKER_HUB_REPO = '<your-dockerhub-user>/devops-bootcamp-backend'
}

stage('Build') {
    steps {
        sh 'docker build -t "$IMAGE_NAME:$BUILD_NUMBER" -t "$IMAGE_NAME:latest" ./app/backend'
    }
}

stage('Push') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-creds',
                usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh '''
                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                docker tag  "$IMAGE_NAME:$BUILD_NUMBER" "$DOCKER_HUB_REPO:$BUILD_NUMBER"
                docker push "$DOCKER_HUB_REPO:$BUILD_NUMBER"
                docker logout
            '''
        }
    }
}

post {
    always { sh 'docker rmi "$IMAGE_NAME:$BUILD_NUMBER" || true' }
}

triggers { pollSCM('H/5 * * * *') }     // опрашивать git каждые 5 минут (внутри pipeline { })
```

## Кавычки в `sh`

| Запись | Кто подставляет | Для секретов |
|--------|-----------------|--------------|
| `sh '''echo "$VAR"'''` | shell | ✅ да |
| `sh "echo ${env.VAR}"` | Groovy | ❌ нет |
| `sh """echo ${DOCKER_PASS}"""` | Groovy | ❌ никогда |

## Образы и реестр

```bash
docker build -t app:42 .
docker tag app:42 user/app:42                  # второе имя, без копирования
docker login -u user --password-stdin < token.txt
docker push user/app:42
docker pull user/app:42
docker image inspect user/app:42 --format '{{.Id}}'
docker rmi user/app:42                         # только локально
docker logout
```

## Проверить результат сборки

```bash
docker pull <your-dockerhub-user>/devops-bootcamp-backend:latest
docker run --rm -d -p 3000:3000 --name check <your-dockerhub-user>/devops-bootcamp-backend:latest
curl http://localhost:3000/health          # Windows: curl.exe
docker stop check
```

## Cron в Jenkins

| Запись | Когда |
|--------|-------|
| `H/5 * * * *` | каждые 5 минут |
| `H * * * *` | раз в час |
| `H 2 * * *` | каждую ночь между 2:00 и 2:59 |
| `H 9 * * 1-5` | по будням утром |

Поля: минута, час, день месяца, месяц, день недели. `H` — Jenkins распределяет время запуска между job.

## Частые ошибки

| Симптом | Причина |
|---------|---------|
| `ERROR: Could not find credentials entry with ID 'docker-hub-creds'` | ID в Jenkins не совпадает с Jenkinsfile |
| `unauthorized: incorrect username or password` | Неверный логин или токен; токен отозван |
| `denied: requested access to the resource is denied` при push | Токен только на чтение, или `DOCKER_HUB_REPO` с чужим логином |
| `invalid reference format` | В `DOCKER_HUB_REPO` остался `<your-dockerhub-user>` или заглавные буквы |
| `A secret was passed to "sh" using Groovy String interpolation` | Секрет в `"""` — замените на `'''` и `$VAR` |
| `couldn't find remote ref` / `Couldn't find any revision to build` | Неверный *Branch Specifier* (`*/main` vs `*/master`) |
| `Unable to find project/Jenkinsfile` | Неверный *Script Path* |
| Сборка не запускается по коммиту | Poll SCM выключен или коммит не в ветке job; смотрите **Polling Log** |
| `no space left on device` на агенте | Образы не удаляются — проверьте `post { always }` и `docker system df` |

## ✅ Самопроверка

- [ ] Stage View job `devops-handbook`: Checkout, Build, Test, Push — зелёные.
- [ ] В логе `Push`: логин и пароль замаскированы (`****`).
- [ ] На Docker Hub теги `N` и `latest` с одинаковым digest.
- [ ] `docker pull ...:N` + `docker run` + `curl /health` работает на вашем компьютере.

## Почитать

| Тема | Ссылка |
|------|--------|
| Jenkins — документация | [www.jenkins.io/doc](https://www.jenkins.io/doc/) |
| Pipeline from SCM | [www.jenkins.io/doc/book/pipeline/getting-started](https://www.jenkins.io/doc/book/pipeline/getting-started/#defining-a-pipeline-in-scm) |
| Credentials в pipeline | [www.jenkins.io/doc/book/pipeline/jenkinsfile/#handling-credentials](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#handling-credentials) |
| Интерполяция строк и секреты | [www.jenkins.io/doc/book/pipeline/jenkinsfile/#string-interpolation](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#string-interpolation) |
| Триггеры | [www.jenkins.io/doc/book/pipeline/syntax/#triggers](https://www.jenkins.io/doc/book/pipeline/syntax/#triggers) |
| Docker Hub: Personal access tokens | [docs.docker.com/security/access-tokens](https://docs.docker.com/security/access-tokens/) |
| `docker push` | [docs.docker.com/reference/cli/docker/image/push](https://docs.docker.com/reference/cli/docker/image/push/) |
| Trivy — сканер уязвимостей | [trivy.dev](https://trivy.dev/) |
