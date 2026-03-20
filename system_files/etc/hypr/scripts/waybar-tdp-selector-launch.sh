#!/bin/bash

supports_tdp=0

if command -v amdctl >/dev/null 2>&1; then
    supports_tdp=1
elif command -v ryzenadj >/dev/null 2>&1; then
    info=$(ryzenadj --info 2>&1)
    if printf '%s' "$info" | grep -q 'STAPM LIMIT'; then
        supports_tdp=1
    fi
fi

if [ "$supports_tdp" -eq 1 ]; then
    exec /etc/hypr/scripts/tdp-profile-selector.sh
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "TDP Control" "TDP control is unsupported on this CPU"
fi

exit 0
