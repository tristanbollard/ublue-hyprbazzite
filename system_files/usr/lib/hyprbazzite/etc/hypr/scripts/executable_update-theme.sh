#!/bin/bash
# Wallust Color Generator Script
# Generates color schemes for waybar, wofi, dunst, mako, gtk, and other applets
# from the current wallpaper

WALLPAPER="${1:-$HOME/.config/hypr/wallust/current_wallpaper.jpg}"
WALLUST_CONFIG="$HOME/.config/wallust/wallust.toml"
ROFI_COLORS="$HOME/.config/rofi/wallust/colors-rofi.rasi"
WOFI_COLORS="$HOME/.config/wofi/colors.css"
DUNST_COLORS="$HOME/.config/dunst/colors"
MAKO_COLORS="$HOME/.config/mako/colors"
GTK_COLORS="$HOME/.config/gtk-3.0/colors.css"

# Check if wallust is installed
if ! command -v wallust &> /dev/null; then
    echo "Error: wallust is not installed"
    echo "Install with: sudo rpm-ostree install wallust"
    exit 1
fi

# Check if wallpaper exists
if [ ! -f "$WALLPAPER" ]; then
    echo "Error: Wallpaper not found: $WALLPAPER"
    exit 1
fi

# Generate colors from wallpaper
echo "Generating colors from: $WALLPAPER"
wallust run "$WALLPAPER"

# Extract colors for additional applets
if [ -f "$ROFI_COLORS" ]; then
    # Parse rofi colors for use in other configs
    BG=$(grep "background-color:" "$ROFI_COLORS" | head -1 | awk '{print $2}' | tr -d ';')
    FG=$(grep "foreground:" "$ROFI_COLORS" | head -1 | awk '{print $2}' | tr -d ';')
    BORDER=$(grep "border-color:" "$ROFI_COLORS" | head -1 | awk '{print $2}' | tr -d ';')
    ACCENT=$(grep "color13:" "$ROFI_COLORS" | head -1 | awk '{print $2}' | tr -d ';')
    
    # Generate GTK colors
    mkdir -p "$(dirname "$GTK_COLORS")"
    cat > "$GTK_COLORS" << EOF
/* Auto-generated from wallust */
@define-color theme_bg_color $BG;
@define-color theme_fg_color $FG;
@define-color theme_selected_bg_color $ACCENT;
@define-color theme_selected_fg_color $FG;
@define-color borders $BORDER;
EOF

    # Generate Wofi colors
    mkdir -p "$(dirname "$WOFI_COLORS")"
    cat > "$WOFI_COLORS" << EOF
/* Auto-generated from wallust */
@define-color bg $BG;
@define-color fg $FG;
@define-color border $BORDER;
@define-color accent $ACCENT;
EOF
    
    echo "✓ Generated color schemes"
    echo "  - Rofi (palette source): $ROFI_COLORS"
    echo "  - Wofi: $WOFI_COLORS"
    echo "  - GTK:  $GTK_COLORS"
fi

# Reload waybar
if pgrep -x waybar > /dev/null; then
    killall -SIGUSR2 waybar
    echo "✓ Reloaded waybar"
fi

# Reload dunst
if pgrep -x dunst > /dev/null; then
    killall -SIGUSR1 dunst
    echo "✓ Reloaded dunst"
fi

# Reload mako
if pgrep -x mako > /dev/null; then
    makoctl reload
    echo "✓ Reloaded mako"
fi

echo "✓ Theme updated successfully"
