#!/usr/bin/env bash

set -euo pipefail

WVKBD_CONF="/etc/hypr/wvkbd.conf"
if [ -f "${WVKBD_CONF}" ]; then
    . "${WVKBD_CONF}"
fi

WVKBD_LAYOUT="${WVKBD_LAYOUT:-mobintl}"
WVKBD_FONT="${WVKBD_FONT:-JetBrains Mono 20}"
WVKBD_BG="${WVKBD_BG:-282a36}"
WVKBD_FG="${WVKBD_FG:-44475a}"
WVKBD_FG_SP="${WVKBD_FG_SP:-bd93f9}"
WVKBD_PRESS="${WVKBD_PRESS:-6272a4}"
WVKBD_PRESS_SP="${WVKBD_PRESS_SP:-ff79c6}"
WVKBD_TEXT="${WVKBD_TEXT:-f8f8f2}"
WVKBD_TEXT_SP="${WVKBD_TEXT_SP:-f8f8f2}"
WVKBD_ALPHA="${WVKBD_ALPHA:-230}"
WVKBD_ANCHOR="${WVKBD_ANCHOR:-bottom}"
WVKBD_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/wvkbd-anchor"

WVKBD_BIN=""

if [ -f "${WVKBD_STATE_FILE}" ]; then
    WVKBD_ANCHOR="$(cat "${WVKBD_STATE_FILE}" 2>/dev/null || echo "${WVKBD_ANCHOR}")"
fi

if command -v wvkbd-mobintl >/dev/null 2>&1; then
    WVKBD_BIN="wvkbd-mobintl"
elif command -v wvkbd >/dev/null 2>&1; then
    WVKBD_BIN="wvkbd"
else
    exit 0
fi

has_physical_keyboard() {
    compgen -G "/dev/input/by-id/*-event-kbd" >/dev/null
}

is_running() {
    pgrep -x "${WVKBD_BIN}" >/dev/null 2>&1
}

apply_position_rules() {
    local anchor="$1"

    if ! command -v hyprctl >/dev/null 2>&1; then
        return
    fi

    hyprctl keyword windowrule "float on, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    hyprctl keyword windowrule "float on, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    hyprctl keyword windowrule "size 100% 50%, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    hyprctl keyword windowrule "size 100% 50%, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true

    if [ "${anchor}" = "top" ]; then
        hyprctl keyword windowrule "move 0 0, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 0, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    else
        hyprctl keyword windowrule "move 0 50%, match:class ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
        hyprctl keyword windowrule "move 0 50%, match:title ^(wvkbd|wvkbd-.*)$" >/dev/null 2>&1 || true
    fi
}

start_hidden() {
    if ! is_running; then
        "${WVKBD_BIN}" \
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
            --text-sp "${WVKBD_TEXT_SP}" \
            >/dev/null 2>&1 &
    fi
}

stop_wvkbd() {
    pkill -x "${WVKBD_BIN}" >/dev/null 2>&1 || true
}

sync_state() {
    if has_physical_keyboard; then
        stop_wvkbd
    else
        start_hidden
    fi
}

sync_state
apply_position_rules "${WVKBD_ANCHOR}"

udevadm monitor --udev --subsystem-match=input --property | while IFS= read -r line; do
    case "${line}" in
        ACTION=add|ACTION=remove|ACTION=change)
            sync_state
            ;;
    esac
done