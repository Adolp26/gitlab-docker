# Verifica se foi fornecido um nome de usuário do Docker Hub
if [ -z "$1" ]
then
    echo "Por favor, forneça seu usuário do Docker Hub"
    echo "Uso: ./build-images.sh SEU_USUARIO_DOCKERHUB"
    exit 1
fi

DOCKER_USER=$1
VERSION=$(date +%Y%m%d_%H%M%S)

# Faz login no Docker Hub
echo "Fazendo login no Docker Hub..."
docker login

# Build e push do GitLab
echo "Buildando e publicando imagem do GitLab..."
cd gitlab
docker build -t $DOCKER_USER/gitlab-custom:$VERSION .
docker tag $DOCKER_USER/gitlab-custom:$VERSION $DOCKER_USER/gitlab-custom:latest
docker push $DOCKER_USER/gitlab-custom:$VERSION
docker push $DOCKER_USER/gitlab-custom:latest

# Build e push do Runner
echo "Buildando e publicando imagem do Runner..."
cd ../runner
docker build -t $DOCKER_USER/gitlab-runner-custom:$VERSION .
docker tag $DOCKER_USER/gitlab-runner-custom:$VERSION $DOCKER_USER/gitlab-runner-custom:latest
docker push $DOCKER_USER/gitlab-runner-custom:$VERSION
docker push $DOCKER_USER/gitlab-runner-custom:latest

echo "Imagens publicadas com sucesso!"
echo "Tags criadas: $VERSION e latest"