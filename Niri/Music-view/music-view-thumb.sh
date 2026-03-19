#!/bin/bash
# ─────────────────────────────────────────
#  music-view-thumb — painel esquerdo
# ─────────────────────────────────────────
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
IMG_BOTTOM_MARGIN=-10

# ══════════════════════════════════════
#  FIM DA CONFIGURAÇÃO
# ╚══════════════════════════════════════

SESSION="music-view"
LAST_ART=""
LAST_TITLE=""
LAST_ARTISTTIME=""
LAST_STATUS=""
LAST_TERM=""

# Cores
C_L="\e[38;2;79;190;240m"    # #4FBEF0
C_M="\e[38;2;53;138;199m"    # #358AC7
C_D="\e[38;2;27;85;158m"     # #1B559E
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"

cleanup() {
    tput cnorm
    stty echo 2>/dev/null
    kitty +kitten icat --clear 2>/dev/null
    tput rmcup
    tmux kill-session -t "$SESSION" 2>/dev/null
    exit
}
trap cleanup INT TERM EXIT

tput smcup
tput civis
stty -echo 2>/dev/null
clear

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
    [ "$STATUS" = "Playing" ] && status_icon="▶" || status_icon="⏸"

    local max_title=$(( TERM_COLS - 4 ))
    local title="$CLEAN_TITLE"
    [ ${#title} -gt $max_title ] && title="${title:0:$max_title}…"

    local artisttime="${ARTIST:-Desconhecido}  ·  ${TIME}"

    if [ "$title" != "$LAST_TITLE" ]; then
        draw_line "$TEXT_ROW" "${C_BOLD}${C_L}♪  ${title}${C_RESET}" "$TERM_COLS"
        LAST_TITLE="$title"
    fi

    if [ "$artisttime" != "$LAST_ARTISTTIME" ]; then
        draw_line "$(( TEXT_ROW + 1 ))" "${C_M}${ARTIST:-Desconhecido}  ${C_D}·  ${C_M}${TIME}${C_RESET}" "$TERM_COLS"
        LAST_ARTISTTIME="$artisttime"
    fi

    if [ "$status_icon" != "$LAST_STATUS" ]; then
        draw_line "$(( TEXT_ROW + 3 ))" "${C_DIM}${status_icon}  p·play/pause   n·próxima   b·anterior   q·sair${C_RESET}" "$TERM_COLS"
        LAST_STATUS="$status_icon"
    fi
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

    # Detecta mudança de tamanho do terminal — força redesenho
    CURR_TERM="${TERM_COLS}x${TERM_ROWS}"
    if [ "$CURR_TERM" != "$LAST_TERM" ]; then
        LAST_ART=""
        LAST_TERM="$CURR_TERM"
    fi

    # Todo o cálculo de layout em awk com precisão decimal
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

        max_img_cols = tc - 2 * gap
        if (max_img_cols < 1) max_img_cols = 1

        img_cols = int(tc * w_pct)
        if (img_cols > max_img_cols) img_cols = max_img_cols
        img_rows = int(img_cols / 2)

        max_img_rows = int(tr * h_pct)
        if (img_rows > max_img_rows) {
            img_rows = max_img_rows
            img_cols = img_rows * 2
            if (img_cols > max_img_cols) img_cols = max_img_cols
        }

        col_off = gap + int(margin_side + 0.5)

        total_content = int(margin_top + 0.5) + img_rows + gap + text_lines
        vert_off = int((tr - total_content) / 2.0 + 0.5)
        if (vert_off < 0) vert_off = 0
        row_off = vert_off + int(margin_top + 0.5)

        sep_row  = row_off + img_rows + gap - 1 + int(margin_bottom + 0.5)
        text_row = sep_row + 1

        print img_cols, img_rows, col_off, row_off, sep_row, text_row
    }
    ")

    if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then

        CLEAN_TITLE="$FULL_TITLE"
        if [ -n "$ARTIST" ]; then
            ESCAPED_ARTIST=$(printf '%s\n' "$ARTIST" | sed 's/[[\.*^$()+?{|]/\\&/g')
            CLEAN_TITLE=$(echo "$CLEAN_TITLE" | sed -E "s/^${ESCAPED_ARTIST}[[:space:]]*(-|–|\||\/|:)[[:space:]]*//i")
            CLEAN_TITLE=$(echo "$CLEAN_TITLE" | sed -E "s/[[:space:]]*(\||–|-)[[:space:]]*${ESCAPED_ARTIST}([[:space:]]*(\||–|-).*)?$//i")
            CLEAN_TITLE=$(echo "$CLEAN_TITLE" | sed -E "s/[[:space:]]*(-|–|\||\/)[[:space:]]*${ESCAPED_ARTIST}[[:space:]]*$//i")
            CLEAN_TITLE=$(echo "$CLEAN_TITLE" | sed -E "s/[[:space:]]*\(${ESCAPED_ARTIST}\)[[:space:]]*$//i")
            CLEAN_TITLE=$(echo "$CLEAN_TITLE" | sed -E 's/^[[:space:]]+|[[:space:]]+$//')
        fi

        if [ "$ART_URL" != "$LAST_ART" ]; then
            clear
            kitty +kitten icat --clear 2>/dev/null

            # Remove @mentions e emojis, preserva CJK (japonês, etc)
            CLEAN_QUERY=$(python3 -c "
import sys, re
text = sys.argv[1]
text = re.sub(r'@[^ ]+', '', text)
text = re.sub(u'[𐀀-􏿿]', '', text)
text = re.sub(u'[☀-➿⬀-⯿︀-️]', '', text)
text = re.sub(r'[ ]+', ' ', text).strip()
print(text)
" "${ARTIST} ${FULL_TITLE}" 2>/dev/null)
            LOWER_ARTIST=$(python3 -c "
import sys, re
text = sys.argv[1].lower()
text = re.sub(r'@[^ ]+', '', text).strip()
print(text)
" "$ARTIST" 2>/dev/null)

            SEARCH_TMP=$(mktemp)
            yt-dlp "ytsearch5:${CLEAN_QUERY}" --get-title --get-id 2>/dev/null > "$SEARCH_TMP"

            BEST_ID=""
            BEST_SCORE=999
            while IFS= read -r vid_title && IFS= read -r vid_id; do
                [ -z "$vid_id" ] && continue
                LOWER_TITLE=$(echo "$vid_title" | tr '[:upper:]' '[:lower:]')
                SCORE=0
                echo "$LOWER_TITLE" | grep -qiE 'react|reaction|reacts|cover|remix|karaoke|lyrics|letra|ao vivo|parody|paródia|casal|reage' && SCORE=$(( SCORE + 10 ))
                echo "$LOWER_TITLE" | grep -qiF "$LOWER_ARTIST" && SCORE=$(( SCORE - 5 ))
                if [ $SCORE -lt $BEST_SCORE ]; then
                    BEST_SCORE=$SCORE
                    BEST_ID="$vid_id"
                fi
            done < "$SEARCH_TMP"
            rm -f "$SEARCH_TMP"

            VIDEO_ID="$BEST_ID"
            if [ -n "$VIDEO_ID" ]; then
                THUMB_URL=""
                for quality in maxresdefault sddefault hqdefault; do
                    URL="https://i.ytimg.com/vi/${VIDEO_ID}/${quality}.jpg"
                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
                    if [ "$HTTP_CODE" = "200" ]; then
                        THUMB_URL="$URL"
                        break
                    fi
                done
                if [ -n "$THUMB_URL" ]; then
                    curl -s "$THUMB_URL" -o /tmp/music-view-hq-thumb.jpg 2>/dev/null
                    DISPLAY_THUMB="/tmp/music-view-hq-thumb.jpg"
                else
                    DISPLAY_THUMB="$THUMB_FILE"
                fi
            else
                DISPLAY_THUMB="$THUMB_FILE"
            fi

            if [ -f "$DISPLAY_THUMB" ]; then
                kitty +kitten icat \
                    --align left \
                    --scale-up \
                    --place "${IMG_COLS}x${IMG_ROWS}@${IMG_COL_OFF}x${IMG_ROW_OFF}" \
                    "$DISPLAY_THUMB" 2>/dev/null
            fi

            draw_separator
            LAST_ART="$ART_URL"
            LAST_TITLE=""
            LAST_ARTISTTIME=""
            LAST_STATUS=""
        fi

        draw_text

    else
        if [ -n "$LAST_ART" ]; then
            clear
            kitty +kitten icat --clear 2>/dev/null
            LAST_ART=""
            LAST_TITLE=""
            LAST_ARTISTTIME=""
            LAST_STATUS=""
        fi
        draw_line "$(( TERM_ROWS / 2 ))" "${C_DIM}💤  nenhuma mídia tocando…${C_RESET}" "$TERM_COLS"
    fi

    read -t 1 -n 1 key 2>/dev/null
    case $key in
        p) playerctl -p "$PLAYER" play-pause ;;
        n) playerctl -p "$PLAYER" next ;;
        b) playerctl -p "$PLAYER" previous ;;
        q) break ;;
    esac
done