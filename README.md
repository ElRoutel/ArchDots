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
| `config/waybar/` | `~/.config/waybar/` | Barra, módulos y scripts |
| `config/swaync/` | `~/.config/swaync/` | Notificaciones y centro de control (tema `tidol-glass`) |
| `config/rofi/` | `~/.config/rofi/` | `config.rasi`, `mi_cristal.rasi`, `wallpicker.rasi` |
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

## Restaurar desde cero

```bash
git clone https://github.com/ElRoutel/ArchDots.git ~/ArchDots && cd ~/ArchDots

# 1. Configs (respalda lo que ya exista)
for d in config/*/; do n=$(basename "$d"); [ -e ~/.config/$n ] && mv ~/.config/$n ~/.config/$n.bak; done
cp -a config/. ~/.config/
cp -a local/bin/. ~/.local/bin/ && chmod +x ~/.local/bin/*
cp .zshrc .bashrc .p10k.zsh ~/

# 2. Repos propios
git clone https://github.com/ElRoutel/gradfetch.git ~/gradfetch && ~/gradfetch/install.sh
git clone https://github.com/ElRoutel/wallpaperengine-wayland-bridge.git ~/wpe-bridge && ~/wpe-bridge/install.sh

# 3. Servicios de usuario
systemctl --user daemon-reload
systemctl --user enable --now ddcci-uleds-bridge hyprnotify shairport-sync
```

## Notas

- **Datos privados**: los scripts de Waybar leen hosts, IPs y tokens de `~/.config/.secrets/`, que **no** está en el repo. En `.zshrc` la MAC del alias `notison` está reemplazada por `XX:XX:XX:XX:XX:XX`.
- Los temas de rofi `style_*.rasi` y otros son enlaces a HyDE (`~/.local/share/hyde/rofi/themes/`).
