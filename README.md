# dotfiles-ubuntu

Minha personalização do Ubuntu (GNOME), pronta para reaplicar numa máquina nova.

## Instalar numa máquina nova

```bash
sudo apt install -y git
git clone https://github.com/MEUCAPSQUEBROU/dotfiles-ubuntu.git ~/dotfiles-ubuntu
cd ~/dotfiles-ubuntu
./instalar.sh
```

No fim, **faça logout e login** para o GNOME carregar o tema, as extensões e os widgets.

| Comando | O que faz |
|---|---|
| `./instalar.sh` | Visual + apps, e pergunta se instala o ambiente de dev |
| `./instalar.sh --tudo` | Visual + apps + dev |
| `./instalar.sh --sem-dev` | Só visual + apps |
| `bash scripts/dev.sh` | Só o ambiente de dev |

Pode rodar de novo sem medo: o que já está instalado é pulado.

## O que vem no pacote

**Visual**
- Tema GTK **MacTahoe-Dark-grey** (também no GTK 4/libadwaita e no shell), modo escuro, destaque *slate*
- Ícones **Yaru-white-dark** (Yaru escuro com pastas brancas) + pacote de ícones MacTahoe
- Dock embaixo, escondendo sozinha, transparente, sem lixeira e sem discos
- Botões de janela: minimizar, maximizar, fechar

**Widgets na área de trabalho** (extensão Desktop Widgets / azclock, com ajustes)
- Relógio e data grandes no centro
- Clima (Aracaju), uso do disco, velocidade da rede, chuva estilo Matrix

**Extensões**: azclock, Clipboard Indicator (`Super+V`), Tiling Assistant, User Themes, entre outras.

**Atalhos**
- `Super+S`: print de uma área direto para a área de transferência
- `Super+Shift+S`: print da tela inteira para a área de transferência
- `Super+E`: abre a pasta pessoal
- `Super+M`: central de notificações

**Apps**
- Variety trocando o wallpaper a cada 20 min (39 wallpapers, baixados do Release `wallpapers`)
- Spotify com Spicetify + Marketplace
- Zen Browser, Telegram, Postman, Chromium
- Ptyxis (terminal) com paleta Linux
- VS Code: tema Dark+ Pure Black (OLED), Material Icons, atalhos e extensões

**Ambiente de dev** (`scripts/dev.sh`): Docker Engine + Desktop, SDKMAN com Java 21/17 (Temurin), NVM com Node LTS/20/22, PostgreSQL, pgAdmin/DBeaver, opencode, VS Code e IntelliJ IDEA Community. Funciona em rede com proxy.

## Atualizar o pacote depois de mudar algo

```bash
cd ~/dotfiles-ubuntu
./exportar.sh                 # copia as configs atuais para o repo
./exportar.sh --wallpapers    # idem, e também reenvia os wallpapers para o Release
git add -A && git commit -m "Atualiza configurações" && git push
```

## Observações

- **Rede com proxy autenticado**: o widget de clima precisa de um proxy local. Coloque o endereço em `~/.config/azclock/weather-proxy` (ex.: `http://127.0.0.1:3129`). Sem esse arquivo, ele usa a rede normal.
- **Widget de rede**: detecta a placa de rede sozinho. Para forçar uma, defina `NET_IFACE`.
- **Tema do Spotify**: o tema escolhido dentro do Marketplace fica salvo no próprio Spotify. Numa máquina nova, escolha de novo em *Marketplace → Themes*.
- A cidade do clima e a posição dos widgets ficam em `gnome/dconf/shell.ini`.

## Estrutura

```
instalar.sh           instala tudo
exportar.sh           copia a configuração atual desta máquina para o repo
scripts/dev.sh        ambiente de desenvolvimento
gnome/dconf/          configurações do GNOME (dconf), uma por área
gnome/extensions/     extensões instaladas pelo usuário
icons/                ícones Yaru-white-dark
bin/                  scripts dos widgets e do print
config/               Variety, Spicetify, Zen, VS Code, chave do repositório do Spotify
```

## Créditos

- [MacTahoe GTK theme](https://github.com/vinceliuice/MacTahoe-gtk-theme) e [MacTahoe icon theme](https://github.com/vinceliuice/MacTahoe-icon-theme), de vinceliuice
- [Desktop Widgets (azclock)](https://gitlab.com/AndrewZaech/azclock) — GPL-3.0, com ajustes locais
- [Clipboard Indicator](https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator)
- [Spicetify](https://spicetify.app)
- Wallpapers: [wallhaven.cc](https://wallhaven.cc)
