#!/bin/bash
# tdp-profile-selector.sh: Interactive TDP selector for AMD CPUs
# Uses tdp-control.sh to list and set TDP

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
TDP_SCRIPT="$SCRIPT_DIR/tdp-control.sh"

# Get available TDP values
TDP_LIST=$($TDP_SCRIPT list)

# Show selection menu (wofi/rofi/dmenu)
SELECTED=$(echo "$TDP_LIST" | wofi --dmenu --width 300 --height 400 --prompt "Select TDP (W)")

if [ -n "$SELECTED" ]; then
    $TDP_SCRIPT set "$SELECTED" | wofi --dmenu --width 400 --height 100 --prompt "TDP Set to $SELECTED W" || true
fi
