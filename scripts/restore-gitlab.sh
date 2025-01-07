restore_gitlab() {
    local backup_dir="/backup/gitlab"
    local timestamp=$1
    
    if [ -z "$timestamp" ]; then
        echo "Por favor, forneca o timestamp do backup"
        exit 1
    fi
    
    # Parar containers
    docker compose down
    
    # Restaurar dados
    tar -xzf "${backup_dir}/gitlab_data_${timestamp}.tar.gz" -C /path/to/gitlab/data
    tar -xzf "${backup_dir}/gitlab_config_${timestamp}.tar.gz" -C /path/to/gitlab/config
    tar -xzf "${backup_dir}/gitlab_logs_${timestamp}.tar.gz" -C /path/to/gitlab/logs
    tar -xzf "${backup_dir}/gitlab_runner_${timestamp}.tar.gz" -C /path/to/gitlab/gitlab-runner
    
    # Iniciar containers
    docker compose up -d
}