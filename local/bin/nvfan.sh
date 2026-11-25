#!/bin/bash

# Comprobar si se pasó un argumento
if [ -z "$1" ]; then
    echo "Uso: nvfan {silent|load|auto}"
    exit 1
fi

case "$1" in
    silent)
        echo "Activando modo silencioso (30%)..."
        # Activa el control manual (1) y fija la velocidad al 30%
        nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=30"
        ;;
    load)
        echo "Activando modo de carga pesada (75%)..."
        # Fija la velocidad al 75% para mantener buenas temperaturas
        nvidia-settings -a "[gpu:0]/GPUFanControlState=1" -a "[fan:0]/GPUTargetFanSpeed=75"
        ;;
    auto)
        echo "Devolviendo control automático al driver..."
        # Desactiva el control manual (0)
        nvidia-settings -a "[gpu:0]/GPUFanControlState=0"
        ;;
    *)
        echo "Opción no válida. Usa: nvfan {silent|load|auto}"
        exit 1
        ;;
esac
