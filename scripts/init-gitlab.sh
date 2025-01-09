# Verifica se as variáveis de ambiente necessárias estão definidas
if [ -z "$DOCKER_USER" ] || [ -z "$GITLAB_HOST" ]; then
  echo "Por favor, defina as variáveis de ambiente necessárias:"
  echo "export DOCKER_USER=seu-usuario-dockerhub"
  echo "export GITLAB_HOST=seu-ip-ou-dominio"
  exit 1
fi

init_gitlab() {
  # Cria diretórios necessários
  mkdir -p gitlab/{config,logs,data,gitlab-runner}

  # Baixa imagens customizadas
  docker pull $DOCKER_USER/gitlab-custom:latest
  # docker pull $DOCKER_USER/gitlab-runner-custom:latest

  # Cria docker-compose.yml com mapeamentos de volume
  cat >docker-compose.yml <<EOL
version: '3.8'
services:
  gitlab:
    image: '\${DOCKER_USER}/gitlab-custom:latest'
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
        gitlab_rails['initial_root_password'] = 'password123'
    networks:
      - gitlab-network

  # Runner comentado inicialmente para primeira execução
  #gitlab-runner:
  #  image: '$DOCKER_USER/gitlab-runner-custom:latest'
  #  container_name: gitlab-runner
  #  restart: always
  #  volumes:
  #    - './gitlab/gitlab-runner:/etc/gitlab-runner'
  #    - '/var/run/docker.sock:/var/run/docker.sock'
  #  networks:
  #    - gitlab-network
  #  depends_on:
  #    - gitlab

networks:
  gitlab-network:
    name: gitlab-network
EOL

  # Inicia apenas o GitLab
  echo "Iniciando o GitLab..."
  docker compose up -d gitlab

  # Aguarda até o GitLab estar pronto
  echo "Aguardando o GitLab iniciar..."
  until curl -s http://$GITLAB_HOST/-/health >/dev/null; do
    echo "Ainda inicializando... (aguarde, isso pode levar alguns minutos)"
    sleep 30
  done

  echo "O GitLab está pronto!"
  echo "Senha inicial do root:"
  sudo cat gitlab/config/initial_root_password
  echo -e "\nPróximos passos:"
  echo "1. Acesse http://$GITLAB_HOST"
  echo "2. Faça login como root com a senha acima"
  echo "3. Vá em Admin Area > CI/CD > Runners e copie o token de registro"
  echo "4. Descomente a seção do gitlab-runner no docker-compose.yml"
  echo "5. Execute: docker compose up -d gitlab-runner"
  echo "6. Execute: docker compose exec gitlab-runner gitlab-runner register"
}

# Executa a função
init_gitlab
