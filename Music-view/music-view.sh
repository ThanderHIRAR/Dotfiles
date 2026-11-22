#!/bin/bash
# ─────────────────────────────────────────
#  music-view — arquivo único
#  Uso:  ./music-view.sh          (abre o tmux com thumbnail + cava)
#        ./music-view.sh --thumb  (uso interno: painel esquerdo)
# ─────────────────────────────────────────

SESSION="music-view"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Config base do cava (tema/cores). Padrão: o config do sistema (~/.config/cava/config)
# Para usar outro arquivo: CAVA_CONF=/caminho/config ./music-view.sh
CAVA_BASE="${CAVA_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/cava/config}"
# Config gerado (cópia do base com a quantidade de barras ajustada ao painel)
CAVA_RUN_CONF="/tmp/music-view-cava.conf"
# Barras: 0 = ajusta automaticamente à largura do painel
CAVA_BARS=0
# Cor usada se não der para ler a cor do config do cava
FALLBACK_COLOR="#4FBEF0"

# ══════════════════════════════════════
#  TECLAS — ajuste aqui
# ══════════════════════════════════════
KEY_PLAYPAUSE=" "    # barra de espaço
KEY_NEXT="n"
KEY_PREV="b"
KEY_QUIT="q"         # q ou Q (as duas funcionam)

# Ícone mostrado em cada estado (troque os dois se preferir o inverso)
ICON_PLAYING="⏸"     # tocando  → mostra pausar
ICON_PAUSED="▶"      # pausado  → mostra tocar

# ══════════════════════════════════════
#  MODO LAUNCHER (padrão)
# ══════════════════════════════════════

# Converte nome de cor do cava ou #RRGGBB em #rrggbb (vazio se inválido/default)
cava_hex() {
    local c="${1,,}"
    case "$c" in
        black)   echo "#000000"; return ;;
        red)     echo "#ff0000"; return ;;
        green)   echo "#00ff00"; return ;;
        yellow)  echo "#ffff00"; return ;;
        blue)    echo "#0000ff"; return ;;
        magenta) echo "#ff00ff"; return ;;
        cyan)    echo "#00ffff"; return ;;
        white)   echo "#ffffff"; return ;;
    esac
    [[ "$c" =~ ^#[0-9a-f]{6}$ ]] && echo "$c"
}

# Escurece uma cor #rrggbb (usado quando o cava só tem uma cor)
darken_hex() {
    local h="${1#\#}"
    printf '#%02x%02x%02x' \
        $(( 16#${h:0:2} * 70 / 100 )) \
        $(( 16#${h:2:2} * 70 / 100 )) \
        $(( 16#${h:4:2} * 70 / 100 ))
}

# #rrggbb → sequência de cor truecolor (para usar com printf '%b')
rgb_esc() {
    local h="${1#\#}"
    echo "\\e[38;2;$(( 16#${h:0:2} ));$(( 16#${h:2:2} ));$(( 16#${h:4:2} ))m"
}

# Imprime "cor1 cor2" a partir do config do cava:
#   gradient=1 → gradient_color_1 e gradient_color_2
#   senão      → foreground e uma versão mais escura dela
get_cava_colors() {
    local g="" g1="" g2="" fg="" c1="" c2=""
    if [ -f "$CAVA_BASE" ]; then
        IFS='|' read -r g g1 g2 fg < <(awk '
            /^[[:space:]]*[#;]/ { next }
            /^[[:space:]]*\[/ { sec=$0; gsub(/[^A-Za-z]/, "", sec); sec=tolower(sec); next }
            sec == "color" && /=/ {
                i = index($0, "=")
                k = substr($0, 1, i - 1); v = substr($0, i + 1)
                gsub(/[[:space:]]/, "", k)
                sub(/;.*$/, "", v)
                kv[k] = v
            }
            END {
                gsub(/[^0-9]/, "", kv["gradient"])
                print kv["gradient"] "|" kv["gradient_color_1"] "|" kv["gradient_color_2"] "|" kv["foreground"]
            }
        ' "$CAVA_BASE" | tr -d "'\" \t\r")
    fi
    if [ "$g" = "1" ]; then
        c1=$(cava_hex "$g1")
        c2=$(cava_hex "$g2")
    else
        c1=$(cava_hex "$fg")
    fi
    [ -z "$c1" ] && c1="$FALLBACK_COLOR"
    [ -z "$c2" ] && c2=$(darken_hex "$c1")
    echo "$c1 $c2"
}

if [ "$1" != "--thumb" ]; then
    # Mata sessão anterior se existir
    tmux kill-session -t "$SESSION" 2>/dev/null
    sleep 0.1

    tmux new-session -d -s "$SESSION"

    # Painel esquerdo: thumbnail + info (este mesmo arquivo em modo --thumb)
    tmux send-keys -t "$SESSION:0.0" "CAVA_CONF='$CAVA_BASE' bash '$SELF' --thumb" Enter

    # Painel direito com 40% da largura para o cava
    tmux split-window -t "$SESSION:0.0" -h -p 40

    # Gera o config do cava: mantém o tema do base e só força o número de barras
    if [ -f "$CAVA_BASE" ]; then
        awk -v bars="$CAVA_BARS" '
            /^[[:space:]]*bars[[:space:]]*=/ { next }
            { print }
            /^\[general\]/ { print "bars = " bars; found=1 }
            END { if (!found) print "\n[general]\nbars = " bars }
        ' "$CAVA_BASE" > "$CAVA_RUN_CONF"
    else
        printf '[general]\nbars = %s\n' "$CAVA_BARS" > "$CAVA_RUN_CONF"
    fi
    tmux send-keys -t "$SESSION:0.1" "cava -p '$CAVA_RUN_CONF'" Enter

    # Visual: borda na cor base do cava
    read -r BORDER_COLOR _ < <(get_cava_colors)
    tmux set-option -t "$SESSION" status off
    tmux set-option -t "$SESSION" pane-border-style "fg=$BORDER_COLOR"
    tmux set-option -t "$SESSION" pane-active-border-style "fg=$BORDER_COLOR"
    tmux set-option -t "$SESSION" pane-border-lines heavy

    # Necessário para o kitty (icat) desenhar/apagar imagens dentro do tmux
    tmux set-option -p -t "$SESSION:0.0" allow-passthrough on 2>/dev/null

    tmux select-pane -t "$SESSION:0.0"
    tmux attach-session -t "$SESSION"
    exit 0
fi

# ══════════════════════════════════════
#  MODO PAINEL (thumbnail + info)
# ══════════════════════════════════════

# ╔══════════════════════════════════════╗
#  CONFIGURAÇÃO — ajuste aqui
# ══════════════════════════════════════

# Largura da thumbnail como % da largura do painel (0-100+)
IMG_WIDTH_PCT=110

# Altura máxima da thumbnail como % da altura do painel (0-100)
IMG_HEIGHT_PCT=85

# Espaço fixo em células: entre imagem e borda esquerda,
# borda direita (cava), e entre imagem e texto abaixo
IMG_GAP=2

# Margem extra do topo em linhas, aceita decimais
IMG_TOP_MARGIN=0

# Ajuste fino horizontal, aceita decimais (positivo = direita, negativo = esquerda)
IMG_SIDE_MARGIN=0

# Ajuste fino do separador em relação à imagem, aceita decimais
# (o separador já é posicionado logo abaixo da imagem real; use 0 como base)
IMG_BOTTOM_MARGIN=0

# ══════════════════════════════════════
#  FIM DA CONFIGURAÇÃO
# ╚══════════════════════════════════════

# Log de diagnóstico da busca de thumbnail (cat /tmp/music-view-debug.log)
DEBUG_LOG="/tmp/music-view-debug.log"
: > "$DEBUG_LOG"
dbg() {
    echo "[$(date +%T)] $*" >> "$DEBUG_LOG"
    # limita o log a ~100 KB
    if [ "$(stat -c %s "$DEBUG_LOG" 2>/dev/null || echo 0)" -gt 102400 ]; then : > "$DEBUG_LOG"; fi
}

# Remove arquivos temporários de instâncias anteriores que morreram sem limpar
# (kill -9, queda do terminal etc.) e o arquivo fixo usado por versões antigas
sweep_orphans() {
    local f pid
    for f in /tmp/music-view-hq-*; do
        [ -e "$f" ] || continue
        pid="${f#/tmp/music-view-hq-}"
        pid="${pid%%-*}"
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        [ "$pid" = "$$" ] && continue
        kill -0 "$pid" 2>/dev/null || rm -f "$f"
    done
    rm -f /tmp/music-view-hq-thumb.jpg
}
sweep_orphans

NOART="<none>"          # marcador: nada desenhado ainda
LAST_ART="$NOART"
LAST_TITLE=""
LAST_ARTISTTIME=""
LAST_STATUS=""
LAST_TERM=""

# Estado do job da thumbnail HQ (roda em segundo plano)
JOB_PID=""
JOB_N=0
JOB_KEY=""
JOB_PENDING=0
HQ_BASE=""
HQ_FILE=""
HQ_DONE=""
BEST_IMG=""
THUMB_STATE="loading"   # loading = baixando a HQ | none = sem thumbnail

# Cores: 1ª cor do cava (título e barra) e 2ª cor (subtítulo)
read -r CAVA_C1 CAVA_C2 < <(get_cava_colors)
C_L="$(rgb_esc "$CAVA_C1")"
C_M="$(rgb_esc "$CAVA_C2")"
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"

# Mata um processo e todos os descendentes (timeout → yt-dlp → ...)
kill_tree() {
    local pid="$1" child
    for child in $(pgrep -P "$pid" 2>/dev/null); do
        kill_tree "$child"
    done
    kill "$pid" 2>/dev/null
}

stop_thumb_job() {
    if [ -n "$JOB_PID" ]; then
        kill_tree "$JOB_PID"
        wait "$JOB_PID" 2>/dev/null
    fi
    # apaga TUDO que o job desta faixa criou (imagem, .part, .done, temporários)
    [ -n "$HQ_BASE" ] && rm -f "$HQ_BASE".*
    JOB_PID=""
    JOB_PENDING=0
    HQ_FILE=""
    HQ_DONE=""
}

cleanup() {
    stop_thumb_job
    rm -f /tmp/music-view-hq-$$-*
    dbg "encerrando — arquivos temporários removidos"
    tput cnorm
    stty echo 2>/dev/null
    kitty +kitten icat --clear 2>/dev/null
    tput rmcup
    tmux kill-session -t "$SESSION" 2>/dev/null
    exit
}
trap cleanup INT TERM HUP EXIT

tput smcup
tput civis
stty -echo 2>/dev/null
clear

# Nome legível da tecla para o rodapé
key_label() {
    case "$1" in
        " ") echo "espaço" ;;
        *)   echo "$1" ;;
    esac
}

draw_line() {
    local row="$1" text="$2" width="$3"
    local visible
    visible=$(printf '%b' "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#visible}
    local pad=$(( (width - len) / 2 ))
    [ $pad -lt 0 ] && pad=0
    tput cup "$row" 0
    printf '\e[2K'
    printf "%${pad}s" ""
    printf '%b' "$text"
}

draw_separator() {
    tput cup "$SEP_ROW" 0
    printf '%b' "${C_L}"
    printf '%.0s─' $(seq 1 "$TERM_COLS")
    printf '%b' "${C_RESET}"
}

draw_text() {
    local status_icon
    [ "$STATUS" = "Playing" ] && status_icon="$ICON_PLAYING" || status_icon="$ICON_PAUSED"

    local max_title=$(( TERM_COLS - 4 ))
    local title="$CLEAN_TITLE"
    [ ${#title} -gt $max_title ] && title="${title:0:$max_title}…"

    local artisttime="${ARTIST:-Desconhecido}  ·  ${TIME}"

    if [ "$title" != "$LAST_TITLE" ]; then
        draw_line "$TEXT_ROW" "${C_BOLD}${C_L}♪  ${title}${C_RESET}" "$TERM_COLS"
        LAST_TITLE="$title"
    fi

    if [ "$artisttime" != "$LAST_ARTISTTIME" ]; then
        draw_line "$(( TEXT_ROW + 1 ))" "${C_M}${ARTIST:-Desconhecido}  ${C_DIM}·${C_RESET}${C_M}  ${TIME}${C_RESET}" "$TERM_COLS"
        LAST_ARTISTTIME="$artisttime"
    fi

    if [ "$status_icon" != "$LAST_STATUS" ]; then
        draw_line "$(( TEXT_ROW + 3 ))" "${C_DIM}${status_icon}  $(key_label "$KEY_PLAYPAUSE")·play/pause   ${KEY_NEXT}·próxima   ${KEY_PREV}·anterior   $(key_label "$KEY_QUIT")·sair${C_RESET}" "$TERM_COLS"
        LAST_STATUS="$status_icon"
    fi
}

# Código Python compartilhado: lê largura/altura de JPEG e PNG
PY_DIMS_SRC='
import struct
def dims(b):
    try:
        if b[:2] == b"\xff\xd8":
            i = 2
            while i + 9 < len(b):
                if b[i] != 0xFF:
                    i += 1
                    continue
                m = b[i + 1]
                if m == 0xFF:
                    i += 1
                    continue
                if m in (0xD8, 0x01) or 0xD0 <= m <= 0xD7:
                    i += 2
                    continue
                if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
                    h, w = struct.unpack(">HH", b[i + 5:i + 9])
                    return w, h
                i += 2 + struct.unpack(">H", b[i + 2:i + 4])[0]
        elif b[:8] == b"\x89PNG\r\n\x1a\n":
            w, h = struct.unpack(">II", b[16:24])
            return w, h
    except Exception:
        pass
    return 0, 0
'

IMG_ASPECT="1.7778"     # proporção (largura/altura) da imagem atual
CELL_ASPECT="2.0"       # altura/largura de uma célula do terminal

# Proporção real da imagem (fallback 16:9)
img_aspect() {
    local a
    a=$(python3 -c "${PY_DIMS_SRC}"$'\n''
import sys
try:
    b = open(sys.argv[1], "rb").read(400000)
    w, h = dims(b)
    print("%.4f" % (w / h) if w and h else "1.7778")
except Exception:
    print("1.7778")
' "$1" 2>/dev/null)
    echo "${a:-1.7778}"
}

# Proporção da célula do terminal (fallback 2.0)
cell_aspect() {
    local c
    c=$(python3 -c '
import fcntl, termios, struct
try:
    r, c, xp, yp = struct.unpack("HHHH", fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8))
    v = (yp / r) / (xp / c) if (r and c and xp and yp) else 2.0
    print("%.3f" % (v if 1.4 < v < 3.0 else 2.0))
except Exception:
    print("2.0")
' 2>/dev/null)
    echo "${c:-2.0}"
}

set_best_img() {
    BEST_IMG="$1"
    IMG_ASPECT=$(img_aspect "$1")
}

# Calcula a área da imagem pela proporção REAL dela (sem sobra embaixo),
# centraliza o conjunto e posiciona separador/texto logo abaixo da imagem.
compute_layout() {
    read -r IMG_COLS IMG_ROWS IMG_COL_OFF IMG_ROW_OFF SEP_ROW TEXT_ROW < <(awk "
    BEGIN {
        tc = $TERM_COLS
        tr = $TERM_ROWS
        text_lines = 4

        w_pct         = $IMG_WIDTH_PCT  / 100.0
        h_pct         = $IMG_HEIGHT_PCT / 100.0
        gap           = $IMG_GAP
        margin_top    = $IMG_TOP_MARGIN
        margin_side   = $IMG_SIDE_MARGIN
        margin_bottom = $IMG_BOTTOM_MARGIN

        # colunas por linha que a imagem ocupa (proporção da imagem x da célula)
        ar = $IMG_ASPECT * $CELL_ASPECT
        if (ar < 0.1) ar = 3.5556

        max_img_cols = tc - 2 * gap
        if (max_img_cols < 1) max_img_cols = 1

        avail_rows = tr - gap - text_lines - int(margin_top + 0.5)
        max_img_rows = int(tr * h_pct)
        if (max_img_rows > avail_rows) max_img_rows = avail_rows
        if (max_img_rows < 1) max_img_rows = 1

        img_cols = int(tc * w_pct)
        if (img_cols > max_img_cols) img_cols = max_img_cols
        img_rows = int(img_cols / ar + 0.5)
        if (img_rows < 1) img_rows = 1

        if (img_rows > max_img_rows) {
            img_rows = max_img_rows
            img_cols = int(img_rows * ar + 0.5)
            if (img_cols > max_img_cols) img_cols = max_img_cols
        }
        if (img_cols < 1) img_cols = 1

        col_off = int((tc - img_cols) / 2.0 + 0.5) + int(margin_side + 0.5)
        if (col_off < 0) col_off = 0

        total_content = int(margin_top + 0.5) + img_rows + gap + text_lines
        vert_off = int((tr - total_content) / 2.0 + 0.5)
        if (vert_off < 0) vert_off = 0
        row_off = vert_off + int(margin_top + 0.5)

        sep_row  = row_off + img_rows + gap - 1 + int(margin_bottom + 0.5)
        text_row = sep_row + 1

        print img_cols, img_rows, col_off, row_off, sep_row, text_row
    }
    ")
    dbg "layout: term=${TERM_COLS}x${TERM_ROWS} cell=${CELL_ASPECT} img=${BEST_IMG##*/} aspect=${IMG_ASPECT} box=${IMG_COLS}x${IMG_ROWS}@${IMG_COL_OFF},${IMG_ROW_OFF} sep=${SEP_ROW}"
}

# Desenha uma imagem na área calculada
show_image() {
    [ -f "$1" ] || return
    kitty +kitten icat \
        --stdin=no \
        --align left \
        --scale-up \
        --place "${IMG_COLS}x${IMG_ROWS}@${IMG_COL_OFF}x${IMG_ROW_OFF}" \
        "$1" 2>/dev/null
}

# Área da imagem: mostra a HQ; enquanto ela não chega, mostra um aviso em texto
draw_image_area() {
    if [ -n "$BEST_IMG" ] && [ -f "$BEST_IMG" ]; then
        show_image "$BEST_IMG"
    else
        local msg="Aguarde, baixando thumbnail..."
        [ "$THUMB_STATE" = "none" ] && msg="Thumbnail indisponível"
        draw_line "$(( IMG_ROW_OFF + IMG_ROWS / 2 ))" "${C_DIM}${msg}${C_RESET}" "$TERM_COLS"
    fi
}

# Busca a thumbnail HQ no YouTube (roda em segundo plano, nunca bloqueia a UI)
# Args: artista, título, arquivo de saída
fetch_hq_thumb() {
    local artist="$1" title="$2" out="$3"
    local query lower_artist search_tmp

    # Remove @mentions e emojis, preserva CJK (japonês, etc)
    query=$(python3 -c '
import sys, re
text = sys.argv[1]
text = re.sub(r"@[^ ]+", "", text)
text = re.sub("[\U00010000-\U0010FFFF]", "", text)
text = re.sub("[\u2600-\u27BF\u2B00-\u2BFF\uFE00-\uFE0F]", "", text)
text = re.sub(r"[ ]+", " ", text).strip()
print(text)
' "${artist} ${title}" 2>/dev/null)
    lower_artist=$(python3 -c '
import sys, re
text = sys.argv[1].lower()
text = re.sub(r"@[^ ]+", "", text).strip()
print(text)
' "$artist" 2>/dev/null)

    search_tmp=$(mktemp "${out%.jpg}.search.XXXXXX")
    dbg "faixa: ${artist} - ${title}"
    # Busca "flat" (rápida: não extrai cada vídeo), com fallback para o modo antigo
    timeout 25 yt-dlp "ytsearch5:${query}" --flat-playlist --no-warnings \
        --print "%(title)s" --print "%(id)s" 2>/dev/null > "$search_tmp"
    if [ ! -s "$search_tmp" ]; then
        timeout 25 yt-dlp "ytsearch5:${query}" --get-title --get-id 2>/dev/null > "$search_tmp"
    fi

    local best_id="" best_score=999 vid_title vid_id lower_title score
    while IFS= read -r vid_title && IFS= read -r vid_id; do
        [ -z "$vid_id" ] && continue
        lower_title=$(echo "$vid_title" | tr '[:upper:]' '[:lower:]')
        score=0
        echo "$lower_title" | grep -qiE 'react|reaction|reacts|cover|remix|karaoke|lyrics|letra|ao vivo|parody|paródia|casal|reage' && score=$(( score + 10 ))
        echo "$lower_title" | grep -qiF "$lower_artist" && score=$(( score - 5 ))
        if [ $score -lt $best_score ]; then
            best_score=$score
            best_id="$vid_id"
        fi
    done < "$search_tmp"
    rm -f "$search_tmp"

    [ -z "$best_id" ] && { dbg "nenhum vídeo encontrado para: ${query}"; return; }
    dbg "vídeo escolhido: ${best_id}"

    local cand_file
    cand_file=$(mktemp "${out%.jpg}.cand.XXXXXX")

    # 1) Thumbnails que o yt-dlp conhece para o vídeo. Só entram as capas
    #    oficiais (maxres/hq720/sd/hq/mq/default) — frames do vídeo (1.jpg,
    #    hq2.jpg, oar2.jpg...) são descartados. .webp vira .jpg.
    timeout 25 yt-dlp --skip-download --no-warnings \
        --print '%(thumbnails)j' "https://www.youtube.com/watch?v=${best_id}" 2>/dev/null \
        | python3 -c '
import sys, json, re
OK = {"maxresdefault.jpg", "hq720.jpg", "sddefault.jpg", "hqdefault.jpg", "mqdefault.jpg", "default.jpg"}
try:
    th = json.loads(sys.stdin.read())
except Exception:
    sys.exit()
for t in th:
    u = t.get("url")
    if not u:
        continue
    if "ytimg.com" in u:
        u = u.split("?")[0]
        if "/vi_webp/" in u:
            u = u.replace("/vi_webp/", "/vi/").replace(".webp", ".jpg")
        if u.rsplit("/", 1)[-1] not in OK:
            continue
        print(u)
    elif "googleusercontent.com" in u or "ggpht.com" in u:
        print(re.sub(r"=(?:w\d+-h\d+|s\d+)[^ ]*$", "=w1600-h1600-l100", u))
' > "$cand_file" 2>/dev/null

    # 2) Nomes clássicos do YouTube (hq720 e maxres são as maiores)
    printf '%s\n' \
        "https://i.ytimg.com/vi/${best_id}/maxresdefault.jpg" \
        "https://i.ytimg.com/vi/${best_id}/hq720.jpg" \
        "https://i.ytimg.com/vi/${best_id}/sddefault.jpg" \
        "https://i.ytimg.com/vi/${best_id}/hqdefault.jpg" >> "$cand_file"

    dbg "candidatos: $(sort -u "$cand_file" | wc -l)"

    # 3) Baixa todos em paralelo, mede a resolução REAL e fica com a maior
    python3 -c "${PY_DIMS_SRC}"$'\n''
import sys, os, urllib.request
from concurrent.futures import ThreadPoolExecutor

out, listfile, logfile = sys.argv[1], sys.argv[2], sys.argv[3]
urls = []
for line in open(listfile):
    u = line.strip()
    if u and u not in urls:
        urls.append(u)
urls = urls[:14]

def fetch(u):
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            b = r.read()
        w, h = dims(b)
        return u, b, w, h
    except Exception:
        return u, None, 0, 0

with ThreadPoolExecutor(6) as ex:
    res = list(ex.map(fetch, urls))

log = open(logfile, "a")
good = []
for u, b, w, h in res:
    info = ("%dx%d %dB" % (w, h, len(b))) if b else "falhou"
    log.write("  cand %s -> %s\n" % (u[:100], info))
    if b and w > 0 and len(b) > 8000:
        good.append((w * h, len(b), u, b, w, h))
if good:
    good.sort(key=lambda g: (g[0], g[1]), reverse=True)
    best = good[0]
    open(out + ".part", "wb").write(best[3])
    os.replace(out + ".part", out)
    log.write("  escolhida %dx%d %s\n" % (best[4], best[5], best[2][:100]))
else:
    log.write("  nenhuma thumbnail valida\n")
log.close()
' "$out" "$cand_file" "$DEBUG_LOG" 2>>"$DEBUG_LOG"

    rm -f "$cand_file"
}

start_thumb_job() {
    JOB_N=$(( JOB_N + 1 ))
    HQ_BASE="/tmp/music-view-hq-$$-${JOB_N}"
    HQ_FILE="${HQ_BASE}.jpg"
    HQ_DONE="${HQ_BASE}.done"
    JOB_KEY="$ART_URL"
    JOB_PENDING=1
    (
        fetch_hq_thumb "$ARTIST" "$FULL_TITLE" "$HQ_FILE"
        touch "$HQ_DONE"
    ) >/dev/null 2>&1 &
    JOB_PID=$!
}

# ── Loop principal ──────────────────────────────────────────────────────────
while true; do
    PLAYER=$(playerctl --list-all 2>/dev/null | grep -i brave | head -1)
    [ -z "$PLAYER" ] && PLAYER="%any"

    STATUS=$(playerctl -p "$PLAYER" status 2>/dev/null)
    FULL_TITLE=$(playerctl -p "$PLAYER" metadata xesam:title 2>/dev/null)
    ARTIST=$(playerctl -p "$PLAYER" metadata xesam:artist 2>/dev/null)
    ART_URL=$(playerctl -p "$PLAYER" metadata mpris:artUrl 2>/dev/null)
    TIME=$(playerctl -p "$PLAYER" metadata --format '{{duration(position)}} / {{duration(mpris:length)}}' 2>/dev/null)
    THUMB_FILE="${ART_URL#file://}"

    TERM_COLS=$(tput cols)
    TERM_ROWS=$(tput lines)
    CURR_TERM="${TERM_COLS}x${TERM_ROWS}"

    # Janela mudou de tamanho: apaga imagem/texto na hora, espera o tamanho
    # estabilizar (evita desenhar em tamanhos intermediários) e força redesenho
    if [ "$CURR_TERM" != "$LAST_TERM" ]; then
        if [ -n "$LAST_TERM" ]; then
            kitty +kitten icat --clear 2>/dev/null
            clear
            for _ in 1 2 3 4 5 6 7 8; do
                sleep 0.2
                NEW_TERM="$(tput cols)x$(tput lines)"
                [ "$NEW_TERM" = "$CURR_TERM" ] && break
                CURR_TERM="$NEW_TERM"
            done
            TERM_COLS="${CURR_TERM%x*}"
            TERM_ROWS="${CURR_TERM#*x}"
        fi
        CELL_ASPECT=$(cell_aspect)
        LAST_TERM="$CURR_TERM"
        LAST_ART="$NOART"
        LAST_TITLE=""
        LAST_ARTISTTIME=""
        LAST_STATUS=""
        dbg "terminal: ${CURR_TERM} (célula ${CELL_ASPECT})"
    fi

    if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then

        CLEAN_TITLE=$(python3 -c '
import sys, re

title = sys.argv[1]
artist = re.sub(r"[\r\n]+", " ", sys.argv[2]).strip()

if artist:
    esc = re.escape(artist)
    title = re.sub(rf"^{esc}\s*[-–|/:]\s*", "", title, flags=re.IGNORECASE)
    title = re.sub(rf"\s*[|–-]\s*{esc}(?:\s*[|–-].*)?$", "", title, flags=re.IGNORECASE)
    title = re.sub(rf"\s*[-–|/]\s*{esc}\s*$", "", title, flags=re.IGNORECASE)
    title = re.sub(rf"\s*\({esc}\)\s*$", "", title, flags=re.IGNORECASE)

print(title.strip())
' "$FULL_TITLE" "$ARTIST" 2>/dev/null)
        [ -z "$CLEAN_TITLE" ] && CLEAN_TITLE="$FULL_TITLE"

        REDRAW_IMG=0
        START_JOB=0

        if [ "$ART_URL" != "$LAST_ART" ]; then
            clear
            kitty +kitten icat --clear 2>/dev/null

            if [ "$ART_URL" != "$JOB_KEY" ]; then
                # Música nova: apaga os arquivos da faixa anterior e espera a HQ
                stop_thumb_job
                BEST_IMG=""
                IMG_ASPECT="1.7778"
                THUMB_STATE="loading"
                START_JOB=1
            fi
            # (se for só redimensionamento/troca de imagem, reaproveita BEST_IMG e o job)

            compute_layout
            draw_separator
            LAST_ART="$ART_URL"
            LAST_TITLE=""
            LAST_ARTISTTIME=""
            LAST_STATUS=""
            REDRAW_IMG=1
        fi

        # Texto, barra e botões aparecem imediatamente
        draw_text

        # Imagem (ou aviso de download) e início da busca HQ em segundo plano
        [ "$REDRAW_IMG" = 1 ] && draw_image_area
        [ "$START_JOB" = 1 ] && start_thumb_job

        # Quando o job termina, troca para a thumbnail HQ
        if [ "$JOB_PENDING" = 1 ] && [ -e "$HQ_DONE" ]; then
            JOB_PENDING=0
            wait "$JOB_PID" 2>/dev/null
            JOB_PID=""
            if [ -f "$HQ_FILE" ]; then
                dbg "HQ pronta: $HQ_FILE — redesenhando tudo"
                set_best_img "$HQ_FILE"
                # Redesenho completo (mesmo caminho do redimensionamento, que
                # comprovadamente troca a imagem): limpa, refaz layout e desenha
                LAST_ART="$NOART"
                continue
            else
                dbg "HQ indisponível — usando thumb local se existir"
                if [ -f "$THUMB_FILE" ]; then
                    set_best_img "$THUMB_FILE"
                else
                    THUMB_STATE="none"
                fi
                LAST_ART="$NOART"
                continue
            fi
        fi

    else
        if [ "$LAST_ART" != "$NOART" ]; then
            clear
            kitty +kitten icat --clear 2>/dev/null
            stop_thumb_job
            JOB_KEY=""
            BEST_IMG=""
            LAST_ART="$NOART"
            LAST_TITLE=""
            LAST_ARTISTTIME=""
            LAST_STATUS=""
        fi
        draw_line "$(( TERM_ROWS / 2 ))" "${C_DIM}💤  nenhuma mídia tocando…${C_RESET}" "$TERM_COLS"
    fi

    # IFS= e -r garantem que a barra de espaço seja lida corretamente
    key=""
    IFS= read -rsn1 -t 1 key 2>/dev/null
    # status 1 = fim da entrada (terminal fechado): sai em vez de girar em falso
    [ $? -eq 1 ] && break
    case "$key" in
        "$KEY_PLAYPAUSE") playerctl -p "$PLAYER" play-pause ;;
        "$KEY_NEXT")      playerctl -p "$PLAYER" next ;;
        "$KEY_PREV")      playerctl -p "$PLAYER" previous ;;
        "$KEY_QUIT"|"${KEY_QUIT^^}") break ;;
    esac
done