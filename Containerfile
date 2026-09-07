# ===========================================================================
# HyprBazzite - Custom bootc image based on Bazzite with Hyprland
# ===========================================================================

# BASE_IMAGE selects which Bazzite variant to build on. CI overrides it per
# build variant (see the matrix in .github/workflows/build.yml):
#   - default -> ghcr.io/ublue-os/bazzite:stable-<fedora>.<date>
#   - nvidia  -> ghcr.io/ublue-os/bazzite-nvidia-open:stable-<fedora>.<date>
# The tag is PINNED (not floating :stable) so Renovate can open PRs bumping the
# date-stamped tag — that's what makes upstream base updates visible/reviewable.
# Declared before the first FROM so it can be referenced in the final FROM.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable-44.20260907

# ---------------------------------------------------------------------------
# Stage 1: Download external assets (fonts, themes)
# ---------------------------------------------------------------------------
# Tiny build-only stage: just needs curl + unzip to fetch fonts/themes, which
# are plain data files COPY'd into the final image (no musl/glibc concern).
# Alpine (~7MB) instead of Fedora (~150MB) makes this stage pull faster.
# Renovate manages this tag (tag-only, no digest pin) — see .github/renovate.json5.
FROM alpine:3.24 AS assets

ARG NERD_FONTS_VERSION=v3.5.1

# Install download utilities
RUN apk add --no-cache curl unzip

RUN curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors -o /tmp/jb-mono.zip \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/JetBrainsMono.zip" && \
    unzip -o /tmp/jb-mono.zip -d /fonts/ && \
    rm -f /tmp/jb-mono.zip

RUN curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors -L \
    https://github.com/dracula/gtk/archive/master.zip -o /tmp/dracula-gtk.zip && \
    unzip -q /tmp/dracula-gtk.zip -d /tmp && \
    mkdir -p /themes/Dracula && mv /tmp/gtk-master/* /themes/Dracula/ && \
    rm -rf /tmp/dracula-gtk.zip /tmp/gtk-master

RUN mkdir -p /qt5ct/colors && \
    curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors -o /qt5ct/colors/Dracula.conf \
    https://raw.githubusercontent.com/dracula/qt5/master/Dracula.conf

# ===========================================================================
# Stage 3: Final Image
# ===========================================================================
# Base is pinned to a date-stamped stable tag (stable-<fedora>.<date>) and bumped
# by Renovate. We pin the TAG, not a digest: a digest pin forces a full ~8GB
# re-pull every build, whereas the date-stamped tag updates cleanly through a
# Renovate PR while staying reproducible for any given commit.
FROM ${BASE_IMAGE}

# Build arguments for versioning
ARG SHA_HEAD_SHORT=unknown
ARG BUILD_STAMP

# ---------------------------------------------------------------------------
# Step 1: Image metadata and build identification
# ---------------------------------------------------------------------------
RUN build_id="${BUILD_STAMP:-stable.$(date -u +%Y%m%d)-${SHA_HEAD_SHORT:-unknown}}" && \
    echo "TBLUE_BUILD_ID=$build_id" >> /usr/lib/os-release && \
    sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"HyprBazzite ($build_id)\"/" /usr/lib/os-release && \
    sed -i 's/^NAME=.*/NAME="HyprBazzite"/' /usr/lib/os-release

# ---------------------------------------------------------------------------
# Step 2: Enable COPR repositories
# ---------------------------------------------------------------------------
RUN --mount=type=cache,dst=/var/cache \
    for repo in lionheartp/Hyprland erikreider/SwayNotificationCenter fed500/wvkbd hhd-dev/hhd atim/starship; do \
      dnf5 -y copr enable "$repo"; \
    done && \
    dnf5 -y clean all

# ---------------------------------------------------------------------------
# Step 3: Remove Plasma desktop packages
# ---------------------------------------------------------------------------
RUN --mount=type=cache,dst=/var/cache \
    dnf5 -y remove --setopt=protected_packages= \
    akonadi-server sddm baloo kate dolphin konsole khelpcenter \
    "plasma-*" "kde*" "gnome-*" "kf5-*" "kf6-*" && \
    dnf5 -y clean all

# ---------------------------------------------------------------------------
# Step 4: Install HyprBazzite packages
# ---------------------------------------------------------------------------
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 -y install --skip-unavailable \
    hyprland hyprland-guiutils hyprlock hypridle hyprpicker hyprpaper uwsm hyprland-uwsm \
    awww waybar SwayNotificationCenter wofi wvkbd \
    xdg-desktop-portal-hyprland lxqt-policykit sddm \
    openrgb openrgb-udev-rules \
    zsh starship lsd git chezmoi kitty tmux fastfetch jq ripgrep \
    hhd adjustor hhd-ui lact \
    rom-properties lutris steam-devices \
    brightnessctl gparted systemd-devel btop \
    nemo nemo-fileroller tumbler gvfs gvfs-mtp gvfs-gphoto2 gvfs-nfs gvfs-fuse gvfs-smb \
    network-manager-applet pavucontrol \
    gnome-keyring seahorse libsecret libsecret-devel gcr gcr-devel \
    blueman breeze-icon-theme qt5ct qt6ct \
    jetbrains-mono jetbrains-mono-fonts \
    wl-clipboard grim slurp playerctl imv swappy mpv cliphist && \
    dnf5 -y autoremove && \
    dnf5 -y clean all

# ---------------------------------------------------------------------------
# Step 5: Copy system files and assets into image
# ---------------------------------------------------------------------------
COPY system_files/usr/ /usr/
COPY --from=assets /fonts /usr/share/fonts/
COPY --from=assets /themes/Dracula /usr/share/themes/Dracula
COPY --from=assets /qt5ct/colors /usr/share/qt5ct/colors

# ---------------------------------------------------------------------------
# Step 6: Import terra-mesa GPG key (instead of disabling gpgcheck)
# ---------------------------------------------------------------------------
RUN if [ -f /etc/yum.repos.d/terra-mesa.repo ]; then \
        rpm --import https://repos.fyralabs.com/terra42/key.asc 2>/dev/null || \
        rpm --import https://repos.fyralabs.com/terra41/key.asc 2>/dev/null || \
        (echo "Warning: Could not import terra GPG key, disabling gpgcheck as fallback" && \
         sed -i 's/^gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo && \
         sed -i 's/^repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/terra-mesa.repo); \
    fi

# ---------------------------------------------------------------------------
# Step 7: Set up user config symlinks (bootc-compliant)
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/share/hyprbazzite/config && \
    cp -af /usr/lib/hyprbazzite/skel/.config/. /usr/share/hyprbazzite/config/ && \
    mkdir -p /etc/skel/.config && \
    for dir in /usr/share/hyprbazzite/config/*/; do \
        dirname=$(basename "$dir"); \
        ln -sf "/usr/share/hyprbazzite/config/$dirname" "/etc/skel/.config/$dirname"; \
    done

# ---------------------------------------------------------------------------
# Step 8: Set permissions on scripts and executables
# ---------------------------------------------------------------------------
RUN chmod +x /usr/bin/wallpaper-cycle /usr/bin/hyprbazzite-session && \
    find /usr/libexec/ -type f -exec chmod +x {} +

# ---------------------------------------------------------------------------
# Step 9: Configure user defaults, environment, and systemd presets
# ---------------------------------------------------------------------------
RUN usermod -s /bin/zsh root && \
    mkdir -p /etc/default && \
    echo 'SHELL=/bin/zsh' >> /etc/default/useradd && \
    # Set Qt platform theme (gtk3 for consistent theme propagation via GTK settings)
    mkdir -p /usr/lib/environment.d/ && \
    echo 'QT_QPA_PLATFORMTHEME=gtk3' >> /usr/lib/environment.d/10-qtct.conf && \
    echo 'QT_STYLE_OVERRIDE=Fusion' >> /usr/lib/environment.d/10-qtct.conf && \
    # Build font cache
    fc-cache -f && \
    # Set session file permissions
    chmod 0644 /usr/share/wayland-sessions/hyprland.desktop && \
    # Set SDDM theme permissions
    chmod -R 0755 /usr/share/sddm/themes && \
    chmod 0644 /usr/share/sddm/themes/hyprlockish/* && \
    # Enable system services via preset
    mkdir -p /usr/lib/systemd/system-preset && \
    echo "enable hhd.service" > /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable sddm.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable tblue-hibernate-setup.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable tblue-disable-nonpower-wakeup.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    echo "enable hyprbazzite-flatpak-overrides.service" >> /usr/lib/systemd/system-preset/50-hyprbazzite.preset && \
    # Enable the per-user first-login service for all users (global user preset
    # + an explicit default.target.wants symlink so it activates without relying
    # on preset timing for freshly-created users)
    mkdir -p /usr/lib/systemd/user-preset && \
    echo "enable hyprbazzite-user-firstboot.service" > /usr/lib/systemd/user-preset/50-hyprbazzite.preset && \
    mkdir -p /usr/lib/systemd/user/default.target.wants && \
    ln -sf ../hyprbazzite-user-firstboot.service \
        /usr/lib/systemd/user/default.target.wants/hyprbazzite-user-firstboot.service && \
    mkdir -p /etc/systemd/user && \
    ln -sf /dev/null /etc/systemd/user/swaync.service && \
    # Copy dconf theme settings
    mkdir -p /etc/dconf/db/distro.d/ && \
    cp /usr/lib/hyprbazzite/dconf/db/distro.d/00-dracula-theme /etc/dconf/db/distro.d/

# ---------------------------------------------------------------------------
# Step 10: Cleanup - remove build artifacts from /var
# ---------------------------------------------------------------------------
RUN rm -rf /var/lib/flatpak/* && \
    rm -rf /var/cache/libdnf5/* && \
    rm -rf /var/lib/dnf && \
    rm -rf /var/log/dnf* && \
    rm -rf /var/log/hawkey.log && \
    find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true && \
    # Validate final image
    bootc container lint
