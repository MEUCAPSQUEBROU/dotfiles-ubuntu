#!/usr/bin/env bash
#
# dev.sh - ambiente de desenvolvimento para Ubuntu
# ----------------------------------------------------------------------------
# Instala e configura:
#   - git, curl, wget, htop, ferramentas básicas de build
#   - Docker Engine + Docker Desktop
#   - SDKMAN com Java 21 (Temurin) e Java 17 (Temurin)
#   - NVM com Node LTS, Node 20 e Node 22 (padrão = LTS)
#   - PostgreSQL
#   - pgAdmin e/ou DBeaver (menu, ou variável DB_CLIENT=pgadmin|dbeaver|ambos|nenhum)
#   - opencode
#   - VS Code
#   - IntelliJ IDEA Community
#
# Funciona em rede com proxy: os downloads via curl rodam com o proxy desligado
# só naquele trecho e depois a configuração original volta.
#
# NÃO rode com sudo. O script pede sudo quando precisa:  bash scripts/dev.sh
# ----------------------------------------------------------------------------
set -uo pipefail

# ============================================================================
# CONFIGURAÇÕES (ajuste aqui se algum link/versão ficar desatualizado)
# ============================================================================
NODE_VERSIONS=("20" "22")
JAVA_CANDIDATES=("21-tem" "17-tem")
JAVA_DEFAULT="21-tem"
IDEA_VERSION="${IDEA_VERSION:-2024.3.2}"
IDEA_URL="https://download.jetbrains.com/idea/ideaIC-${IDEA_VERSION}.tar.gz"
IDEA_INSTALL_DIR="/opt/idea"
DOCKER_DESKTOP_URL="${DOCKER_DESKTOP_URL:-https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb}"
LOG_FILE="$HOME/setup-ambiente-$(date +%Y%m%d-%H%M%S).log"

# ============================================================================
# CORES / LOG
# ============================================================================
COR_OK='\033[0;32m'; COR_INFO='\033[0;34m'; COR_WARN='\033[0;33m'
COR_ERR='\033[0;31m'; COR_TITULO='\033[1;36m'; NC='\033[0m'
log_info() { echo -e "${COR_INFO}[INFO]${NC} $*"  | tee -a "$LOG_FILE"; }
log_ok()   { echo -e "${COR_OK}[ OK ]${NC} $*"    | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${COR_WARN}[AVISO]${NC} $*" | tee -a "$LOG_FILE"; }
log_err()  { echo -e "${COR_ERR}[ERRO]${NC} $*"   | tee -a "$LOG_FILE"; }
titulo()   { echo -e "\n${COR_TITULO}==> $*${NC}" | tee -a "$LOG_FILE"; }

declare -A RESULTADO
marcar() { RESULTADO["$1"]="$2"; }

# ============================================================================
# CHECAGENS INICIAIS
# ============================================================================
if [[ $EUID -eq 0 ]]; then
  echo "Não execute este script como root/sudo. Rode como usuário normal: bash scripts/dev.sh"
  exit 1
fi
if ! command -v sudo &>/dev/null; then
  log_err "sudo não encontrado."
  exit 1
fi
log_info "Validando permissão de sudo (pode pedir senha agora)..."
sudo -v || { log_err "Sem permissão de sudo. Abortando."; exit 1; }
# mantém o sudo ativo durante todo o script
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )

# ============================================================================
# PROXY (desliga só durante os downloads e restaura depois)
# ============================================================================
_ORIG_HTTP_PROXY="${http_proxy:-}";   _ORIG_HTTPS_PROXY="${https_proxy:-}";   _ORIG_NO_PROXY="${no_proxy:-}"
_ORIG_HTTP_PROXY_U="${HTTP_PROXY:-}"; _ORIG_HTTPS_PROXY_U="${HTTPS_PROXY:-}"; _ORIG_NO_PROXY_U="${NO_PROXY:-}"

proxy_off() {
  unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY
}
proxy_on() {
  [[ -n "$_ORIG_HTTP_PROXY"    ]] && export http_proxy="$_ORIG_HTTP_PROXY"
  [[ -n "$_ORIG_HTTPS_PROXY"   ]] && export https_proxy="$_ORIG_HTTPS_PROXY"
  [[ -n "$_ORIG_NO_PROXY"      ]] && export no_proxy="$_ORIG_NO_PROXY"
  [[ -n "$_ORIG_HTTP_PROXY_U"  ]] && export HTTP_PROXY="$_ORIG_HTTP_PROXY_U"
  [[ -n "$_ORIG_HTTPS_PROXY_U" ]] && export HTTPS_PROXY="$_ORIG_HTTPS_PROXY_U"
  [[ -n "$_ORIG_NO_PROXY_U"    ]] && export NO_PROXY="$_ORIG_NO_PROXY_U"
  return 0
}
# Executa um comando com o proxy desligado e religa no final, mesmo se der erro.
run_sem_proxy() {
  proxy_off
  "$@"
  local status=$?
  proxy_on
  return $status
}

# ============================================================================
# ENTRADA .desktop
# ============================================================================
criar_desktop_entry() {
  local nome="$1" exec_cmd="$2" icone="$3" comentario="$4" terminal="${5:-false}"
  local dir="$HOME/.local/share/applications"
  mkdir -p "$dir"
  local arquivo="$dir/${nome// /-}.desktop"
  cat > "$arquivo" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${nome}
Comment=${comentario}
Exec=${exec_cmd}
Icon=${icone}
Terminal=${terminal}
Categories=Development;
EOF
  chmod +x "$arquivo"
  log_ok "Entrada de menu criada: $arquivo"
}

# ============================================================================
# 1) ATUALIZAÇÃO DO SISTEMA
# ============================================================================
titulo "Atualizando pacotes (apt update/upgrade)"
if sudo apt-get update -y && sudo apt-get upgrade -y; then
  marcar "apt update/upgrade" "OK"
else
  marcar "apt update/upgrade" "FALHOU"
  log_warn "Falha no apt update/upgrade, seguindo mesmo assim."
fi

# ============================================================================
# 2) PACOTES BASE
# ============================================================================
titulo "Instalando pacotes base: git, curl, wget, htop, build-essential..."
if sudo apt-get install -y git curl wget htop build-essential \
    apt-transport-https ca-certificates gnupg lsb-release software-properties-common unzip; then
  marcar "pacotes base" "OK"
else
  marcar "pacotes base" "FALHOU"
fi

# ============================================================================
# 3) DOCKER ENGINE
# ============================================================================
titulo "Instalando Docker Engine"
if command -v docker &>/dev/null; then
  log_ok "Docker já instalado, pulando."
  marcar "Docker Engine" "JÁ INSTALADO"
else
  instalar_docker_engine() {
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  }
  if run_sem_proxy instalar_docker_engine; then
    sudo usermod -aG docker "$USER"
    sudo systemctl enable --now docker
    marcar "Docker Engine" "OK (faça logout/login para usar sem sudo)"
  else
    marcar "Docker Engine" "FALHOU"
  fi
fi

# ============================================================================
# 4) DOCKER DESKTOP
# ============================================================================
titulo "Instalando Docker Desktop"
if command -v docker-desktop &>/dev/null || [[ -f /opt/docker-desktop/bin/docker-desktop ]]; then
  log_ok "Docker Desktop já instalado, pulando."
  marcar "Docker Desktop" "JÁ INSTALADO"
else
  instalar_docker_desktop() {
    local tmp_deb
    tmp_deb="$(mktemp --suffix=.deb)"
    curl -fsSL -o "$tmp_deb" "$DOCKER_DESKTOP_URL" || return 1
    sudo apt-get install -y "$tmp_deb"
    rm -f "$tmp_deb"
  }
  if run_sem_proxy instalar_docker_desktop; then
    marcar "Docker Desktop" "OK"
  else
    marcar "Docker Desktop" "FALHOU (verifique DOCKER_DESKTOP_URL)"
    log_warn "Pegue a URL atual em https://www.docker.com/products/docker-desktop/ e rode com DOCKER_DESKTOP_URL=..."
  fi
fi
if command -v docker-desktop &>/dev/null; then
  criar_desktop_entry "Docker Desktop" "docker-desktop" "docker" "Docker Desktop" false
fi

# ============================================================================
# 5) SDKMAN + JAVA 21 e 17
# ============================================================================
titulo "Instalando SDKMAN e Java (21 e 17 - Temurin)"
if [[ -d "$HOME/.sdkman" ]]; then
  log_ok "SDKMAN já instalado."
else
  instalar_sdkman() { curl -s "https://get.sdkman.io" | bash; }
  run_sem_proxy instalar_sdkman
fi
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  set +u; source "$HOME/.sdkman/bin/sdkman-init.sh"; set -u
  sed -i 's/sdkman_auto_answer=false/sdkman_auto_answer=true/' "$HOME/.sdkman/etc/config" 2>/dev/null \
    || echo "sdkman_auto_answer=true" >> "$HOME/.sdkman/etc/config"
  falhou_java=0
  for jv in "${JAVA_CANDIDATES[@]}"; do
    instalar_java() { set +u; sdk install java "$jv"; local s=$?; set -u; return $s; }
    if run_sem_proxy instalar_java; then
      log_ok "Java $jv instalado."
    else
      log_warn "Java $jv já pode estar instalado ou falhou (veja o log)."
      falhou_java=1
    fi
  done
  set +u; sdk default java "$JAVA_DEFAULT" 2>&1 | tee -a "$LOG_FILE"; set -u
  sed -i 's/sdkman_auto_answer=true/sdkman_auto_answer=false/' "$HOME/.sdkman/etc/config" 2>/dev/null || true
  if [[ $falhou_java -eq 0 ]]; then
    marcar "SDKMAN + Java 21/17" "OK (padrão: $JAVA_DEFAULT)"
  else
    marcar "SDKMAN + Java 21/17" "PARCIAL - confira o log"
  fi
else
  marcar "SDKMAN + Java 21/17" "FALHOU"
  log_err "SDKMAN não foi instalado, pulando Java."
fi

# ============================================================================
# 6) NVM + NODE (LTS, 20 e 22 - padrão LTS)
# ============================================================================
titulo "Instalando NVM e Node (LTS, 20 e 22)"
if [[ -d "$HOME/.nvm" ]]; then
  log_ok "NVM já instalado."
else
  instalar_nvm() { curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; }
  run_sem_proxy instalar_nvm
fi
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  set +u; source "$NVM_DIR/nvm.sh"; set -u
  falhou_node=0
  instalar_node_lts() { set +u; nvm install --lts; local s=$?; set -u; return $s; }
  if run_sem_proxy instalar_node_lts; then log_ok "Node LTS instalado."; else falhou_node=1; fi
  for v in "${NODE_VERSIONS[@]}"; do
    instalar_node_v() { set +u; nvm install "$v"; local s=$?; set -u; return $s; }
    if run_sem_proxy instalar_node_v; then
      log_ok "Node $v instalado."
    else
      log_warn "Falha ao instalar Node $v."
      falhou_node=1
    fi
  done
  set +u; nvm alias default 'lts/*'; nvm use default; set -u
  if [[ $falhou_node -eq 0 ]]; then
    marcar "NVM + Node (LTS/20/22)" "OK (padrão: LTS)"
  else
    marcar "NVM + Node (LTS/20/22)" "PARCIAL - confira o log"
  fi
else
  marcar "NVM + Node (LTS/20/22)" "FALHOU"
  log_err "NVM não foi instalado, pulando Node."
fi

# ============================================================================
# 7) POSTGRESQL
# ============================================================================
titulo "Instalando PostgreSQL"
if command -v psql &>/dev/null; then
  log_ok "PostgreSQL já instalado."
  marcar "PostgreSQL" "JÁ INSTALADO"
elif sudo apt-get install -y postgresql postgresql-contrib; then
  sudo systemctl enable --now postgresql
  marcar "PostgreSQL" "OK"
  log_info "Usuário padrão do Postgres: 'postgres' (use: sudo -u postgres psql)"
else
  marcar "PostgreSQL" "FALHOU"
fi

# ============================================================================
# 8) pgAdmin e/ou DBeaver
# ============================================================================
titulo "Cliente de banco de dados"
instalar_pgadmin() {
  instalar_pgadmin_curl() {
    curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub \
      | sudo gpg --yes --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
    sudo apt-get update -y
  }
  if run_sem_proxy instalar_pgadmin_curl && sudo apt-get install -y pgadmin4-desktop; then
    marcar "pgAdmin4" "OK"
  else
    marcar "pgAdmin4" "FALHOU"
  fi
}
instalar_dbeaver() {
  instalar_dbeaver_curl() {
    local tmp_deb
    tmp_deb="$(mktemp --suffix=.deb)"
    curl -fsSL -o "$tmp_deb" "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" || return 1
    sudo apt-get install -y "$tmp_deb"
    rm -f "$tmp_deb"
  }
  if run_sem_proxy instalar_dbeaver_curl; then
    marcar "DBeaver" "OK"
  else
    marcar "DBeaver" "FALHOU"
  fi
}
opcao_db="${DB_CLIENT:-}"
if [[ -z "$opcao_db" ]]; then
  echo
  echo "Qual cliente de banco de dados você quer instalar?"
  echo "  1) pgAdmin"
  echo "  2) DBeaver"
  echo "  3) Ambos"
  echo "  4) Nenhum"
  read -rp "Escolha [1-4]: " opcao_db
fi
case "$opcao_db" in
  1|pgadmin) instalar_pgadmin ;;
  2|dbeaver) instalar_dbeaver ;;
  3|ambos)   instalar_pgadmin; instalar_dbeaver ;;
  *)         log_info "Nenhum cliente de banco selecionado."; marcar "pgAdmin/DBeaver" "PULADO" ;;
esac

# ============================================================================
# 9) opencode
# ============================================================================
titulo "Instalando opencode"
if command -v opencode &>/dev/null || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  log_ok "opencode já instalado."
  marcar "opencode" "JÁ INSTALADO"
else
  instalar_opencode() { curl -fsSL https://opencode.ai/install | bash; }
  if run_sem_proxy instalar_opencode; then
    marcar "opencode" "OK"
  else
    marcar "opencode" "FALHOU"
  fi
fi

# ============================================================================
# 10) VS CODE
# ============================================================================
titulo "Instalando Visual Studio Code"
if command -v code &>/dev/null; then
  log_ok "VS Code já instalado."
  marcar "VS Code" "JÁ INSTALADO"
else
  instalar_vscode() {
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f /tmp/packages.microsoft.gpg
    sudo apt-get update -y
  }
  if run_sem_proxy instalar_vscode && sudo apt-get install -y code; then
    marcar "VS Code" "OK"
  else
    marcar "VS Code" "FALHOU"
  fi
fi

# ============================================================================
# 11) INTELLIJ IDEA COMMUNITY
# ============================================================================
titulo "Instalando IntelliJ IDEA Community"
if [[ -x "$IDEA_INSTALL_DIR/bin/idea.sh" ]]; then
  log_ok "IntelliJ já instalado em $IDEA_INSTALL_DIR."
  marcar "IntelliJ IDEA" "JÁ INSTALADO"
else
  instalar_intellij() {
    local tmp_tar
    tmp_tar="$(mktemp --suffix=.tar.gz)"
    curl -fsSL -o "$tmp_tar" "$IDEA_URL" || return 1
    sudo mkdir -p "$IDEA_INSTALL_DIR"
    sudo tar -xzf "$tmp_tar" -C "$IDEA_INSTALL_DIR" --strip-components=1
    rm -f "$tmp_tar"
  }
  if run_sem_proxy instalar_intellij; then
    sudo ln -sf "$IDEA_INSTALL_DIR/bin/idea.sh" /usr/local/bin/idea
    marcar "IntelliJ IDEA" "OK"
  else
    marcar "IntelliJ IDEA" "FALHOU"
    log_warn "Confira IDEA_VERSION no topo do script (pode estar desatualizada)."
  fi
fi
if [[ -x "$IDEA_INSTALL_DIR/bin/idea.sh" ]]; then
  criar_desktop_entry "IntelliJ IDEA Community" "$IDEA_INSTALL_DIR/bin/idea.sh %f" "$IDEA_INSTALL_DIR/bin/idea.svg" "IntelliJ IDEA Community Edition" false
fi

# ============================================================================
# 12) ATALHO DO HTOP NO MENU
# ============================================================================
criar_desktop_entry "Htop" "ptyxis --new-window -x htop" "utilities-system-monitor" "Monitor de processos htop" false

# ============================================================================
# RESUMO
# ============================================================================
titulo "RESUMO DA INSTALAÇÃO"
for item in "${!RESULTADO[@]}"; do
  printf "  %-35s %s\n" "$item" "${RESULTADO[$item]}" | tee -a "$LOG_FILE"
done
echo
log_info "Log completo: $LOG_FILE"
echo
log_warn "Próximos passos:"
echo "  1) Faça LOGOUT/LOGIN para o grupo 'docker' valer sem sudo."
echo "  2) Abra um novo terminal para nvm/sdkman entrarem no PATH."
echo "  3) Teste: docker run hello-world | node -v | java -version"
echo
log_ok "Script finalizado."
