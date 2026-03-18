#!/bin/bash

# --- HIJACKED INSTALLER LOGIC START ---
echo "[HIJACK] Running custom Flatpak installer logic (Injected)..."

echo "[HIJACK] Removing all existing Flatpaks..."
# 1. REMOVE ALL EXISTING APPS (DANGER ZONE)
REMOVE_FLATPAKS=false
while getopts "d" opt; do
    case $opt in
        d)
            REMOVE_FLATPAKS=true
            ;;
    esac
done

echo "[HIJACK] Removing all existing Flatpaks..."
if [ "$REMOVE_FLATPAKS" = true ]; then
    flatpak list --app --columns=application | xargs -r flatpak uninstall --system -y
else
    echo "[HIJACK] Skipping Flatpak removal (use -d to enable)."
fi

# Check for internet connection with retry prompt (GUI)
check_internet() {
    curl -s --head --request GET --connect-timeout 5 https://flathub.org > /dev/null 2>&1
}

while ! check_internet; do
    if command -v zenity >/dev/null 2>&1; then
        if zenity --question --title="No Internet Connection" \
            --text="Internet is required to install your custom Flatpaks.\n\nWithout internet, the installation will be skipped.\n\nYou can run this provisioning later by executing:\n/usr/libexec/bazzite-flatpak-hijack.sh" \
            --ok-label="Retry" \
            --cancel-label="Skip Installation"; then
            echo "[HIJACK] Retrying connection..."
            sleep 2
        else
            echo "[HIJACK] Skipping Flatpak installation."
            exit 0
        fi
    else
        # Fallback to text prompt if zenity fails unexpectedly
        echo "[HIJACK] No internet connection detected."
        echo "1) Retry"
        echo "2) Skip Flatpak installation"
        echo "(To run later: /usr/libexec/bazzite-flatpak-hijack.sh)"
        read -p "Select an option [1/2]: " choice
        case $choice in
            1) echo "[HIJACK] Retrying connection...";;
            2) echo "[HIJACK] Skipping Flatpak installation."; exit 0;;
            *) echo "[HIJACK] Invalid option.";;
        esac
    fi
done

# Function to send notification with progress
send_progress_notification() {
    local summary="$1"
    local percentage="$2"  # 0-100
    local body="$3"
    local urgency="${4:-normal}"
    local replace_id="${5:-0}"

    for user in $(users | tr ' ' '\n' | sort -u); do
        local uid=$(id -u "$user")
        local bus_address="unix:path=/run/user/$uid/bus"

        if [ -e "/run/user/$uid/bus" ]; then
            # Using -p (print id) and -r (replace id) to update the same notification
            # Using -h int:value:$percentage for the progress bar hint
            new_id=$(su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' notify-send -p -r '$replace_id' -u '$urgency' -h int:value:$percentage '$summary' '$body'")
            echo "$new_id"
            return
        fi
    done
    echo "0"
}

echo "[HIJACK] Internet connection established."

# 2. INSTALL CUSTOM APPS
# Add your desired applications to this list
CUSTOM_FLATPAKS=(
   "com.visualstudio.code"
   "com.discordapp.Discord"
   "org.prismlauncher.PrismLauncher"
   "com.bitwarden.desktop"
   "org.openrgb.OpenRGB"
   "com.surfshark.Surfshark"
   "app.zen_browser.zen"
)

NOTIFICATION_ID=0
TOTAL_APPS=${#CUSTOM_FLATPAKS[@]}
CURRENT_APP=0

# Initial notification
NOTIFICATION_ID=$(send_progress_notification "System Provisioning" 0 "Starting Flatpak installation..." "critical" 0)

echo "[HIJACK] Installing custom Flatpaks..."
for app in "${CUSTOM_FLATPAKS[@]}"; do
    let CURRENT_APP=CURRENT_APP+1
    PERCENTAGE=$((CURRENT_APP * 100 / TOTAL_APPS))

    echo "[HIJACK] Installing $app ($CURRENT_APP/$TOTAL_APPS)..."

    # Update notification before starting install
    NOTIFICATION_ID=$(send_progress_notification "System Provisioning" $PERCENTAGE "Installing $app ($CURRENT_APP/$TOTAL_APPS)..." "normal" "$NOTIFICATION_ID")

    flatpak install --system -y flathub "$app" || echo "[HIJACK] Failed to install $app"
done

echo "[HIJACK] Applying VS Code overrides..."
flatpak override --system --filesystem=host --talk-name=org.freedesktop.Flatpak com.visualstudio.code
flatpak override --system --socket=ssh-auth com.visualstudio.code
flatpak override --system --filesystem=home com.visualstudio.code

echo "[HIJACK] Applying Discord Wayland override..."
flatpak override --system --socket=wayland com.discordapp.Discord

echo "[HIJACK] Applying Zen browser download fix..."
# Allow Zen browser to access Downloads and host filesystem for file downloads
flatpak override --system --filesystem=xdg-download --filesystem=host app.zen_browser.zen

echo "[HIJACK] Applying OpenRGB Flatpak device/udev override..."
# Allow OpenRGB Flatpak to access all devices and udev
flatpak override --system --device=all --filesystem=host --filesystem=/run/udev:ro org.openrgb.OpenRGB

echo "[HIJACK] Applying global font and theme overrides for all Flatpaks..."
flatpak override --system --filesystem=xdg-config/fontconfig:ro
flatpak override --system --filesystem=/usr/share/fonts:ro
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro
flatpak override --system --filesystem=xdg-config/kdeglobals:ro
flatpak override --system --filesystem=/usr/share/themes:ro

# Final success notification (closes or updates the progress bar to 100%)
NOTIFICATION_ID=$(send_progress_notification "System Provisioning" 100 "All Flatpaks installed successfully!" "normal" "$NOTIFICATION_ID")

echo "[HIJACK] Applying user-specific font and theme overrides for active users..."
for user in $(users | tr ' ' '\n' | sort -u); do
    uid=$(id -u "$user")
    bus_address="unix:path=/run/user/$uid/bus"
    if [ -e "/run/user/$uid/bus" ]; then
        echo "[HIJACK] Applying user overrides for $user..."
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=xdg-config/fontconfig:ro"
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=/usr/share/fonts:ro"
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=xdg-config/gtk-3.0:ro"
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=xdg-config/gtk-4.0:ro"
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=xdg-config/kdeglobals:ro"
        su - "$user" -c "DBUS_SESSION_BUS_ADDRESS='$bus_address' flatpak override --user --filesystem=/usr/share/themes:ro"
    fi
done
# --- HIJACKED INSTALLER LOGIC END ---
