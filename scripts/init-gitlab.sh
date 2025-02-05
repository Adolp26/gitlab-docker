# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para verificar dependências
check_dependencies() {
    echo "Verificando dependências..."

    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker não está instalado. Por favor, instale o Docker antes de continuar.${NC}"
        exit 1
    fi

    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        echo -e "${RED}Docker Compose não está instalado. Por favor, instale o Docker Compose antes de continuar.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Todas dependências verificadas com sucesso.${NC}"
}

# Função para criar diretórios com permissões corretas
setup_directories() {
    echo "Criando diretórios..."

    # 1. Criar diretórios principais
    mkdir -p gitlab/{config,logs,data}
    mkdir -p gitlab-runner/config

    # 2. Criar o arquivo config.toml antes de mudar as permissões
    echo "Criando arquivo config.toml..."
    cat >gitlab-runner/config/config.toml <<'EOL'
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "http://gitlab"
  token = "__RUNNER_TOKEN__"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "ubuntu:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 256
EOL

    # 3. Ajustar permissões dos diretórios e arquivos
    echo "Ajustando permissões..."
    sudo chown -R 1000:1000 gitlab/
    sudo chmod -R 755 gitlab/

    sudo chown -R 998:998 gitlab-runner/
    sudo chmod -R 755 gitlab-runner/
    sudo chmod 644 gitlab-runner/config/config.toml

    # 4. Verificar se tudo foi criado corretamente
    echo "Verificando criação dos arquivos..."
    if [ -f "gitlab-runner/config/config.toml" ]; then
        echo -e "${GREEN}Arquivo config.toml criado com sucesso${NC}"
        echo -e "${YELLOW}Permissões do arquivo:${NC}"
        ls -l gitlab-runner/config/config.toml
    else
        echo -e "${RED}Erro ao criar arquivo config.toml${NC}"
    fi
}

# Função para criar docker-compose do GitLab
create_gitlab_compose() {
    cat >docker-compose.gitlab.yml <<EOL
version: '3.6'

services:
  gitlab:
    image: gitlab/gitlab-ee:latest
    container_name: gitlab
    restart: always
    hostname: ${GITLAB_HOST}
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://${GITLAB_HOST}'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        puma['worker_processes'] = 1
        puma['min_threads'] = 2
        puma['max_threads'] = 4
        postgresql['shared_buffers'] = "128MB"
        postgresql['max_worker_processes'] = 2
        sidekiq['concurrency'] = 5
        prometheus_monitoring['enable'] = false
        alertmanager['enable'] = false
        node_exporter['enable'] = false
        redis_exporter['enable'] = false
        postgres_exporter['enable'] = false
        gitlab_exporter['enable'] = false
        mattermost['enable'] = false
        registry['enable'] = false
        gitlab_kas['enable'] = false
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - './gitlab/config:/etc/gitlab'
      - './gitlab/logs:/var/log/gitlab'
      - './gitlab/data:/var/opt/gitlab'
    shm_size: '128m'
    ulimits:
      nproc: 65535
      nofile:
        soft: 65535
        hard: 65535
    read_only: false
    networks:
      - gitlab-network

networks:
  gitlab-network:
    name: gitlab-network
EOL
}

# Função para criar docker-compose do Runner
create_runner_compose() {
    cat >docker-compose.runner.yml <<EOL
version: '3.6'

services:
  gitlab-runner:
    image: 'gitlab/gitlab-runner:latest'
    container_name: gitlab-runner
    restart: always
    privileged: true  # Necessário para Docker-in-Docker
    volumes:
      - './gitlab-runner/config:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - gitlab-network

networks:
  gitlab-network:
    external: true
EOL
}

# Função para configurar GITLAB_HOST
set_gitlab_host() {
    while true; do
        read -rp "Digite o hostname ou IP do GitLab: " gitlab_host
        if [[ -n "$gitlab_host" ]]; then
            export GITLAB_HOST="$gitlab_host"
            echo "export GITLAB_HOST=$gitlab_host" >>~/.bashrc
            echo -e "${GREEN}GITLAB_HOST configurado como: $gitlab_host${NC}"
            break
        else
            echo -e "${RED}Hostname ou IP não pode ser vazio. Tente novamente.${NC}"
        fi
    done
}

# Função para configurar DOCKER_USER
set_docker_user() {
    while true; do
        read -rp "Digite seu usuário do DockerHub: " docker_user
        if [[ -n "$docker_user" ]]; then
            export DOCKER_USER="$docker_user"
            echo "export DOCKER_USER=$docker_user" >>~/.bashrc
            echo -e "${GREEN}DOCKER_USER configurado como: $docker_user${NC}"
            break
        else
            echo -e "${RED}Usuário do DockerHub não pode ser vazio. Tente novamente.${NC}"
        fi
    done
}

# Função para atualizar token do runner
update_runner_token() {
    while true; do
        read -rp "Digite o token do runner: " runner_token
        if [[ -n "$runner_token" ]]; then
            if [ -f "gitlab-runner/config/config.toml" ]; then
                sed -i "s/__RUNNER_TOKEN__/$runner_token/" gitlab-runner/config/config.toml
                echo -e "${GREEN}Token do runner atualizado com sucesso${NC}"
                break
            else
                echo -e "${RED}Arquivo config.toml não encontrado${NC}"
                break
            fi
        else
            echo -e "${RED}Token não pode ser vazio. Tente novamente.${NC}"
        fi
    done
}

# Função para iniciar GitLab
start_gitlab() {
    if [ -z "$GITLAB_HOST" ]; then
        echo -e "${RED}GITLAB_HOST não configurado. Configure-o primeiro.${NC}"
        return 1
    fi

    echo "Iniciando GitLab..."
    docker compose -f docker-compose.gitlab.yml up -d
    echo "Verifique a URL do GitLab em http://$GITLAB_HOST"
}

# Função para iniciar Runner
start_runner() {
    if [ ! -f "docker-compose.runner.yml" ]; then
        echo -e "${RED}Arquivo docker-compose.runner.yml não encontrado${NC}"
        return 1
    fi

    echo "Iniciando GitLab Runner..."
    docker compose -f docker-compose.runner.yml up -d
    echo -e "${GREEN}GitLab Runner iniciado${NC}"
}

# Função para mostrar senha do root
show_root_password() {
    if [ -f "gitlab/config/initial_root_password" ]; then
        echo -e "${YELLOW}Senha inicial do root:${NC}"
        cat gitlab/config/initial_root_password
    else
        echo -e "${RED}Arquivo de senha não encontrado.${NC}"
    fi
}

# Função para mostrar status dos serviços
show_status() {
    echo -e "${YELLOW}Status dos containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E 'gitlab|runner'
}

# Menu principal
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== GitLab Setup Menu ===${NC}"
        echo "1. Configurar GITLAB_HOST"
        echo "2. Configurar DOCKER_USER"
        echo "3. Criar diretórios e arquivos docker-compose"
        echo "4. Iniciar GitLab"
        echo "5. Iniciar GitLab Runner"
        echo "6. Mostrar senha do root"
        echo "7. Mostrar status dos serviços"
        echo "8. Registrar novo Runner"
        echo "9. Atualizar token do Runner"
        echo "0. Sair"

        read -rp "Escolha uma opção: " choice

        case $choice in
        1) set_gitlab_host ;;
        2) set_docker_user ;;
        3)
            setup_directories
            create_gitlab_compose
            create_runner_compose
            echo -e "${GREEN}Diretórios e arquivos criados com sucesso${NC}"
            ;;
        4) start_gitlab ;;
        5) start_runner ;;
        6) show_root_password ;;
        7) show_status ;;
        8)
            echo "Para registrar um novo runner:"
            echo "1. Acesse http://$GITLAB_HOST"
            echo "2. Vá em Admin Area > CI/CD > Runners"
            echo "3. Copie o token de registro"
            echo "4. Execute: docker compose -f docker-compose.runner.yml exec gitlab-runner gitlab-runner register"
            ;;
        9) update_runner_token ;;
        0)
            echo "Saindo..."
            exit 0
            ;;
        *) echo -e "${RED}Opção inválida${NC}" ;;
        esac
    done
}

# Verifica dependências antes de começar
check_dependencies

# Inicia o menu
show_menu