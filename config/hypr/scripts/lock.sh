#!/usr/bin/env bash

# Valores por defecto de tu sistema (cámbialos si usas otros valores en hyprland.conf)
DEFAULT_GAPS="10"
DEFAULT_DIM="0" # 0 significa desactivado

# --- 1. ANIMACIÓN DE ENTRADA (Efecto macOS "Push Back") ---
# Aumentamos los bordes drásticamente para que las ventanas se encojan (animación fluida)
# y activamos el oscurecimiento de pantalla.
hyprctl --batch "\
  keyword general:gaps_out 60;\
  keyword decoration:dim_inactive 1;\
  keyword decoration:dim_strength 0.6"

# Le damos a Hyprland los milisegundos necesarios para completar la animación de la ventana
sleep 0.35

# --- 2. BLOQUEO ---
# El script se pausará en esta línea hasta que introduzcas la contraseña
hyprlock

# --- 3. ANIMACIÓN DE SALIDA (Post-Unlock) ---
# Al desbloquear, restauramos los valores para que el escritorio vuelva a hacer "Zoom In"
hyprctl --batch "\
  keyword general:gaps_out $DEFAULT_GAPS;\
  keyword decoration:dim_inactive $DEFAULT_DIM;\
  keyword decoration:dim_strength 0.2"

