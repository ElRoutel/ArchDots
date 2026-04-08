#!/bin/bash

# --- CONFIGURACIÓN ---
DIR_ASCII="/home/routel/.config/fastfetch/processedASCII"
DIR_PNG="/home/routel/.config/fastfetch/png"
DIR_POOL="$HOME/.cache/fastfetch-pool"

# Colores para el output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> Actualizando pool de logos para Fastfetch...${NC}"

# 1. Crear el directorio pool si no existe
if [ ! -d "$DIR_POOL" ]; then
    mkdir -p "$DIR_POOL"
    echo "Carpeta pool creada."
fi

# 2. Limpiar el pool actual (para evitar enlaces rotos o archivos viejos)
rm -f "$DIR_POOL"/*
echo "Pool limpiado."

# 3. Crear enlaces simbólicos para imágenes (PNG, GIF, JPG, WEBP)
# Redirigimos stderr a /dev/null por si alguna carpeta no tiene cierto tipo de archivo
count_img=0
find "$DIR_PNG" -type f \( -iname "*.png" -o -iname "*.gif" -o -iname "*.jpg" -o -iname "*.webp" \) -exec ln -sf {} "$DIR_POOL" \; 2>/dev/null
count_img=$(ls -1q "$DIR_PNG" | wc -l)

# 4. Crear enlaces simbólicos para ASCII (TXT)
count_ascii=0
find "$DIR_ASCII" -type f -iname "*.txt" -exec ln -sf {} "$DIR_POOL" \; 2>/dev/null
count_ascii=$(ls -1q "$DIR_ASCII" | wc -l)

# 5. Resumen
total=$(ls -1q "$DIR_POOL" | wc -l)
echo -e "${GREEN}✔ Listo.${NC}"
echo -e "  - Imágenes enlazadas: $count_img (desde $DIR_PNG)"
echo -e "  - ASCIIs enlazados:   $count_ascii (desde $DIR_ASCII)"
echo -e "  - Total en rotación:  $total archivos."
