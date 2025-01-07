FROM gitlab/gitlab-runner:latest
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY config.toml /etc/gitlab-runner/config.toml
RUN chmod 644 /etc/gitlab-runner/config.toml
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]