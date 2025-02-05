GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m" # No Color

BACKUP_DIR="./backup"

listar_backups() {
    local tipo=$1
    local backup_path="${BACKUP_DIR}/${tipo}"

    echo -e "\n${YELLOW}Backups disponíveis para ${tipo}:${NC}"
    
    # Listar arquivos e extrair timestamps únicos
    ls "${backup_path}"/*.tar.gz 2>/dev/null | grep -oP '\d{8}_\d{6}' | sort -u

    if [ $? -ne 0 ]; then
        echo -e "${RED}Nenhum backup encontrado!${NC}"
        return 1
    fi
}

# Função para restaurar o GitLab
restore_gitlab() {
    local backup_path="${BACKUP_DIR}/gitlab"

    listar_backups "gitlab"
    read -rp "Digite o timestamp do backup do GitLab: " timestamp

    if [ -z "$timestamp" ]; then
        echo -e "${RED}Erro: Nenhum timestamp fornecido.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Restaurando backup do GitLab...${NC}"

    docker compose down

    for type in "data" "config" "logs"; do
        if [ -f "${backup_path}/gitlab_${type}_${timestamp}.tar.gz" ]; then
            tar -xzf "${backup_path}/gitlab_${type}_${timestamp}.tar.gz" -C "gitlab/${type}"
            echo -e "${GREEN}Restaurado ${type}.${NC}"
        else
            echo -e "${RED}Backup ${type} não encontrado!${NC}"
        fi
    done

    docker compose up -d

    echo -e "${GREEN}Restauração do GitLab concluída!${NC}"
}

restore_gitlab_runner() {
    local backup_path="${BACKUP_DIR}/gitlab-runner"

    # Listar backups disponíveis
    listar_backups "gitlab-runner"
    read -rp "Digite o timestamp do backup do GitLab Runner: " timestamp

    # Verificar se o timestamp foi fornecido
    if [ -z "$timestamp" ]; then
        echo -e "${RED}Erro: Nenhum timestamp fornecido.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Restaurando backup do GitLab Runner...${NC}"

    if [ -f "${backup_path}/gitlab_runner_${timestamp}.tar.gz" ]; then
        tar -xzf "${backup_path}/gitlab_runner_${timestamp}.tar.gz" -C "gitlab-runner/config"
        echo -e "${GREEN}GitLab Runner restaurado com sucesso!${NC}"
    else
        echo -e "${RED}Backup do Runner não encontrado!${NC}"
    fi
}

# Menu do script
show_menu() {
    echo -e "\n${YELLOW}=== Restauração de Backup ===${NC}"
    echo "1. Restaurar GitLab"
    echo "2. Restaurar GitLab Runner"
    echo "0. Sair"

    read -rp "Escolha uma opção: " choice

    case $choice in
    1)
        restore_gitlab
        ;;
    2)
        restore_gitlab_runner
        ;;
    0)
        echo "Saindo..."
        exit 0
        ;;
    *)
        echo -e "${RED}Opção inválida!${NC}"
        ;;
    esac
}

show_menu
