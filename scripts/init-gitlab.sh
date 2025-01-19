# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para configurar variáveis de ambiente
set_environment_variables() {
    echo -e "${GREEN}Configuração inicial - Por favor, insira os valores obrigatórios:${NC}"
    
    # Solicitar GITLAB_HOST
    while [ -z "$GITLAB_HOST" ]; do
        read -p "Insira o host do GitLab (exemplo: gitlab.meudominio.com): " GITLAB_HOST
    done
    export GITLAB_HOST

    # Solicitar DOCKER_USER
    while [ "$INSTALLATION_TYPE" = "docker" ] && [ -z "$DOCKER_USER" ]; do
        read -p "Insira o nome de usuário do Docker Hub: " DOCKER_USER
    done
    export DOCKER_USER

    echo -e "${GREEN}As variáveis de ambiente foram configuradas com sucesso!${NC}"
}

# Verificar se variáveis obrigatórias estão definidas
if [ -z "$GITLAB_HOST" ] || ([ "$INSTALLATION_TYPE" = "docker" ] && [ -z "$DOCKER_USER" ]); then
    set_environment_variables
fi

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

    mkdir -p gitlab/{config,logs,data,backups}
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
        gitlab_rails['backup_keep_time'] = 604800
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
    networks:
      - gitlab-network

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

    mkdir -p gitlab-runner/config
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
EOL
}

# Função para verificar requisitos do sistema
check_system_requirements() {
    echo "Verificando requisitos do sistema..."
    
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 4 ]; then
        echo -e "${RED}Atenção: GitLab requer no mínimo 4GB de RAM. Sistema tem ${total_mem}GB${NC}"
        return 1
    fi
    
    local free_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$free_space" -lt 20 ]; then
        echo -e "${RED}Atenção: É recomendado pelo menos 20GB de espaço livre. Disponível: ${free_space}GB${NC}"
        return 1
    fi
    
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
}

# Função para configurar o tipo de instalação
set_installation_type() {
    local valid_choice=0
    while [ $valid_choice -eq 0 ]; do
        echo "Escolha o tipo de instalação:"
        echo "1. Docker"
        echo "2. Local"
        read -rp "Digite sua escolha (1 ou 2): " choice
        
        case $choice in
            1)
                INSTALLATION_TYPE="docker"
                valid_choice=1
                ;;
            2)
                INSTALLATION_TYPE="local"
                valid_choice=1
                ;;
            *)
                echo -e "${RED}Escolha inválida! Por favor, digite 1 ou 2.${NC}"
                ;;
        esac
    done
    export INSTALLATION_TYPE
    echo -e "${GREEN}Tipo de instalação configurado como: $INSTALLATION_TYPE${NC}"
}

# Menu principal
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== GitLab Setup Menu ===${NC}"
        echo -e "${GREEN}Configuração atual:${NC}"
        echo "INSTALLATION_TYPE=${INSTALLATION_TYPE:-não configurado}"
        echo "GITLAB_HOST=${GITLAB_HOST:-não configurado}"
        [ "$INSTALLATION_TYPE" = "docker" ] && echo "DOCKER_USER=${DOCKER_USER:-não configurado}"
        
        echo -e "\n${YELLOW}Opções:${NC}"
        echo "1. Configurar tipo de instalação (Docker/Local)"
        echo "2. Configurar variáveis obrigatórias"
        echo "3. Verificar requisitos do sistema"
        echo "4. Preparar ambiente"
        echo "5. Fazer backup"
        echo "6. Restaurar backup"
        echo "0. Sair"

        read -rp "Escolha uma opção: " choice

        case $choice in
            1) set_installation_type ;;
            2) set_environment_variables ;;
            3) check_system_requirements ;;
            4)
                if check_required_vars; then
                    if [ "$INSTALLATION_TYPE" = "docker" ]; then
                        create_gitlab_compose
                        create_runner_compose
                        echo -e "${GREEN}Ambiente Docker preparado${NC}"
                    else
                        echo "Instalação local ainda não implementada"
                    fi
                fi
                ;;
            5) backup_gitlab ;;
            6) restore_gitlab ;;
            0) echo "Saindo..."; exit 0 ;;
            *) echo -e "${RED}Opção inválida${NC}" ;;
        esac
    done
}

# Iniciar menu
show_menu
