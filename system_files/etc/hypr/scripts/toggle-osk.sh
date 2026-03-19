#!/usr/bin/env bash

set -euo pipefail

WVKBD_CONF="/etc/hypr/wvkbd.conf"
if [ -f "${WVKBD_CONF}" ]; then
    . "${WVKBD_CONF}"
fi

WVKBD_FONT="${WVKBD_FONT:-JetBrains Mono 20}"
WVKBD_BG="${WVKBD_BG:-282a36}"
WVKBD_FG="${WVKBD_FG:-44475a}"
WVKBD_FG_SP="${WVKBD_FG_SP:-bd93f9}"
WVKBD_PRESS="${WVKBD_PRESS:-6272a4}"
WVKBD_PRESS_SP="${WVKBD_PRESS_SP:-ff79c6}"
WVKBD_TEXT="${WVKBD_TEXT:-f8f8f2}"
WVKBD_TEXT_SP="${WVKBD_TEXT_SP:-f8f8f2}"
WVKBD_ALPHA="${WVKBD_ALPHA:-230}"

if pgrep -x wvkbd-mobintl >/dev/null 2>&1; then
    pkill -RTMIN -x wvkbd-mobintl
    exit 0
fi

if pgrep -x wvkbd >/dev/null 2>&1; then
    pkill -RTMIN -x wvkbd
    exit 0
fi

if command -v wvkbd-mobintl >/dev/null 2>&1; then
    wvkbd-mobintl \
        --hidden \
        --non-exclusive \
        --fn "${WVKBD_FONT}" \
        --alpha "${WVKBD_ALPHA}" \
        --bg "${WVKBD_BG}" \
        --fg "${WVKBD_FG}" \
        --fg-sp "${WVKBD_FG_SP}" \
        --press "${WVKBD_PRESS}" \
        --press-sp "${WVKBD_PRESS_SP}" \
        --text "${WVKBD_TEXT}" \
        --text-sp "${WVKBD_TEXT_SP}" >/dev/null 2>&1 &
    exit 0
fi

if command -v wvkbd >/dev/null 2>&1; then
    wvkbd \
        --hidden \
        --non-exclusive \
        --fn "${WVKBD_FONT}" \
        --alpha "${WVKBD_ALPHA}" \
        --bg "${WVKBD_BG}" \
        --fg "${WVKBD_FG}" \
        --fg-sp "${WVKBD_FG_SP}" \
        --press "${WVKBD_PRESS}" \
        --press-sp "${WVKBD_PRESS_SP}" \
        --text "${WVKBD_TEXT}" \
        --text-sp "${WVKBD_TEXT_SP}" >/dev/null 2>&1 &
    exit 0
fi

notify-send "On-screen keyboard" "wvkbd is not installed or not in PATH"