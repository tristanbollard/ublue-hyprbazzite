#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wvkbd-anchor"
CURRENT="bottom"

if [ -f "${STATE_FILE}" ]; then
    CURRENT="$(cat "${STATE_FILE}" 2>/dev/null || echo "bottom")"
fi

if [ "${CURRENT}" = "bottom" ]; then
    NEXT="top"
else
    NEXT="bottom"
fi

printf '%s\n' "${NEXT}" > "${STATE_FILE}"

if command -v hyprctl >/dev/null 2>&1; then
    if [ "${NEXT}" = "top" ]; then
        hyprctl keyword windowrule "move 0 0, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 0, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    else
        hyprctl keyword windowrule "move 0 50%, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 50%, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    fi
fi

pkill -RTMIN -x wvkbd-mobintl >/dev/null 2>&1 || true
pkill -RTMIN -x wvkbd >/dev/null 2>&1 || true