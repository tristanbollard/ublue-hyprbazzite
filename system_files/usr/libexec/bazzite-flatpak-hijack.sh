#!/bin/bash

# --- HIJACKED INSTALLER LOGIC START ---
echo "[HIJACK] Running custom Flatpak installer logic (Injected)..."

# 1. REMOVE ALL EXISTING APPS (DANGER ZONE)
echo "[HIJACK] Removing all existing Flatpaks..."
# Uncomment to enable wiping
# flatpak list --app --columns=application | xargs -r flatpak uninstall --system -y

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
# Ensure the SSH agent socket directory exists for Flatpak VS Code
if [ -n "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR/keyring"
fi
flatpak override --system --env=SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/keyring/ssh com.visualstudio.code
flatpak override --system --filesystem=home com.visualstudio.code

echo "[HIJACK] Applying Discord Wayland override..."
flatpak override --system --socket=wayland com.discordapp.Discord

# Final success notification (closes or updates the progress bar to 100%)
NOTIFICATION_ID=$(send_progress_notification "System Provisioning" 100 "All Flatpaks installed successfully!" "normal" "$NOTIFICATION_ID")
# --- HIJACKED INSTALLER LOGIC END ---
