#!/bin/bash

# Configurações
BACKUP_RETENTION_DAYS=7
BACKUP_DIR="/backup/gitlab"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Criar diretórios, se não existirem
mkdir -p "${BACKUP_DIR}/config"
mkdir -p "${BACKUP_DIR}/data"
mkdir -p "${BACKUP_DIR}/logs"
mkdir -p "${BACKUP_DIR}/runner"

# Fazer backup do GitLab
echo "Iniciando backup do GitLab em ${TIMESTAMP}..."
tar -czf "${BACKUP_DIR}/gitlab_data_${TIMESTAMP}.tar.gz" -C /path/to/gitlab/data .
tar -czf "${BACKUP_DIR}/gitlab_config_${TIMESTAMP}.tar.gz" -C /path/to/gitlab/config .
tar -czf "${BACKUP_DIR}/gitlab_logs_${TIMESTAMP}.tar.gz" -C /path/to/gitlab/logs .
tar -czf "${BACKUP_DIR}/gitlab_runner_${TIMESTAMP}.tar.gz" -C /path/to/gitlab/gitlab-runner .

# Criar manifesto
echo "GitLab Backup - ${TIMESTAMP}" > "${BACKUP_DIR}/manifest_${TIMESTAMP}.txt"
echo "Configuration: gitlab_config_${TIMESTAMP}.tar.gz" >> "${BACKUP_DIR}/manifest_${TIMESTAMP}.txt"
echo "Data: gitlab_data_${TIMESTAMP}.tar.gz" >> "${BACKUP_DIR}/manifest_${TIMESTAMP}.txt"
echo "Logs: gitlab_logs_${TIMESTAMP}.tar.gz" >> "${BACKUP_DIR}/manifest_${TIMESTAMP}.txt"
echo "Runner: gitlab_runner_${TIMESTAMP}.tar.gz" >> "${BACKUP_DIR}/manifest_${TIMESTAMP}.txt"

echo "Backup concluído!"

# Remover backups antigos
echo "Removendo backups com mais de ${BACKUP_RETENTION_DAYS} dias..."
find $BACKUP_DIR -type f -mtime +$BACKUP_RETENTION_DAYS -delete
echo "Limpeza concluída!"
