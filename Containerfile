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
    dnf5 -y remove akonadi-server sddm baloo kate dolphin konsole khelpcenter "plasma-*" "kde*" "gnome-*" "kf5-*" "kf6-*" && \
    dnf5 -y install --skip-unavailable \
    hyprland hyprland-guiutils hyprlock hypridle hyprpaper uwsm hyprland-uwsm \
    swww waybar SwayNotificationCenter wofi wvkbd hhd adjustor hhd-ui lact \
    zsh starship lsd sddm git chezmoi kitty nix tmux fastfetch jq ripgrep \
    thunar tumbler gvfs gvfs-mtp gvfs-gphoto2 network-manager-applet pavucontrol \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gnome lxqt-policykit \
    gnome-keyring seahorse blueman breeze-icon-theme checkpolicy policycoreutils \
    libsecret libsecret-devel gcr gcr-devel qt5ct rom-properties lutris jetbrains-mono \
    wl-clipboard grim slurp brightnessctl playerctl imv swappy systemd-devel steam-devices mpv btop cliphist && \
    dnf5 -y autoremove && \
    dnf5 -y clean all

# 3. Copy Files into image
COPY system_files/usr/ /usr/

# Fix terra-mesa GPG key issue by disabling GPG check for the repo
RUN sed -i 's/^gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true && \
    sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo 2>/dev/null || true


# 4. Handle the "Skel"
RUN cp -af /usr/lib/hyprbazzite/etc/skel/. /etc/skel/

# 5. Manage Flatpaks (Including adding Hijack)
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && \
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

RUN echo 'QT_QPA_PLATFORMTHEME=qt5ct' >> /etc/environment

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
    chmod +x /usr/lib/hyprbazzite/etc/hypr/scripts/*.sh && \

RUN mkdir -p /etc/skel/.var/app/com.visualstudio.code/config/Code/User && \
    if [ -f /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json ]; then \
        jq '. + {"terminal.integrated.defaultProfile.linux": "zsh-host", "terminal.integrated.profiles.linux": (.terminal.integrated.profiles.linux // {}) + {"zsh-host": {"path": "flatpak-spawn", "args": ["--host", "env", "TERM=xterm-256color", "zsh", "-i"]}}}' \
        /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json > /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json.tmp && \
        mv /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json.tmp /etc/skel/.var/app/com.visualstudio.code/config/Code/User/settings.json; \
    fi

# 5. Permissions and Service Enablement
RUN chmod +x /usr/bin/wallpaper-cycle && \
    find /usr/libexec/ -type f -exec chmod +x {} + && \
    # Updated path to match the new Golden Source location
    find /usr/lib/tblue/etc/hypr/scripts/ -type f -exec chmod +x {} + && \
    systemctl enable hhd.service sddm.service \
                   tblue-hibernate-setup.service \
                   tblue-sync-desktop-config.service

RUN dconf update

# 7. Final Cleanup for Linter
RUN rm -rf /var/lib/dnf /var/log/dnf* /var/log/hawkey.log /var/lib/blueman && \
    find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    bootc container lint
