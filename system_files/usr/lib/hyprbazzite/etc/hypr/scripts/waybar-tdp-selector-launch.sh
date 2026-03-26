#!/bin/bash

if /etc/hypr/scripts/tdp-control.sh supports >/dev/null 2>&1; then
    exec /etc/hypr/scripts/tdp-profile-selector.sh
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "TDP Control" "TDP control is unsupported on this CPU"
fi

exit 0
