backup_gitlab() {
    local backup_dir="/backup/gitlab"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Criar diretórios de backup
    mkdir -p "${backup_dir}/config"
    mkdir -p "${backup_dir}/data"
    mkdir -p "${backup_dir}/logs"
    mkdir -p "${backup_dir}/runner"
    
    # Backup de dados do GitLab
    tar -czf "${backup_dir}/gitlab_data_${timestamp}.tar.gz" -C /path/to/gitlab/data .
    tar -czf "${backup_dir}/gitlab_config_${timestamp}.tar.gz" -C /path/to/gitlab/config .
    tar -czf "${backup_dir}/gitlab_logs_${timestamp}.tar.gz" -C /path/to/gitlab/logs .
    tar -czf "${backup_dir}/gitlab_runner_${timestamp}.tar.gz" -C /path/to/gitlab/gitlab-runner .
    
    # Criar o arquivo de manifesto
    echo "GitLab Backup - ${timestamp}" > "${backup_dir}/manifest_${timestamp}.txt"
    echo "Configuration: gitlab_config_${timestamp}.tar.gz" >> "${backup_dir}/manifest_${timestamp}.txt"
    echo "Data: gitlab_data_${timestamp}.tar.gz" >> "${backup_dir}/manifest_${timestamp}.txt"
    echo "Logs: gitlab_logs_${timestamp}.tar.gz" >> "${backup_dir}/manifest_${timestamp}.txt"
    echo "Runner: gitlab_runner_${timestamp}.tar.gz" >> "${backup_dir}/manifest_${timestamp}.txt"
}