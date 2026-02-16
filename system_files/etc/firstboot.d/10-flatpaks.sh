#!/bin/bash
# Install desired Flatpaks on first boot

FLATPAKS=(
  com.visualstudio.code
  com.discordapp.Discord
  org.prismlauncher.PrismLauncher
  com.bitwarden.desktop
  org.openrgb.OpenRGB
  com.surfshark.Surfshark
  io.github.zen_browser.zen
  org.gtk.Gtk3theme.Dracula
)

# Wait for internet connection to ensure Flathub is reachable
echo "Waiting for internet connection..."
until curl -s --head --request GET --connect-timeout 5 https://flathub.org > /dev/null 2>&1; do
  echo "Waiting for flathub.org..."
  sleep 5
done
echo "Internet connection established."

# Ensure flathub is added
echo "Adding flathub remote..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || echo "Error adding remote, continuing..."

echo "Starting flatpak installations..."
for pkg in "${FLATPAKS[@]}"; do
  echo "Installing $pkg..."
  flatpak install -y flathub "$pkg" || echo "Failed to install $pkg, skipping..."
done
echo "Flatpak installations finished."

# Provision qt5ct for existing users (ensures theme works immediately)
echo "Provisioning qt5ct for existing users..."
for user_dir in /home/*; do
  if [ -d "$user_dir" ] && [ "$(basename "$user_dir")" != "lost+found" ]; then
    user_name=$(basename "$user_dir")
    target_dir="$user_dir/.config/qt5ct"
    
    # Skip if not a real user directory (basic check)
    id -u "$user_name" >/dev/null 2>&1 || continue

    echo "Configuring qt5ct for user: $user_name"
    mkdir -p "$target_dir"
    cp -f /etc/skel/.config/qt5ct/qt5ct.conf "$target_dir/qt5ct.conf"
    
    # Fix permissions
    chown -R "$user_name:$user_name" "$target_dir"
  fi
done

# Flatpak overrides for zen-browser

# Set Dracula theme for zen-browser Flatpak
flatpak override --system --env=GTK_THEME=Dracula io.github.zen_browser.zen


exit 0
