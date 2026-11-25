#!/bin/bash
# Toggle modo inmersivo (Waybar + bordes)

STATE_FILE="/tmp/hypr_immersive_mode"

if [ -f "$STATE_FILE" ]; then
    # RESTAURAR: Modo normal
    if ! pgrep -x waybar > /dev/null; then
        waybar &
    fi
    hyprctl keyword general:border_size 2
    rm "$STATE_FILE"
else
    # ACTIVAR: Modo inmersivo
    killall waybar 2>/dev/null
    hyprctl keyword general:border_size 0
    touch "$STATE_FILE"
fi

