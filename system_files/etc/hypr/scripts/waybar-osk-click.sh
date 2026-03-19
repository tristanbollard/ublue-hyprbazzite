#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wvkbd-anchor"
ANCHOR="bottom"

if [ -f "${STATE_FILE}" ]; then
    ANCHOR="$(cat "${STATE_FILE}" 2>/dev/null || echo "bottom")"
fi

if pgrep -x wvkbd-mobintl >/dev/null 2>&1 || pgrep -x wvkbd >/dev/null 2>&1; then
    exec /etc/hypr/scripts/swap-osk-half.sh
fi

/etc/hypr/scripts/toggle-osk.sh >/dev/null 2>&1
sleep 0.3
pkill -USR2 -x wvkbd-mobintl >/dev/null 2>&1 || true
pkill -USR2 -x wvkbd >/dev/null 2>&1 || true

if command -v hyprctl >/dev/null 2>&1; then
    if [ "${ANCHOR}" = "top" ]; then
        hyprctl keyword windowrule "move 0 0, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 0, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    else
        hyprctl keyword windowrule "move 0 50%, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 50%, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    fi
fi