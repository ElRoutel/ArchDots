#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# GRADIENT PROCESSOR v3.0 - MOTOR MULTI-MODO
# ═══════════════════════════════════════════════════════════════════════════════

set -u
export LC_NUMERIC=C
export LC_ALL=C.utf8

GLOBAL_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"

if [ -n "${THEME_BASE:-}" ] && [ -d "$THEME_BASE" ]; then
    ASCII_DIR="$THEME_BASE/ascii"
    PROCESSED_DIR="$THEME_BASE/processedASCII"
    GRADIENT_CONF="$THEME_BASE/gradient.conf"
    GRADIENT_BAK="$THEME_BASE/.gradient.conf.bak"
    CONTEXT="Tema: $(basename "$THEME_BASE")"
else
    ASCII_DIR="$GLOBAL_CONFIG_DIR/ascii"
    PROCESSED_DIR="$GLOBAL_CONFIG_DIR/processedASCII"
    GRADIENT_CONF="$GLOBAL_CONFIG_DIR/gradient.conf"
    GRADIENT_BAK="$GLOBAL_CONFIG_DIR/.gradient.conf.bak"
    CONTEXT="Global"
fi

# ── CARGAR CONFIGURACIÓN ──
# Valores por defecto
GRADIENT_MODE="vertical"
GRADIENT_COLORS=("255,255,255" "255,255,255")

if [ -f "$GRADIENT_CONF" ]; then
    # Intentar cargar como array o variables simples
    source "$GRADIENT_CONF"
else
    echo -e "\033[33m[WARN]\033[0m Falta gradient.conf, usando blanco sólido."
fi

# Convertir array de colores a una cadena para pasarla a AWK
COLORS_STR="${GRADIENT_COLORS[*]}"

process_file() {
    local input="$1"
    local output="$2"
    
    # 1. Medir dimensiones del ASCII
    local height=$(wc -l < "$input")
    local width=$(awk '{ if (length($0) > max) max = length($0) } END { print max }' "$input")
    
    # 2. Procesamiento Maestro con AWK
    awk -v h="$height" -v w="$width" -v mode="$GRADIENT_MODE" -v c_str="$COLORS_STR" '
    BEGIN {
        split(c_str, colors, " ")
        n_colors = 0
        for (i in colors) n_colors++
    }
    
    function interpolate(c1, c2, r) {
        split(c1, rgb1, ",")
        split(c2, rgb2, ",")
        r_out = int(rgb1[1] + (rgb2[1] - rgb1[1]) * r)
        g_out = int(rgb1[2] + (rgb2[2] - rgb1[2]) * r)
        b_out = int(rgb1[3] + (rgb2[3] - rgb1[3]) * r)
        return r_out ";" g_out ";" b_out
    }

    function get_color(ratio) {
        if (ratio <= 0) return interpolate(colors[1], colors[1], 0)
        if (ratio >= 1) return interpolate(colors[n_colors], colors[n_colors], 0)
        
        # Encontrar en qué segmento del gradiente cae el ratio
        seg_idx = int(ratio * (n_colors - 1)) + 1
        seg_ratio = (ratio - (seg_idx - 1) / (n_colors - 1)) * (n_colors - 1)
        return interpolate(colors[seg_idx], colors[seg_idx+1], seg_ratio)
    }

    {
        y = NR - 1
        len = length($0)
        for (x = 1; x <= len; x++) {
            char = substr($0, x, 1)
            
            # Calcular ratio según el modo
            if (mode == "horizontal") ratio = (w > 1 ? (x - 1) / (w - 1) : 0)
            else if (mode == "diagonal") ratio = ((h + w - 2) > 0 ? (y + x - 2) / (h + w - 2) : 0)
            else ratio = (h > 1 ? y / (h - 1) : 0) # vertical por defecto

            color = get_color(ratio)
            printf "\033[38;2;%sm%s", color, char
        }
        printf "\033[0m\n"
    }
    ' "$input" > "$output"
}

# ── MAIN ──
mkdir -p "$PROCESSED_DIR"
find "$ASCII_DIR" -type f -name "*.txt" | while read -r input_file; do
    filename=$(basename "$input_file")
    echo -n "  🎨 [$GRADIENT_MODE] Procesando: $filename ... "
    process_file "$input_file" "$PROCESSED_DIR/$filename" && echo "Hecho." || echo "FALLÓ."
done

cp "$GRADIENT_CONF" "$GRADIENT_BAK" 2>/dev/null || true
