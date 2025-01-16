# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (sudo)"
    exit 1
fi

# Função para instalar o Docker
install_docker() {
    echo "Iniciando instalação do Docker..."
    
    # Atualiza o sistema
    apt update
    apt upgrade -y
    
    # Instala dependências
    apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
    
    # Adiciona chave oficial do Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Adiciona repositório do Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instala Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Adiciona usuário ao grupo docker
    usermod -aG docker $SUDO_USER
    
    echo "Docker instalado com sucesso!"
}

# Função para verificar instalação do Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker não encontrado. Instalando..."
        install_docker
    else
        echo "Docker já está instalado."
    fi
}

# Função principal
main() {
    echo "Iniciando setup do ambiente..."
    
    # Verifica e instala Docker se necessário
    check_docker
    
    echo -e "\nSetup completo! Para finalizar:"
    echo "1. Faça logout e login novamente para que as mudanças do grupo docker tenham efeito"
    echo "2. Execute 'docker login' para conectar ao Docker Hub"
    echo "3. Configure as variáveis de ambiente:"
    echo "   export DOCKER_USER=seu-usuario-dockerhub"
    echo "   export GITLAB_HOST=seu-ip-ou-dominio"
    echo "4. Execute o script de inicialização do GitLab:"
    echo "   ./init-gitlab.sh"
}

# Executa função principal
main