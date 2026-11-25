#!/usr/bin/env bash
# fp-check.sh — read-only verification of anti-fingerprinting configuration.
#
# Checks only. Writes nothing, starts/stops nothing, installs nothing.
# Always exits 0 so it is safe in pipelines, hooks and cron.
#
# Legend:
#   PASS  configured as intended
#   FAIL  expected setting missing or wrong
#   SKIP  not applicable here (component absent, or deliberately not applied)
#   INFO  audit-only observation, no pass/fail judgement

# No `set -e`: a failing probe must not abort the run.
set -uo pipefail

# --- output helpers -------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_PASS=$'\033[32m'; C_FAIL=$'\033[31m'; C_SKIP=$'\033[33m'
    C_INFO=$'\033[36m'; C_HEAD=$'\033[1m';  C_OFF=$'\033[0m'
else
    C_PASS=''; C_FAIL=''; C_SKIP=''; C_INFO=''; C_HEAD=''; C_OFF=''
fi

n_pass=0; n_fail=0; n_skip=0

pass() { printf '  %sPASS%s  %s\n' "$C_PASS" "$C_OFF" "$1"; n_pass=$((n_pass+1)); }
fail() { printf '  %sFAIL%s  %s\n' "$C_FAIL" "$C_OFF" "$1"; n_fail=$((n_fail+1)); }
skip() { printf '  %sSKIP%s  %s\n' "$C_SKIP" "$C_OFF" "$1"; n_skip=$((n_skip+1)); }
info() { printf '  %sINFO%s  %s\n' "$C_INFO" "$C_OFF" "$1"; }
head() { printf '\n%s== %s ==%s\n' "$C_HEAD" "$1" "$C_OFF"; }

# --- environment discovery (never hardcode) -------------------------------
REAL_USER="$(id -un)"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -n "$REAL_HOME" ] || REAL_HOME="${HOME:-/home/$REAL_USER}"

# The shared UA string all three CLI tools must present.
UA='Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0'

# unit_state <unit> -> "<enabled-state>/<active-state>"
# Note: is-enabled/is-active print a meaningful word ("static", "inactive")
# AND exit non-zero, so `|| echo` would append a second value. Capture the
# output first and only substitute when it is genuinely empty.
unit_state() {
    local en ac
    en="$(systemctl is-enabled "$1" 2>/dev/null)"
    ac="$(systemctl is-active  "$1" 2>/dev/null)"
    printf '%s/%s' "${en:-n-a}" "${ac:-n-a}"
}

printf '%sAnti-fingerprinting verification%s\n' "$C_HEAD" "$C_OFF"
printf 'host: %s   user: %s   home: %s\n' "$(uname -n)" "$REAL_USER" "$REAL_HOME"
printf 'date: %s\n' "$(date -Is)"

# =========================================================================
head "SECTION 1 — Firefox user.js"

# Firefox on this system uses the XDG path; accept the legacy path too.
FF_ROOT=""
for cand in "$REAL_HOME/.config/mozilla/firefox" "$REAL_HOME/.mozilla/firefox"; do
    if [ -f "$cand/profiles.ini" ]; then FF_ROOT="$cand"; break; fi
done

if [ -z "$FF_ROOT" ]; then
    skip "no profiles.ini found under ~/.config/mozilla/firefox or ~/.mozilla/firefox"
    PROFILE_DIR=""
else
    info "profile root: $FF_ROOT"
    # Prefer the profile pinned by the [Install...] section, else Default=1.
    PROF_REL="$(awk '
        /^\[Install/       {ins=1; next}
        /^\[/              {ins=0}
        ins && /^Default=/ {sub(/^Default=/,""); print; exit}
    ' "$FF_ROOT/profiles.ini")"
    if [ -z "$PROF_REL" ]; then
        PROF_REL="$(awk '
            /^\[Profile/ {p=""; d=0}
            /^Path=/     {sub(/^Path=/,""); p=$0}
            /^Default=1/ {d=1}
            d && p       {print p; exit}
        ' "$FF_ROOT/profiles.ini")"
    fi
    PROFILE_DIR="$FF_ROOT/$PROF_REL"
    if [ -d "$PROFILE_DIR" ]; then
        info "active profile: $PROF_REL"
    else
        fail "profile referenced by profiles.ini is missing: $PROF_REL"
        PROFILE_DIR=""
    fi
fi

USERJS="${PROFILE_DIR:+$PROFILE_DIR/user.js}"

if [ -n "$USERJS" ] && [ -f "$USERJS" ]; then
    pass "user.js present ($USERJS)"

    check_pref() {  # check_pref <name> <expected-value>
        if grep -qF "user_pref(\"$1\", $2);" "$USERJS"; then
            pass "$1 = $2"
        elif grep -qF "user_pref(\"$1\"," "$USERJS"; then
            fail "$1 present but not set to $2"
        else
            fail "$1 missing (expected $2)"
        fi
    }

    check_pref privacy.resistFingerprinting              true
    check_pref privacy.resistFingerprinting.letterboxing true
    check_pref privacy.trackingprotection.enabled        true
    check_pref media.peerconnection.enabled              false
    check_pref network.captive-portal-service.enabled    false
    check_pref network.connectivity-service.enabled      false
    check_pref network.dns.disablePrefetch               true
    check_pref network.prefetch-next                     false
    check_pref network.predictor.enabled                 false
    check_pref browser.send_pings                        false
    check_pref beacon.enabled                            false
    # Sin esto, el gestor de categorias de content-blocking resetea
    # privacy.trackingprotection.enabled en cada arranque.
    check_pref browser.contentblocking.category          '"strict"'

    # Confirmar que la categoria no fue revertida desde la UI: si prefs.js
    # dice "standard", la UI gano y la proteccion de rastreo esta inerte.
    if [ -f "$PROFILE_DIR/prefs.js" ]; then
        cat_live="$(sed -n 's/.*"browser\.contentblocking\.category", "\([^"]*\)".*/\1/p' \
                    "$PROFILE_DIR/prefs.js" | tail -n1)"
        case "$cat_live" in
            strict)   pass "prefs.js: content-blocking category = strict (aplicada)" ;;
            standard) fail "prefs.js: category = standard — esta reseteando trackingprotection.enabled" ;;
            "")       info "prefs.js: category ausente (Firefox aun no ha arrancado con la pref nueva)" ;;
            *)        info "prefs.js: category = $cat_live" ;;
        esac
        if grep -qF '"privacy.trackingprotection.enabled", true' "$PROFILE_DIR/prefs.js"; then
            pass "prefs.js: trackingprotection.enabled = true (efectiva)"
        else
            fail "prefs.js: trackingprotection.enabled NO efectiva — revisa la categoria"
        fi
    fi

    # These must NOT be present: they contradict resistFingerprinting.
    for bad in general.useragent.override privacy.resistFingerprinting.override \
               intl.accept_languages general.appversion.override \
               general.platform.override general.oscpu.override; do
        if grep -q "^[[:space:]]*user_pref(\"$bad\"" "$USERJS"; then
            fail "$bad is set — conflicts with resistFingerprinting, remove it"
        else
            pass "$bad absent (correct)"
        fi
    done

    if grep -q '^[[:space:]]*user_pref("webgl.disabled"' "$USERJS"; then
        info "webgl.disabled is set — optional trade-off, enabled by choice"
    else
        info "webgl.disabled not set — WebGL enabled (chosen default)"
    fi

    # user.js only takes effect at startup.
    if pgrep -u "$REAL_USER" -x firefox >/dev/null 2>&1; then
        info "firefox is RUNNING — restart it for user.js to be applied"
    else
        info "firefox not running — user.js applies on next launch"
    fi
elif [ -n "$PROFILE_DIR" ]; then
    fail "user.js missing in $PROFILE_DIR"
else
    skip "Firefox pref checks (no usable profile)"
fi

# =========================================================================
head "SECTION 1a — topologia de perfiles"

# El user.js canonico vive fuera de los perfiles; cada perfil endurecido lo
# consume por symlink para que no puedan divergir. profiles.ini reasigna el
# perfil por defecto por su cuenta (observado: cambio dos veces en 6 minutos),
# asi que endurecer solo el "activo" no es fiable.
CANON="${FF_ROOT:+$FF_ROOT/user.js.hardened}"
HARDENED_PROFILES=("7oVMt9td.Profile 1" "eu2p91o1.default-release")

if [ -n "$CANON" ] && [ -f "$CANON" ]; then
    pass "user.js canonico presente ($CANON)"
    for p in "${HARDENED_PROFILES[@]}"; do
        t="$FF_ROOT/$p/user.js"
        if [ ! -e "$t" ] && [ ! -L "$t" ]; then
            fail "perfil '$p': sin user.js"
        elif [ -L "$t" ] && [ "$(readlink -f "$t")" = "$(readlink -f "$CANON")" ]; then
            pass "perfil '$p': enlazado al canonico"
        elif [ -L "$t" ]; then
            fail "perfil '$p': symlink apunta a $(readlink "$t"), no al canonico"
        else
            fail "perfil '$p': user.js es copia independiente — puede divergir"
        fi
    done
    # Perfiles excluidos a proposito: no deben tener user.js.
    for p in "1qxkncs0.zap-client-profile"; do
        if [ -e "$FF_ROOT/$p/user.js" ]; then
            info "perfil '$p' (ZAP) tiene user.js — RFP puede falsear la interceptacion"
        else
            pass "perfil '$p' (ZAP) sin endurecer (correcto)"
        fi
    done
elif [ -n "$FF_ROOT" ]; then
    fail "falta el user.js canonico en $CANON"
else
    skip "topologia de perfiles (no se localizo el arbol de Firefox)"
fi

# ShowSelector: si esta en 1, Firefox puede arrancar en un perfil distinto sin
# avisar. Firefox reescribe profiles.ini al salir, asi que solo se puede
# cambiar con el navegador CERRADO.
if [ -n "$FF_ROOT" ] && [ -f "$FF_ROOT/profiles.ini" ]; then
    sel="$(sed -n 's/^ShowSelector=//p' "$FF_ROOT/profiles.ini" | tail -n1)"
    case "$sel" in
        0)  pass "ShowSelector=0 (Firefox no preguntara el perfil al arrancar)" ;;
        1)  fail "ShowSelector=1 — aplicalo con Firefox CERRADO o se revierte" ;;
        "") info "ShowSelector ausente de profiles.ini" ;;
        *)  info "ShowSelector=$sel" ;;
    esac
    info "perfil por defecto ahora: $(awk '/^\[Install/{i=1;next}/^\[/{i=0}i&&/^Default=/{sub(/^Default=/,"");print;exit}' "$FF_ROOT/profiles.ini")"
fi

# =========================================================================
head "SECTION 1b — aislamiento de fuentes Windows (solo Firefox)"

# Las fuentes de Windows instaladas en Linux midieron 14.92 bits de entropia
# en Cover Your Tracks. resistFingerprinting NO las oculta en Linux, asi que
# se bloquean con un fontconfig que solo ve Firefox, via FONTCONFIG_FILE.
FC_FF="${XDG_CONFIG_HOME:-$REAL_HOME/.config}/fontconfig/firefox-fonts.conf"
FF_WRAP="$REAL_HOME/.local/bin/firefox"

if [ -r "$FC_FF" ]; then
    pass "fontconfig de Firefox presente ($FC_FF)"
else
    fail "falta $FC_FF"
fi

if [ -x "$FF_WRAP" ]; then
    pass "wrapper ejecutable ($FF_WRAP)"
    if grep -q 'FONTCONFIG_FILE' "$FF_WRAP"; then
        pass "el wrapper exporta FONTCONFIG_FILE"
    else
        fail "el wrapper no exporta FONTCONFIG_FILE"
    fi
    # Si /usr/bin/firefox gana en el PATH, el wrapper nunca se usa.
    resolved="$(command -v firefox 2>/dev/null)"
    if [ "$resolved" = "$FF_WRAP" ]; then
        pass "'firefox' en PATH resuelve al wrapper"
    else
        fail "'firefox' resuelve a ${resolved:-nada} — el wrapper queda ignorado"
    fi
else
    fail "falta o no es ejecutable $FF_WRAP"
fi

DESK="$REAL_HOME/.local/share/applications/firefox.desktop"
if [ -f "$DESK" ]; then
    if grep -q "^Exec=$FF_WRAP" "$DESK"; then
        pass ".desktop override apunta al wrapper (lanzadores graficos cubiertos)"
    else
        fail ".desktop existe pero su Exec no apunta al wrapper"
    fi
else
    fail "falta $DESK — los lanzadores graficos evitarian el wrapper"
fi

# Comprobacion de fondo: ninguna familia de Windows debe seguir resolviendo a
# su archivo real cuando el fontconfig restringido esta activo.
if [ -r "$FC_FF" ] && command -v fc-match >/dev/null 2>&1; then
    win_fams='Andale Mono|Arial|Arial Black|Comic Sans MS|Courier New|Georgia|Impact|Times New Roman|Trebuchet MS|Verdana|Webdings|Calibri|Cambria|Cambria Math|Candara|Consolas|Constantia|Corbel|Meiryo|Meiryo UI|Segoe UI Variable Static Display|Segoe UI Variable Static Small|Segoe UI Variable Static Text'
    leaks=0; total=0
    old_ifs="$IFS"; IFS='|'
    for fam in $win_fams; do
        total=$((total+1))
        resolved_file="$(FONTCONFIG_FILE="$FC_FF" fc-match "$fam" -f '%{file}' 2>/dev/null)"
        [ -n "$resolved_file" ] || continue
        owner="$(pacman -Qoq "$resolved_file" 2>/dev/null)"
        case "$owner" in
            *ttf-ms-fonts*|*ttf-vista-fonts*|*ttf-segoe-ui-variable*)
                leaks=$((leaks+1))
                info "  fuga: '$fam' -> $(basename "$resolved_file") ($owner)" ;;
        esac
    done
    IFS="$old_ifs"
    if [ "$leaks" -eq 0 ]; then
        pass "0/$total familias Windows visibles con el fontconfig restringido"
    else
        fail "$leaks/$total familias Windows siguen visibles para Firefox"
    fi

    # El resto del sistema debe conservarlas.
    sys_file="$(fc-match Calibri -f '%{file}' 2>/dev/null)"
    if [ "$(basename "${sys_file:-}")" = "calibri.ttf" ]; then
        pass "fuera del wrapper Calibri sigue disponible (LibreOffice/Wine intactos)"
    else
        info "fuera del wrapper Calibri resuelve a $(basename "${sys_file:-ninguno}")"
    fi
else
    skip "comprobacion de resolucion de fuentes (falta fc-match o el fontconfig)"
fi

# =========================================================================
head "SECTION 2 — CLI user agents"

info "expected UA: $UA"

# curl: config is `user-agent = "..."` (quotes optional).
if [ -f "$REAL_HOME/.curlrc" ]; then
    got="$(sed -n 's/^[[:space:]]*user-agent[[:space:]]*=[[:space:]]*//p' \
           "$REAL_HOME/.curlrc" | tail -n1 | sed 's/^"//; s/"$//')"
    if [ "$got" = "$UA" ]; then pass "~/.curlrc user-agent matches"
    elif [ -n "$got" ];  then fail "~/.curlrc user-agent differs: $got"
    else                      fail "~/.curlrc has no user-agent directive"; fi
else
    fail "~/.curlrc does not exist"
fi

# wget: config is `user_agent = ...` (unquoted).
if [ -f "$REAL_HOME/.wgetrc" ]; then
    got="$(sed -n 's/^[[:space:]]*user_agent[[:space:]]*=[[:space:]]*//p' \
           "$REAL_HOME/.wgetrc" | tail -n1 | sed 's/^"//; s/"$//')"
    if [ "$got" = "$UA" ]; then pass "~/.wgetrc user_agent matches"
    elif [ -n "$got" ];  then fail "~/.wgetrc user_agent differs: $got"
    else                      fail "~/.wgetrc has no user_agent directive"; fi
else
    fail "~/.wgetrc does not exist"
fi

# git: read via git itself so include/conditional-include are honoured.
if command -v git >/dev/null 2>&1; then
    got="$(git config --global --get http.userAgent 2>/dev/null)"
    if [ "$got" = "$UA" ]; then pass "git http.userAgent matches"
    elif [ -n "$got" ];  then fail "git http.userAgent differs: $got"
    else                      fail "git http.userAgent not set"; fi
else
    skip "git not installed"
fi

if command -v curl-impersonate >/dev/null 2>&1; then
    info "curl-impersonate present — use it when the TLS/JA3 fingerprint matters"
else
    info "curl-impersonate absent; a UA header does not change the TLS/JA3 fingerprint"
fi

# =========================================================================
head "SECTION 3 — pacman"

if [ -f /etc/pacman.conf ]; then
    if grep -qE '^[[:space:]]*XferCommand[[:space:]]*=' /etc/pacman.conf; then
        info "XferCommand is ACTIVE: $(grep -m1 -E '^[[:space:]]*XferCommand[[:space:]]*=' /etc/pacman.conf)"
        if grep -qE '^[[:space:]]*ParallelDownloads[[:space:]]*=' /etc/pacman.conf; then
            info "ParallelDownloads is set but an external XferCommand overrides it (downloads serialize)"
        fi
    else
        skip "XferCommand not set — deliberately skipped (keeps ParallelDownloads and DownloadUser=alpm intact)"
    fi
else
    skip "/etc/pacman.conf not found"
fi

if pacman -Q pkgstats >/dev/null 2>&1; then
    info "pkgstats INSTALLED ($(pacman -Q pkgstats)); timer: $(unit_state pkgstats.timer)"
    info "  it submits your installed-package list to Arch on a timer"
else
    pass "pkgstats not installed (nothing reporting your package list)"
fi

# =========================================================================
head "SECTION 4 — NetworkManager"

NMD=/etc/NetworkManager/conf.d

check_nm_key() {  # check_nm_key <file> <key=value>
    if [ ! -f "$1" ]; then fail "$(basename "$1") missing"; return; fi
    if grep -qxF "$2" "$1"; then pass "$(basename "$1"): $2"
    else fail "$(basename "$1"): expected '$2'"; fi
}

if [ -d "$NMD" ]; then
    check_nm_key "$NMD/00-macrandomize.conf" 'wifi.scan-rand-mac-address=yes'
    check_nm_key "$NMD/00-macrandomize.conf" 'wifi.cloned-mac-address=stable-ssid'
    check_nm_key "$NMD/00-macrandomize.conf" 'ipv6.ip6-privacy=2'

    # Wired MAC: 'permanent' is the intended value (keeps the DHCP reservation
    # that remote SSH/Tailscale access relies on). 'random' is a lockout risk.
    if [ -f "$NMD/00-macrandomize.conf" ]; then
        eth="$(sed -n 's/^[[:space:]]*ethernet\.cloned-mac-address[[:space:]]*=[[:space:]]*//p' \
               "$NMD/00-macrandomize.conf" | tail -n1)"
        case "$eth" in
            permanent) pass "ethernet.cloned-mac-address=permanent (hardware MAC kept)" ;;
            stable)    fail "ethernet.cloned-mac-address=stable — NOT the hardware MAC; breaks DHCP reservations" ;;
            random)    fail "ethernet.cloned-mac-address=random — HIGH lockout risk on a remote node" ;;
            "")        fail "ethernet.cloned-mac-address not set" ;;
            *)         fail "ethernet.cloned-mac-address=$eth (unexpected)" ;;
        esac
    fi

    check_nm_key "$NMD/01-connectivity.conf" 'enabled=false'

    # Anything else in conf.d that touches the same keys is a conflict.
    others="$(grep -lE 'cloned-mac-address|scan-rand-mac-address|ip6-privacy|^\[connectivity\]' \
              "$NMD"/*.conf 2>/dev/null \
              | grep -vE '/(00-macrandomize|01-connectivity)\.conf$')"
    if [ -n "$others" ]; then
        fail "other conf.d files set overlapping keys (later filename wins):"
        printf '        %s\n' $others
    else
        pass "no conflicting conf.d files"
    fi

    # Are the files actually in effect, or only on disk?
    if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
        eff="$(nmcli -t -f running general 2>/dev/null)"
        [ -n "$eff" ] && info "NetworkManager is running — 'nmcli general reload conf' needed if configs changed since start"
        conn="$(nmcli -t -f CONNECTIVITY general 2>/dev/null)"
        case "$conn" in
            none|unknown|"") pass "connectivity check reports '${conn:-unknown}' (disabled or inactive)" ;;
            *)               fail "connectivity check still active (reports '$conn') — config not reloaded" ;;
        esac
    else
        skip "nmcli runtime check (NetworkManager not running or nmcli absent)"
    fi
else
    skip "$NMD does not exist (NetworkManager not installed?)"
fi

# =========================================================================
head "SECTION 5 — audit only"

# geoclue
if pacman -Q geoclue >/dev/null 2>&1; then
    info "geoclue INSTALLED ($(pacman -Q geoclue)); geoclue.service: $(unit_state geoclue.service)"
    info "  'static' enablement means it is D-Bus activated on demand, not at boot"
else
    info "geoclue not installed"
fi

# avahi
if pacman -Q avahi >/dev/null 2>&1; then
    info "avahi INSTALLED ($(pacman -Q avahi))"
    info "  avahi-daemon.service: $(unit_state avahi-daemon.service)"
    info "  avahi-daemon.socket:  $(unit_state avahi-daemon.socket)"
    if systemctl is-active --quiet avahi-daemon.service; then
        info "  ACTIVE: broadcasting this host's name and services to the whole LAN via mDNS"
    fi
else
    info "avahi not installed"
fi

# systemd-resolved
info "systemd-resolved: $(unit_state systemd-resolved.service)"
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    dot="$(resolvectl status 2>/dev/null | sed -n 's/.*DNSOverTLS[[:space:]]*:[[:space:]]*//p' | head -1)"
    dnssec="$(resolvectl status 2>/dev/null | sed -n 's/.*DNSSEC[[:space:]]*:[[:space:]]*//p' | head -1)"
    info "  DNSOverTLS: ${dot:-unreported}"
    info "  DNSSEC:     ${dnssec:-unreported}"
else
    info "  inactive — DNSOverTLS/DNSSEC not applicable"
fi

# Resolver ownership
if [ -e /etc/resolv.conf ]; then
    info "resolv.conf -> $(readlink -f /etc/resolv.conf)"
    info "  nameservers: $(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf)"
    if grep -q '100\.100\.100\.100' /etc/resolv.conf 2>/dev/null; then
        info "  Tailscale MagicDNS owns the resolver — do not hand-edit resolv.conf"
    fi
fi

# Tailscale
if command -v tailscale >/dev/null 2>&1; then
    info "tailscaled: $(unit_state tailscaled.service)"
    exitnode="$(tailscale status --json 2>/dev/null | grep -c '"ExitNode": *true')"
    [ "${exitnode:-0}" -gt 0 ] \
        && info "  an exit node is in use — egress traffic is tunnelled" \
        || info "  no exit node in use — normal traffic egresses on the local link"
else
    info "tailscale not installed"
fi

# IPv6 reality check
v6addrs="$(ip -6 addr show scope global 2>/dev/null | grep -c 'inet6')"
v6route="$(ip -6 route show default 2>/dev/null | head -1)"
if [ "${v6addrs:-0}" -gt 0 ] && [ -n "$v6route" ]; then
    info "IPv6 IS IN USE: $v6addrs global address(es), default route present"
    ip -6 addr show scope global 2>/dev/null \
        | awk '/inet6/{print "        " $2}'
    info "  net.ipv6.conf.all.disable_ipv6=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null) but per-interface overrides re-enable it"
    for i in $(ls /sys/class/net 2>/dev/null); do
        # Only 1 and 2 enable privacy addresses; 0 is off and -1 is
        # "not applicable" (loopback, tunnels).
        ta="$(sysctl -n "net.ipv6.conf.$i.use_tempaddr" 2>/dev/null)"
        case "$ta" in
            1|2) info "  $i use_tempaddr=$ta (privacy addresses on)" ;;
        esac
    done
    if [ "$(sysctl -n net.ipv6.conf.all.use_tempaddr 2>/dev/null)" = "2" ]; then
        info "  all.use_tempaddr=2, but this only applies to interfaces created after it was set"
    fi
    info "  a native IPv6 address bypasses IPv4-only proxying — check for leaks"
else
    info "IPv6 not in active use (no global address and/or no default route)"
fi

# Extensions per profile
if [ -n "$FF_ROOT" ]; then
    found_ext=0
    for d in "$FF_ROOT"/*/extensions; do
        [ -d "$d" ] || continue
        c="$(find "$d" -maxdepth 1 -name '*.xpi' 2>/dev/null | wc -l)"
        [ "$c" -eq 0 ] && continue
        found_ext=1
        prof="$(basename "$(dirname "$d")")"
        if [ "$c" -gt 1 ]; then
            info "profile '$prof': $c extensions — each one is fingerprintable surface"
        else
            info "profile '$prof': $c extension"
        fi
        find "$d" -maxdepth 1 -name '*.xpi' -printf '        %f\n' 2>/dev/null
    done
    [ "$found_ext" -eq 0 ] && info "no installed extensions found in any profile"
fi

# =========================================================================
printf '\n%s== summary ==%s\n' "$C_HEAD" "$C_OFF"
printf '  %sPASS%s %d   %sFAIL%s %d   %sSKIP%s %d\n' \
    "$C_PASS" "$C_OFF" "$n_pass" "$C_FAIL" "$C_OFF" "$n_fail" "$C_SKIP" "$C_OFF" "$n_skip"
printf '  (read-only check; exits 0 regardless of findings)\n'

exit 0
