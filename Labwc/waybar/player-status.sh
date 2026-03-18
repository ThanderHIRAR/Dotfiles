#!/bin/bash

STATUS=$(playerctl status 2>/dev/null)

if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
    # Pega Título e escapa caracteres especiais para o Waybar (Pango Markup)
    TITLE=$(playerctl metadata --format '{{title}}' 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    
    # Pega o Tempo (formatado como [atual/total])
    TIME=$(playerctl metadata --format '{{duration(position)}}/{{duration(mpris:length)}}' 2>/dev/null)

    # Ícone baseado no status
    [ "$STATUS" = "Playing" ] && ICON="󰏤" || ICON="󰐊"

    # Retorna com a tag <small> (o TITLE já está protegido pelo sed agora)
    echo "$ICON <small>[$TIME]</small> $TITLE"
else
    echo "󰅙 Não há nada em reprodução"
fi
