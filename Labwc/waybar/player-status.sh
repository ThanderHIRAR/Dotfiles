#!/bin/bash

STATUS=$(playerctl status 2>/dev/null)

if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
    # Pega Título e o Tempo
    TITLE=$(playerctl metadata --format '{{title}}' 2>/dev/null)
    TIME=$(playerctl metadata --format '{{duration(position)}}/{{duration(mpris:length)}}' 2>/dev/null)
    
    # Ícone baseado no status
    [ "$STATUS" = "Playing" ] && ICON="󰏤" || ICON="󰐊"
    
    # Retorna com a tag <small> para diminuir o tempo
    echo "$ICON $TITLE <small>[$TIME]</small>"
else
    echo "󰅙 Não há nada em reprodução"
fi