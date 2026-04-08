#!/usr/bin/env bash

# Si Waybar está corriendo, lo mata (lo oculta)
if pgrep -x "waybar" > /dev/null; then
    killall waybar
    echo "Waybar oculta."
else
    # Si NO está corriendo, lo inicia en segundo plano (lo muestra)
    waybar > /dev/null 2>&1 &
    echo "Waybar iniciada."
fi

