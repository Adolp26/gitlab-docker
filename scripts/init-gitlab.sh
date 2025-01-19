#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para criar diretórios com permissões corretas
setup_directories() {
    echo "Criando diretórios..."

    # 1. Criar diretórios principais
    mkdir -p gitlab/{config,logs,data}
    mkdir -p gitlab-runner/config

    # 2. Criar o arquivo config.toml antes de mudar as permissões
    if [ ! -f "gitlab-runner/config/config.toml" ]; then
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
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 256
EOL
    fi

    # 3. Ajustar permissões dos diretórios e arquivos
    echo "Ajustando permissões..."
    sudo chown -R 1000:1000 gitlab gitlab-runner
    sudo chmod -R 755 gitlab gitlab-runner
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
    if [ ! -f "docker-compose.gitlab.yml" ]; then
        cat >docker-compose.gitlab.yml <<EOL
services:
  gitlab:
    image: gitlab/gitlab-ee:latest
    container_name: gitlab
    restart: always
    hostname: \${GITLAB_HOST}
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        # Configuração de URL e porta SSH
        external_url 'http://\${GITLAB_HOST}'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222

        # Configurações de recursos
        postgresql['shared_buffers'] = "128MB"
        unicorn['worker_processes'] = 1
        postgresql['max_worker_processes'] = 2

        # Desabilitar serviços não essenciais
        prometheus['enable'] = false
        alertmanager['enable'] = false
        grafana['enable'] = false
        gitlab_rails['monitoring_enabled'] = false
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - './gitlab/config:/etc/gitlab'
      - './gitlab/logs:/var/log/gitlab'
      - './gitlab/data:/var/opt/gitlab'
    shm_size: '256m'
    networks:
      - gitlab-network

networks:
  gitlab-network:
    name: gitlab-network
EOL
    fi
}

# Função para criar docker-compose do Runner
create_runner_compose() {
    if [ ! -f "docker-compose.runner.yml" ]; then
        cat >docker-compose.runner.yml <<EOL
services:
  gitlab-runner:
    image: 'gitlab/gitlab-runner:latest'
    container_name: gitlab-runner
    restart: always
    volumes:
      - './gitlab-runner/config:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - gitlab-network
    privileged: false  # Modificado para reduzir consumo de recursos

networks:
  gitlab-network:
    external: true
EOL
    fi
}

# Função para verificar permissões do Docker
check_docker_permissions() {
    if ! docker ps >/dev/null 2>&1; then
        echo -e "${RED}O usuário atual não tem permissão para acessar o Docker. Tentando corrigir...${NC}"
        sudo usermod -aG docker "$(whoami)"
        echo "Reinicie sua sessão e execute o script novamente."
        exit 1
    fi
}

# Função para configurar GITLAB_HOST
set_gitlab_host() {
    read -rp "Digite o hostname ou IP do GitLab: " gitlab_host
    export GITLAB_HOST="$gitlab_host"
    echo "export GITLAB_HOST=$gitlab_host" >>~/.bashrc
    echo -e "${GREEN}GITLAB_HOST configurado como: $gitlab_host${NC}"
}

# Função para configurar DOCKER_USER
set_docker_user() {
    read -rp "Digite seu usuário do DockerHub: " docker_user
    export DOCKER_USER="$docker_user"
    echo "export DOCKER_USER=$docker_user" >>~/.bashrc
    echo -e "${GREEN}DOCKER_USER configurado como: $docker_user${NC}"
}

# Função para atualizar token do runner
update_runner_token() {
    read -rp "Digite o token do runner: " runner_token
    if [ -f "gitlab-runner/config/config.toml" ]; then
        sudo sed -i "s/__RUNNER_TOKEN__/$runner_token/" gitlab-runner/config/config.toml
        echo -e "${GREEN}Token do runner atualizado com sucesso${NC}"
    else
        echo -e "${RED}Arquivo config.toml não encontrado${NC}"
    fi
}

# Função para iniciar GitLab
start_gitlab() {
    if [ -z "$DOCKER_USER" ] || [ -z "$GITLAB_HOST" ]; then
        echo -e "${RED}Variáveis de ambiente não configuradas. Configure-as primeiro.${NC}"
        return 1
    fi

    echo "Iniciando GitLab..."
    docker compose -f docker-compose.gitlab.yml up -d

    echo "Verifique a URL do GITLAB em http://$GITLAB_HOST"
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
        sudo cat gitlab/config/initial_root_password
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
        0) exit 0 ;;
        *) echo -e "${RED}Opção inválida. Tente novamente.${NC}" ;;
        esac
    done
}

# Verificar permissões do Docker antes de prosseguir
check_docker_permissions

# Mostrar menu
show_menu
