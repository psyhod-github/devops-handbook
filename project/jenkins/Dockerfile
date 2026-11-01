# Глава 11 — Jenkins с Docker CLI для сборки образов через сокет хоста.
# Ставим только клиент (docker-ce-cli + buildx) из официального репозитория Docker:
# демон внутри контейнера не нужен, команды уходят демону хоста через /var/run/docker.sock.

FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER jenkins
