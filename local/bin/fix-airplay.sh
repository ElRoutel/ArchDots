#!/usr/bin/env bash
# fix-airplay.sh — Reinicia la cadena AirPlay -> MPRIS -> Waybar cuando
# el título de la canción deja de aparecer en la barra.
#
# Causa típica: un crash-loop de shairport-sync deja a playerctld con un
# estado corrupto, y playerctl/Waybar dejan de ver al reproductor
# org.mpris.MediaPlayer2.ShairportSync aunque D-Bus sí lo tenga registrado.

set -u

log() { printf '\033[1;36m::\033[0m %s\n' "$*"; }

# 1. Asegura que solo corra la instancia de USUARIO de shairport-sync
#    (la de root no tiene acceso a PipeWire y roba el puerto 7000).
if systemctl is-active --quiet shairport-sync.service 2>/dev/null; then
    log "Deteniendo instancia de sistema (root) de shairport-sync..."
    sudo systemctl disable --now shairport-sync.service
fi

log "Reiniciando shairport-sync del usuario..."
systemctl --user restart shairport-sync.service
sleep 1

# 2. playerctld no es un servicio: se relanza solo al invocar playerctl.
log "Limpiando playerctld (estado envenenado)..."
killall playerctld 2>/dev/null && sleep 1 || true

# 3. Relanza Waybar para que su módulo mpris tome el estado limpio.
log "Relanzando Waybar..."
killall waybar 2>/dev/null
sleep 1
setsid waybar >/tmp/waybar.log 2>&1 </dev/null &
sleep 2

# 4. Verificación
log "Verificando..."
if playerctl -l 2>/dev/null | grep -q ShairportSync; then
    status=$(playerctl -p ShairportSync status 2>/dev/null)
    title=$(playerctl -p ShairportSync metadata xesam:title 2>/dev/null)
    printf '\033[1;32m OK\033[0m: ShairportSync detectado (%s) — %s\n' "${status:-?}" "${title:-sin metadatos}"
else
    printf '\033[1;33m Aviso\033[0m: ShairportSync aún no aparece. '
    echo "Reconecta el AirPlay desde el iPhone y reintenta."
fi
