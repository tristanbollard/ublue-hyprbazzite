#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"

# Resolve internal display name (prefer eDP/LVDS connectors)
get_internal_output() {
    hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.name | test("^(eDP|LVDS)")) | .name' | head -n1
}

# Count external outputs currently connected/enabled
count_external_outputs() {
    hyprctl -j monitors 2>/dev/null | jq '[.[] | select(.name | test("^(eDP|LVDS)") | not)] | length'
}

internal_output="$(get_internal_output || true)"
external_count="$(count_external_outputs || echo 0)"

case "$action" in
    close)
        # With an external display attached, disable only the internal panel.
        if [[ -n "$internal_output" && "$external_count" -gt 0 ]]; then
            hyprctl keyword monitor "$internal_output,disable"
            exit 0
        fi

        # No external display: suspend as expected on lid close.
        systemctl suspend
        ;;
    open)
        # Restore internal panel using preferred mode/position when lid reopens.
        if [[ -n "$internal_output" ]]; then
            hyprctl keyword monitor "$internal_output,preferred,auto,1"
        fi
        ;;
    *)
        echo "Usage: $0 {close|open}" >&2
        exit 1
        ;;
esac
