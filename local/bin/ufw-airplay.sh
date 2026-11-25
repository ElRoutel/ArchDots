#!/usr/bin/env bash
# ufw-airplay.sh — Permite AirPlay 2 (shairport-sync) a traves de ufw
# confiando en la RED LOCAL, en IPv4 e IPv6.
#
# Por que "confiar en la LAN" y no abrir puertos sueltos:
# AirPlay 2 NO usa puertos fijos para el audio. shairport-sync abre
# puertos altos ALEATORIOS y efimeros en cada sesion (ej. 40643, 38867...),
# ademas del PTP (319/320) y el control (7000). Enumerarlos es imposible.
# Ademas el iPhone se conecta por IPv6, no por IPv4. La solucion estandar
# para un receptor multimedia domestico es confiar en la propia red local:
# se abre TODO solo para tu LAN (IPv4 + tu /64 IPv6 + link-local), lo que
# NO expone nada a internet (solo hosts dentro de tu propia red encajan).
#
# Ejecutar con: sudo ~/.local/bin/ufw-airplay.sh
set -euo pipefail

IFACE="enp2s0"
LAN4="192.168.1.0/24"
LL6="fe80::/10"   # IPv6 link-local

# Detecta el prefijo /64 IPv6 global de la interfaz (se adapta si el ISP lo cambia)
GUA=$(ip -6 addr show dev "$IFACE" scope global 2>/dev/null \
        | grep -m1 inet6 | awk '{print $2}')
NET6=$(printf '%s\n' "$GUA" | sed -E 's|^([0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+):.*|\1::/64|')

echo ":: Interfaz: $IFACE"
echo ":: LAN IPv4: $LAN4"
echo ":: LAN IPv6: ${NET6:-<no detectada>}  +  link-local $LL6"
echo

echo ":: Limpiando reglas AirPlay por-puerto previas (ya no se usan)..."
ufw --force delete allow 5353/udp     2>/dev/null || true
ufw --force delete allow 319,320/udp  2>/dev/null || true
ufw --force delete allow 7000/tcp     2>/dev/null || true
ufw --force delete allow 6001:6010/udp 2>/dev/null || true

echo ":: Confiando en la red local para AirPlay..."
ufw allow in on "$IFACE" from "$LAN4" comment 'AirPlay LAN v4'
ufw allow in on "$IFACE" from "$LL6"  comment 'AirPlay v6 link-local'
if [[ -n "${NET6:-}" ]]; then
    ufw allow in on "$IFACE" from "$NET6" comment 'AirPlay LAN v6'
else
    echo "   AVISO: no se detecto prefijo IPv6 global; revisa 'ip -6 addr'."
fi

ufw reload
echo
echo ":: Listo. Reglas AirPlay activas:"
ufw status verbose | grep -i airplay
