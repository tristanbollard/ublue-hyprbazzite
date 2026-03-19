#!/bin/bash
# tdp-control.sh: Universal TDP (power limit) management for AMD CPUs
# Supports: Strix Halo (AI+ 395), Ryzen 5700X3D, and other AMD CPUs
# Usage:
#   ./tdp-control.sh get         # Show current TDP info
#   ./tdp-control.sh set <watts> # Set TDP (if supported)
#   ./tdp-control.sh profile <eco|balanced|performance> # Set preset

set -e

# Detect CPU
CPU_MODEL=$(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)


# Preset values (adjust as needed)
ECO_TDP=35
BALANCED_TDP=54
PERFORMANCE_TDP=65

# Default TDP bounds (override if detected)
MIN_TDP=15
MAX_TDP=65
STEP_TDP=1

# Try to detect TDP bounds from ryzenadj or amdctl
detect_bounds() {
    if has_ryzenadj; then
        # Try to parse min/max from ryzenadj --info
        local info=$(ryzenadj --info 2>/dev/null)
        local min=$(echo "$info" | grep -i 'min tdp' | grep -o '[0-9]\+')
        local max=$(echo "$info" | grep -i 'max tdp' | grep -o '[0-9]\+')
        if [ -n "$min" ] && [ -n "$max" ]; then
            MIN_TDP=$min
            MAX_TDP=$max
        fi
    elif has_amdctl; then
        # Try to parse min/max from amdctl info
        local info=$(amdctl info 2>/dev/null)
        local min=$(echo "$info" | grep -i 'min power limit' | grep -o '[0-9]\+')
        local max=$(echo "$info" | grep -i 'max power limit' | grep -o '[0-9]\+')
        if [ -n "$min" ] && [ -n "$max" ]; then
            MIN_TDP=$min
            MAX_TDP=$max
        fi
    fi
}

list_tdps() {
    detect_bounds
    for ((w=$MIN_TDP; w<=$MAX_TDP; w+=$STEP_TDP)); do
        echo "$w"
    done
}

# Helper: check for ryzenadj
has_ryzenadj() { command -v ryzenadj >/dev/null 2>&1; }

# Helper: check for AMD PBO/eco-mode
has_amdctl() { command -v amdctl >/dev/null 2>&1; }

get_tdp() {
    if has_ryzenadj; then
        ryzenadj --info | grep -E 'TDP|CPU Name'
    elif has_amdctl; then
        amdctl info | grep -i 'power limit\|cpu model'
    else
        echo "TDP control not supported on this system."
        exit 1
    fi
}

set_tdp() {
    local tdp_watts="$1"
    if has_ryzenadj; then
        sudo ryzenadj --stapm-limit=$((tdp_watts*1000)) --fast-limit=$((tdp_watts*1000)) --slow-limit=$((tdp_watts*1000))
        echo "Set TDP to $tdp_watts W (ryzenadj)"
    elif has_amdctl; then
        sudo amdctl set power-limit $tdp_watts
        echo "Set TDP to $tdp_watts W (amdctl)"
    else
        echo "TDP control not supported on this system."
        exit 1
    fi
}

set_profile() {
    case "$1" in
        eco)
            set_tdp "$ECO_TDP"
            ;;
        balanced)
            set_tdp "$BALANCED_TDP"
            ;;
        performance)
            set_tdp "$PERFORMANCE_TDP"
            ;;
        *)
            echo "Unknown profile: $1 (use eco, balanced, performance)"
            exit 1
            ;;
    esac
}

case "$1" in
    get)
        get_tdp
        ;;
    set)
        set_tdp "$2"
        ;;
    profile)
        set_profile "$2"
        ;;
    list)
        list_tdps
        ;;
    *)
        echo "Usage: $0 get | set <watts> | profile <eco|balanced|performance> | list"
        exit 1
        ;;
