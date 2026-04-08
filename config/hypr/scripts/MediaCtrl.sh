#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-update}"

# === SELECCIÓN DE REPRODUCTOR INTELIGENTE ===
get_active_player() {
  local playing
  # 1. Buscar primero cualquier reproductor que esté activamente en "Playing"
  playing=$(playerctl -l 2>/dev/null | while read -r p; do
    if [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ]; then
      echo "$p"
      break
    fi
  done)

  if [ -n "$playing" ]; then
    echo "$playing"
    return 0
  fi

  # 2. Si todo está pausado, agarra el último que se usó (el primero de la lista de dbus)
  local first
  first=$(playerctl -l 2>/dev/null | head -n 1)
  if [ -n "$first" ]; then
    echo "$first"
  else
    # 3. Fallback absoluto si dbus está vacío
    echo "brave"
  fi
}

PLAYER="$(get_active_player)"

CACHE_DIR="/tmp/hyprlock-mpris"
COVER="$CACHE_DIR/cover.png"
BG="$CACHE_DIR/bg.png"
STATE_FILE="$CACHE_DIR/state.txt"
ART_SOURCE_FILE="$CACHE_DIR/art_source.txt"
TITLE_FILE="$CACHE_DIR/title.txt"
ARTIST_FILE="$CACHE_DIR/artist.txt"
STATUS_FILE="$CACHE_DIR/status.txt"
TITLE_RAW_FILE="$CACHE_DIR/title_raw.txt"
ARTIST_RAW_FILE="$CACHE_DIR/artist_raw.txt"
LOCK_FILE="$CACHE_DIR/update.lock"

mkdir -p "$CACHE_DIR"

get_res() {
  hyprctl monitors -j 2>/dev/null \
    | jq -r '.[0] | "\(.width) \(.height)"' \
    | head -n1
}

escape_pango() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

trim_spaces() {
  sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

clean_title() {
  printf '%s' "$1" | sed -E \
    -e 's/[[:space:]]+\[[^][]+\]$//' \
    -e 's/[[:space:]]+\([^()]*feat\.[^()]*\)$//' \
    -e 's/[[:space:]]+\([^()]*featuring[^()]*\)$//' \
    -e 's/[[:space:]]+\([^()]*remaster[^()]*\)$//I' \
    -e 's/[[:space:]]+\([^()]*version[^()]*\)$//I' \
    -e 's/[[:space:]]+\([^()]*edit[^()]*\)$//I' \
    -e 's/[[:space:]]+-[[:space:]]+official.*$//I' \
    -e 's/[[:space:]]+-[[:space:]]+audio.*$//I' \
    -e 's/[[:space:]]+-[[:space:]]+video.*$//I' | trim_spaces
}

clean_artist() {
  printf '%s' "$1" | trim_spaces
}

shorten_smart() {
  local text="$1"
  local max="$2"
  if [ "${#text}" -le "$max" ]; then
    printf '%s' "$text"
  else
    printf '%s…' "${text:0:$((max-1))}"
  fi
}

marquee_text() {
  local text="$1"
  local width="${2:-25}"  # Cantidad de caracteres visibles antes de scrollear
  local gap="   •   "     # Separador entre repeticiones
  local speed=4           # Velocidad (mayor = más rápido)
  
  text="$(clean_title "$text")"
  text="${text:-No Music}"

  # Si el texto cabe en el límite, no hacemos scroll
  if [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
    return 0
  fi

  local padded="${text}${gap}"
  local len=${#padded}
  
  # Usamos milisegundos para calcular la posición suave
  # date +%s%N da segundos y nanosegundos. Extraemos milisegundos.
  local ms
  ms=$(date +%s%3N)
  
  # Calculamos el desplazamiento continuo
  local offset=$(( (ms / (1000 / speed)) % len ))
  
  # Creamos el string duplicado para el efecto de bucle infinito
  local display_string="${padded}${padded}"
  
  # Extraemos el fragmento exacto basado en el offset
  printf '%s' "${display_string:$offset:$width}"
}

urlencode() {
  jq -nr --arg v "$1" '$v|@uri'
}

magick_identify() {
  magick identify "$@" 2>/dev/null \
    || identify "$@" 2>/dev/null \
    || echo "0 0"
}

art_is_lowres_file() {
  local url="$1"
  local path dims w h

  [[ "$url" == file://* ]] || return 1
  path="${url#file://}"
  [[ -f "$path" ]] || return 0

  dims="$(magick_identify -format '%w %h' "$path")"
  read -r w h <<< "$dims"
  [[ "${w:-0}" -lt 500 || "${h:-0}" -lt 500 ]]
}

upscale_apple_art_url() {
  local url="$1"
  printf '%s' "$url" | sed -E \
    -e 's#/source/[0-9]+x[0-9]+bb\.(jpg|png)$#/source/1400x1400bb.\1#' \
    -e 's#/source/[0-9]+x[0-9]+-[0-9]+\.(jpg|png)$#/source/1400x1400-100.\1#' \
    -e 's#/[0-9]+x[0-9]+bb\.(jpg|png)$#/1400x1400bb.\1#' \
    -e 's#/[0-9]+x[0-9]+-[0-9]+\.(jpg|png)$#/1400x1400-100.\1#'
}

lookup_itunes_art() {
  local title="$1" artist="$2" album="$3"
  local term query json artwork ntitle nartist

  ntitle="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')"
  nartist="$(printf '%s' "$artist" | tr '[:upper:]' '[:lower:]')"

  if [[ -n "$album" && "$album" != "---" ]]; then
    term="${artist} ${album}"
  else
    term="${artist} ${title}"
  fi

  query="$(urlencode "$term")"
  json="$(curl -Lsf --connect-timeout 3 --max-time 6 \
    "https://itunes.apple.com/search?term=${query}&media=music&entity=song&limit=10" \
    2>/dev/null || true)"
  [[ -n "$json" ]] || return 1

  artwork="$(printf '%s' "$json" | jq -r --arg t "$ntitle" --arg a "$nartist" '
    .results
    | map(select(.artworkUrl100 != null))
    | (
        map(select(
          (.artistName // "" | ascii_downcase | contains($a)) and
          ((.trackName // .collectionName // "" | ascii_downcase | contains($t)))
        ))[0]
        // map(select(.artistName // "" | ascii_downcase | contains($a)))[0]
        // .[0]
        // empty
      )
    | .artworkUrl100 // empty
  ' 2>/dev/null || true)"

  [[ -n "$artwork" ]] || return 1
  upscale_apple_art_url "$artwork"
}

resolve_best_art_url() {
  local title="$1" artist="$2" album="$3" raw_url="${4:-}"
  local resolved=""

  if [[ "$raw_url" =~ ^https?://.*(mzstatic|apple).*$ ]]; then
    upscale_apple_art_url "$raw_url"
    return 0
  fi

  if art_is_lowres_file "$raw_url"; then
    resolved="$(lookup_itunes_art "$title" "$artist" "$album" || true)"
    if [[ -n "$resolved" ]]; then
      printf '%s' "$resolved"
      return 0
    fi
  fi

  if [[ "$raw_url" == file://* || "$raw_url" == http://* || "$raw_url" == https://* ]]; then
    printf '%s' "$raw_url"
    return 0
  fi

  lookup_itunes_art "$title" "$artist" "$album" || true
}

write_fallback_bg() {
  local w h tmpbg
  read -r w h < <(get_res || true)
  w="${w:-1920}"; h="${h:-1080}"
  tmpbg="$(mktemp --suffix=.png)"
  magick -size "${w}x${h}" xc:"#181818" "$tmpbg"
  mv -f "$tmpbg" "$BG"
}

write_text_files() {
  local raw_title raw_artist status clean_t clean_a
  local tmptitle tmpartist tmpstatus tmprawt tmprawa

  raw_title="$(playerctl --player="$PLAYER" metadata --format '{{title}}' 2>/dev/null || true)"
  raw_artist="$(playerctl --player="$PLAYER" metadata --format '{{artist}}' 2>/dev/null || true)"
  status="$(playerctl --player="$PLAYER" status 2>/dev/null || echo "Paused")"

  raw_title="${raw_title:-No Music}"
  raw_artist="${raw_artist:---}"

  clean_t="$(clean_title "$raw_title")"
  clean_a="$(clean_artist "$raw_artist")"

  tmptitle="$(mktemp)"; tmpartist="$(mktemp)"; tmpstatus="$(mktemp)"
  tmprawt="$(mktemp)";  tmprawa="$(mktemp)"

  shorten_smart "$clean_t" 34 | escape_pango > "$tmptitle"
  shorten_smart "$clean_a" 42 | escape_pango > "$tmpartist"
  printf '%s\n' "$status"  > "$tmpstatus"
  printf '%s'   "$clean_t" > "$tmprawt"
  printf '%s'   "$clean_a" > "$tmprawa"

  mv -f "$tmptitle"  "$TITLE_FILE"
  mv -f "$tmpartist" "$ARTIST_FILE"
  mv -f "$tmpstatus" "$STATUS_FILE"
  mv -f "$tmprawt"   "$TITLE_RAW_FILE"
  mv -f "$tmprawa"   "$ARTIST_RAW_FILE"
}

fetch_art_to_temp() {
  local source="$1" out="$2" path

  if [[ "$source" == file://* ]]; then
    path="${source#file://}"
    [[ -f "$path" ]] || return 1
    cp -- "$path" "$out"
  else
    curl -Lsf --connect-timeout 3 --max-time 10 "$source" -o "$out" || return 1
  fi
}

update_files() {
  # flock -w 3 asegura que si hay otra actualización corriendo, espere hasta 3 segundos
  (
    flock -w 3 9 || { echo "update: lock timeout" >&2; return 1; }

    # Refresca el reproductor activo en cada pasada
    PLAYER="$(get_active_player)"

    local raw_title raw_artist raw_album raw_url status
    local title artist album best_url old_state state old_art_source
    local tmp tmpcover tmpbg w h

    tmp="$(mktemp)" tmpcover="$(mktemp --suffix=.png)" tmpbg="$(mktemp --suffix=.png)"
    trap 'rm -f "$tmp" "$tmpcover" "$tmpbg"' RETURN

    raw_title="$(playerctl --player="$PLAYER" metadata --format '{{title}}'      2>/dev/null || true)"
    raw_artist="$(playerctl --player="$PLAYER" metadata --format '{{artist}}'    2>/dev/null || true)"
    raw_album="$(playerctl --player="$PLAYER" metadata --format '{{album}}'      2>/dev/null || true)"
    raw_url="$(playerctl --player="$PLAYER" metadata --format '{{mpris:artUrl}}' 2>/dev/null || true)"
    status="$(playerctl --player="$PLAYER" status                                2>/dev/null || echo "Paused")"

    title="$(clean_title  "${raw_title:-No Music}")"
    artist="$(clean_artist "${raw_artist:---}")"
    album="$(clean_title  "${raw_album:---}")"

    write_text_files

    best_url="$(resolve_best_art_url "$title" "$artist" "$album" "$raw_url" || true)"
    old_state="$(cat "$STATE_FILE"      2>/dev/null || true)"
    old_art_source="$(cat "$ART_SOURCE_FILE" 2>/dev/null || true)"
    state="${title}|${artist}|${album}|${best_url}|${status}"

    # Si no hay imagen disponible (e.g. pausado sin reproductor activo)
    if [[ -z "$best_url" ]]; then
      rm -f "$COVER" "$ART_SOURCE_FILE"
      write_fallback_bg
      printf '%s' "$state" > "$STATE_FILE"
      pkill -USR2 hyprlock 2>/dev/null || true
      return 0
    fi

    # Si nada ha cambiado, salimos sin descargar ni procesar imágenes
    if [[ "$state" == "$old_state" && "$best_url" == "$old_art_source" \
          && -f "$COVER" && -f "$BG" ]]; then
      return 0
    fi

    # Si hay una URL nueva, la descargamos y procesamos
    if [[ "$best_url" != "$old_art_source" || ! -f "$COVER" || ! -f "$BG" ]]; then
      if ! fetch_art_to_temp "$best_url" "$tmp"; then
        write_fallback_bg
        printf '%s' "$state" > "$STATE_FILE"
        pkill -USR2 hyprlock 2>/dev/null || true
        return 0
      fi

      if ! file "$tmp" | grep -qiE 'image|jpeg|png|webp'; then
        write_fallback_bg
        printf '%s' "$state" > "$STATE_FILE"
        pkill -USR2 hyprlock 2>/dev/null || true
        return 0
      fi

      read -r w h < <(get_res || true)
      w="${w:-1920}"; h="${h:-1080}"

      # Procesar Cover Art y Background
      magick "$tmp" -auto-orient -strip "$tmpcover"
      magick "$tmpcover" \
        -resize "${w}x${h}^" \
        -gravity center \
        -extent "${w}x${h}" \
        -blur 0x22 \
        -modulate 65,115,100 \
        "$tmpbg"

      mv -f "$tmpcover" "$COVER"
      mv -f "$tmpbg"    "$BG"
      printf '%s' "$best_url" > "$ART_SOURCE_FILE"
    fi

    printf '%s' "$state" > "$STATE_FILE"
    pkill -USR2 hyprlock 2>/dev/null || true

  ) 9>"$LOCK_FILE"
}

daemon_loop() {
  while sleep 2; do
    update_files || true
  done
}

case "$ACTION" in
  update)        update_files ;;
  daemon)        daemon_loop ;;
  title)         cat "$TITLE_FILE"      2>/dev/null || echo "No Music" ;;
  artist)        cat "$ARTIST_FILE"     2>/dev/null || echo "---" ;;
  status)        cat "$STATUS_FILE"     2>/dev/null || echo "Paused" ;;
  marquee-title)
    title="$(cat "$TITLE_RAW_FILE" 2>/dev/null || echo "No Music")"
    marquee_text "$title" 32 | escape_pango
    ;;
  toggle) /usr/bin/playerctl --player="$PLAYER" play-pause ;;
  prev)   /usr/bin/playerctl --player="$PLAYER" previous ;;
  next)   /usr/bin/playerctl --player="$PLAYER" next ;;
  *)
    echo "uso: $0 {update|daemon|title|artist|status|marquee-title|toggle|prev|next}" >&2
    exit 1
    ;;
esac


