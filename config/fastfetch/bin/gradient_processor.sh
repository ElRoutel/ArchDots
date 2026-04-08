#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# GRADIENT PROCESSOR - VERSIÓN ROBUSTA
# ═══════════════════════════════════════════════════════════════════════════════

# Desactivamos 'set -e' estricto para evitar cierres silenciosos. 
# Controlaremos los errores manualmente.
set -u

# Forzar modo numérico inglés (puntos para decimales)
export LC_NUMERIC=C 

# ── CONFIGURACIÓN ──
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
ASCII_DIR="$CONFIG_DIR/ascii"
PROCESSED_DIR="$CONFIG_DIR/processedASCII"
GRADIENT_CONF="$CONFIG_DIR/gradient.conf"
GRADIENT_BAK="$CONFIG_DIR/.gradient.conf.bak"

# ── FUNCIONES ──

log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[OK]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1" >&2; }

interpolate() {
    # awk seguro para evitar errores de división o sintaxis
    awk -v s="$1" -v e="$2" -v r="$3" 'BEGIN { printf "%.0f", s + (e - s) * r }'
}

process_ascii_file() {
    local input="$1"
    local output="$2"
    local temp_file="/tmp/fastfetch_proc_$$.tmp"
    
    # Verificar existencia
    if [ ! -f "$input" ]; then
        log_error "No se puede leer: $input"
        return 1
    fi

    # Contar líneas (manejo seguro de wc)
    local total_lines
    total_lines=$(wc -l < "$input" | tr -d ' ')

    if [ "$total_lines" -eq 0 ]; then
        log_error "Archivo vacío: $(basename "$input")"
        return 1
    fi

    local current_line=0
    
    # Bucle de lectura línea a línea
    while IFS= read -r line || [ -n "$line" ]; do
        # Calcular ratio (progreso de 0 a 1)
        local ratio=0
        if [ "$total_lines" -gt 1 ]; then
            # Usamos awk para la división flotante
            ratio=$(awk -v c="$current_line" -v t="$total_lines" 'BEGIN { print c / (t - 1) }')
        fi

        # Calcular colores
        local r=$(interpolate "$COLOR_TOP_R" "$COLOR_BOTTOM_R" "$ratio")
        local g=$(interpolate "$COLOR_TOP_G" "$COLOR_BOTTOM_G" "$ratio")
        local b=$(interpolate "$COLOR_TOP_B" "$COLOR_BOTTOM_B" "$ratio")

        # Escribir al temporal
        echo -e "\u001b[38;2;${r};${g};${b}m${line}\u001b[0m" >> "$temp_file"
        
        ((current_line++))
    done < "$input"

    # Mover archivo final
    mv "$temp_file" "$output"
}

# ── MAIN ──

# 1. Verificar directorios
mkdir -p "$PROCESSED_DIR"
if [ ! -d "$ASCII_DIR" ]; then
    log_error "Directorio ASCII no encontrado: $ASCII_DIR"
    exit 1
fi

# 2. Cargar Configuración
if [ -f "$GRADIENT_CONF" ]; then
    source "$GRADIENT_CONF"
else
    log_error "Falta $GRADIENT_CONF"
    exit 1
fi

# 3. Detectar si forzamos reprocesado
force_reprocess=false
if [ ! -f "$GRADIENT_BAK" ]; then
    log_info "Primera ejecución detectada."
    force_reprocess=true
elif ! cmp -s "$GRADIENT_CONF" "$GRADIENT_BAK"; then
    log_info "Configuración modificada. Reprocesando..."
    force_reprocess=true
fi

# 4. Bucle de Procesamiento (Modo Compatible)
count=0
echo "📂 Buscando archivos en $ASCII_DIR..."

# Usamos find con while read para máxima compatibilidad
find "$ASCII_DIR" -type f -name "*.txt" | while read -r input_file; do
    filename=$(basename "$input_file")
    output_file="$PROCESSED_DIR/$filename"
    
    should_process=false
    
    if [ "$force_reprocess" = true ]; then
        should_process=true
    elif [ ! -f "$output_file" ]; then
        should_process=true
    elif [ "$input_file" -nt "$output_file" ]; then
        should_process=true
    fi
    
    if [ "$should_process" = true ]; then
        echo -n "  🎨 Procesando: $filename ... "
        if process_ascii_file "$input_file" "$output_file"; then
            echo "Hecho."
            ((count++))
        else
            echo "FALLÓ."
        fi
    else
        echo "  ⏭️  Saltado: $filename (actualizado)"
    fi
done

# 5. Finalizar
log_success "Proceso terminado."
cp "$GRADIENT_CONF" "$GRADIENT_BAK" 2>/dev/null || true
