#!/usr/bin/env bash
# Copia a personalização atual desta máquina para dentro do repositório.
# Rode sempre que mudar algo no visual e depois faça commit/push.
#
#   ./exportar.sh              -> configs, scripts, extensões, ícones
#   ./exportar.sh --wallpapers -> também empacota os wallpapers e atualiza o Release no GitHub
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PICS="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Imagens")"
WALL_DIR="$PICS/Wallpapers"

ok()   { echo -e "\033[0;32m[ OK ]\033[0m $*"; }
info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }

# Troca caminhos desta máquina por marcadores que o instalar.sh preenche depois
anon() { sed -e "s|$WALL_DIR|@WALLPAPERS@|g" -e "s|$HOME|@HOME@|g"; }

# Padrões (um por linha) que nunca devem ir para o repo: chaves do settings.json
# do VS Code e extensões. O arquivo é local e fica fora do git.
IGNORAR="$(grep -v '^\s*$' "$REPO/.exportar-ignorar" 2>/dev/null | paste -sd'|' || true)"
IGNORAR="${IGNORAR:-^$}"

# ---------------------------------------------------------------- GNOME (dconf)
info "Exportando configurações do GNOME"
D="$REPO/gnome/dconf"
rm -rf "$D"; mkdir -p "$D"
declare -A DCONF=(
  [interface]=/org/gnome/desktop/interface/
  [background]=/org/gnome/desktop/background/
  [wm]=/org/gnome/desktop/wm/preferences/
  [teclado]=/org/gnome/desktop/peripherals/keyboard/
  [layout-teclado]=/org/gnome/desktop/input-sources/
  [mutter]=/org/gnome/mutter/
  [shell]=/org/gnome/shell/
  [atalhos]=/org/gnome/settings-daemon/plugins/media-keys/
  [ptyxis]=/org/gnome/Ptyxis/
  [nautilus]=/org/gnome/nautilus/preferences/
  [nautilus-icones]=/org/gnome/nautilus/icon-view/
)
for nome in "${!DCONF[@]}"; do
  caminho="${DCONF[$nome]}"
  {
    echo "# dconf: $caminho"
    dconf dump "$caminho" \
      | grep -vE '^(app-picker-layout|welcome-dialog-last-shown-version|last-selected-power-profile|last-version-installed|overridden-settings)=' \
      | anon
  } > "$D/$nome.ini"
done
ok "dconf -> gnome/dconf/"

# ---------------------------------------------------------------- Extensões
info "Copiando extensões do GNOME instaladas pelo usuário"
E="$REPO/gnome/extensions"
rm -rf "$E"; mkdir -p "$E"
for ext in "$HOME/.local/share/gnome-shell/extensions/"*/; do
  cp -a "$ext" "$E/"
done
gsettings get org.gnome.shell enabled-extensions | tr -d "[]' " | tr ',' '\n' > "$REPO/gnome/extensoes-ativas.txt"
ok "extensões -> gnome/extensions/"

# ---------------------------------------------------------------- Ícones próprios
rm -rf "$REPO/icons"; mkdir -p "$REPO/icons"
cp -a "$HOME/.local/share/icons/Yaru-white-dark" "$REPO/icons/"
ok "ícones Yaru-white-dark -> icons/"

# ---------------------------------------------------------------- Scripts (~/.local/bin)
B="$REPO/bin"
rm -rf "$B"; mkdir -p "$B"
for s in disk-widget.sh net-widget.sh matrix-rain.py print-clipboard print-atrasado weather-fetch.js gerar-slideshow-wallpapers; do
  [[ -f "$HOME/.local/bin/$s" ]] && cp -a "$HOME/.local/bin/$s" "$B/"
done
ok "scripts dos widgets -> bin/"

# ---------------------------------------------------------------- Apps
C="$REPO/config"
mkdir -p "$C/variety" "$C/spicetify" "$C/vscode" "$C/autostart" "$C/applications"
anon < "$HOME/.config/variety/variety.conf" > "$C/variety/variety.conf"
anon < "$HOME/.config/autostart/variety.desktop" > "$C/autostart/variety.desktop"
# A seção [Backup] é gerada pelo próprio spicetify em cada máquina
anon < "$HOME/.config/spicetify/config-xpui.ini" \
  | sed -E '/^\[Backup\]/,$ s/^(version|with)( *)=.*/\1\2= /' > "$C/spicetify/config-xpui.ini"
[[ -f "$HOME/.local/share/applications/zen.desktop" ]] && anon < "$HOME/.local/share/applications/zen.desktop" > "$C/applications/zen.desktop"

if [[ -d "$HOME/.config/Code/User" ]]; then
  python3 - "$HOME/.config/Code/User/settings.json" "$IGNORAR" > "$C/vscode/settings.json" <<'PY'
import json, re, sys
cfg = json.load(open(sys.argv[1]))
cfg = {k: v for k, v in cfg.items() if not re.search(sys.argv[2], k, re.I)}
print(json.dumps(cfg, indent=4, ensure_ascii=False))
PY
  cp "$HOME/.config/Code/User/keybindings.json" "$C/vscode/keybindings.json"
  command -v code >/dev/null && code --list-extensions | grep -viE "$IGNORAR" > "$C/vscode/extensions.txt"
fi
ok "Variety, Spicetify, Zen e VS Code -> config/"

# ---------------------------------------------------------------- Wallpapers (Release)
if [[ "${1:-}" == "--wallpapers" ]]; then
  info "Empacotando wallpapers de $WALL_DIR"
  TMP="$(mktemp -d)"
  tar -C "$WALL_DIR" -czf "$TMP/wallpapers.tar.gz" .
  if gh release view wallpapers -R "$(cd "$REPO" && gh repo view --json nameWithOwner -q .nameWithOwner)" >/dev/null 2>&1; then
    (cd "$REPO" && gh release upload wallpapers "$TMP/wallpapers.tar.gz" --clobber)
  else
    (cd "$REPO" && gh release create wallpapers "$TMP/wallpapers.tar.gz" \
      --title "Wallpapers" --notes "Pacote de wallpapers baixado pelo instalar.sh.")
  fi
  rm -rf "$TMP"
  ok "Wallpapers enviados para o Release 'wallpapers'"
fi

echo
ok "Pronto. Confira com 'git status' e faça commit/push."
