#!/usr/bin/env bash
# Deixa um Ubuntu (GNOME) novo com a mesma cara deste.
#
#   ./instalar.sh            -> visual + apps, e pergunta se instala o ambiente de dev
#   ./instalar.sh --tudo     -> visual + apps + dev, sem perguntar (exceto o cliente de banco)
#   ./instalar.sh --sem-dev  -> só visual + apps
#
# Pode rodar de novo quantas vezes quiser: o que já estiver instalado é pulado.
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
GITHUB_REPO="MEUCAPSQUEBROU/dotfiles-ubuntu"
SRC="$HOME/.cache/dotfiles-ubuntu"          # onde baixamos temas e afins
PICS="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Imagens")"
WALL_DIR="$PICS/Wallpapers"

ok()     { echo -e "\033[0;32m[ OK ]\033[0m $*"; }
info()   { echo -e "\033[0;34m[INFO]\033[0m $*"; }
aviso()  { echo -e "\033[0;33m[AVISO]\033[0m $*"; }
titulo() { echo -e "\n\033[1;36m==> $*\033[0m"; }

# Preenche os marcadores gravados pelo exportar.sh
preencher() { sed -e "s|@WALLPAPERS@|$WALL_DIR|g" -e "s|@HOME@|$HOME|g"; }

MODO_DEV="perguntar"
case "${1:-}" in
  --tudo)    MODO_DEV="sim" ;;
  --sem-dev) MODO_DEV="nao" ;;
  -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
esac

if [[ $EUID -eq 0 ]]; then
  echo "Não rode como root. Use: ./instalar.sh (ele pede sudo quando precisa)."
  exit 1
fi
if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
  aviso "Este pacote foi feito para Ubuntu com GNOME. Desktop atual: ${XDG_CURRENT_DESKTOP:-desconhecido}"
fi
if [[ "$MODO_DEV" == "perguntar" ]]; then
  read -rp "Instalar também o ambiente de dev (Docker, Java, Node, Postgres, IDEs)? [s/N] " r
  [[ "$r" =~ ^[sS] ]] && MODO_DEV="sim" || MODO_DEV="nao"
fi

info "Validando sudo (pode pedir senha agora)..."
sudo -v || { echo "Sem sudo, abortando."; exit 1; }
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null & )
mkdir -p "$SRC" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.config/autostart"

# ============================================================================
titulo "1/9 Pacotes do sistema"
# ============================================================================
if ! [[ -f /etc/apt/keyrings/spotify.gpg ]]; then
  sudo install -D -m 644 "$REPO/config/apt/spotify.gpg" /etc/apt/keyrings/spotify.gpg
  sudo tee /etc/apt/sources.list.d/spotify.sources >/dev/null <<'EOF'
Types: deb
URIs: https://repository.spotify.com
Suites: stable
Components: non-free
Signed-By: /etc/apt/keyrings/spotify.gpg
EOF
fi
sudo apt-get update -y
PACOTES=(
  git curl wget unzip xz-utils python3 gjs
  sassc libglib2.0-dev-bin libxml2-utils
  gnome-shell-extensions gnome-shell-extension-manager gnome-tweaks
  gir1.2-gweather-4.0 fonts-noto-cjk
  ptyxis variety spotify-client
)
if ! sudo apt-get install -y --no-install-recommends "${PACOTES[@]}"; then
  # Se algum pacote não existir nesta versão do Ubuntu, instala os outros um a um
  for p in "${PACOTES[@]}"; do
    sudo apt-get install -y --no-install-recommends "$p" &>/dev/null || aviso "pacote $p não instalado"
  done
fi
ok "pacotes apt"

for s in telegram-desktop postman chromium; do
  snap list "$s" &>/dev/null || sudo snap install "$s" || aviso "snap $s falhou"
done

# ============================================================================
titulo "2/9 Tema GTK MacTahoe (Dark, grey)"
# ============================================================================
if [[ -d "$HOME/.themes/MacTahoe-Dark-grey" ]]; then
  ok "tema já instalado"
else
  rm -rf "$SRC/MacTahoe-gtk-theme"
  git clone --depth 1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$SRC/MacTahoe-gtk-theme" \
    && (cd "$SRC/MacTahoe-gtk-theme" && ./install.sh -c dark -t grey -o normal -l) \
    && ok "tema MacTahoe-Dark-grey" || aviso "falha ao instalar o tema GTK"
fi

# ============================================================================
titulo "3/9 Ícones"
# ============================================================================
if [[ -d "$HOME/.local/share/icons/MacTahoe-grey" ]]; then
  ok "ícones MacTahoe já instalados"
else
  rm -rf "$SRC/MacTahoe-icon-theme"
  git clone --depth 1 https://github.com/vinceliuice/MacTahoe-icon-theme.git "$SRC/MacTahoe-icon-theme" \
    && bash "$SRC/MacTahoe-icon-theme/install.sh" -t grey \
    && ok "ícones MacTahoe" || aviso "falha ao instalar os ícones MacTahoe"
fi
mkdir -p "$HOME/.local/share/icons"
rm -rf "$HOME/.local/share/icons/Yaru-white-dark"
cp -a "$REPO/icons/Yaru-white-dark" "$HOME/.local/share/icons/"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/Yaru-white-dark" &>/dev/null || true
ok "ícones Yaru-white-dark (pastas brancas)"

# ============================================================================
titulo "4/9 Extensões do GNOME e scripts dos widgets"
# ============================================================================
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXT_DIR"
for ext in "$REPO/gnome/extensions/"*/; do
  nome="$(basename "$ext")"
  rm -rf "${EXT_DIR:?}/$nome"
  cp -a "$ext" "$EXT_DIR/"
  ok "extensão $nome"
done
for s in "$REPO/bin/"*; do
  install -m 755 "$s" "$HOME/.local/bin/"
done
ok "scripts em ~/.local/bin (relógio, clima, disco, rede, chuva Matrix, print)"

# ============================================================================
titulo "5/9 Wallpapers"
# ============================================================================
mkdir -p "$WALL_DIR"
if compgen -G "$WALL_DIR/*" >/dev/null; then
  ok "já existem wallpapers em $WALL_DIR, pulando download"
else
  URL="https://github.com/$GITHUB_REPO/releases/download/wallpapers/wallpapers.tar.gz"
  if curl -fL --progress-bar "$URL" | tar -xz -C "$WALL_DIR"; then
    ok "wallpapers em $WALL_DIR"
  else
    aviso "não consegui baixar os wallpapers de $URL"
  fi
fi

# ============================================================================
titulo "6/9 Configurações do GNOME"
# ============================================================================
for f in "$REPO/gnome/dconf/"*.ini; do
  caminho="$(head -1 "$f" | sed 's/^# dconf: //')"
  tail -n +2 "$f" | preencher | dconf load "$caminho" && ok "dconf $caminho"
done
# GTK 4 / libadwaita usa o tema via ~/.config/gtk-4.0 (o instalador do tema já faz com -l)

# ============================================================================
titulo "7/9 Apps: Variety, Zen, Spotify + Spicetify"
# ============================================================================
mkdir -p "$HOME/.config/variety"
preencher < "$REPO/config/variety/variety.conf" > "$HOME/.config/variety/variety.conf"
preencher < "$REPO/config/autostart/variety.desktop" > "$HOME/.config/autostart/variety.desktop"
ok "Variety (troca o wallpaper a cada 20 min, usando $WALL_DIR)"

if [[ -x "$HOME/.local/opt/zen/zen" ]]; then
  ok "Zen Browser já instalado"
else
  mkdir -p "$HOME/.local/opt"
  if curl -fL --progress-bar https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz \
       | tar -xJ -C "$HOME/.local/opt"; then
    ln -sf "$HOME/.local/opt/zen/zen" "$HOME/.local/bin/zen"
    ok "Zen Browser"
  else
    aviso "falha ao baixar o Zen Browser"
  fi
fi
preencher < "$REPO/config/applications/zen.desktop" > "$HOME/.local/share/applications/zen.desktop"

if command -v spotify &>/dev/null; then
  if ! [[ -x "$HOME/.spicetify/spicetify" ]]; then
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh || aviso "falha ao instalar o Spicetify"
  fi
  if [[ -x "$HOME/.spicetify/spicetify" ]]; then
    # O Spicetify precisa poder escrever na pasta do Spotify
    sudo chmod a+wr /usr/share/spotify && sudo chmod -R a+wr /usr/share/spotify/Apps
    # O Spotify precisa ter sido aberto uma vez para criar o arquivo prefs
    if ! [[ -f "$HOME/.config/spotify/prefs" ]]; then
      info "Abrindo o Spotify uma vez para ele criar as configurações..."
      (spotify &>/dev/null &) ; sleep 15; pkill -x spotify || true
    fi
    mkdir -p "$HOME/.config/spicetify"
    preencher < "$REPO/config/spicetify/config-xpui.ini" > "$HOME/.config/spicetify/config-xpui.ini"
    curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh \
      || aviso "falha ao instalar o Marketplace do Spicetify"
    if "$HOME/.spicetify/spicetify" backup apply &>/dev/null || "$HOME/.spicetify/spicetify" apply &>/dev/null; then
      ok "Spotify com Spicetify + Marketplace"
    else
      aviso "spicetify apply falhou, rode depois: spicetify backup apply"
    fi
  fi
fi

# ============================================================================
titulo "8/9 Terminal (.bashrc)"
# ============================================================================
MARCA="# >>> dotfiles-ubuntu >>>"
if ! grep -qF "$MARCA" "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'

# >>> dotfiles-ubuntu >>>
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"
[ -d "$HOME/.spicetify" ] && export PATH="$PATH:$HOME/.spicetify"
# <<< dotfiles-ubuntu <<<
EOF
fi
ok ".bashrc"

# ============================================================================
titulo "9/9 Ambiente de desenvolvimento"
# ============================================================================
if [[ "$MODO_DEV" == "sim" ]]; then
  bash "$REPO/scripts/dev.sh"
else
  info "pulado (rode depois com: bash scripts/dev.sh)"
fi

# VS Code: configurações e extensões (se o VS Code existir)
if command -v code &>/dev/null; then
  mkdir -p "$HOME/.config/Code/User"
  cp "$REPO/config/vscode/settings.json" "$REPO/config/vscode/keybindings.json" "$HOME/.config/Code/User/"
  while read -r e; do
    [[ -n "$e" ]] && code --install-extension "$e" --force &>/dev/null
  done < "$REPO/config/vscode/extensions.txt"
  ok "VS Code: configurações e extensões"
fi

echo
ok "Tudo pronto!"
echo "  -> Faça LOGOUT e LOGIN para o GNOME carregar as extensões, o tema e os widgets."
echo "  -> Em rede com proxy autenticado, o widget de clima precisa de um proxy local:"
echo "       echo http://127.0.0.1:3129 > ~/.config/azclock/weather-proxy"
