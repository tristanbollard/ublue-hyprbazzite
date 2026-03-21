#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//"/\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

is_valid_mc() {
    local v="$1"
    [[ "$v" =~ ^[0-9]+$ ]] && (( v >= 1000 && v <= 120000 ))
}

score_source() {
    local src_lc="$1"

    if [[ "$src_lc" =~ (tctl|cpu|package|x86_pkg_temp|coretemp|k10temp|zenpower|soc_thermal) ]]; then
        echo 300
        return
    fi
    if [[ "$src_lc" =~ acpitz ]]; then
        echo 180
        return
    fi
    if [[ "$src_lc" =~ (junction|edge|amdgpu|gpu) ]]; then
        echo 120
        return
    fi
    if [[ "$src_lc" =~ (nvme|ssd) ]]; then
        echo 90
        return
    fi

    echo 60
}

best_temp_mc=""
best_source=""
best_score=-1

consider_candidate() {
    local temp_mc="$1"
    local source="$2"

    if ! is_valid_mc "$temp_mc"; then
        return
    fi

    local source_lc score
    source_lc=$(printf '%s' "$source" | tr '[:upper:]' '[:lower:]')
    score=$(score_source "$source_lc")

    if (( score > best_score )); then
        best_score=$score
        best_temp_mc="$temp_mc"
        best_source="$source"
        return
    fi

    if (( score == best_score )) && [[ -n "$best_temp_mc" ]] && (( temp_mc > best_temp_mc )); then
        best_temp_mc="$temp_mc"
        best_source="$source"
    fi
}

for zone in /sys/class/thermal/thermal_zone*; do
    [[ -d "$zone" ]] || continue
    [[ -r "$zone/temp" ]] || continue

    temp_mc=$(cat "$zone/temp" 2>/dev/null || true)
    zone_type=$(cat "$zone/type" 2>/dev/null || echo "unknown")
    consider_candidate "$temp_mc" "thermal:${zone_type}"
done

for hw in /sys/class/hwmon/hwmon*; do
    [[ -d "$hw" ]] || continue
    hw_name=$(cat "$hw/name" 2>/dev/null || echo "unknown")

    for input in "$hw"/temp*_input; do
        [[ -r "$input" ]] || continue
        temp_mc=$(cat "$input" 2>/dev/null || true)
        idx=${input##*/temp}
        idx=${idx%_input}
        label_file="$hw/temp${idx}_label"
        if [[ -r "$label_file" ]]; then
            label=$(cat "$label_file" 2>/dev/null)
        else
            label="temp${idx}"
        fi
        consider_candidate "$temp_mc" "${hw_name}:${label}"
    done
done

if [[ -z "$best_temp_mc" ]]; then
    text="N/A 󰔏"
    printf -v tooltip 'Temperature: unavailable\nNo valid sensors found'
    class="missing"
else
    temp_c=$((best_temp_mc / 1000))
    if (( temp_c >= 85 )); then
        icon="󰸁"
        class="hot"
    elif (( temp_c >= 70 )); then
        icon="󰔄"
        class="warm"
    else
        icon="󰈸"
        class="cool"
    fi

    text="${temp_c}°C ${icon}"
    printf -v tooltip 'Temperature: %s°C\nSensor: %s' "$temp_c" "$best_source"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "$class")"
