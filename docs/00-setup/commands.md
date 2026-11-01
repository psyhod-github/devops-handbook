# 00 · Подготовка — шпаргалка

## Установка

=== "Windows (PowerShell)"

    ```powershell
    winget install --id Git.Git -e
    winget install --id Microsoft.VisualStudioCode -e
    winget install --id Amazon.AWSCLI -e
    winget install --id Hashicorp.Terraform -e
    winget install --id Docker.DockerDesktop -e
    winget install --id Kubernetes.kubectl -e
    winget install --id Kubernetes.minikube -e
    wsl --install -d Ubuntu          # ← для Ansible (глава 13)

    winget upgrade --all             # ← обновить всё установленное через winget
    ```

=== "macOS"

    ```bash
    brew install git awscli kubectl minikube ansible
    brew tap hashicorp/tap && brew install hashicorp/tap/terraform
    brew install --cask visual-studio-code docker

    brew upgrade                     # ← обновить всё
    ```

=== "Linux (Ubuntu)"

    ```bash
    sudo apt update && sudo apt install -y git unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
    unzip awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
    # Terraform, Docker, kubectl, minikube — по ссылкам из раздела «Почитать»
    sudo usermod -aG docker $USER    # ← docker без sudo (перелогиниться)
    ```

## Проверить версии

```bash
git --version              # → git version 2.4x
aws --version              # → aws-cli/2.x.x        ← должна быть v2
terraform -version         # → Terraform v1.1x.x    ← не ниже 1.11
docker --version           # → Docker version 2x.x.x
docker run hello-world     # → Hello from Docker!
kubectl version --client   # → Client Version: v1.3x.x
minikube version           # → minikube version: v1.3x.x
```

## Git

```bash
git config --global user.name "Ваше Имя"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global --list                    # ← проверить

git clone https://github.com/<your-github-user>/devops-handbook.git
cd devops-handbook
git status                                    # ← перед каждым коммитом: нет ли секретов
```

## AWS Console — чек-лист

| Действие | Где |
|----------|-----|
| MFA для root | Имя аккаунта (справа сверху) → Security credentials → Assign MFA device |
| Регион `us-west-2` | Переключатель региона справа сверху |
| Бюджет $10 | Billing and Cost Management → Budgets → Create budget → Monthly cost budget |
| Бюджет $0 (опционально) | Budgets → Create budget → Zero spend budget |
| Все EC2 во всех регионах | EC2 → EC2 Global View |

## ✅ Самопроверка

- [ ] Все команды из «Проверить версии» отвечают, `aws --version` показывает `aws-cli/2`.
- [ ] `docker run hello-world` печатает `Hello from Docker!`.
- [ ] Вход root в консоль AWS запрашивает код MFA.
- [ ] Бюджет `monthly-10usd` есть в списке Budgets.
- [ ] У root **нет** access keys (Security credentials → Access keys → пусто).

## Почитать

| Тема | Ссылка |
|------|--------|
| AWS Free Tier | [aws.amazon.com/free](https://aws.amazon.com/free/) |
| AWS CLI — установка | [docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Защита root user | [docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html) |
| AWS Budgets | [docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) |
| Terraform — установка | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| Docker — установка | [docs.docker.com/get-started/get-docker](https://docs.docker.com/get-started/get-docker/) |
| kubectl — установка | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| minikube | [minikube.sigs.k8s.io/docs/start](https://minikube.sigs.k8s.io/docs/start/) |
| Ansible — установка | [docs.ansible.com/ansible/latest/installation_guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html) |
| WSL | [learn.microsoft.com/windows/wsl/install](https://learn.microsoft.com/windows/wsl/install) |
