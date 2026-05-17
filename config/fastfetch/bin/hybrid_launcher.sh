#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# HYBRID LAUNCHER — DEBUG MODE + SAFE KITTY + COWTHINK + THEMES
# Uso: ff                 → Aleatorio (Imagen o ASCII) del tema actual
#      ff -themels        → Lista los temas disponibles y el activo
#      ff -theme <nombre> → Cambia el tema global y lo guarda
#      ff -theme default  → Restaura la configuración a las rutas originales
#      ff -adjust         → Recorte inteligente del ASCII para mejor alineación
#      ff --debug         → Con tiempos de ejecución
#      ff --img           → Fuerza renderizado de imagen (Kitty)
#      ff --ascii | -ct   → Fuerza renderizado de ASCIIs procesados
#      ff -cts "txt"      → Fuerza renderizado de Cowthink con mensaje
#      ff -gr             → Fuerza regeneración de gradientes (procesador)
#      ff -t <ruta|txt>   → Modo test: prueba un ASCII sin procesar
# ═══════════════════════════════════════════════════════════════════════════════

# ── Fail-fast: Verificar dependencia principal ────────────────────────────────
if ! command -v fastfetch >/dev/null 2>&1; then
    echo -e "\e[31mError: fastfetch no está instalado o no está en el PATH.\e[0m" >&2
    exit 1
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
THEMES_DIR="$CONFIG_DIR/themes"
STATE_FILE="$CONFIG_DIR/current_theme"
GRADIENT_PROCESSOR="$CONFIG_DIR/bin/gradient_processor.sh"

# ── Configuración de Umbrales de Tamaño ───────────────────────────────────────
MIN_COLS_IMG=110
MIN_LINES_IMG=26
MIN_COLS_ASCII=85
MIN_LINES_ASCII=22
MIN_COLS_TINY=60

IMG_CHANCE=50
DEBUG=false
FORCE_MODE="auto"
COW_MSG=""
FORCE_ADJUST=false

# ── Timer helper ──────────────────────────────────────────────────────────────
_t0=$(date +%s%3N)
_last=$_t0

tick() {
    if $DEBUG; then
        local now=$(date +%s%3N)
        local delta=$((now - _last))
        local total=$((now - _t0))
        printf "\e[90m[DEBUG] %-40s +%dms  (total: %dms)\e[0m\n" "$1" "$delta" "$total" >&2
        _last=$now
    fi
}

tick "script start"

# ── Parseo de Argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -adjust)
            FORCE_ADJUST=true; shift ;;
        -gr)
            echo -e "\e[36m[i] Regenerando gradientes para TODOS los temas...\e[0m"
            # 1. Procesar Global
            echo -e "\e[33m[>] Procesando Global...\e[0m"
            unset THEME_BASE
            bash "$GRADIENT_PROCESSOR" >/dev/null 2>&1
            
            # 2. Procesar cada tema
            if [ -d "$THEMES_DIR" ]; then
                for t in "$THEMES_DIR"/*/; do
                    [ -d "$t" ] || continue
                    theme_name=$(basename "$t")
                    echo -e "\e[33m[>] Procesando Tema: $theme_name...\e[0m"
                    export THEME_BASE="${t%/}"
                    bash "$GRADIENT_PROCESSOR"
                done
            fi
            echo -e "\e[32m[+] Proceso completado.\e[0m"
            exit 0
            ;;
        -t)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                clear
                sleep 0.5
                TEST_INPUT="$2"
                TEST_FILE=""
                
                if [ -f "$TEST_INPUT" ]; then
                    TEST_FILE="$TEST_INPUT"
                else
                    TEST_FILE="${XDG_RUNTIME_DIR:-/tmp}/ff_test_$$.txt"
                    printf "%s\n" "$TEST_INPUT" > "$TEST_FILE"
                fi
                
                echo -e "\e[36m[i] Modo Test: Visualizando ASCII sin procesar...\e[0m"
                fastfetch "${FF_ARGS[@]}" --logo "$TEST_FILE" --logo-type file-raw --logo-padding-top 1 --logo-padding-right 3
                
                # Limpiar si es temporal
                [ "$TEST_FILE" != "$TEST_INPUT" ] && rm -f "$TEST_FILE"
                exit 0
            else
                echo -e "\e[31mError: Falta la ruta o el texto para el modo test.\e[0m" >&2
                exit 1
            fi
            ;;
        -themels)
            echo -e "\e[36m[i] Temas disponibles:\e[0m"
            echo -e "  - \e[32mdefault\e[0m (Configuración original)"
            if [ -d "$THEMES_DIR" ]; then
                for t in "$THEMES_DIR"/*/; do
                    [ -d "$t" ] || continue
                    theme_name=$(basename "$t")
                    echo "  - $theme_name"
                done
            fi
            
            current="default"
            [ -f "$STATE_FILE" ] && current=$(cat "$STATE_FILE")
            echo -e "\n\e[36m[i] Tema actual activo:\e[0m \e[33m$current\e[0m"
            exit 0
            ;;
        -theme)
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                if [ "$2" = "default" ]; then
                    echo "default" > "$STATE_FILE"
                    echo -e "\e[32m[+] Tema restaurado a: default (Original)\e[0m"
                    # Ejecutar procesador para modo global
                    unset THEME_BASE
                    bash "$GRADIENT_PROCESSOR" >/dev/null 2>&1
                    shift 2
                elif [ -d "$THEMES_DIR/$2" ]; then
                    echo "$2" > "$STATE_FILE"
                    echo -e "\e[32m[+] Tema cambiado a: $2\e[0m"
                    # Ejecutar procesador para el nuevo tema
                    export THEME_BASE="$THEMES_DIR/$2"
                    bash "$GRADIENT_PROCESSOR"
                    shift 2
                else
                    echo -e "\e[31mError: El tema '$2' no existe en $THEMES_DIR\e[0m" >&2
                    exit 1
                fi
            else
                echo -e "\e[31mError: Falta el nombre del tema.\e[0m" >&2
                exit 1
            fi
            ;;
        --debug) 
            DEBUG=true; shift ;;
        --img) 
            FORCE_MODE="img"; shift ;;
        --ascii|-ct) 
            FORCE_MODE="ascii"; shift ;;
        -cts)
            FORCE_MODE="cowthink"
            if [ -n "$2" ] && [[ "$2" != -* ]]; then
                COW_MSG="$2"
                shift 2
            else
                COW_MSG="Pensando en ricing..."
                shift 1
            fi
            ;;
        *) 
            shift ;;
    esac
done

# ── Cargar Tema Actual (Después de parseo de argumentos) ──────────────────────
CURRENT_THEME="default"
[ -f "$STATE_FILE" ] && CURRENT_THEME=$(cat "$STATE_FILE")

# Definir rutas base dependiendo del tema
if [ "$CURRENT_THEME" != "default" ] && [ -d "$THEMES_DIR/$CURRENT_THEME" ]; then
    tick "theme loaded: $CURRENT_THEME"
    THEME_BASE="$THEMES_DIR/$CURRENT_THEME"
    IMG_DIR="$THEME_BASE/pngs"
    PROCESSED_ASCII_DIR="$THEME_BASE/processedASCII"
    
    # Preparar array de argumentos base para fastfetch
    FF_ARGS=()
    if [ -f "$THEME_BASE/config.jsonc" ]; then
        FF_ARGS+=(--config "$THEME_BASE/config.jsonc")
        tick "using custom config: $THEME_BASE/config.jsonc"
    fi
else
    tick "using default paths"
    THEME_BASE=""
    IMG_DIR="$CONFIG_DIR/pngs"
    PROCESSED_ASCII_DIR="$CONFIG_DIR/processedASCII"
    FF_ARGS=()
fi

# ── Timer helper ──────────────────────────────────────────────────────────────

# ── Obtener dimensiones de la terminal ────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
LINES=$(tput lines 2>/dev/null || echo 24)
tick "terminal size: ${COLS}x${LINES}"

# ── Funciones ─────────────────────────────────────────────────────────────────
calculate_safe_logo_dimensions() {
    local max_width=$((COLS - 50))
    local max_height=$((LINES - 10))
    
    [ "$max_width" -lt 20 ] && max_width=20
    [ "$max_width" -gt 40 ] && max_width=40
    [ "$max_height" -lt 12 ] && max_height=12
    [ "$max_height" -gt 20 ] && max_height=20
    
    echo "$max_width $max_height"
}

try_run_image() {
    tick "try_run_image: start"

    if [[ "$TERM" != *"kitty"* ]] && [[ "$TERM_PROGRAM" != *"WezTerm"* ]] && [[ "$TERM" != *"foot"* ]]; then
        tick "try_run_image: Terminal doesn't support kitty graphics protocol"
        return 1
    fi

    if [ "$COLS" -lt "$MIN_COLS_IMG" ] || [ "$LINES" -lt "$MIN_LINES_IMG" ]; then
        tick "try_run_image: terminal too small"
        return 1
    fi

    [ ! -d "$IMG_DIR" ] && return 1

    local selected
    selected=$(find "$IMG_DIR" -type f -name "*.png" 2>/dev/null | shuf -n 1)
    [ -z "$selected" ] && return 1
    
    read -r safe_width safe_height <<< "$(calculate_safe_logo_dimensions)"
    tick "try_run_image: calling fastfetch (${safe_width}x${safe_height})"

    fastfetch "${FF_ARGS[@]}" \
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
        tick "try_run_ascii: terminal too small"
        return 1
    fi

    # Definir ASCII_DIR para comparación
    local current_ascii_dir
    if [ "$CURRENT_THEME" != "default" ] && [ -d "$THEMES_DIR/$CURRENT_THEME" ]; then
        current_ascii_dir="$THEMES_DIR/$CURRENT_THEME/ascii"
    else
        current_ascii_dir="$CONFIG_DIR/ascii"
    fi

    if [ -x "$GRADIENT_PROCESSOR" ]; then
        local count_processed=0
        local count_ascii=0
        [ -d "$PROCESSED_ASCII_DIR" ] && count_processed=$(find "$PROCESSED_ASCII_DIR" -name "*.txt" 2>/dev/null | wc -l)
        [ -d "$current_ascii_dir" ] && count_ascii=$(find "$current_ascii_dir" -name "*.txt" 2>/dev/null | wc -l)
        
        if [ "$count_processed" -eq 0 ] || [ "$count_ascii" -ne "$count_processed" ]; then
            echo -e "\e[36m[i] Detectados cambios en ASCII, procesando gradientes...\e[0m"
            tick "try_run_ascii: running gradient_processor (ascii=$count_ascii, processed=$count_processed)"
            export THEME_BASE PROCESSED_ASCII_DIR
            "$GRADIENT_PROCESSOR" || true
        fi
    fi

    [ ! -d "$PROCESSED_ASCII_DIR" ] && return 1
    
    local selected
    selected=$(find "$PROCESSED_ASCII_DIR" -type f -name "*.txt" 2>/dev/null | shuf -n 1)
    [ -z "$selected" ] && return 1

    # ── Lógica de Ajuste Inteligente (Smart Crop + Box Closer) ────────────────
    if [ "$FORCE_ADJUST" = true ]; then
        tick "adjust mode: running fastfetch to buffer"
        
        # 1. Preparar el logo recortado
        local adj_logo="${XDG_RUNTIME_DIR:-/tmp}/ff_logo_$$.txt"
        sed 's/[[:space:]]*$//' "$selected" > "$adj_logo.tmp"
        local min_indent
        min_indent=$(sed 's/\x1b\[[0-9;]*m//g' "$adj_logo.tmp" | grep '[^[:space:]]' | awk '{ 
            match($0, /[^[:space:]]/); 
            indent = RSTART - 1;
            if (min == "" || indent < min) min = indent 
        } END { print (min == "" ? 0 : min) }')
        
        if [ -n "$min_indent" ] && [ "$min_indent" -gt 0 ]; then
            sed "s/^[[:space:]]\{$min_indent\}//" "$adj_logo.tmp" > "$adj_logo"
        else
            mv "$adj_logo.tmp" "$adj_logo"
        fi

        tick "adjust mode: pipe processing for box alignment"
        
        # 2. Ejecutar fastfetch y procesar la salida en tiempo real
        fastfetch "${FF_ARGS[@]}" \
            --logo "$adj_logo" \
            --logo-type file-raw \
            --logo-padding-top 1 \
            --logo-padding-right 3 \
            --logo-padding-left 0 | awk '
        BEGIN { max_w = 0 }
        {
            lines[NR] = $0
            p = $0
            gsub(/\x1b\[[0-9;]*m/, "", p) # Quitar ANSI para medir real
            # Identificar el ancho de la caja buscando líneas de bordes horizontales (─ o ═)
            if (p ~ /[─━═]{10,}/) {
                if (length(p) > max_w) max_w = length(p)
            }
        }
        END {
            for (i=1; i<=NR; i++) {
                l = lines[i]
                p = l
                gsub(/\x1b\[[0-9;]*m/, "", p)
                
                # Si la línea es parte del contenido (empieza con un vertical de caja)
                # pero NO termina con un cierre de caja (esquina o vertical)
                if (p ~ /^[[:space:]]*[│┃║].*[^│┃║╮┓╗╯┛╝]$/) {
                    match(p, /[│┃║]/)
                    v_char = substr(p, RSTART, 1)
                    needed = max_w - length(p) - 1
                    if (needed > 0) {
                        # Añadir espacios de relleno y el cierre
                        printf "%s%*s%s\n", l, needed, "", v_char
                    } else {
                        printf "%s%s\n", l, v_char
                    }
                } else {
                    print l
                }
            }
        }'
        
        rm -f "$adj_logo"*
        return 0
    fi

    tick "try_run_ascii: calling fastfetch"

    fastfetch "${FF_ARGS[@]}" \
        --logo "$selected" \
        --logo-type file-raw \
        --logo-padding-top 1 \
        --logo-padding-right 3

    local exit_code=$?
    # Limpiar archivo temporal si se usó -adjust
    [ "$FORCE_ADJUST" = true ] && rm -f "${XDG_RUNTIME_DIR:-/tmp}/ff_adj_$$"*
    tick "try_run_ascii: fastfetch done (exit: $exit_code)"
    return $exit_code
}

try_run_cowthink() {
    tick "try_run_cowthink: start"

    if ! command -v cowthink >/dev/null 2>&1; then
        echo -e "\e[31mError: 'cowthink' no está instalado.\e[0m" >&2
        return 1
    fi

    local tmp_cow="${XDG_RUNTIME_DIR:-/tmp}/ff_cowthink_$$.txt"
    cowthink "$COW_MSG" > "$tmp_cow"

    tick "try_run_cowthink: calling fastfetch"

    fastfetch "${FF_ARGS[@]}" \
        --logo "$tmp_cow" \
        --logo-type file-raw \
        --logo-padding-top 1 \
        --logo-padding-right 3

    local exit_code=$?
    rm -f "$tmp_cow"
    
    tick "try_run_cowthink: fastfetch done (exit: $exit_code)"
    return $exit_code
}

fallback_safe_mode() {
    tick "fallback_safe_mode: using built-in ASCII"
    fastfetch "${FF_ARGS[@]}" --logo-type auto --logo-padding-right 2
}

# ── Main ──────────────────────────────────────────────────────────────────────
if [ "$COLS" -lt "$MIN_COLS_TINY" ]; then
    tick "main: terminal is tiny (${COLS}x${LINES}), using no-logo mode"
    fastfetch "${FF_ARGS[@]}" --logo none
elif [ "$FORCE_MODE" = "img" ]; then
    tick "main: force img mode"
    try_run_image || fallback_safe_mode
elif [ "$FORCE_MODE" = "ascii" ]; then
    tick "main: force ascii mode (-ct)"
    try_run_ascii || fallback_safe_mode
elif [ "$FORCE_MODE" = "cowthink" ]; then
    tick "main: force cowthink mode (-cts)"
    try_run_cowthink || fallback_safe_mode
else
    ROLL=$((1 + RANDOM % 100))
    tick "main: roll=$ROLL (img_chance=$IMG_CHANCE)"

    if [ "$ROLL" -le "$IMG_CHANCE" ]; then
        try_run_image || try_run_ascii || fallback_safe_mode
    else
        try_run_ascii || try_run_image || fallback_safe_mode
    fi
fi

tick "TOTAL DONE"
