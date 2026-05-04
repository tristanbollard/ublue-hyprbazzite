# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite:stable
ARG SHA_HEAD_SHORT=unknown
ARG BUILD_STAMP

# 1. Metadata setup
RUN build_commit="${SHA_HEAD_SHORT:-unknown}" && \
    build_id="${build_commit}-${BUILD_STAMP:-$(date -u +%d%m%y)}" && \
    echo "TBLUE_BUILD_ID=$build_id" >> /usr/lib/os-release && \
    sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"HyprBazzite ($build_id)\"/" /usr/lib/os-release && \
    sed -i 's/^NAME=.*/NAME="HyprBazzite"/' /usr/lib/os-release

# 2. Remove and Install my packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y copr enable sdegler/hyprland && \
    dnf5 -y copr enable erikreider/SwayNotificationCenter && \
    dnf5 -y copr enable fed500/wvkbd && \
    dnf5 -y copr enable hhd-dev/hhd && \
    dnf5 -y copr enable atim/starship && \
    dnf5 -y remove --setopt=protected_packages= akonadi-server sddm baloo kate dolphin konsole khelpcenter "plasma-*" "kde*" "gnome-*" "kf5-*" "kf6-*" && \
    dnf5 -y install --skip-unavailable \
    hyprland hyprland-guiutils hyprlock hypridle hyprpaper uwsm hyprland-uwsm \
    swww waybar SwayNotificationCenter wofi wvkbd hhd adjustor hhd-ui lact \
    zsh starship lsd sddm git chezmoi kitty nix tmux fastfetch jq ripgrep \
    thunar tumbler gvfs gvfs-mtp gvfs-gphoto2 network-manager-applet pavucontrol \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gnome lxqt-policykit \
    gnome-keyring seahorse blueman breeze-icon-theme checkpolicy policycoreutils \
    libsecret libsecret-devel gcr gcr-devel qt5ct rom-properties lutris jetbrains-mono jetbrains-mono-fonts \
    wl-clipboard grim slurp brightnessctl playerctl imv swappy gparted systemd-devel steam-devices mpv btop cliphist && \
    dnf5 -y autoremove && \
    dnf5 -y clean all

# 3. Copy Files into image
COPY system_files/usr/ /usr/

# Fix terra-mesa GPG key issue
RUN sed -i 's/^gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true && \
    sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true

# 4. IMPLEMENTING LIVE SYMLINKS (Back to /etc for bootc compliance)
RUN mkdir -p /usr/share/hyprbazzite/config && \
    cp -af /usr/lib/hyprbazzite/etc/skel/.config/. /usr/share/hyprbazzite/config/

# bootc wants us to use /etc/skel, not /usr/etc/skel
RUN mkdir -p /etc/skel/.config && \
    for dir in $(ls /usr/share/hyprbazzite/config/); do \
        ln -s /usr/share/hyprbazzite/config/$dir /etc/skel/.config/$dir; \
    done

# 5. Manage Flatpaks (Modified to avoid polluting /var)
# We place the remote file in /etc instead of running 'flatpak remote-add'
RUN mkdir -p /etc/flatpak/remotes.d && \
    curl -L https://flathub.org/repo/flathub.flatpakrepo -o /etc/flatpak/remotes.d/flathub.flatpakrepo && \
    flatpak uninstall -y org.mozilla.firefox org.gnome.* 2>/dev/null || true && \
    chmod +x /usr/libexec/bazzite-flatpak-hijack.sh && \
    chmod +x /usr/libexec/bazzite-flatpak-manager && \
    chmod +x /usr/bin/wallpaper-cycle && \
    echo 'source /usr/libexec/bazzite-flatpak-hijack.sh' >> /usr/libexec/bazzite-flatpak-manager

# 6. Setup user defaults and customization
RUN dnf5 install -y zsh && \
    usermod -s /bin/zsh root && \
    mkdir -p /etc/default && \
    echo 'SHELL=/bin/zsh' >> /etc/default/useradd

RUN mkdir -p /usr/lib/environment.d/ && \
    echo 'QT_QPA_PLATFORMTHEME=qt5ct' >> /usr/lib/environment.d/10-qtct.conf

RUN curl -L -o /tmp/jb-mono.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip && \
    unzip -o /tmp/jb-mono.zip -d /usr/share/fonts/ && \
    rm /tmp/jb-mono.zip && \
    fc-cache -fv

RUN mkdir -p /usr/share/themes/Dracula && \
    curl -L https://github.com/dracula/gtk/archive/master.zip -o /tmp/dracula-gtk.zip && \
    unzip /tmp/dracula-gtk.zip -d /tmp && \
    mv /tmp/gtk-master/* /usr/share/themes/Dracula/ && \
    rm -rf /tmp/dracula-gtk.zip /tmp/gtk-master && \
    mkdir -p /usr/share/qt5ct/colors && \
    curl -L https://raw.githubusercontent.com/dracula/qt5/master/Dracula.conf -o /usr/share/qt5ct/colors/Dracula.conf && \
    mkdir -p /usr/share/backgrounds/gif_wallpapers

RUN chmod 0644 /usr/share/wayland-sessions/hyprland.desktop && \
    chmod 0644 /usr/share/wayland-sessions/hyprland-uwsm.desktop && \
    chmod -R 0755 /usr/share/sddm/themes && \
    chmod 0644 /usr/share/sddm/themes/hyprlockish/* && \
    chmod +x /usr/lib/hyprbazzite/etc/hypr/scripts/*.sh

# VS Code Live Sync (Pointed to /etc/skel)
RUN mkdir -p /usr/share/hyprbazzite/vscode && \
    echo '{"terminal.integrated.defaultProfile.linux": "zsh-host"}' > /usr/share/hyprbazzite/vscode/settings.json && \
    mkdir -p /etc/skel/.var/app/com.visualstudio.code/config/Code/User && \
    ln -s /usr/share/hyprbazzite/vscode/settings.json /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json

# 7. Permissions and Service Enablement
RUN chmod +x /usr/bin/wallpaper-cycle && \
    find /usr/libexec/ -type f -exec chmod +x {} + && \
    find /usr/lib/hyprbazzite/etc/hypr/scripts/ -type f -exec chmod +x {} + && \
    mkdir -p /usr/lib/systemd/system-preset && \
    echo "enable hhd.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable sddm.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable tblue-hibernate-setup.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable tblue-sync-desktop-config.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset

# Dconf Source
RUN mkdir -p /etc/dconf/db/distro.d/ && \
    cp /usr/lib/hyprbazzite/etc/dconf/db/distro.d/00-dracula-theme /etc/dconf/db/distro.d/

# 8. Scorched Earth Cleanup for /var (The Linter's main enemy)
RUN rm -rf /var/lib/flatpak/* && \
    rm -rf /var/cache/libdnf5/* && \
    rm -rf /var/lib/dnf && \
    rm -rf /var/log/dnf* && \
    rm -rf /var/log/hawkey.log && \
    find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    bootc container lint