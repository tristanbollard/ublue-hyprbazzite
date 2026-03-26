#!/bin/bash
# Install cursor-clip clipboard manager for Hyprland

echo "Installing cursor-clip..."

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: cargo not found. Install rust toolchain first:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

# Clone and build cursor-clip
cd /tmp
git clone https://github.com/Sirulex/cursor-clip.git
cd cursor-clip
cargo build --release

# Install binary
sudo install -Dm755 target/release/cursor-clip /usr/local/bin/cursor-clip

# Create desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/cursor-clip.desktop << 'EOF'
[Desktop Entry]
Name=Cursor Clip
Comment=Clipboard Manager
Exec=cursor-clip --show
Icon=edit-paste
Terminal=false
Type=Application
Categories=Utility;
EOF

echo "✓ cursor-clip installed successfully"
echo ""
echo "Next steps:"
echo "1. Reload Hyprland config: hyprctl reload"
echo "2. Or relaunch Hyprland"
echo "3. Press Super+V to open clipboard history"
