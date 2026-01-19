#!/bin/bash

# Caminho para o seu vídeo
VIDEO="/home/herbert/Wallpapers/hollow-knight-silksong-wallpaperwaifu-com.mp4"

# 1. Mata instâncias anteriores para não pesar
pkill -9 xwinwrap
pkill -9 mpv

# 2. Inicia o wallpaper no fundo (camada inferior do Openbox)
xwinwrap -fs -fdt -ni -b -nf -ov -- mpv -wid %WID --loop --no-audio --panscan=1.0 "$VIDEO" &

# 3. Loop de monitoramento de performance
while true; do
    # Obtém o ID da janela ativa
    ACTIVE_WIN=$(xdotool getactivewindow)
    
    # Verifica se a janela está maximizada ou em tela cheia (X11 State)
    # Procuramos por _NET_WM_STATE_FULLSCREEN ou _NET_WM_STATE_MAXIMIZED
    IS_FULL=$(xprop -id "$ACTIVE_WIN" _NET_WM_STATE | grep -E "FULLSCREEN|MAXIMIZED")

    if [ -n "$IS_FULL" ]; then
        pkill -STOP mpv  # Pausa o processo (0% CPU/GPU)
    else
        pkill -CONT mpv  # Retoma o vídeo
    fi
    
    sleep 2 # Verifica a cada 2 segundos para não sobrecarregar o processador
done
