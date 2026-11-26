#!/usr/bin/env bash
# KURENAI installer. Copies files into place after a backup. It does NOT edit hyprland.lua;
# that is a separate, explicit step:  kurenai-ctl enable
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/kurenai"

[ -d "$CFG/hypr" ] || { echo "No $CFG/hypr found; is Hyprland configured for this user?" >&2; exit 1; }

mkdir -p "$BIN" "$CFG/quickshell" "$STATE"

echo "1/4 Backing up current config..."
bash "$SRC/bin/kurenai-ctl" backup

TS="$(date +%Y%m%d-%H%M%S)"
REPLACED="$STATE/replaced-$TS"

echo "2/4 Installing Hyprland theme module..."
if [ -e "$CFG/hypr/kurenai.lua" ]; then
  mkdir -p "$REPLACED"; mv "$CFG/hypr/kurenai.lua" "$REPLACED/"
fi
cp "$SRC/hypr/kurenai.lua" "$CFG/hypr/kurenai.lua"

echo "3/4 Installing Quickshell config (qs -c kurenai)..."
if [ -d "$CFG/quickshell/kurenai" ]; then
  mkdir -p "$REPLACED"; mv "$CFG/quickshell/kurenai" "$REPLACED/quickshell-kurenai"
fi
cp -r "$SRC/quickshell/kurenai" "$CFG/quickshell/kurenai"

echo "4/4 Installing kurenai-ctl to $BIN..."
install -m 0755 "$SRC/bin/kurenai-ctl" "$BIN/kurenai-ctl"

echo
echo "Installed. Nothing has been activated yet."
echo "  Test the bar:   qs -c kurenai"
echo "  Health check:   $BIN/kurenai-ctl validate"
echo "  Enable theme:   $BIN/kurenai-ctl enable"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "  (note: $BIN is not on your PATH; use the full path above)";; esac
