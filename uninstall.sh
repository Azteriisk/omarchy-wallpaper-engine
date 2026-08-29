#!/usr/bin/env bash
# Uninstaller script for Omarchy Wallpaper Engine plugin
# Author: Azteriisk
set -e

PLUGIN_ID="azterisk.wallpaper-engine"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
HOOK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d/wpe-theme-sync.sh"
BIN_LINK="${XDG_BIN_HOME:-$HOME/.local/bin}/omarchy-wpe"

echo "==> Uninstalling Omarchy Wallpaper Engine plugin ($PLUGIN_ID)..."

# Stop any running Wallpaper Engine instances
if [ -x "$TARGET_DIR/scripts/omarchy-wpe" ]; then
  "$TARGET_DIR/scripts/omarchy-wpe" stop >/dev/null 2>&1 || true
fi
pkill -x linux-wallpaperengine 2>/dev/null || true

# Disable plugin via omarchy CLI
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
fi

# Remove theme hook
if [ -f "$HOOK_FILE" ] || [ -L "$HOOK_FILE" ]; then
  rm -f "$HOOK_FILE"
fi

# Remove CLI binary symlink
if [ -L "$BIN_LINK" ] || [ -f "$BIN_LINK" ]; then
  rm -f "$BIN_LINK"
fi

# Clean bar layout in shell.json if present
if [ -f "$SHELL_CONFIG" ] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '.bar.layout.right |= map(select(.id != "azterisk.wallpaper-engine"))' "$SHELL_CONFIG" > "$tmp" && mv "$tmp" "$SHELL_CONFIG"
fi

# Remove plugin directory if requested or run from outside
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SCRIPT_DIR" != "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
  rm -rf "$TARGET_DIR"
fi

# Restart shell
if command -v omarchy >/dev/null 2>&1; then
  omarchy restart shell 2>/dev/null || true
fi

echo "==> Omarchy Wallpaper Engine plugin uninstalled successfully."
