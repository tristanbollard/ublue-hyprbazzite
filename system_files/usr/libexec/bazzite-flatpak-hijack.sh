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

echo "[HIJACK] Internet connection established."

if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "System Provisioning" "Flatpak installation in progress. Please keep internet connected."
fi

# 2. INSTALL CUSTOM APPS
# Add your desired applications to this list
CUSTOM_FLATPAKS=(
   "com.visualstudio.code"
   "com.discordapp.Discord"
   "org.prismlauncher.PrismLauncher"
   "com.bitwarden.desktop"
   "org.openrgb.OpenRGB"
   "com.surfshark.Surfshark"
   "io.github.zen_browser.zen"
)

echo "[HIJACK] Installing custom Flatpaks..."
for app in "${CUSTOM_FLATPAKS[@]}"; do
    echo "[HIJACK] Installing $app..."
    flatpak install --system -y flathub "$app" || echo "[HIJACK] Failed to install $app"
done

if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal "System Provisioning" "Flatpak installation finished successfully."
fi
# --- HIJACKED INSTALLER LOGIC END ---
