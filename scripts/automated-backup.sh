#Para agendamento via cron
BACKUP_RETENTION_DAYS=7
BACKUP_DIR="/backup/gitlab"

# Executa backup
./backup_gitlab.sh

# Remove backups antigos
find $BACKUP_DIR -type f -mtime +$BACKUP_RETENTION_DAYS -delete