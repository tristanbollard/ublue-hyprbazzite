#!/bin/bash

#================================================================================================
#
#          FILE: TritonCtl.sh
#
#         USAGE: ./TritonCtl.sh [subcommand] [args...]
#
#   DESCRIPTION: A centralized control script for Hyprland dotfiles.
#                It compacts various scripts into subcommands and provides a Rofi-based
#                menu for easy, interactive access to all functions and settings.
#
#================================================================================================

# --- Configuration ---
runner="rofi"
SCRIPTS_DIR="$HOME/.config/hypr/scripts"
USER_SCRIPTS_DIR="$HOME/.config/hypr/UserScripts"
ROFI_THEME="$HOME/.config/rofi/config-tritonctl.rasi"


# --- Wallpaper Management ---
# Provides a dedicated menu for managing wallpapers, compatible with swaybg and wallust.
Wallpaper() {
    # Check for dependencies
    if ! command -v jq &>/dev/null || ! command -v bc &>/dev/null;
    then
        notify-send "TritonCtl" "Missing dependency: jq or bc"
        exit 1
    fi

    local wall_dir="$HOME/Pictures/wallpapers"
    local wallust_dir="$HOME/.config/hypr/wallust"
    local wallust_current_wall="$wallust_dir/current_wallpaper.jpg"
    local wallpaper_rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"

    # --- Dynamic Rofi styling from WallpaperSelect.sh ---
    local focused_monitor
    focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    if [[ -z "$focused_monitor" ]]; then
        notify-send "TritonCtl" "Could not detect focused monitor"
        exit 1
    fi
    local scale_factor
    scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
    local monitor_height
    monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')
    local icon_size
    icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
    local adjusted_icon_size
    adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
    # --- End of dynamic styling ---

    handle_selection() {
        local wall_path="$1"
        if [ -z "$wall_path" ]; then return; fi

        # Handle Random selection
        if [ "$wall_path" = "Random" ]; then
            # Find a random wallpaper
            mapfile -d '' wall_files < <(find "$wall_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) -print0)
            if [ ${#wall_files[@]} -eq 0 ]; then
                notify-send -u critical "Error" "No wallpapers found in $wall_dir"
                return
            fi
            wall_path="${wall_files[$((RANDOM % ${#wall_files[@]}))]}"
        fi

        # Ensure the wallust directory exists
        mkdir -p "$wallust_dir"

    # Convert the selected wallpaper to PNG for Hyprlock compatibility
    local wallust_png="$wallust_dir/current_wallpaper.png"
    magick convert "$wall_path" "$wallust_png"
    cp "$wall_path" "$wallust_current_wall"

    # Run wallust to generate new color schemes, skipping tty colors
    wallust run "$wallust_current_wall" -s

    hyprctl reload

    # Set the new wallpaper (still using JPG for swaybg, PNG for Hyprlock)
    swaybg -i "$wallust_current_wall" -m fill &

    notify-send "Wallpaper and Theme Changed" "$(basename "$wall_path")"
    }

    # Find all wallpapers
    mapfile -d '' wall_files < <(find "$wall_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) -print0)
    if [ ${#wall_files[@]} -eq 0 ]; then
        notify-send -u critical "TritonCtl" "No wallpapers found in $wall_dir"
        exit 1
    fi

    local random_wall="${wall_files[$((RANDOM % ${#wall_files[@]}))]}"

    # Generate wallpaper list for Rofi
    generate_list() {
        echo -e "Random\x00icon\x1f$random_wall"
        for wall in "${wall_files[@]}"; do
            local filename
            filename=$(basename "$wall")
            local label
            label="${filename%.*}"
            printf "%s\x00icon\x1f%s\n" "$label" "$wall"
        done | sort
    }

    # Run Rofi
    local choice
    choice=$(generate_list | $runner -dmenu -p "🖼️ Wallpaper" -i -config "$wallpaper_rofi_theme")

    # Handle selection
    if [ -n "$choice" ]; then
        if [ "$choice" = "Random" ]; then
            handle_selection "Random"
        else
            # 'choice' is the label (filename without extension). Find the full path.
            local selected_path
            selected_path=$(find "$wall_dir" -type f -name "$choice.*" -print -quit)
            if [ -n "$selected_path" ]; then
                handle_selection "$selected_path"
            fi
        fi
    fi
}

# --- Script Functions (Subcommands) ---
QuickSettings() {
    local theme="$HOME/.config/rofi/config.rasi"
    local msg='Configuration'
    # Detect current mode using gsettings for GTK
    local gtk_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
    local mode_label=""
    if [[ "$gtk_mode" == "'prefer-dark'" ]]; then
        mode_label="(dark mode)"
    else
        mode_label="(light mode)"
    fi
    local options="Choose Kitty Terminal Theme\nGTK Settings (nwg-look)\nQT Apps Settings (qt6ct)\nQT Apps Settings (qt5ct)\nSwitch Dark-Light Theme $mode_label"
    local choice
    choice=$(echo -e "$options" | rofi -i -dmenu -config "$theme" -mesg "$msg")
    # Remove mode label for matching
    case "${choice%% *}" in
        "Choose Kitty Terminal Theme")
            # List available themes in Kitty's themes directory
            local kitty_theme_dir="$HOME/.config/kitty/themes"
            if [ ! -d "$kitty_theme_dir" ]; then
                notify-send "QuickSettings" "Kitty themes directory not found."
                return
            fi
            local themes=$(ls "$kitty_theme_dir" | grep '\.conf$' | sed 's/\.conf$//')
            local selected_theme=$(echo "$themes" | rofi -dmenu -p "Kitty Theme" -i -config "$theme")
            if [ -n "$selected_theme" ]; then
                # Update Kitty config to use the selected theme
                sed -i "/^include themes\//d" "$HOME/.config/kitty/kitty.conf"
                echo "include themes/$selected_theme.conf" >> "$HOME/.config/kitty/kitty.conf"
                pkill -USR1 kitty
                notify-send "QuickSettings" "Kitty theme set to $selected_theme."
            fi
            ;;
        "GTK Settings (nwg-look)")
            if ! command -v nwg-look &>/dev/null; then
                notify-send "QuickSettings" "Install nwg-look first"
                return
            fi
            nwg-look
            ;;
        "QT Apps Settings (qt6ct)")
            if ! command -v qt6ct &>/dev/null; then
                notify-send "QuickSettings" "Install qt6ct first"
                return
            fi
            qt6ct
            ;;
        "QT Apps Settings (qt5ct)")
            if ! command -v qt5ct &>/dev/null; then
                notify-send "QuickSettings" "Install qt5ct first"
                return
            fi
            qt5ct
            ;;
        "Switch Dark-Light Theme")
            # Toggle between dark and light mode for GTK and QT apps
            local gtk_dark="Adwaita-dark"
            local gtk_light="Adwaita"
            local qt_dark="Adwaita-dark"
            local qt_light="Adwaita"
            local gtk_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
            if [[ "$gtk_mode" == "'prefer-dark'" ]]; then
                gsettings set org.gnome.desktop.interface gtk-theme "$gtk_light"
                gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
                sed -i "s/^theme = .*/theme = $qt_light/" "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null
                sed -i "s/^theme = .*/theme = $qt_light/" "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null
                notify-send "QuickSettings" "Switched to light mode for GTK and QT apps."
            else
                gsettings set org.gnome.desktop.interface gtk-theme "$gtk_dark"
                gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
                sed -i "s/^theme = .*/theme = $qt_dark/" "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null
                sed -i "s/^theme = .*/theme = $qt_dark/" "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null
                notify-send "QuickSettings" "Switched to dark mode for GTK and QT apps."
            fi
            hyprctl reload
            ;;
        *)
            return
            ;;
    esac
}
PowerMenu() {
    local theme="$HOME/.config/rofi/config-powermenu.rasi"
    local options="  Shutdown\n  Reboot\n  Suspend\n⏾  Hybrid Sleep\n  Lock\n  Logout"
    local choice
    choice=$(echo -e "$options" | rofi -dmenu -p "⏻ Power Menu" -i -config "$theme")
    case "$choice" in
        *Shutdown*)
            systemctl poweroff
            ;;
        *Reboot*)
            systemctl reboot
            ;;
        *Suspend*)
            systemctl suspend
            ;;
        *Hybrid\ Sleep*)
            systemctl suspend-then-hibernate
            ;;
        *Lock*)
            hyprlock
            ;;
        *Logout*)
            hyprctl dispatch exit
            ;;
    esac
}
Refresh() {
    # Custom refresh for graphical/session apps from autostart.conf
    apps=(hypridle mako waybar fcitx5 swaybg)
    # Optionally add swayosd-server and walker if enabled
    for app in "${apps[@]}"; do
        pkill "$app"
    done
    # Restart each app under uwsm
    hypridle &
    mako &
    waybar &
    fcitx5 &
    swaybg -i "$HOME/.config/hypr/wallust/current_wallpaper.jpg" -m fill &
    notify-send "TritonCtl" "Session apps refreshed."
}
ChezmoiPullApply() {
    # Pull latest dotfiles and apply them
    if ! command -v chezmoi &>/dev/null; then
        notify-send "Chezmoi" "chezmoi not installed" -u critical
        return 1
    fi

    # Confirm with user
    local choice
    choice=$(echo -e "Yes\nNo" | $runner -dmenu -p "Pull and apply chezmoi changes?" -i -config "$ROFI_THEME")
    if [[ "$choice" != "Yes" ]]; then
        notify-send "Chezmoi" "Pull cancelled"
        return 0
    fi

    notify-send "Chezmoi" "Pulling and applying dotfiles..."
    local logfile="/tmp/chezmoi-pull-$(date +%s).log"

    # Use chezmoi git proxy where possible (pass args through with --)
    if chezmoi git -- pull --rebase --autostash &>>"$logfile"; then
        if chezmoi apply &>>"$logfile"; then
            notify-send "Chezmoi" "Pull and apply succeeded"
            return 0
        else
            notify-send "Chezmoi" "Apply failed — see $logfile" -u critical
            return 2
        fi
    else
        notify-send "Chezmoi" "Git pull failed — see $logfile" -u critical
        return 3
    fi
}

ChezmoiPush() {
    notify-send "Chezmoi" "Preparing push..."
    notify-send "Chezmoi" "Checking for changes..."

    if ! command -v chezmoi &>/dev/null; then
        notify-send "Chezmoi" "chezmoi not installed" -u critical
        return 1
    fi

    # Check for uncommitted changes in chezmoi source (pass args to git with --)
    if chezmoi git -- status --porcelain | grep -q .; then
        local logfile="/tmp/chezmoi-push-$(date +%s).log"
        chezmoi git -- add -A &>>"$logfile"
        chezmoi git -- commit -m "chezmoi: update $(date -u +"%Y-%m-%dT%H:%M:%SZ")" &>>"$logfile" || true
        if chezmoi git -- push &>>"$logfile"; then
            notify-send "Chezmoi" "Changes pushed successfully"
            return 0
        else
            notify-send "Chezmoi" "Push failed — see $logfile" -u critical
            return 2
        fi
    else
        notify-send "Chezmoi" "No local changes to push"
        return 0
    fi
}
Gamemode() {
    notif="$HOME/.config/swaync/images/ja.png"
    SCRIPTSDIR="$HOME/.config/hypr/scripts"

    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 1 ] ; then
        # Disable game mode features using hyprctl statements
        hyprctl keyword animations:enabled 0
        hyprctl keyword decoration:shadow:enabled 0
        hyprctl keyword decoration:blur:enabled 0
        hyprctl keyword general:gaps_in 0
        hyprctl keyword general:gaps_out 0
        hyprctl keyword general:border_size 1
        hyprctl keyword decoration:rounding 0
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
        hyprctl keyword "windowrule opacity 1 override 1 override 1 override, ^(.*)$"
    pkill swaybg
        notify-send -e -u low -i "$notif" " Gamemode:" " enabled"
        exit
    else
        # Re-enable all features
        hyprctl keyword animations:enabled 1
        hyprctl keyword decoration:shadow:enabled 1
        hyprctl keyword decoration:blur:enabled 1
        hyprctl keyword general:gaps_in 5
        hyprctl keyword general:gaps_out 20
        hyprctl keyword general:border_size 3
        hyprctl keyword decoration:rounding 10
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
        hyprctl keyword "windowrule opacity 1 override, ^(.*)$"
        swaybg -i "$HOME/.config/hypr/wallust/current_wallpaper.jpg" -m fill &
        sleep 0.5
        notify-send -e -u normal -i "$notif" " Gamemode:" " disabled"
        hyprctl reload
        exit
    fi
    hyprctl reload
}

# --- Lid Action Subcommand ---
lidact() {
    # Define the internal monitor's properties.
    INTERNAL_MONITOR_NAME="eDP-1"  # The monitor's connector name
    INTERNAL_MONITOR_DESC="desc:Thermotrex Corporation TL134ADXP01-0" # The monitor's description
    INTERNAL_MONITOR_MODE="2560x1600@165"
    INTERNAL_MONITOR_POS="0x0"
    INTERNAL_MONITOR_SCALE="1.6"

    # Function to check if an external monitor is currently connected.
    is_external_monitor_connected() {
        local monitor_count=$(hyprctl monitors | grep -c "Monitor")
        if [[ "$monitor_count" -gt 1 ]]; then
            return 0
        else
            return 1
        fi
    }

    LOCK_FILE="/tmp/lid_action.lock"

    # Check if script is already running
    if [[ -f "$LOCK_FILE" ]]; then
        echo "Script already running, exiting..."
        exit 0
    fi

    # Create lock file
    touch "$LOCK_FILE"
    trap "rm -f $LOCK_FILE" EXIT

    case "$1" in
        "close")
            if is_external_monitor_connected; then
                echo "Lid closed, external monitor connected. Disabling internal monitor: ${INTERNAL_MONITOR_DESC}"
                hyprctl keyword monitor "${INTERNAL_MONITOR_DESC},disable"
            else
                echo "Lid closed, no external monitor connected. Suspending system."
                dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.Suspend boolean:true
            fi
            ;;
        "open")
            echo "Lid opened. Enabling internal monitor: ${INTERNAL_MONITOR_DESC} with mode ${INTERNAL_MONITOR_MODE}."
            until hyprctl monitors | grep -q "${INTERNAL_MONITOR_NAME}"; do
                echo "Waiting for internal monitor to be detected..."
                sleep 0.5
            done
            hyprctl keyword monitor "${INTERNAL_MONITOR_DESC},${INTERNAL_MONITOR_MODE},auto,${INTERNAL_MONITOR_SCALE}"
            ;;
        *)
            echo "Usage: $0 lidact {close|open}"
            exit 1
            ;;
    esac
    exit 0
}
# This section "compacts" all executable scripts from the script directories into callable
# bash functions. This makes them available as subcommands for this script.

# Functions from /etc/hypr/scripts/
#AirplaneMode() { "$SCRIPTS_DIR/AirplaneMode.sh"; }
#Animations() { "$SCRIPTS_DIR/Animations.sh"; }
#Brightness() { "$SCRIPTS_DIR/Brightness.sh" "$@"; }
#BrightnessKbd() { "$SCRIPTS_DIR/BrightnessKbd.sh" "$@"; }
#ChangeBlur() { "$SCRIPTS_DIR/ChangeBlur.sh"; }
#ChangeLayout() { "$SCRIPTS_DIR/ChangeLayout.sh"; }
#ClipManager() { "$SCRIPTS_DIR/ClipManager.sh"; }
#DistroUpdate() { "$SCRIPTS_DIR/Distro_update.sh"; }
#GameMode() { "$SCRIPTS_DIR/GameMode.sh"; }
#Hypridle() { "$SCRIPTS_DIR/Hypridle.sh" "$@"; }
#KeyBinds() { "$SCRIPTS_DIR/KeyBinds.sh"; }
#KeyHints() { "$SCRIPTS_DIR/KeyHints.sh"; }
#KillActiveProcess() { "$SCRIPTS_DIR/KillActiveProcess.sh"; }
#KittyThemes() { "$SCRIPTS_DIR/Kitty_themes.sh"; }
#KoolsDotsUpdate() { "$SCRIPTS_DIR/KooLsDotsUpdate.sh"; }
#KoolQuickSettings() { "$SCRIPTS_DIR/Kool_Quick_Settings.sh"; }
#LockScreen() { "$SCRIPTS_DIR/LockScreen.sh"; }
#MediaCtrl() { "$SCRIPTS_DIR/MediaCtrl.sh" "$@"; }
#MonitorProfiles() { "$SCRIPTS_DIR/MonitorProfiles.sh"; }
#PolkitNixOS() { "$SCRIPTS_DIR/Polkit-NixOS.sh"; }
#Polkit() { "$SCRIPTS_DIR/Polkit.sh"; }
#PortalHyprland() { "$SCRIPTS_DIR/PortalHyprland.sh"; }
#Refresh() { "$SCRIPTS_DIR/Refresh.sh"; }
#RefreshNoWaybar() { "$SCRIPTS_DIR/RefreshNoWaybar.sh"; }
#RofiEmoji() { "$SCRIPTS_DIR/RofiEmoji.sh"; }
#RofiSearch() { "$SCRIPTS_DIR/RofiSearch.sh"; }
#RofiThemeSelectorModified() { "$SCRIPTS_DIR/RofiThemeSelector-modified.sh"; }
#RofiThemeSelector() { "$SCRIPTS_DIR/RofiThemeSelector.sh"; }
# Embedded screenshot function to avoid external dependency on omarchy-cmd-screenshot
ScreenShot() {
    # Usage: ScreenShot [region|window|output]
    [[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
    local mode="${1:-region}"
    local OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
        return 1
    fi

    # Only region capture supported
    if command -v hyprshot &>/dev/null; then
        pkill slurp || true
        hyprshot -m region --raw |
            satty --filename - \
                --output-filename "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png" \
                --early-exit \
                --actions-on-enter save-to-clipboard \
                --save-after-copy \
                --copy-command 'wl-copy'
    elif command -v slurp &>/dev/null && command -v grim &>/dev/null && command -v swappy &>/dev/null; then
        region=$(slurp)
        grim -g "$region" /tmp/screenshot.png && swappy -f /tmp/screenshot.png && mv /tmp/screenshot.png "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
    else
        notify-send "No screenshot tool (hyprshot or slurp/grim/swappy) found!" -u critical -t 3000
        return 1
    fi
}

# Friendly menu wrapper so Rofi shows "Screenshot" and offers Region/Window/Output
Screenshot() {
    # Only act on argument given; no modifier detection
    if [[ $# -gt 0 ]]; then
        ScreenShot "$@"
    else
        ScreenShot region
    fi
}
# LogiBattery: simplified embedded headset battery checker (outputs only an integer percentage)
LogiBattery() {
    local bin="/usr/bin/headsetcontrol"
    # If headsetcontrol is not available, exit non-zero so status modules can hide the item
    if ! command -v "$bin" &>/dev/null; then
        return 1
    fi

    local out
    if ! out=$($bin -b 2>/dev/null); then
        return 1
    fi

    # Normalize output to lowercase for pattern checks
    local low_out
    low_out=$(printf "%s" "$out" | tr '[:upper:]' '[:lower:]')

    # If output indicates headset is not connected / powered off, return -1
    if printf "%s" "$low_out" | grep -E -q "not found|no headset|not connected|disconnected|power: *off|state: *off|status: *off"; then
        printf "%s\n" "-1"
        return 0
    fi

    # Extract the Level field (keep sign if any), examples:
    #   "Level: 85%"
    #   "Level: -24% (some extra)"
    local level_field
    level_field=$(printf "%s" "$out" | awk -F'Level:' '/Level:/ {print $2; exit}' | tr -d ' \t')
    if [ -z "$level_field" ]; then
        return 1
    fi

    # Capture an optional sign and digits from the field
    local pct_signed
    pct_signed=$(printf "%s" "$level_field" | sed -n 's/^\([+-]\?[0-9]\+\).*/\1/p')
    if [ -z "$pct_signed" ]; then
        return 1
    fi

    # If negative, the headset is considered powered off/disconnected -> return -1
    if [[ "$pct_signed" =~ ^- ]]; then
        # Negative level indicates disconnected/powered off — return non-zero so Waybar hides the module
        return 1
    fi

    # Otherwise strip any leading + and print the number
    local pct
    pct=$(printf "%s" "$pct_signed" | sed 's/^+//')
    printf "%s\n" "$pct"
}
#Sounds() { "$SCRIPTS_DIR/Sounds.sh" "$@"; }
#SwitchKeyboardLayout() { "$SCRIPTS_DIR/SwitchKeyboardLayout.sh"; }
#TouchPad() { "$SCRIPTS_DIR/TouchPad.sh"; }
#UptimeNixOS() { "$SCRIPTS_DIR/UptimeNixOS.sh"; }
#Volume() { "$SCRIPTS_DIR/Volume.sh" "$@"; }
#WallustSwww() { "$SCRIPTS_DIR/WallustSwww.sh"; } # Helper script, excluded from menu
#WaybarCava() { "$SCRIPTS_DIR/WaybarCava.sh"; }
#WaybarLayout() { "$SCRIPTS_DIR/WaybarLayout.sh"; }
#WaybarScripts() { "$SCRIPTS_DIR/WaybarScripts.sh" "$@"; }
#WaybarStyles() { "$SCRIPTS_DIR/WaybarStyles.sh"; }
#Wlogout() { "$SCRIPTS_DIR/Wlogout.sh"; }
#LidAction() { "$SCRIPTS_DIR/lid_action.sh" "$@"; }

# Functions from /etc/hypr/UserScripts/
#RainbowBorders() { "$USER_SCRIPTS_DIR/RainbowBorders.sh"; }
#RofiBeats() { "$USER_SCRIPTS_DIR/RofiBeats.sh"; }
#RofiCalc() { "$USER_SCRIPTS_DIR/RofiCalc.sh"; }
#WeatherPy() { "$USER_SCRIPTS_DIR/Weather.py"; }
#WeatherSh() { "$USER_SCRIPTS_DIR/Weather.sh" "$@"; }
#ZshChangeTheme() { "$USER_SCRIPTS_DIR/ZshChangeTheme.sh"; }


# --- Rofi Menu ---
# Generates and displays a Rofi menu with all available functions (subcommands).
show_menu() {
    # Automatically generate a list of options from the functions defined in this script.
    # It excludes internal/helper functions.
    # Show GameMode status in menu
    local gamemode_status=""
    local gamemode_enabled=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$gamemode_enabled" = "0" ]; then
        gamemode_status="Gamemode (enabled)"
    else
        gamemode_status="Gamemode (disabled)"
    fi

    local options=$(declare -F | awk '{print $3}' | grep -v -E 'show_menu|main|show_help|WallustSwww|handle_selection|lidact|ScreenShot|LogiBattery' | sort | sed "s/^Gamemode$/$gamemode_status/")

    local rofi_cmd="$runner -dmenu -p '🔱 TritonCtl' -i"
    if [ -f "$ROFI_THEME" ]; then
        rofi_cmd="$rofi_cmd -config $ROFI_THEME"
    fi
    local choice=$(echo "$options" | $rofi_cmd)

    # Map the status label back to the function name
    if [ "$choice" = "$gamemode_status" ]; then
        choice="Gamemode"
    fi

    if [ -n "$choice" ]; then
        "$choice"
    fi
}

# --- Help Function ---
show_help() {
    echo "Usage: $0 [subcommand] [args...]"
    echo ""
    echo "A centralized control script for Hyprland dotfiles."
    echo "It compacts various scripts into subcommands and provides a Rofi-based"
    echo "menu for easy, interactive access to all functions and settings."
    echo ""
    echo "Subcommands:"
    declare -F | awk '{print $3}' | grep -v -E 'show_menu|main|show_help|WallustSwww|handle_selection|ScreenShot|LogiBattery' | sort | awk '{print "  " $1}'
    echo ""
    echo "Run '$0' without arguments to show the Rofi menu."
    echo "Example: $0 Screenshot region    # take a region screenshot"
}

# Usage: ScreenShot [region|clipboard]
ScreenShot() {
    [[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
    local mode="${1:-region}"
    local OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
        return 1
    fi

    if command -v hyprshot &>/dev/null; then
        pkill slurp || true
        if [[ "$mode" == "clipboard" ]]; then
            hyprshot -m region --raw | wl-copy
            notify-send "Screenshot copied to clipboard"
        elif [[ "$mode" == "region" || -z "$mode" ]]; then
            hyprshot -m region --raw |
                satty --filename - \
                    --output-filename "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png" \
                    --early-exit \
                    --actions-on-enter save-to-clipboard \
                    --save-after-copy \
                    --copy-command 'wl-copy'
        fi
    elif command -v slurp &>/dev/null && command -v grim &>/dev/null && command -v swappy &>/dev/null; then
        region=$(slurp)
        if [[ "$mode" == "clipboard" ]]; then
            grim -g "$region" - | wl-copy
            notify-send "Screenshot copied to clipboard"
        elif [[ "$mode" == "region" || -z "$mode" ]]; then
            grim -g "$region" /tmp/screenshot.png && swappy -f /tmp/screenshot.png && mv /tmp/screenshot.png "$OUTPUT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
        fi
    else
        notify-send "No screenshot tool (hyprshot or slurp/grim/swappy) found!" -u critical -t 3000
        return 1
    fi
}

# --- Main Logic ---
# Determines whether to show the menu or execute a subcommand.
main() {
    if [ -z "$1" ]; then
        show_menu
        exit 0
    fi

    local subcommand="$1"
    shift

    case "$subcommand" in
        help|--help)
            show_help
            ;;
        *)
            if declare -f "$subcommand" > /dev/null; then
                "$subcommand" "$@"
            else
                echo "Error: Subcommand '$subcommand' not found." >&2
                echo "Run '$0 help' for a list of available commands." >&2
                exit 1
            fi
            ;;
    esac
}

# --- Execution ---
main "$@"
