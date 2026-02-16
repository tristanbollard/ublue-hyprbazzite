# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable

# Bazzite-style provisioning (ship defaults in /usr)
COPY system_files /

# Ensure firstboot scripts are executable
RUN chmod +x /etc/firstboot.d/*

# Ensure hijacked script is executable and inject it into manager
RUN chmod +x /usr/libexec/bazzite-flatpak-hijack.sh && \
    chmod +x /usr/libexec/bazzite-flatpak-manager && \
    echo 'source /usr/libexec/bazzite-flatpak-hijack.sh' >> /usr/libexec/bazzite-flatpak-manager


# Fix terra-mesa GPG key issue by disabling GPG check for the repo
RUN sed -i 's/^gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true && \
    sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Organize package installation and system configuration into logical RUN blocks

# Remove GNOME and KDE Desktop Environments
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 remove -y gnome-shell gnome-desktop gnome-session gnome-settings-daemon \
    gnome-shell-extensions gnome-control-center gnome-terminal \
    kde-workspace kde-plasma-desktop kdebase kde-settings \
    plasma-desktop plasma-workspaces sddm \
    plasma-* kde-* kdeconnectd \
    --noautoremove 2>/dev/null || true

# Remove unwanted Bazzite default flatpak apps
RUN flatpak remove -y \
    org.mozilla.firefox \
    org.gnome.* 2>/dev/null || true

# Install Hyprland and dependencies from sdegler COPR
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable sdegler/hyprland && \
    dnf5 install -y \
    hyprland \
    hyprland-guiutils \
    hyprlock \
    hypridle \
    hyprpaper \
    waybar \
    dunst \
    wofi \
    xdg-desktop-portal-hyprland && \
    dnf5 -y copr disable sdegler/hyprland

# Set zsh as default shell
RUN dnf5 install -y zsh && \
    usermod -s /bin/zsh root && \
    mkdir -p /etc/default && \
    echo 'SHELL=/bin/zsh' >> /etc/default/useradd

# Provision oh-my-zsh for new users first
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.oh-my-zsh

# Install optional zsh tools and starship via COPR
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable atim/starship && \
    dnf5 install -y --skip-unavailable \
    starship \
    lsd \
    zsh-autosuggestions \
    zsh-syntax-highlighting || true

# Install and setup SDDM display manager
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y sddm && \
    mkdir -p /usr/share/wayland-sessions && \
    printf '[Desktop Entry]\nName=Hyprland\nExec=start-hyprland -- --config /etc/hypr/hyprland.conf\nType=Application\n' > /usr/share/wayland-sessions/hyprland.desktop && \
    chmod 0644 /usr/share/wayland-sessions/hyprland.desktop && \
    chmod -R 0755 /usr/share/sddm/themes && \
    chmod 0644 /usr/share/sddm/themes/hyprlockish/* && \
    chmod +x /etc/hypr/scripts/power-menu.sh && \
    systemctl enable sddm.service

# Install essential session, keyring, and authentication packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y \
    xdg-desktop-portal-gnome \
    lxqt-policykit \
    systemd-devel \
    gnome-keyring \
    seahorse \
    blueman \
    python3-secretstorage \
    libsecret \
    libsecret-devel \
    gcr \
    gcr-devel \
    qt5ct

# Fonts already included in bazzite base image

# Install development and system utilities
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y \
    tmux \
    git \
    chezmoi \
    kitty \
    nix \
    wl-clipboard \
    grim \
    slurp \
    brightnessctl \
    playerctl \
    imv \
    fastfetch


# Flatpak installation and overrides moved to first boot script.

# Ensure Adwaita GTK and icon themes are present
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y adwaita-gtk2-theme adwaita-qt5 adwaita-qt6 adwaita-icon-theme || true \
    && git clone --depth=1 https://github.com/dracula/gtk.git /usr/share/themes/Dracula \
    && rm -rf /usr/share/themes/Dracula/.git


# Flatpak overrides for VS Code, OpenRGB, and Bitwarden moved to first boot script if needed.

RUN mkdir -p /etc/skel/.config/Code/User && \
    if [ -f /etc/skel/.config/Code/User/settings.json ]; then \
    jq '. + {"terminal.integrated.defaultProfile.linux": "zsh-host", "terminal.integrated.profiles.linux": (.terminal.integrated.profiles.linux // {}) + {"zsh-host": {"path": "flatpak-spawn", "args": ["--host", "env", "TERM=xterm-256color", "zsh", "-i"]}}}' /etc/skel/.config/Code/User/settings.json > /etc/skel/.config/Code/User/settings.json.tmp && \
    mv /etc/skel/.config/Code/User/settings.json.tmp /etc/skel/.config/Code/User/settings.json; \
    else \
    printf '{\n  "terminal.integrated.defaultProfile.linux": "zsh-host",\n  "terminal.integrated.profiles.linux": {\n    "zsh-host": {\n      "path": "flatpak-spawn",\n      "args": ["--host", "env", "TERM=xterm-256color", "zsh", "-i"]\n    }\n  }\n}\n' > /etc/skel/.config/Code/User/settings.json; \
    fi

# Install file manager, thunar, and media support
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y \
    thunar \
    tumbler \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    network-manager-applet \
    pavucontrol

# Compile dconf database for dark mode defaults
RUN dconf update

# Configure bootc filesystem defaults
RUN mkdir -p /usr/lib/bootc && printf '%s\n' \
    '[[customizations.filesystem]]' \
    'mountpoint = "/"' \
    'type = "xfs"' \
    '' \
    '[[customizations.filesystem]]' \
    'mountpoint = "/boot"' \
    'type = "ext4"' > /usr/lib/bootc/bootc.toml

# Cleanup runtime artifacts from /var that shouldn't persist in image
RUN rm -rf /var/cache/* /var/log/* /var/lib/dnf /var/lib/yum /var/opt

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
