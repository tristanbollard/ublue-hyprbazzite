#!/bin/bash

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Power Profile" "$1"
    fi
}

get_next_ppd_profile() {
    local current
    current=$(busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null | awk -F'"' '{print $2}')

    case "$current" in
        power-saver) printf 'balanced' ;;
        balanced) printf 'performance' ;;
        performance) printf 'power-saver' ;;
        *) printf 'balanced' ;;
    esac
}

if busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile >/dev/null 2>&1; then
    next_profile=$(get_next_ppd_profile)

    if busctl --system set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s "$next_profile" >/dev/null 2>&1; then
        notify "Switched to ${next_profile}"
        exit 0
    fi

    notify "Could not switch profile via DBus"
    exit 1
fi

if command -v tuned-adm >/dev/null 2>&1; then
    # Last-resort fallback without interactive GUI authentication.
    if sudo -n tuned-adm profile balanced >/dev/null 2>&1; then
        notify "Switched to balanced"
        exit 0
    fi

    notify "No permission to switch profile (no popup mode)"
    exit 1
fi

notify "No supported power profile tool found"
exit 1
