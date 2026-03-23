# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable
ARG SHA_HEAD_SHORT=unknown
ARG BUILD_STAMP


# Bazzite-style provisioning (ship defaults in /usr)
COPY system_files /
COPY secure-boot-keys/secureboot.crt /usr/share/tblue-secureboot/secureboot.pem

# Compile and install the SELinux policy module for hibernation
RUN checkmodule -M -m -o /tmp/tblue_hibernate.mod /usr/share/selinux/packages/tblue_hibernate.te && \
    semodule_package -o /usr/share/selinux/packages/tblue_hibernate.pp -m /tmp/tblue_hibernate.mod && \
    semodule -i /usr/share/selinux/packages/tblue_hibernate.pp

# Rebuild the initramfs for the installed kernel(s) with the resume module
RUN KVER=$(ls /lib/modules | head -n 1) && \
    dracut --force --add "resume" /lib/modules/$KVER/initramfs.img $KVER

RUN build_commit="${SHA_HEAD_SHORT:-unknown}" && \
    build_stamp="${BUILD_STAMP:-$(date -u +%d%m%y)}" && \
    build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    build_id="${build_commit}-${build_stamp}" && \
    mkdir -p /usr/share/tblue && \
    printf 'TBLUE_GIT_COMMIT=%s\nTBLUE_BUILD_DATE=%s\nTBLUE_BUILD_ID=%s\n' "$build_commit" "$build_date" "$build_id" > /usr/share/tblue/build-info && \
    grep -q '^TBLUE_GIT_COMMIT=' /usr/lib/os-release || echo "TBLUE_GIT_COMMIT=$build_commit" >> /usr/lib/os-release && \
    grep -q '^TBLUE_BUILD_DATE=' /usr/lib/os-release || echo "TBLUE_BUILD_DATE=$build_date" >> /usr/lib/os-release && \
    grep -q '^TBLUE_BUILD_ID=' /usr/lib/os-release || echo "TBLUE_BUILD_ID=$build_id" >> /usr/lib/os-release && \
    sed -i "s/^PRETTY_NAME=\"\(.*\)\"$/PRETTY_NAME=\"\1 (${build_id})\"/" /usr/lib/os-release

RUN mkdir -p /usr/share/ublue-os && \
    curl -fsSL -o /usr/share/ublue-os/sb_pubkey.der https://github.com/ublue-os/akmods/raw/main/certs/public_key.der && \
    chmod 0644 /usr/share/ublue-os/sb_pubkey.der

RUN openssl x509 -in /usr/share/tblue-secureboot/secureboot.pem -outform DER -out /usr/share/tblue-secureboot/secureboot.der && \
    chmod 0644 /usr/share/tblue-secureboot/secureboot.pem /usr/share/tblue-secureboot/secureboot.der && \
    chmod 0755 /usr/libexec/tblue-secureboot-firstboot /usr/libexec/tblue-hibernate-setup /usr/libexec/tblue-sync-desktop-config /usr/libexec/tblue-hhd-enable-user && \
    systemctl enable tblue-secureboot-firstboot.service tblue-hibernate-setup.service tblue-sync-desktop-config.service tblue-hhd-enable-user.service


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
# Manage Flatpaks
# Manage Flatpaks (Move custom install to first-boot service due to build-time sandbox limitations)
# Manage Flatpaks
# Manage Flatpaks (Runtime Hijack Method)
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
    flatpak uninstall -y org.mozilla.firefox org.gnome.* 2>/dev/null || true && \
    chmod +x /usr/libexec/bazzite-flatpak-hijack.sh && \
    chmod +x /usr/libexec/bazzite-flatpak-manager && \
    chmod +x /usr/bin/wallpaper-cycle && \
    echo 'source /usr/libexec/bazzite-flatpak-hijack.sh' >> /usr/libexec/bazzite-flatpak-manager

# Install Hyprland and dependencies from sdegler COPR
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable sdegler/hyprland && \
    dnf5 -y copr enable erikreider/SwayNotificationCenter && \
    dnf5 -y copr enable fed500/wvkbd && \
    dnf5 -y copr enable hhd-dev/hhd && \
    dnf5 install -y \
    hyprland \
    hyprland-guiutils \
    hyprlock \
    hypridle \
    hyprpaper \
    steam-devices \
    uwsm \
    hyprland-uwsm \
    swww \
    waybar \
    SwayNotificationCenter \
    wofi \
    wvkbd \
    hhd \
    adjustor \
    hhd-ui \
    xdg-desktop-portal-hyprland

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
    lsd || true

# Install and setup SDDM display manager
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 install -y sddm && \
    mkdir -p /usr/share/wayland-sessions && \
    printf '[Desktop Entry]\nName=Hyprland\nComment=Hyprland (direct)\nExec=start-hyprland -- --config /etc/hypr/hyprland.conf\nType=Application\nDesktopNames=Hyprland\n' > /usr/share/wayland-sessions/hyprland.desktop && \
    printf '[Desktop Entry]\nName=Hyprland (UWSM)\nComment=Hyprland managed by Universal Wayland Session Manager\nExec=uwsm start -- start-hyprland -- --config /etc/hypr/hyprland.conf\nType=Application\nDesktopNames=Hyprland\n' > /usr/share/wayland-sessions/hyprland-uwsm.desktop && \
    chmod 0644 /usr/share/wayland-sessions/hyprland.desktop && \
    chmod 0644 /usr/share/wayland-sessions/hyprland-uwsm.desktop && \
    chmod -R 0755 /usr/share/sddm/themes && \
    chmod 0644 /usr/share/sddm/themes/hyprlockish/* && \
    chmod +x /etc/hypr/scripts/*.sh && \
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
    breeze-icon-theme \
    python3-secretstorage \
    libsecret \
    libsecret-devel \
    gcr \
    gcr-devel \
    qt5ct

# Install Dracula GTK and Qt themes
RUN mkdir -p /usr/share/themes/Dracula && \
    curl -L https://github.com/dracula/gtk/archive/master.zip -o /tmp/dracula-gtk.zip && \
    unzip /tmp/dracula-gtk.zip -d /tmp && \
    mv /tmp/gtk-master/* /usr/share/themes/Dracula/ && \
    rm -rf /tmp/dracula-gtk.zip /tmp/gtk-master && \
    mkdir -p /usr/share/qt5ct/colors && \
    curl -L https://raw.githubusercontent.com/dracula/qt5/master/Dracula.conf -o /usr/share/qt5ct/colors/Dracula.conf && \
    mkdir -p /usr/share/backgrounds/gif_wallpapers

# Set global environment variables for Qt theming
RUN echo 'QT_QPA_PLATFORMTHEME=qt5ct' >> /etc/environment

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
    jetbrains-mono-fonts \
    slurp \
    brightnessctl \
    playerctl \
    imv \
    fastfetch \
    jq \
    ripgrep \
    swappy \
    mpv \
    btop \
    cliphist \
    network-manager-applet

# Install Nerd Fonts for icons
RUN curl -L -o /tmp/jb-mono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip && \
    unzip -o /tmp/jb-mono.zip -d /usr/share/fonts/ && \
    rm /tmp/jb-mono.zip && \
    fc-cache -fv


# Flatpak overrides for VS Code, OpenRGB, and Bitwarden moved to first boot script if needed.

RUN mkdir -p /etc/skel/.var/app/com.visualstudio.code/config/Code/User && \
    if [ -f /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json ]; then \
    jq '. + {"terminal.integrated.defaultProfile.linux": "zsh-host", "terminal.integrated.profiles.linux": (.terminal.integrated.profiles.linux // {}) + {"zsh-host": {"path": "flatpak-spawn", "args": ["--host", "env", "TERM=xterm-256color", "zsh", "-i"]}}}' /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json > /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json.tmp && \
    mv /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json.tmp /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json; \
    else \
    printf '{\n  "terminal.integrated.defaultProfile.linux": "zsh-host",\n  "terminal.integrated.profiles.linux": {\n    "zsh-host": {\n      "path": "flatpak-spawn",\n      "args": ["--host", "env", "TERM=xterm-256color", "zsh", "-i"]\n    }\n  }\n}\n' > /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json; \
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
