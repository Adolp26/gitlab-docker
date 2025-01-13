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
  sudo chown -R 1000:1000 gitlab/
  sudo chmod -R 755 gitlab/

  # Baixa imagens customizadas
  docker pull "$DOCKER_USER/gitlab-custom:latest"

  # Cria docker-compose.yml com mapeamentos de volume
  cat >docker-compose.yml <<EOL
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
    networks:
      - gitlab-network
    privileged: true 
  gitlab-runner:
    image: 'gitlab/gitlab-runner:latest'
    container_name: gitlab-runner
    restart: always
    volumes:
      - './gitlab-runner/config:/etc/gitlab-runner'  # Configuração do GitLab Runner
      - '/var/run/docker.sock:/var/run/docker.sock' # Necessário para o Docker executar dentro do Runner
    networks:
      - gitlab-network
    privileged: true  # Necessário para rodar o Docker dentro do container
networks:
  gitlab-network:
    name: gitlab-network
EOL

  # Inicia apenas o GitLab
  echo "Iniciando o GitLab..."
  docker compose up -d gitlab

  # Aguarda até o GitLab estar pronto
  echo "Aguardando o GitLab iniciar..."
  if [ "$(curl -s -o /dev/null -w "%{http_code}" http://"$GITLAB_HOST"/-/health)" -ne 200 ]; then
    echo "GitLab ainda não está pronto. Verifique novamente mais tarde."
    exit 1
  fi

  echo "O GitLab está pronto!"
  echo "Senha inicial do root:"
  sudo cat gitlab/config/initial_root_password || echo "Arquivo de senha não encontrado."
  echo -e "\nPróximos passos:"
  echo "1. Acesse http://$GITLAB_HOST"
  echo "2. Faça login como root com a senha acima"
  echo "3. Vá em Admin Area > CI/CD > Runners e copie o token de registro"
  echo "4. Descomente a seção do gitlab-runner no docker-compose.yml"
  echo "5. Execute: docker compose up -d gitlab-runner"
  echo "6. Execute: docker compose exec gitlab-runner gitlab-runner register"
}

# Verifica permissões do Docker
check_docker_permissions() {
  if ! docker ps >/dev/null 2>&1; then
    echo "O usuário atual não tem permissão para acessar o Docker. Tentando corrigir..."
    sudo usermod -aG docker "$(whoami)"
    echo "Reinicie sua sessão e execute o script novamente."
    exit 1
  fi
}

# Executa verificações e a função principal
check_docker_permissions
init_gitlab
