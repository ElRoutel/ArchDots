#!/usr/bin/env bash
sleep 0.3
pkill waybar
hyprlock
sleep 0.72
if pgrep -x "waybar" > /dev/null; then
    killall waybar
    echo "Waybar oculta. (lock.sh)"
else
    # Si NO está corriendo, lo inicia en segundo plano (lo muestra)
    waybar > /dev/null 2>&1 &
    echo "Waybar iniciada.(lock.sh)"
fi

