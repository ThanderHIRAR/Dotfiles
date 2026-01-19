#!/bin/bash

# Ações disponíveis
# Icons: Shutdown (⏻), Reboot (↻), Suspend (☾), Lock (🔒), Logout (⏴)
options="Shutdown\nReboot\nLogout"

# Executa o rofi para exibir o menu
choice=$(echo -e "$options" | rofi -dmenu -i -p "Power Menu:")

case "$choice" in
    Shutdown)
        systemctl poweroff
        ;;
    Reboot)
        systemctl reboot
        ;;
    Logout)
        # Substitua 'openbox-exit' pelo comando que encerra sua sessão (pode ser 'pkill openbox' ou 'openbox --exit')
        openbox --exit 
        ;;
esac
