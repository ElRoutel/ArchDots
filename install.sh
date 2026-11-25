#!/usr/bin/env bash
# install.sh — enlaza los dotfiles de este repo en su sitio (~/.config, ~/.local/bin, ~/).
#
# Lo que ya exista y no sea el enlace correcto se mueve a ~/dotfiles-backup-<fecha>/
# con la misma ruta relativa, así que nunca se pierde nada. Se puede ejecutar varias veces.
#
#   ./install.sh           crea/repara los enlaces
#   ./install.sh --dry     solo muestra lo que haría
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY=0; [ "${1:-}" = "--dry" ] && DRY=1

link() { # link <origen en el repo> <destino>
    local src="$REPO/$1" dest="$2"
    [ -e "$src" ] || { echo "  ✗ no existe en el repo: $1"; return; }
    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
        return  # ya está bien
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        local rel="${dest#$HOME/}"
        echo "  ↺ respaldo: ~/$rel"
        if [ $DRY = 0 ]; then mkdir -p "$BACKUP/$(dirname "$rel")"; mv "$dest" "$BACKUP/$rel"; fi
    fi
    echo "  → ~/${dest#$HOME/}  ⇒  $1"
    if [ $DRY = 0 ]; then mkdir -p "$(dirname "$dest")"; ln -s "$src" "$dest"; fi
}

echo "Carpetas completas:"
for d in hypr kitty waybar swaync wlogout; do link "config/$d" "$CFG/$d"; done

echo "Archivos sueltos de ~/.config:"
for f in config.rasi theme.rasi mi_cristal.rasi; do link "config/rofi/$f" "$CFG/rofi/$f"; done
link config/btop/btop.conf        "$CFG/btop/btop.conf"
link config/starship.toml         "$CFG/starship.toml"
link config/fastfetch/config.jsonc "$CFG/fastfetch/config.jsonc"
for s in "$REPO"/config/systemd/user/*.service; do
    link "config/systemd/user/$(basename "$s")" "$CFG/systemd/user/$(basename "$s")"
done

echo "Scripts de ~/.local/bin:"
for s in "$REPO"/local/bin/*; do link "local/bin/$(basename "$s")" "$HOME/.local/bin/$(basename "$s")"; done

echo "Shell:"
for f in .zshrc .bashrc .p10k.zsh; do link "$f" "$HOME/$f"; done

if [ $DRY = 0 ]; then
    systemctl --user daemon-reload 2>/dev/null || true
    [ -d "$BACKUP" ] && echo "Respaldo de lo reemplazado: $BACKUP"
fi

# Datos privados que el repo no guarda
[ -f "$CFG/.secrets/phone-mac.txt" ] || echo "Aviso: falta $CFG/.secrets/phone-mac.txt (MAC del teléfono para el alias notison)"
echo "Listo."
