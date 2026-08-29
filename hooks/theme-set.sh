#!/usr/bin/env bash
# Hook executed on 'omarchy theme set <theme>'
# Synchronizes Wallpaper Engine live wallpaper with the active theme background
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WPE_BIN="$SCRIPT_DIR/scripts/omarchy-wpe"

if [[ ! -x "$WPE_BIN" ]]; then
  WPE_BIN="$HOME/.local/bin/omarchy-wpe"
fi

if [[ -x "$WPE_BIN" ]]; then
  "$WPE_BIN" sync-current >/dev/null 2>&1 || true
fi
