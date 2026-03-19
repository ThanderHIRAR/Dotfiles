#!/bin/bash
# ─────────────────────────────────────────
#  music-view — launcher
# ─────────────────────────────────────────

SESSION="music-view"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THUMB_SCRIPT="$SCRIPT_DIR/music-view-thumb.sh"
CAVA_CONF="/home/herbert/music-view/config"

# Mata sessão anterior se existir
tmux kill-session -t "$SESSION" 2>/dev/null
sleep 0.1

# Cria sessão detached sem tamanho fixo (tmux usa o terminal atual)
tmux new-session -d -s "$SESSION"

# Painel esquerdo: thumbnail + info
tmux send-keys -t "$SESSION:0.0" "bash '$THUMB_SCRIPT'" Enter

# Divide verticalmente — painel direito com 40% da largura para o cava
tmux split-window -t "$SESSION:0.0" -h -p 40
tmux send-keys -t "$SESSION:0.1" "cava -p '$CAVA_CONF'" Enter

# Visual: sem status bar, bordas na paleta Miku
tmux set-option -t "$SESSION" status off
tmux set-option -t "$SESSION" pane-border-style "fg=#4FBEF0"
tmux set-option -t "$SESSION" pane-active-border-style "fg=#4FBEF0"
tmux set-option -t "$SESSION" pane-border-lines heavy

# Foca painel esquerdo
tmux select-pane -t "$SESSION:0.0"

# Anexa
tmux attach-session -t "$SESSION"
