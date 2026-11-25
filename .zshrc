# ═══════════════════════════════════════════════════════════════════════════════
# ZSHRC - ROUTEL - V5 FINAL (TOTAL CONTROL & HYPER-SPEED)
# ═══════════════════════════════════════════════════════════════════════════════
export GPG_TTY=$(tty)

# ── 0. FASTFETCH (DEBE IR ANTES DEL INSTANT PROMPT) ───────────────────────────
if [[ -n "${KITTY_WINDOW_ID}" ]] && [[ -z "${FASTFETCH_SHOWN}" ]]; then
    export FASTFETCH_SHOWN=1
    "$HOME/.config/fastfetch/bin/hybrid_launcher.sh"
fi

export PATH=~/.npm-global/bin:$PATH

# ── 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT) ──────────────────────────────
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── 2. OPTIMIZACIÓN DE AUTOCOMPLETADO (OH MY ZSH LO GESTIONA) ─────────────────
ZSH_DISABLE_COMPFIX="true"

# ═══════════════════════════════════════════════════════════════════════════════
# OH MY ZSH & PLUGINS
# ═══════════════════════════════════════════════════════════════════════════════
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

plugins=(
  git
  sudo
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)
source $ZSH/oh-my-zsh.sh

# ═══════════════════════════════════════════════════════════════════════════════
# HISTORY
# ═══════════════════════════════════════════════════════════════════════════════
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history
setopt append_history share_history hist_ignore_space hist_ignore_all_dups hist_reduce_blanks hist_verify
alias brillo='ddcutil setvcp 10'
alias ff="$HOME/.config/fastfetch/bin/hybrid_launcher.sh"
alias applemusic='brave --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --ignore-gpu-blocklist --disable-features=WebAppIconInTitlebar --app="https://music.apple.com"'
alias applemusicE='brave --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-gpu-rasterization --ignore-gpu-blocklist --disable-features=WebAppIconInTitlebar --app="https://music.apple.com" && exit'

mouse-profile() {
    local MOUSE=$(ratbagctl list | grep -i "G502" | cut -f1 -d:)
    ratbagctl "$MOUSE" profile active set "$1"
    echo "→ Perfil $1 activado"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ALIASES - NAVEGACIÓN Y SISTEMA
# ═══════════════════════════════════════════════════════════════════════════════
alias ..='cd ..' \
      ...='cd ../..' \
      ....='cd ../../..' \
      c='clear' \
      ls='lsd' \
      ll='lsd -lah --group-dirs first' \
      la='lsd -A' \
      cat='bat' \
      grep='grep --color=auto' \
      imgview='kitty +kitten icat'\
      wallpaper-change='$HOME/.local/bin/wall-picker'\
      wp='$HOME/.local/bin/wall-picker'\
      wlc='wl-copy'
#===========
alias burpsuite='JAVA_HOME=/usr/lib/jvm/java-26-openjdk burpsuite'
# Control de optimización de red
alias net-on='sudo systemctl restart net-optimizer.service && echo "Optimización ACTIVA (2ms Mode)"'
alias net-off='sudo /usr/local/bin/net-optimizer.sh stop && sudo tc qdisc del dev enp2s0 root 2>/dev/null && echo "Optimización DESACTIVADA (Raw Speed Mode)"'
alias net-stat='tc -s qdisc show dev ifb0'

alias nsend='nvim --server /tmp/nvim-server --remote-silent'
alias notison='ancs-linux "$(cat ~/.config/.secrets/phone-mac.txt)" & disown'  # MAC en ~/.config/.secrets (no se versiona)
alias airplay-reload='sudo systemctl disable --now shairport-sync.service ; systemctl --user restart shairport-sync.service ; systemctl --user status shairport-sync.service'
# Arregla la cadena AirPlay -> MPRIS -> Waybar (título no aparece en la barra)
alias airplay-fix='~/.local/bin/fix-airplay.sh'
# ═══════════════════════════════════════════════════════════════════════════════
# ALIASES - PAQUETES & DESARROLLO
# ═══════════════════════════════════════════════════════════════════════════════
alias update='paru -Syu'
alias install='paru -S'
alias remove='paru -Rns'
alias cleanup='paru -c --noconfirm && sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null'
alias v='nvim'
alias zshconfig='nvim ~/.zshrc'
alias zshreload='source ~/.zshrc'
alias reload='hyprctl reload'
alias copyimg='wl-paste -t image/png > ' 



# ═══════════════════════════════════════════════════════════════════════════════
# ALIASES - GIT
# ═══════════════════════════════════════════════════════════════════════════════
alias g='git' ga='git add' gaa='git add --all' gc='git commit -m' gp='git push' \
      gpl='git pull' gs='git status' gd='git diff' gl='git log --oneline --graph --decorate'

# ═══════════════════════════════════════════════════════════════════════════════
# ALIASES - PENTESTING & PROXY FARM
# ═══════════════════════════════════════════════════════════════════════════════
alias htb='sudo openvpn ~/htb.ovpn'
alias htbkill='sudo pkill openvpn'
alias ports='sudo netstat -tulnpe'
alias ipinfo='ip -br -c addr'
alias myip='curl ifconfig.me'
alias farm-up='docker-compose up -d'
alias farm-down='docker-compose down'
alias farm-check='for i in {1..5}; do curl -s --proxy http://127.0.0.1:5555 ifconfig.me; echo ""; done'

alias nvfan="~/.local/bin/nvfan.sh"

export FARM_PATH="/home/routel/Ds1/Tidol_MusicAPp/Tidol/backend/warp-farm"

start-proxyw() {
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
    cd "$FARM_PATH" && docker-compose up -d
    local BEST_PORT=$(python3 "$FARM_PATH/scripts/proxy_test.py" | tail -n 1)
    [[ "$BEST_PORT" == "ERROR" ]] && echo "❌ Error Proxy" || {
        export http_proxy="http://127.0.0.1:$BEST_PORT"
        export https_proxy="http://127.0.0.1:$BEST_PORT"
        export ALL_PROXY="http://127.0.0.1:$BEST_PORT"
        notify-send "Proxy Farm" "Puerto $BEST_PORT"
    }
    cd - > /dev/null
}

# ============================
# Remote Access (SSH + Tailscale)
# ============================
start-ssh() {
    echo "🚀 Preparando acceso remoto..."
    
    # 1. Iniciar el demonio de Tailscale (por si el servicio estaba apagado)
    sudo systemctl start tailscaled
    
    # 2. Levantar la red VPN asegurando que el SSH interno de Tailscale esté apagado
    sudo tailscale up --ssh=false
    
    # 3. Iniciar el servidor OpenSSH
    sudo systemctl start sshd
    
    # Obtener la IP de Tailscale para mostrarla
    local TS_IP=$(tailscale ip -4)
    sudo -k 
    echo "✅ ¡Servicios activos!"
    echo "📱 Ya puedes abrir Termius en tu iPhone."
    echo "🌐 Tu IP de conexión es: \e[1;32m$TS_IP\e[0m"
    echo "TATATA!"
}

stop-ssh() {
    echo "🛑 Cerrando puertos y apagando VPN..."
    sudo systemctl stop sshd
    sudo tailscale down
    # Opcional: sudo systemctl stop tailscaled
    echo "🔒 Acceso remoto desactivado."
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES - UTILIDADES
# ═══════════════════════════════════════════════════════════════════════════════
pk()     { [[ -z "$1" ]] && return 1; pkill -9 -fi "$1"; }
mkcd()   { mkdir -p "$1" && cd "$1"; }
mkt()    { mkdir -p {nmap,content,scripts,tmp,exploits}; }
ffile()  { find . -type f -iname "*$1*" 2>/dev/null; }
fdir()   { find . -type d -iname "*$1*" 2>/dev/null; }

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;;
            *.rar)     unrar x "$1" ;; *.zip)    unzip "$1"   ;;
            *.7z)      7z x "$1"    ;; *)        notify-send "'$1' error" ;;
        esac
    fi
}

backup-config() {
    local file=~/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz
    tar -czf $file ~/.config/{hypr,waybar,kitty,fastfetch} ~/.zshrc ~/.p10k.zsh 2>/dev/null
    echo "✅ Backup: $file"
}

img2b64() {
    local mime=$(file -b --mime-type "$1")
    echo -n "data:${mime};base64,$(base64 -w 0 "$1")" | wl-copy
    echo "Imagen $1 copiada al portapapeles en formato Base64!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT & LAZY LOADING
# ═══════════════════════════════════════════════════════════════════════════════
export EDITOR='nvim'
export PATH="$HOME/.local/bin:$HOME/.local/share/bin:$PATH"

# LAZY LOAD PYENV
function pyenv() {
    unset -f pyenv python python3 pip
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(command pyenv init - --no-rehash zsh)"
    command pyenv "$@"
}

# LAZY LOAD NVM
nvm_load() {
    unset -f nvm node npm npx
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

nvm() { nvm_load; nvm "$@"; }
node() { nvm_load; node "$@"; }
npm() { nvm_load; npm "$@"; }
npx() { nvm_load; npx "$@"; }

# LAZY LOAD DIRENV
function _direnv_hook() {
    eval "$(direnv hook zsh)"
    add-zsh-hook -d precmd _direnv_hook
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _direnv_hook

# Atajo para listar archivos con Alt + Shift + L
bindkey -s '^[^L' 'ls \n'


# ═══════════════════════════════════════════════════════════════════════════════
# POWERLEVEL10K & FASTFETCH
# ═══════════════════════════════════════════════════════════════════════════════
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

alias fastfetch="$HOME/.config/fastfetch/bin/hybrid_launcher.sh"

# Romper el alias viejo para que Zsh no se confunda al compilar la función
unalias tidol 2>/dev/null

tidol() {
    if [ -z "$1" ]; then
        echo "🎵 Uso: tidol \"Nombre del artista o canción\""
        return 1
    fi
    
    # Reemplazamos los espacios por %20 para la URL de red
    QUERY=$(echo "$1" | sed 's/ /%20/g')
    echo "🔥 Inyectando $1 Tidol Core..."
    
    # Lanzamos VLC en segundo plano de forma totalmente silenciosa
    nohup cvlc "http://localhost:3000/api/v1/search/m3u?q=$QUERY" > /dev/null 2>&1 &
}

# Added by Antigravity CLI installer
export PATH="/home/routel/.local/bin:$PATH"

# ═══════════════════════════════════════════════════════════════════════════════
#    SI HAY ALGO DESPUES DE ESTO EL ARCHIVO PUDO SER EDITADO AUTOMATICAMENTE
# ═══════════════════════════════════════════════════════════════════════════════



