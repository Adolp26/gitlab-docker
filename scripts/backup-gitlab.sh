GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m" # No Color

BACKUP_DIR="./backup"

mkdir -p "${BACKUP_DIR}/gitlab"
mkdir -p "${BACKUP_DIR}/gitlab-runner"

backup_gitlab() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/gitlab"

    echo -e "${YELLOW}Iniciando backup do GitLab...${NC}"

    # Verifica se os diretórios existem antes de compactar
    for dir in "gitlab/data" "gitlab/config" "gitlab/logs"; do
        if [ -d "$dir" ]; then
            tar -czf "${backup_path}/$(basename "$dir")_${timestamp}.tar.gz" -C "$dir" .
            echo -e "${GREEN}Backup de $(basename "$dir") concluído.${NC}"
        else
            echo -e "${RED}Diretório $dir não encontrado!${NC}"
        fi
    done

    # Criar arquivo de manifesto
    echo "GitLab Backup - ${timestamp}" > "${backup_path}/manifest_${timestamp}.txt"
    echo "Configuração: gitlab_config_${timestamp}.tar.gz" >> "${backup_path}/manifest_${timestamp}.txt"
    echo "Dados: gitlab_data_${timestamp}.tar.gz" >> "${backup_path}/manifest_${timestamp}.txt"
    echo "Logs: gitlab_logs_${timestamp}.tar.gz" >> "${backup_path}/manifest_${timestamp}.txt"

    echo -e "${GREEN}Backup do GitLab concluído! Arquivos salvos em ${backup_path}${NC}"
}

# Função para backup do GitLab Runner
backup_gitlab_runner() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/gitlab-runner"

    echo -e "${YELLOW}Iniciando backup do GitLab Runner...${NC}"

    if [ -d "gitlab-runner/config" ]; then
        tar -czf "${backup_path}/gitlab_runner_${timestamp}.tar.gz" -C "gitlab-runner/config" .
        echo -e "${GREEN}Backup do Runner concluído.${NC}"
    else
        echo -e "${RED}Diretório gitlab-runner/config não encontrado!${NC}"
    fi

    echo "GitLab Runner Backup - ${timestamp}" > "${backup_path}/manifest_${timestamp}.txt"
    echo "Runner: gitlab_runner_${timestamp}.tar.gz" >> "${backup_path}/manifest_${timestamp}.txt"

    echo -e "${GREEN}Backup do GitLab Runner concluído! Arquivos salvos em ${backup_path}${NC}"
}

# Menu do script
show_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Backup do GitLab ===${NC}"
        echo "1. Fazer backup do GitLab"
        echo "2. Fazer backup do GitLab Runner"
        echo "0. Sair"

        read -rp "Escolha uma opção: " choice

        case $choice in
        1) backup_gitlab ;;
        2) backup_gitlab_runner ;;
        0)
            echo "Saindo..."
            exit 0
            ;;
        *) echo -e "${RED}Opção inválida!${NC}" ;;
        esac
    done
}

# Iniciar menu
show_menu
