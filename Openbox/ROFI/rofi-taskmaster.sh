#!/bin/bash

# 1. Seleção: Mostra PID e Nome
selected=$(ps -u $USER -eo pid,comm --sort=-pcpu | tail -n +2 | rofi -dmenu -i -p "Kill App" -mesg "Selecione qualquer processo da lista")

[ -z "$selected" ] && exit 1

child_pid=$(echo "$selected" | awk '{print $1}')
name=$(echo "$selected" | awk '{print $2}')

# 2. Localiza o PID principal (o topo da árvore desse app)
# O comando 'pidof' ou 'pgrep' pega todos, o 'head -n 1' foca no líder
main_pid=$(pgrep -o -f "$name")

# 3. Confirmação
confirm=$(echo -e "Sim\nNão" | rofi -dmenu -i -p "Matar $name?" -mesg "Isso encerrará todas as instâncias de $name")

if [ "$confirm" == "Sim" ]; then
    # Mata o grupo de processos inteiro (uso do '-' antes do PID foca no grupo)
    pkill -9 -f "$name"
    
    # Limpeza de segurança para garantir que não sobrem órfãos
    pkill -9 $main_pid 2>/dev/null
    
    notify-send "Taskmaster" "Toda a árvore de $name foi encerrada."
fi