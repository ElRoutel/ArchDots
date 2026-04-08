#!/usr/bin/env bash

# Este script lee el título de la canción de AirPlay
title="" 

# shairport-sync escribe metadatos en /tmp/shairport-sync-metadata
if [[ -f /tmp/shairport-sync-metadata ]]; then
    # Buscamos el campo de título
    # La salida de shairport-sync tiene formatos tipo:
    # <name>Some Song</name>
    title=$(grep -m 1 '<name>' /tmp/shairport-sync-metadata | sed -E 's/.*<name>(.*)<\/name>.*/\1/' | head -n1)
fi

if [[ -n "$title" ]]; then
    echo " $title"
else
    echo ""
fi

