# ArchDots

Dotfiles de mi escritorio Arch Linux + Hyprland (config en Lua), NVIDIA, 1920x1080@240 Hz.

## Repos relacionados

Partes del sistema que viven en su propio repo:

| Repo | Qué es |
| :--- | :--- |
| [gradfetch](https://github.com/ElRoutel/gradfetch) | fastfetch con temas, gradientes ASCII e imágenes/GIF (`ff`) |
| [wallpaperengine-wayland-bridge](https://github.com/ElRoutel/wallpaperengine-wayland-bridge) | `set-wall`, `wall-autopause` y `wall-picker` (Wallpaper Engine, videos e imágenes) |
| [AirWave-Hypr](https://github.com/ElRoutel/AirWave-Hypr) | hyprlock dinámico con portada y AirPlay en Waybar |
| [Wayland-Custom-Resolution-WCR](https://github.com/ElRoutel/Wayland-Custom-Resolution-WCR) | Refresh rates personalizados vía EDID |

## Estructura

| Ruta en el repo | Va en | Contenido |
| :--- | :--- | :--- |
| `config/hypr/` | `~/.config/hypr/` | `hyprland.lua` (config activa), `hypridle.conf`, `hyprlock.conf`, `scripts/`, `shaders/`. `hyprland.conf`/`hyprland2.conf` son la config vieja pre-Lua |
| `config/kitty/` | `~/.config/kitty/` | Terminal y temas |
| `config/waybar/` | `~/.config/waybar/` | Barra (todo definido en `config.jsonc` + `style.css`) |
| `config/swaync/` | `~/.config/swaync/` | Notificaciones y centro de control (tema `tidol-glass`) |
| `config/rofi/` | `~/.config/rofi/` | `config.rasi`, `theme.rasi`, `mi_cristal.rasi` (`wallpicker.rasi` vive en el repo del puente) |
| `config/wlogout/`, `config/btop/`, `config/starship.toml` | `~/.config/...` | Menú de apagado, monitor, prompt |
| `config/fastfetch/config.jsonc` | `~/.config/fastfetch/` | Mi config personal (el resto lo instala gradfetch) |
| `config/systemd/user/` | `~/.config/systemd/user/` | `ddcci-uleds-bridge`, `hyprnotify`, `shairport-sync`, `bitcoind` |
| `local/bin/` | `~/.local/bin/` | Scripts propios (ver abajo) |
| `.zshrc`, `.bashrc`, `.p10k.zsh` | `~/` | Shell |

### Scripts en `local/bin/`

| Script | Qué hace |
| :--- | :--- |
| `ddcci-uleds-bridge` | Expone el brillo DDC/CI del monitor como LED del kernel para que swaync lo controle |
| `dpms-if-locked` | Apaga el monitor si MacLock está activo (lo llama hypridle) |
| `firefox` | Wrapper de Firefox con fontconfig restringido (anti-fingerprinting) |
| `fp-check.sh` | Verifica (solo lectura) la config anti-fingerprinting |
| `fix-airplay.sh`, `ufw-airplay.sh` | Reparan la cadena AirPlay → MPRIS → Waybar y abren puertos en UFW |
| `tvbox-trap.sh` | Hotspot para la TV box enrutado por la VPN |
| `nvfan.sh` | Perfiles de ventilador NVIDIA (`silent`/`load`/`auto`) |
| `floating_kitty.sh`, `nvim-special-launch.sh`, `toggle-waybar-borders.sh` | Atajos varios |

## Instalación (enlaces simbólicos)

Este repo **es** la config en uso: `install.sh` enlaza cada carpeta/archivo en su sitio, así que lo que edites en tu sistema ya queda listo para `git commit` y `git push`.

```bash
git clone https://github.com/ElRoutel/ArchDots.git ~/ArchDots
~/ArchDots/install.sh --dry   # ver qué haría
~/ArchDots/install.sh         # enlazar (lo existente se mueve a ~/dotfiles-backup-<fecha>/)

# Repos propios
git clone https://github.com/ElRoutel/gradfetch.git ~/gradfetch && ~/gradfetch/install.sh
git clone https://github.com/ElRoutel/wallpaperengine-wayland-bridge.git ~/wallpaperengine-wayland-bridge && ~/wallpaperengine-wayland-bridge/install.sh

# Datos privados (no están en el repo)
mkdir -p ~/.config/.secrets && chmod 700 ~/.config/.secrets
echo "XX:XX:XX:XX:XX:XX" > ~/.config/.secrets/phone-mac.txt   # MAC del iPhone para el alias notison

# Servicios de usuario
systemctl --user enable --now ddcci-uleds-bridge shairport-sync
```

Enlazado como carpeta completa: `hypr`, `kitty`, `waybar`, `swaync`, `wlogout`. Archivo por archivo: rofi, btop, starship, fastfetch/config.jsonc, servicios de systemd, `~/.local/bin/*` y los dotfiles de shell.

> ⚠️ `sed -i` **reemplaza un enlace por un archivo normal** (rompe el vínculo con el repo). Usa `sed -i --follow-symlinks` o edita con nvim/código.

## Notas

- **Datos privados**: los scripts de Waybar leen hosts, IPs y tokens de `~/.config/.secrets/`, que **no** está en el repo. La MAC del alias `notison` se lee de `~/.config/.secrets/phone-mac.txt`.
