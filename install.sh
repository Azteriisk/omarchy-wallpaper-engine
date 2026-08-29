#!/usr/bin/env bash
# Installer script for Omarchy Wallpaper Engine plugin
# Author: Azteriisk
set -e

PLUGIN_ID="azterisk.wallpaper-engine"
PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
TARGET_DIR="$PLUGINS_DIR/$PLUGIN_ID"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
HOOKS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

echo "==> Installing Omarchy Wallpaper Engine Plugin ($PLUGIN_ID)..."

# Ensure target directories exist
mkdir -p "$PLUGINS_DIR" "$HOOKS_DIR" "$BIN_DIR"

# If script is run from a cloned folder outside plugins dir, copy files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SCRIPT_DIR" != "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
  cp -a "$SCRIPT_DIR/manifest.json" \
        "$SCRIPT_DIR/Panel.qml" \
        "$SCRIPT_DIR/Service.qml" \
        "$SCRIPT_DIR/WpeSlider.qml" \
        "$SCRIPT_DIR/scripts" \
        "$SCRIPT_DIR/hooks" \
        "$SCRIPT_DIR/install.sh" \
        "$SCRIPT_DIR/uninstall.sh" \
        "$SCRIPT_DIR/README.md" "$TARGET_DIR/"
fi

# Ensure scripts are executable
chmod +x "$TARGET_DIR/scripts/omarchy-wpe"
chmod +x "$TARGET_DIR/scripts/wpe-layer-web.py"
chmod +x "$TARGET_DIR/scripts/omarchy-toggle-webkit-crash-alerts"
chmod +x "$TARGET_DIR/hooks/theme-set.sh"
chmod +x "$TARGET_DIR/install.sh"
chmod +x "$TARGET_DIR/uninstall.sh"

# Install CLI binary symlinks
ln -nsf "$TARGET_DIR/scripts/omarchy-wpe" "$BIN_DIR/omarchy-wpe"
ln -nsf "$TARGET_DIR/scripts/omarchy-toggle-webkit-crash-alerts" "$BIN_DIR/omarchy-toggle-webkit-crash-alerts"

# Install theme change hook
ln -nsf "$TARGET_DIR/hooks/theme-set.sh" "$HOOKS_DIR/wpe-theme-sync.sh"

# Check for linux-wallpaperengine dependency
if ! command -v linux-wallpaperengine >/dev/null 2>&1; then
  echo "==> Note: 'linux-wallpaperengine' was not found on your system."
  if command -v yay >/dev/null 2>&1; then
    echo "    To install it, run: yay -S linux-wallpaperengine-git"
  elif command -v paru >/dev/null 2>&1; then
    echo "    To install it, run: paru -S linux-wallpaperengine-git"
  fi
fi

# Check for gtk-layer-shell (for Web/HTML5 wallpapers)
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0'); gi.require_version('GtkLayerShell', '0.1')" >/dev/null 2>&1; then
  echo "==> Optional: For HTML5/Web wallpapers, install gtk-layer-shell:"
  echo "    yay -S gtk-layer-shell"
fi

# Enable plugin via omarchy CLI if available
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable "$PLUGIN_ID" 2>/dev/null || true
fi

# Ensure widget is added to bar.layout.right
if [ -f "$SHELL_CONFIG" ] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq 'if (.bar.layout.right | map(.id == "azterisk.wallpaper-engine") | any) then . else .bar.layout.right += [{"id":"azterisk.wallpaper-engine"}] end' "$SHELL_CONFIG" > "$tmp" && mv "$tmp" "$SHELL_CONFIG"
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy restart shell 2>/dev/null || true
fi

echo ""
echo "================================================================="
echo "  Omarchy Wallpaper Engine Plugin installed successfully!"
echo "================================================================="
echo "  CLI Command: omarchy-wpe"
echo "  - List wallpapers:         omarchy-wpe list"
echo "  - Assign to theme:         omarchy-wpe assign \"Matte Black\" <workshop-id>"
echo "  - Background Switcher:     Wallpapers appear with [WPE] in Super+Ctrl+Space"
echo "  - Top Bar Widget:          Click the wallpaper icon in the navbar"
echo "================================================================="
