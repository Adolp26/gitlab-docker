init_gitlab() {
    # Cria diretórios necessários
    mkdir -p gitlab/{config,logs,data,gitlab-runner}
    
    # Baixa imagens customizadas
    docker pull $DOCKER_USER/gitlab-custom:latest
    docker pull $DOCKER_USER/gitlab-runner-custom:latest
    
    # Cria docker-compose.yml com mapeamentos de volume
    cat > docker-compose.yml << EOL
version: '3.7'

services:
  gitlab:
    image: '$DOCKER_USER/gitlab-custom:latest'
    container_name: gitlab
    restart: always
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - './gitlab/config:/etc/gitlab'
      - './gitlab/logs:/var/log/gitlab'
      - './gitlab/data:/var/opt/gitlab'
    shm_size: '256m'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://\${GITLAB_HOST}'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        postgresql['shared_buffers'] = "256MB"
        unicorn['worker_processes'] = 2
        postgresql['max_worker_processes'] = 4
        prometheus['enable'] = false
        alertmanager['enable'] = false
        grafana['enable'] = false
    networks:
      - gitlab-network

  gitlab-runner:
    image: '$DOCKER_USER/gitlab-runner-custom:latest'
    container_name: gitlab-runner
    restart: always
    volumes:
      - './gitlab/gitlab-runner:/etc/gitlab-runner'
      - '/var/run/docker.sock:/var/run/docker.sock'
    networks:
      - gitlab-network
    depends_on:
      - gitlab

networks:
  gitlab-network:
    name: gitlab-network
EOL

    # Inicia serviços
    docker compose up -d
    
    # Aguarda at  o GitLab estar pronto
    echo "Aguardando o GitLab iniciar..."
    until curl -s http://localhost/-/health > /dev/null; do
        sleep 10
    done
    
    echo "O GitLab está pronto!"
}
