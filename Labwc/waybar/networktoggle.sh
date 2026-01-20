#!/bin/bash

# Busca automaticamente o nome da interface que começa com "enp"
INTERFACE=$(nmcli -t -f DEVICE,STATE device | grep "^enp" | cut -d: -f1 | head -n1)
# Verifica o status dela
STATUS=$(nmcli -t -f DEVICE,STATE device | grep "^$INTERFACE" | cut -d: -f2)

if [ "$STATUS" = "connected" ]; then
    nmcli device disconnect "$INTERFACE"
else
    nmcli device connect "$INTERFACE"
fi
