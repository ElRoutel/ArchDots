#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# HYBRID LAUNCHER — DEBUG MODE + SAFE KITTY
# Uso: ff        → normal
#      ff --debug → con tiempos
# ═══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
IMG_DIR="$CONFIG_DIR/pngs"
PROCESSED_ASCII_DIR="$CONFIG_DIR/processedASCII"
GRADIENT_PROCESSOR="$CONFIG_DIR/bin/gradient_processor.sh"

# ── Configuración de Umbrales de Tamaño ───────────────────────────────────────
# IMPORTANTE: Estos valores garantizan espacio suficiente para imagen + columnas de info
MIN_COLS_IMG=110        # 34 (logo) + 2 (padding) + 70 (info) + margen
MIN_LINES_IMG=26        # 16 (logo) + 1 (padding-top) + 8 (info) + margen
MIN_COLS_ASCII=85       # ASCII suele ser más angosto
MIN_LINES_ASCII=22      # ASCII más compacto verticalmente
MIN_COLS_TINY=60        # Umbral para fallback sin logo

IMG_CHANCE=50
DEBUG=false
[[ "${1:-}" == "--debug" ]] && DEBUG=true

# ── Timer helper ──────────────────────────────────────────────────────────────
_t0=$(date +%s%3N)
_last=$_t0

tick() {
    if $DEBUG; then
        local now=$(date +%s%3N)
        local delta=$((now - _last))
        local total=$((now - _t0))
        printf "\\e[90m[DEBUG] %-40s +%dms  (total: %dms)\\e[0m\\n" "$1" "$delta" "$total" >&2
        _last=$now
    fi
}

tick "script start"

# ── Obtener dimensiones de la terminal ────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
tick "terminal size: ${COLS}x${LINES}"

# ── Funciones ─────────────────────────────────────────────────────────────────
calculate_safe_logo_dimensions() {
    local max_width=$((COLS - 50))   # Reservar espacio para info
    local max_height=$((LINES - 10)) # Reservar espacio para info vertical
    
    # Clamp a valores razonables
    [ "$max_width" -lt 20 ] && max_width=20
    [ "$max_width" -gt 40 ] && max_width=40
    [ "$max_height" -lt 12 ] && max_height=12
    [ "$max_height" -gt 20 ] && max_height=20
    
    echo "$max_width $max_height"
}

try_run_image() {
    tick "try_run_image: start"

    if [ "$COLS" -lt "$MIN_COLS_IMG" ] || [ "$LINES" -lt "$MIN_LINES_IMG" ]; then
        tick "try_run_image: terminal too small (${COLS}x${LINES} < ${MIN_COLS_IMG}x${MIN_LINES_IMG})"
        return 1
    fi

    [ ! -d "$IMG_DIR" ] && { tick "try_run_image: no IMG_DIR"; return 1; }

    mapfile -t images < <(find "$IMG_DIR" -type f -name "*.png" 2>/dev/null)
    tick "try_run_image: find pngs (${#images[@]} found)"
    [ ${#images[@]} -eq 0 ] && return 1

    local selected="${images[$RANDOM % ${#images[@]}]}"
    
    # Calcular dimensiones seguras basadas en el tamaño de la terminal
    read -r safe_width safe_height <<< "$(calculate_safe_logo_dimensions)"
    
    $DEBUG && {
        echo -e "\\e[90m[DEBUG] selected: $selected\\e[0m" >&2
        echo -e "\\e[90m[DEBUG] safe dimensions: ${safe_width}x${safe_height}\\e[0m" >&2
    }
    
    tick "try_run_image: calling fastfetch (${safe_width}x${safe_height})"

    fastfetch \
        --logo "$selected" \
        --logo-type kitty \
        --logo-width "$safe_width" \
        --logo-height "$safe_height" \
        --logo-padding-top 1 \
        --logo-padding-right 2

    local exit_code=$?
    tick "try_run_image: fastfetch done (exit: $exit_code)"
    return $exit_code
}

try_run_ascii() {
    tick "try_run_ascii: start"

    if [ "$COLS" -lt "$MIN_COLS_ASCII" ] || [ "$LINES" -lt "$MIN_LINES_ASCII" ]; then
        tick "try_run_ascii: terminal too small (${COLS}x${LINES} < ${MIN_COLS_ASCII}x${MIN_LINES_ASCII})"
        return 1
    fi

    if [ -x "$GRADIENT_PROCESSOR" ]; then
        local count=0
        [ -d "$PROCESSED_ASCII_DIR" ] && count=$(find "$PROCESSED_ASCII_DIR" -name "*.txt" 2>/dev/null | wc -l)
        tick "try_run_ascii: count check ($count files)"
        if [ "$count" -eq 0 ]; then
            tick "try_run_ascii: running gradient_processor"
            "$GRADIENT_PROCESSOR" >/dev/null 2>&1 || true
            tick "try_run_ascii: gradient_processor done"
        fi
    fi

    [ ! -d "$PROCESSED_ASCII_DIR" ] && return 1
    mapfile -t txts < <(find "$PROCESSED_ASCII_DIR" -type f -name "*.txt" 2>/dev/null)
    tick "try_run_ascii: find txts (${#txts[@]} found)"
    [ ${#txts[@]} -eq 0 ] && return 1

    local selected="${txts[$RANDOM % ${#txts[@]}]}"
    $DEBUG && echo -e "\\e[90m[DEBUG] selected: $selected\\e[0m" >&2
    tick "try_run_ascii: calling fastfetch"

    fastfetch \
        --logo "$selected" \
        --logo-type file-raw \
        --logo-padding-top 1 \
        --logo-padding-right 3

    local exit_code=$?
    tick "try_run_ascii: fastfetch done (exit: $exit_code)"
    return $exit_code
}

fallback_safe_mode() {
    tick "fallback_safe_mode: using built-in ASCII"
    # Usar logo pequeño built-in de fastfetch que siempre funciona
    fastfetch --logo-type auto --logo-padding-right 2
}

# ── Main ──────────────────────────────────────────────────────────────────────
if [ "$COLS" -lt "$MIN_COLS_TINY" ]; then
    tick "main: terminal is tiny (${COLS}x${LINES}), using no-logo mode"
    fastfetch --logo none
else
    ROLL=$((1 + RANDOM % 100))
    tick "main: roll=$ROLL (img_chance=$IMG_CHANCE)"

    if [ "$ROLL" -le "$IMG_CHANCE" ]; then
        # Intentar imagen → ASCII → fallback seguro
        try_run_image || try_run_ascii || fallback_safe_mode
    else
        # Intentar ASCII → imagen → fallback seguro
        try_run_ascii || try_run_image || fallback_safe_mode
    fi
fi

tick "TOTAL DONE"

