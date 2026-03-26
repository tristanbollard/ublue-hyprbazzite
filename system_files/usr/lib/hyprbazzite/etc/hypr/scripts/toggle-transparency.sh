#!/bin/bash
TRANS_STATE="/tmp/hypr_transparency_off"

if [ -f "$TRANS_STATE" ]; then
    rm "$TRANS_STATE"
    hyprctl reload
    notify-send "Transparency Enabled" "Restoring default opacity settings."
else
    touch "$TRANS_STATE"
    hyprctl keyword windowrule "opacity 1 override 1 override, ^(.*)$"
    notify-send "Transparency Disabled" "Full opacity enforced."
fi
