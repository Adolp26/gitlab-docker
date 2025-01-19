# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para verificar variáveis obrigatórias
check_required_vars() {
    local missing_vars=0
    
    if [ -z "$GITLAB_HOST" ]; then
        echo -e "${RED}GITLAB_HOST não está configurado${NC}"
        missing_vars=1
    fi
    
    if [ "$INSTALLATION_TYPE" = "docker" ] && [ -z "$DOCKER_USER" ]; then
        echo -e "${RED}DOCKER_USER não está configurado${NC}"
        missing_vars=1
    fi
    
    [ $missing_vars -eq 1 ] && return 1
    return 0
}

# Função para criar docker-compose do GitLab
create_gitlab_compose() {
    if [ "$INSTALLATION_TYPE" != "docker" ]; then
        return 0
    fi

    cat > docker-compose.gitlab.yml << EOL
version: '3.7'

services:
  gitlab:
    image: gitlab/gitlab-ee:latest
    container_name: gitlab
    hostname: ${GITLAB_HOST}
    restart: always
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://${GITLAB_HOST}'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['time_zone'] = 'America/Sao_Paulo'
        
        # Configurações de Email (ajuste conforme necessário)
        # gitlab_rails['smtp_enable'] = true
        # gitlab_rails['smtp_address'] = "smtp.server.com"
        # gitlab_rails['smtp_port'] = 587
        # gitlab_rails['smtp_user_name'] = "smtp_user"
        # gitlab_rails['smtp_password'] = "smtp_password"
        # gitlab_rails['smtp_domain'] = "example.com"
        # gitlab_rails['smtp_authentication'] = "login"
        # gitlab_rails['smtp_enable_starttls_auto'] = true
        # gitlab_rails['gitlab_email_from'] = 'gitlab@example.com'
        
        # Configurações de Backup
        gitlab_rails['backup_keep_time'] = 604800
        
        # Otimizações de Recursos
        postgresql['shared_buffers'] = "256MB"
        postgresql['max_worker_processes'] = 4
        postgresql['work_mem'] = "16MB"
        postgresql['maintenance_work_mem'] = "64MB"
        
        # Cache e Sessions
        redis['maxmemory'] = "256mb"
        redis['maxmemory_policy'] = "allkeys-lru"
        redis['tcp_timeout'] = "60"
        
        # Workers e Processos
        unicorn['worker_processes'] = 2
        unicorn['worker_timeout'] = 60
        sidekiq['max_concurrency'] = 15
        gitaly['ruby_num_workers'] = 2
        gitlab_workhorse['max_connections'] = 500
        
        # Configurações do Nginx
        nginx['worker_processes'] = 2
        nginx['worker_connections'] = 2048
        nginx['keepalive_timeout'] = 65
        nginx['gzip_enabled'] = true
        
        # Desabilitar serviços não essenciais
        prometheus['enable'] = false
        alertmanager['enable'] = false
        grafana['enable'] = false
        gitlab_monitor['enable'] = false
        postgresql['enable_pgbouncer'] = false
        
        # Configurações de Armazenamento
        git_data_dirs({ "default" => { "path" => "/var/opt/gitlab/git-data" } })
        gitlab_rails['uploads_directory'] = "/var/opt/gitlab/gitlab-rails/uploads"
        gitlab_rails['shared_path'] = "/var/opt/gitlab/gitlab-rails/shared"
        
        # Limites e Timeouts
        gitlab_rails['artifacts_enabled'] = true
        gitlab_rails['artifacts_path'] = "/var/opt/gitlab/gitlab-rails/artifacts"
        gitlab_rails['lfs_enabled'] = true
        gitlab_rails['lfs_storage_path'] = "/var/opt/gitlab/gitlab-rails/lfs-objects"
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - './gitlab/config:/etc/gitlab'
      - './gitlab/logs:/var/log/gitlab'
      - './gitlab/data:/var/opt/gitlab'
      - './gitlab/backups:/var/opt/gitlab/backups'
    shm_size: '256m'
    ulimits:
      memlock:
        soft: 65536
        hard: 65536
      nofile:
        soft: 65536
        hard: 65536
    networks:
      - gitlab-network
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G

networks:
  gitlab-network:
    name: gitlab-network
    driver: bridge
EOL
}

# Função para criar docker-compose do Runner
create_runner_compose() {
    if [ "$INSTALLATION_TYPE" != "docker" ]; then
        return 0
    fi

    cat > docker-compose.runner.yml << EOL
version: '3.7'

services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    restart: always
    environment:
      - RUNNER_EXECUTOR=docker
      - DOCKER_IMAGE=ubuntu:latest
      - DOCKER_PULL_POLICY=if-not-present
      - DOCKER_VOLUMES=/var/run/docker.sock:/var/run/docker.sock
    volumes:
      - './gitlab-runner/config:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
      - '/cache:/cache'
    networks:
      - gitlab-network
    extra_hosts:
      - "gitlab:${GITLAB_HOST}"
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

networks:
  gitlab-network:
    external: true
EOL

    # Criar configuração do runner
    mkdir -p gitlab-runner/config
    cat > gitlab-runner/config/config.toml << EOL
concurrent = 4
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "http://${GITLAB_HOST}"
  token = "__RUNNER_TOKEN__"
  executor = "docker"
  [runners.cache]
    Type = "s3"
    Shared = true
  [runners.docker]
    tls_verify = false
    image = "ubuntu:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    memory = "1g"
    memory_swap = "2g"
    memory_reservation = "512m"
    cpus = "1.5"
    allowed_images = ["ruby:*", "python:*", "node:*", "php:*", "golang:*"]
EOL
}

# Função para verificar requisitos do sistema
check_system_requirements() {
    echo "Verificando requisitos do sistema..."
    
    # Verificar memória disponível
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 4 ]; then
        echo -e "${RED}Atenção: GitLab requer no mínimo 4GB de RAM. Sistema tem ${total_mem}GB${NC}"
        return 1
    fi
    
    # Verificar espaço em disco
    local free_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt 20 ]; then
        echo -e "${RED}Atenção: É recomendado pelo menos 20GB de espaço livre. Disponível: ${free_space}GB${NC}"
        return 1
    fi
    
    # Verificar Docker se necessário
    if [ "$INSTALLATION_TYPE" = "docker" ]; then
        if ! command -v docker >/dev/null 2>&1; then
            echo -e "${RED}Docker não está instalado${NC}"
            return 1
        fi
        
        if ! docker info >/dev/null 2>&1; then
            echo -e "${RED}Docker daemon não está rodando ou usuário não tem permissão${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}Todos os requisitos do sistema atendidos${NC}"
    return 0
}

# Função para backup (Docker)
backup_gitlab() {
    if [ "$INSTALLATION_TYPE" = "docker" ]; then
        echo "Iniciando backup do GitLab..."
        docker compose -f docker-compose.gitlab.yml exec gitlab gitlab-backup create
        echo "Backup concluído. Arquivos em ./gitlab/backups/"
    else
        echo "Executando backup local..."
        sudo gitlab-rake gitlab:backup:create
    fi
}

# Função para restaurar backup (Docker)
restore_gitlab() {
    if [ "$INSTALLATION_TYPE" = "docker" ]; then
        echo "Listando backups disponíveis:"
        ls -l ./gitlab/backups/
        
        read -rp "Digite o nome do arquivo de backup para restaurar: " backup_file
        
        if [ -f "./gitlab/backups/$backup_file" ]; then
            echo "Restaurando backup..."
            docker compose -f docker-compose.gitlab.yml exec gitlab gitlab-backup restore BACKUP=$backup_file
            echo "Restauração concluída"
        else
            echo -e "${RED}Arquivo de backup não encontrado${NC}"
        fi
    else
        echo "Para restaurar backup local, use: sudo gitlab-rake gitlab:backup:restore"
    fi
}

[... resto do código continua o mesmo ...]

# Menu principal atualizado
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== GitLab Setup Menu ===${NC}"
        echo -e "${GREEN}Configuração atual:${NC}"
        echo "INSTALLATION_TYPE=${INSTALLATION_TYPE:-não configurado}"
        echo "GITLAB_HOST=${GITLAB_HOST:-não configurado}"
        [ "$INSTALLATION_TYPE" = "docker" ] && echo "DOCKER_USER=${DOCKER_USER:-não configurado}"
        
        echo -e "\n${YELLOW}Opções:${NC}"
        echo "1. Configurar tipo de instalação (Docker/Local)"
        echo "2. Configurar GITLAB_HOST"
        echo "3. Configurar DOCKER_USER (apenas para Docker)"
        echo "4. Verificar requisitos do sistema"
        echo "5. Preparar ambiente"
        echo "6. Iniciar GitLab"
        echo "7. Iniciar GitLab Runner"
        echo "8. Mostrar senha do root"
        echo "9. Mostrar status"
        echo "10. Registrar novo Runner"
        echo "11. Fazer backup"
        echo "12. Restaurar backup"
        echo "0. Sair"

        read -rp "Escolha uma opção: " choice

        case $choice in
            1) set_installation_type ;;
            2) set_gitlab_host ;;
            3) set_docker_user ;;
            4) check_system_requirements ;;
            5)
                if check_required_vars; then
                    if [ "$INSTALLATION_TYPE" = "docker" ]; then
                        setup_directories
                        create_gitlab_compose
                        create_runner_compose
                        echo -e "${GREEN}Ambiente Docker preparado${NC}"
                    else
                        install_gitlab_local
                        install_runner_local
                        echo -e "${GREEN}Instalação local concluída${NC}"
                    fi
                fi
                ;;
            6) start_gitlab ;;
            7) start_runner ;;
            8) show_root_password ;;
            9)
                if [ "$INSTALLATION_TYPE" = "docker" ]; then
                    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E 'gitlab|runner'
                else
                    sudo gitlab-ctl status
                    sudo gitlab-runner status
                fi
                ;;
            10)
                if [ "$INSTALLATION_TYPE" = "docker" ]; then
                    echo "Para registrar um novo runner:"
                    echo "1. Acesse http://$GITLAB_HOST"
                    echo "2. Vá em Admin Area > CI/CD > Runners"
                    echo "3. Copie o token de registro"
                    echo "4. Execute: docker compose -f docker-compose.runner.yml exec gitlab-runner gitlab-runner register"
                else
                    echo "Para registrar um novo runner local:"
                    echo "1. Acesse http://$GITLAB_HOST"
                    echo "2. Vá em Admin Area > CI/CD > Runners"
                    echo "3. Copie o token de registro"
                    echo "4. Execute: sudo gitlab-runner register"
                fi
                ;;
            11) backup_gitlab ;;
            12) restore_gitlab ;;
            0)
                echo "Saindo..."
                exit 0
                ;;
            *) echo -e "${RED}Opção inválida${NC}" ;;
        esac
    done
}

# Início do script
show_menu