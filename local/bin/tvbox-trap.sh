#!/bin/bash
set -euo pipefail

AP="wlan0"
AP_ADDR="10.10.10.1/24"
AP_NET="10.10.10.0/24"
VPN_IF="proton0"
DNSMASQ_CONF="/etc/dnsmasq-tvbox.conf"
HOSTAPD_CONF="/etc/hostapd/tvbox.conf"
CAPDIR="$HOME/capturas"
STAMP="$(date +%F_%H%M%S)"
PCAP="$CAPDIR/tvbox-$STAMP.pcap"
PIDDIR="/run/tvboxlab"

cleanup() {
  echo "[*] Deteniendo captura y servicios..."
  [ -f "$PIDDIR/tcpdump.pid" ] && kill "$(cat "$PIDDIR/tcpdump.pid")" 2>/dev/null || true
  [ -f "$PIDDIR/dnsmasq.pid" ] && kill "$(cat "$PIDDIR/dnsmasq.pid")" 2>/dev/null || true
  [ -f "$PIDDIR/hostapd.pid" ] && kill "$(cat "$PIDDIR/hostapd.pid")" 2>/dev/null || true

  echo "[*] Limpiando reglas iptables del laboratorio..."
  iptables -D FORWARD -i "$AP" -o "$VPN_IF" -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -i "$VPN_IF" -o "$AP" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s "$AP_NET" -o "$VPN_IF" -j MASQUERADE 2>/dev/null || true
  iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

  echo "[*] Bajando interfaz $AP..."
  ip addr flush dev "$AP" 2>/dev/null || true
  ip link set "$AP" down 2>/dev/null || true

  rm -rf "$PIDDIR"
  echo "[+] Laboratorio detenido."
}

if [[ "${1:-}" == "stop" ]]; then
  cleanup
  exit 0
fi

echo "[1/8] Verificando requisitos..."
command -v ip >/dev/null
command -v iptables >/dev/null
command -v dnsmasq >/dev/null
command -v hostapd >/dev/null
command -v tcpdump >/dev/null

mkdir -p "$CAPDIR" "$PIDDIR"

if ! ip link show "$AP" >/dev/null 2>&1; then
  echo "[-] No existe la interfaz AP: $AP"
  exit 1
fi

if ! ip link show "$VPN_IF" >/dev/null 2>&1; then
  echo "[-] No existe la interfaz VPN: $VPN_IF"
  exit 1
fi

echo "[2/8] Mostrando ruta por defecto actual..."
ip route show default || true

echo "[3/8] Preparando $AP..."
systemctl stop iwd 2>/dev/null || true
pkill -x dnsmasq 2>/dev/null || true
pkill -x hostapd 2>/dev/null || true

ip link set "$AP" down || true
sleep 1
ip addr flush dev "$AP" || true
ip addr add "$AP_ADDR" dev "$AP"
ip link set "$AP" up

echo "[4/8] Activando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[5/8] Aplicando reglas iptables..."
iptables -C FORWARD -i "$AP" -o "$VPN_IF" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "$AP" -o "$VPN_IF" -j ACCEPT

iptables -C FORWARD -i "$VPN_IF" -o "$AP" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "$VPN_IF" -o "$AP" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -t nat -C POSTROUTING -s "$AP_NET" -o "$VPN_IF" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "$AP_NET" -o "$VPN_IF" -j MASQUERADE

iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

echo "[6/8] Verificando configuración de dnsmasq..."
if [[ ! -f "$DNSMASQ_CONF" ]]; then
  cat <<'EOF' > /tmp/dnsmasq-tvbox.example
interface=wlan0
bind-interfaces
dhcp-range=10.10.10.10,10.10.10.80,255.255.255.0,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,10.10.10.1
listen-address=10.10.10.1
no-resolv
server=1.1.1.1
server=8.8.8.8
log-queries
log-dhcp
EOF
  echo "[-] No existe $DNSMASQ_CONF"
  echo "[*] Te dejé un ejemplo en /tmp/dnsmasq-tvbox.example"
  exit 1
fi

if [[ ! -f "$HOSTAPD_CONF" ]]; then
  echo "[-] No existe $HOSTAPD_CONF"
  exit 1
fi

echo "[7/8] Iniciando dnsmasq, hostapd y tcpdump..."
dnsmasq --conf-file="$DNSMASQ_CONF" --keep-in-foreground > /tmp/dnsmasq-tvbox.log 2>&1 &
echo $! > "$PIDDIR/dnsmasq.pid"

hostapd "$HOSTAPD_CONF" > /tmp/hostapd-tvbox.log 2>&1 &
echo $! > "$PIDDIR/hostapd.pid"

tcpdump -i "$AP" -n -s 0 -w "$PCAP" > /tmp/tcpdump-tvbox.log 2>&1 &
echo $! > "$PIDDIR/tcpdump.pid"

sleep 2

echo "[8/8] Estado rápido..."
echo "Ruta default:"
ip route show default || true
echo
echo "FORWARD:"
iptables -L FORWARD -v --line-numbers
echo
echo "NAT:"
iptables -t nat -L POSTROUTING -v --line-numbers
echo
echo "MANGLE:"
iptables -t mangle -L FORWARD -v --line-numbers

cat <<EOF

[+] Laboratorio activo
SSID: revisa $HOSTAPD_CONF
AP IP: 10.10.10.1
VPN IF: $VPN_IF
Captura: $PCAP

Logs:
  /tmp/dnsmasq-tvbox.log
  /tmp/hostapd-tvbox.log
  /tmp/tcpdump-tvbox.log

Para detener todo:
  sudo $0 stop

Comandos útiles:
  sudo iptables -L FORWARD -v --line-numbers
  sudo iptables -t nat -L POSTROUTING -v --line-numbers
  sudo journalctl -f
  sudo tcpdump -i $AP -n port 53
EOF
