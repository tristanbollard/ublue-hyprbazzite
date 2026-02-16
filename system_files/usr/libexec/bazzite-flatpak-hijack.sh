#!/bin/bash

# --- HIJACKED INSTALLER LOGIC START ---
echo "[HIJACK] Running custom Flatpak installer logic (Injected)..."

# 1. REMOVE ALL EXISTING APPS (DANGER ZONE)
echo "[HIJACK] Removing all existing Flatpaks..."
# Uncomment to enable wiping
# flatpak list --app --columns=application | xargs -r flatpak uninstall --system -y

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
# --- HIJACKED INSTALLER LOGIC END ---
