# Altere estas linhas com seu IP ou domínio
external_url 'http://SEU_IP_OU_DOMINIO'
gitlab_rails['gitlab_shell_ssh_port'] = 2222

# Configurações de recursos
postgresql['shared_buffers'] = "256MB"
unicorn['worker_processes'] = 2
postgresql['max_worker_processes'] = 4

# Desabilita serviços não essenciais para economizar recursos
prometheus['enable'] = false
alertmanager['enable'] = false
grafana['enable'] = false