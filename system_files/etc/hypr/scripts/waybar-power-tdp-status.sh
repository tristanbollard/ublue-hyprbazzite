#!/bin/bash

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

backend="unknown"
profile="unknown"

if busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile >/dev/null 2>&1; then
    backend="tuned-ppd"
    profile=$(busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile 2>/dev/null | awk -F'"' '{print $2}')
elif command -v tuned-adm >/dev/null 2>&1; then
    backend="tuned"
    profile=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: *//p')
fi

case "$profile" in
    throughput-performance*|latency-performance*|accelerator-performance*|performance*) icon="" ;;
    balanced*) icon="" ;;
    powersave*|power-saver*) icon="" ;;
    *) icon="" ;;
esac

tdp="unavailable"
tdp_reason=""
tdp_supported=0

if command -v ryzenadj >/dev/null 2>&1; then
    ryzenadj_info=$(ryzenadj --info 2>&1)
    stapm_mw=$(printf '%s\n' "$ryzenadj_info" | awk -F': *' '/STAPM LIMIT/ {print $2; exit}' | grep -Eo '[0-9]+' | head -n1)
    if [ -n "$stapm_mw" ]; then
        tdp="$((stapm_mw / 1000))W"
        tdp_supported=1
    else
        if printf '%s' "$ryzenadj_info" | grep -qi 'unsupported model\|Only Ryzen Mobile Series are supported'; then
            tdp_reason="unsupported on this CPU"
        fi
    fi
elif command -v amdctl >/dev/null 2>&1; then
    amd_tdp=$(amdctl info 2>/dev/null | awk '/power limit/i {for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) {print $i; exit}}')
    if [ -n "$amd_tdp" ]; then
        tdp="${amd_tdp}W"
        tdp_supported=1
    fi
fi

if [ "$tdp" = "unavailable" ] && [ -n "$tdp_reason" ]; then
    tdp="N/A (${tdp_reason})"
fi

if [ "$tdp_supported" -eq 1 ]; then
    printf -v tooltip 'Power profile: %s\nCurrent TDP: %s\nBackend: %s\n\nLeft click: Cycle profile\nRight click: Open TDP selector' "${profile:-unknown}" "$tdp" "$backend"
    text="${tdp} ${icon}"
else
    printf -v tooltip 'Power profile: %s\nBackend: %s\n\nLeft click: Cycle profile' "${profile:-unknown}" "$backend"
    text="${icon}"
fi

printf '{"text":"%s ","tooltip":"%s","class":"%s","alt":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "${profile:-unknown}")" \
    "$(json_escape "${profile:-unknown}")"
