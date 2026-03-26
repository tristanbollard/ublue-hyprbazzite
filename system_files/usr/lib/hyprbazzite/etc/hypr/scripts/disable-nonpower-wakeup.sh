#!/usr/bin/env bash
# Disable all wakeup sources except the power button
# Run as root at boot (e.g., via systemd service)

set -euo pipefail

log() { echo "[wakeup-filter] $*" >&2; }

# Find all wakeup devices
echo "Wakeup devices before filtering:" >&2
cat /proc/acpi/wakeup >&2

# Get the power button device (usually PBTN or PWRB)
power_btns=$(awk '/PBTN|PWRB/ {print $1}' /proc/acpi/wakeup)

# Disable all other wakeup devices
grep enabled /proc/acpi/wakeup | awk '{print $1}' | while read dev; do
    if ! echo "$power_btns" | grep -q "$dev"; then
        echo "$dev" > /proc/acpi/wakeup
        log "Disabled wakeup for $dev"
    fi
done

echo "Wakeup devices after filtering:" >&2
cat /proc/acpi/wakeup >&2
