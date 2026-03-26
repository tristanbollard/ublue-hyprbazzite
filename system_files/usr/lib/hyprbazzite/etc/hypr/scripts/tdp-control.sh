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

# Helper: check for ryzenadj
has_ryzenadj() { command -v ryzenadj >/dev/null 2>&1; }

# Helper: check for AMD PBO/eco-mode
has_amdctl() { command -v amdctl >/dev/null 2>&1; }

is_strix_halo_cpu() {
    local model_lc
    model_lc=$(printf '%s' "$CPU_MODEL" | tr '[:upper:]' '[:lower:]')
    [[ "$model_lc" =~ (ryzen[[:space:]]+ai[[:space:]]+max|strix[[:space:]]+halo) ]]
}

find_sysfs_tdp_file() {
    local f h name

    # Prefer CPU/package-oriented hwmon nodes when available.
    for h in /sys/class/hwmon/hwmon*; do
        [ -d "$h" ] || continue
        [ -r "$h/name" ] || continue
        [ -f "$h/power1_cap" ] || continue

        name=$(cat "$h/name" 2>/dev/null || true)
        case "$name" in
            k10temp|zenpower|fam15h_power|coretemp)
                echo "$h/power1_cap"
                return 0
                ;;
        esac
    done

    # Strix Halo APUs may expose only amdgpu power cap controls for the package policy.
    if is_strix_halo_cpu; then
        for h in /sys/class/hwmon/hwmon*; do
            [ -d "$h" ] || continue
            [ -r "$h/name" ] || continue
            if [ "$(cat "$h/name" 2>/dev/null || true)" = "amdgpu" ] && [ -f "$h/power1_cap" ]; then
                echo "$h/power1_cap"
                return 0
            fi
        done
    fi

    f=$(find /sys/class/powercap -type f -name 'constraint_0_power_limit_uw' 2>/dev/null | head -n1)
    if [ -n "$f" ]; then
        echo "$f"
        return 0
    fi

    return 1
}

has_sysfs_tdp() {
    local f
    f=$(find_sysfs_tdp_file || true)
    [ -n "$f" ]
}

supports_ryzenadj_control() {
    local info
    has_ryzenadj || return 1
    info=$(ryzenadj --info 2>&1 || true)

    # Newer Ryzen AI Max platforms may expose different limit labels.
    if printf '%s' "$info" | grep -Eqi 'unsupported model|only ryzen mobile series are supported'; then
        return 1
    fi

    # Accept common power-limit labels from old/new ryzenadj outputs.
    printf '%s' "$info" | grep -Eqi '(stapm|fast|slow|ppt)[[:space:]_:-]*limit'
}

supports_amdctl_control() {
    local info
    has_amdctl || return 1
    info=$(amdctl info 2>/dev/null || true)
    echo "$info" | grep -qi 'power limit'
}

get_backend() {
    if supports_ryzenadj_control; then
        echo "ryzenadj"
        return 0
    fi

    if supports_amdctl_control; then
        echo "amdctl"
        return 0
    fi

    if has_sysfs_tdp; then
        echo "sysfs"
        return 0
    fi

    return 1
}

is_int() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

set_bounds_if_valid() {
    local min="$1"
    local max="$2"

    if is_int "$min" && is_int "$max" && [ "$min" -gt 0 ] && [ "$max" -ge "$min" ]; then
        MIN_TDP="$min"
        MAX_TDP="$max"
        return 0
    fi
    return 1
}

detect_bounds_from_sysfs() {
    local min_file max_file default_file min max default cap_file cap_dir

    # Common powercap naming for modern AMD/Intel platforms
    min_file=$(find /sys/class/powercap -type f -name 'constraint_0_min_power_uw' 2>/dev/null | head -n1)
    max_file=$(find /sys/class/powercap -type f -name 'constraint_0_max_power_uw' 2>/dev/null | head -n1)
    if [ -n "$min_file" ] && [ -n "$max_file" ]; then
        min=$(( $(cat "$min_file" 2>/dev/null) / 1000000 ))
        max=$(( $(cat "$max_file" 2>/dev/null) / 1000000 ))
        set_bounds_if_valid "$min" "$max" && return 0
    fi

    # hwmon fallback when min/max are exported there
    cap_file=$(find_sysfs_tdp_file || true)
    if [ -n "$cap_file" ]; then
        cap_dir=$(dirname "$cap_file")
        min_file="$cap_dir/power1_cap_min"
        max_file="$cap_dir/power1_cap_max"
        default_file="$cap_dir/power1_cap_default"

        [ -f "$min_file" ] || min_file=""
        [ -f "$max_file" ] || max_file=""
        [ -f "$default_file" ] || default_file=""

        if [ -n "$max_file" ]; then
            max=$(( $(cat "$max_file" 2>/dev/null) / 1000000 ))
        else
            max=""
        fi

        if [ -n "$min_file" ]; then
            min=$(( $(cat "$min_file" 2>/dev/null) / 1000000 ))
        else
            min=""
        fi

        if [ -n "$default_file" ]; then
            default=$(( $(cat "$default_file" 2>/dev/null) / 1000000 ))
        else
            default=""
        fi

        # Some platforms export 0W as minimum (sentinel/no lower policy bound).
        # Use a practical UI floor in that case.
        if ! is_int "$min" || [ "$min" -le 0 ]; then
            min=15
        fi

        # Prefer default cap as user-facing max when available.
        # This avoids listing boost/firmware headroom values as normal operating targets.
        if is_int "$default" && [ "$default" -ge "$min" ]; then
            max="$default"
        fi

        if set_bounds_if_valid "$min" "$max"; then
            return 0
        fi
    fi

    return 1
}

detect_bounds_from_amdctl() {
    local info min max
    info=$(amdctl info 2>/dev/null || true)
    min=$(echo "$info" | grep -i 'min power limit' | grep -Eo '[0-9]+' | head -n1)
    max=$(echo "$info" | grep -i 'max power limit' | grep -Eo '[0-9]+' | head -n1)
    set_bounds_if_valid "$min" "$max"
}

detect_bounds_from_ryzenadj() {
    local info min max
    info=$(ryzenadj --info 2>/dev/null || true)

    # Prefer explicit min/max TDP hints when exported by the platform.
    min=$(echo "$info" | grep -i 'min tdp' | grep -Eo '[0-9]+' | head -n1)
    max=$(echo "$info" | grep -i 'max tdp' | grep -Eo '[0-9]+' | head -n1)
    if set_bounds_if_valid "$min" "$max"; then
        return 0
    fi

    # Fallback: if only an upper limit is discoverable, keep default minimum.
    max=$(echo "$info" | grep -Ei 'stapm.*limit|slow.*limit|fast.*limit' | grep -Eo '[0-9]+' | sort -nr | head -n1)
    if is_int "$max" && [ "$max" -gt "$MIN_TDP" ]; then
        MAX_TDP="$max"
        return 0
    fi

    return 1
}

# Try to detect TDP bounds from ryzenadj or amdctl
detect_bounds() {
    detect_bounds_from_sysfs && return
    has_amdctl && detect_bounds_from_amdctl && return
    has_ryzenadj && detect_bounds_from_ryzenadj && return

    # If control exists but no explicit bounds are exposed, keep defaults.
    get_backend >/dev/null 2>&1 && return 0

    # No backend means no valid bounds.
    return 1
}

list_tdps() {
    detect_bounds || return 1
    for ((w=$MIN_TDP; w<=$MAX_TDP; w+=$STEP_TDP)); do
        echo "$w"
    done
}

get_tdp() {
    local backend cap_file

    backend=$(get_backend || true)
    case "$backend" in
        ryzenadj)
            ryzenadj --info | grep -E 'TDP|CPU Name'
            ;;
        amdctl)
            amdctl info | grep -i 'power limit\|cpu model'
            ;;
        sysfs)
            cap_file=$(find_sysfs_tdp_file || true)
            if [ -z "$cap_file" ]; then
                echo "TDP control not supported on this system."
                exit 1
            fi
            echo "CPU Name: ${CPU_MODEL}"
            echo "Current TDP: $(( $(cat "$cap_file") / 1000000 ))W"
            echo "Backend: sysfs"
            ;;
        *)
            echo "TDP control not supported on this system."
            exit 1
            ;;
    esac
}

get_tdp_current_watts() {
    local backend cap_file watts

    backend=$(get_backend || true)
    case "$backend" in
        ryzenadj)
            # Prefer STAPM when present, otherwise fall back to any known limit.
            watts=$(ryzenadj --info 2>/dev/null | awk -F': *' '/STAPM LIMIT|STAPM[ _:-]*LIMIT/ {print $2; found=1; exit} END{if (!found) exit 0}' | grep -Eo '[0-9]+' | head -n1 || true)
            if [ -z "$watts" ]; then
                watts=$(ryzenadj --info 2>/dev/null | awk -F': *' '/FAST LIMIT|SLOW LIMIT|PPT LIMIT|FAST[ _:-]*LIMIT|SLOW[ _:-]*LIMIT|PPT[ _:-]*LIMIT/ {print $2; exit}' | grep -Eo '[0-9]+' | head -n1 || true)
            fi
            [ -n "$watts" ] || return 1
            # ryzenadj reports limits in mW.
            echo $((watts / 1000))
            ;;
        amdctl)
            watts=$(amdctl info 2>/dev/null | awk '/power limit/i {for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) {print $i; exit}}')
            [ -n "$watts" ] || return 1
            echo "$watts"
            ;;
        sysfs)
            cap_file=$(find_sysfs_tdp_file || true)
            [ -n "$cap_file" ] || return 1
            echo $(( $(cat "$cap_file") / 1000000 ))
            ;;
        *)
            return 1
            ;;
    esac
}

set_tdp() {
    local tdp_watts="$1"
    detect_bounds

    if ! is_int "$tdp_watts"; then
        echo "Invalid TDP value: '$tdp_watts' (must be a whole number in watts)"
        exit 1
    fi

    if [ "$tdp_watts" -lt "$MIN_TDP" ] || [ "$tdp_watts" -gt "$MAX_TDP" ]; then
        echo "Requested TDP ${tdp_watts}W is outside detected bounds: ${MIN_TDP}-${MAX_TDP}W"
        exit 1
    fi

    local backend cap_file cap_dir
    backend=$(get_backend || true)

    if [ "$backend" = "ryzenadj" ]; then
        sudo ryzenadj --stapm-limit=$((tdp_watts*1000)) --fast-limit=$((tdp_watts*1000)) --slow-limit=$((tdp_watts*1000))
        echo "Set TDP to $tdp_watts W (ryzenadj)"
    elif [ "$backend" = "amdctl" ]; then
        sudo amdctl set power-limit $tdp_watts
        echo "Set TDP to $tdp_watts W (amdctl)"
    elif [ "$backend" = "sysfs" ]; then
        cap_file=$(find_sysfs_tdp_file || true)
        if [ -z "$cap_file" ]; then
            echo "TDP control not supported on this system."
            exit 1
        fi

        echo $((tdp_watts * 1000000)) | sudo tee "$cap_file" >/dev/null

        # Mirror to power2_cap when available on hwmon-based devices.
        cap_dir=$(dirname "$cap_file")
        if [ -f "$cap_dir/power2_cap" ]; then
            echo $((tdp_watts * 1000000)) | sudo tee "$cap_dir/power2_cap" >/dev/null
        fi

        echo "Set TDP to $tdp_watts W (sysfs)"
    else
        echo "TDP control not supported on this system."
        exit 1
    fi
}

set_profile() {
    detect_bounds

    case "$1" in
        eco)
            local eco="$ECO_TDP"
            [ "$eco" -lt "$MIN_TDP" ] && eco="$MIN_TDP"
            [ "$eco" -gt "$MAX_TDP" ] && eco="$MAX_TDP"
            set_tdp "$eco"
            ;;
        balanced)
            local balanced="$BALANCED_TDP"
            [ "$balanced" -lt "$MIN_TDP" ] && balanced="$MIN_TDP"
            [ "$balanced" -gt "$MAX_TDP" ] && balanced="$MAX_TDP"
            set_tdp "$balanced"
            ;;
        performance)
            local perf="$PERFORMANCE_TDP"
            [ "$perf" -lt "$MIN_TDP" ] && perf="$MIN_TDP"
            [ "$perf" -gt "$MAX_TDP" ] && perf="$MAX_TDP"
            set_tdp "$perf"
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
    bounds)
        detect_bounds || {
            echo "N/A"
            exit 1
        }
        echo "${MIN_TDP}-${MAX_TDP}"
        ;;
    current)
        get_tdp_current_watts || {
            echo "N/A"
            exit 1
        }
        ;;
    supports)
        if get_backend >/dev/null 2>&1; then
            echo "yes"
            exit 0
        fi
        echo "no"
        exit 1
        ;;
    *)
        echo "Usage: $0 get | set <watts> | profile <eco|balanced|performance> | list | bounds | current | supports"
        exit 1
        ;;
esac
