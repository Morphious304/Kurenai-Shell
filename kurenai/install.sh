#!/usr/bin/env bash
# KURENAI installer. Copies files into place after a backup. It does NOT edit hyprland.lua and does
# NOT start anything; those are separate, explicit steps (see README / kurenai-ctl).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/kurenai"

[ -d "$CFG/hypr" ] || { echo "No $CFG/hypr found; is Hyprland configured for this user?" >&2; exit 1; }

mkdir -p "$BIN" "$CFG/quickshell" "$STATE"

echo "1/5 Backing up current config..."
bash "$SRC/bin/kurenai-ctl" backup

TS="$(date +%Y%m%d-%H%M%S)"
REPLACED="$STATE/replaced-$TS"

echo "2/5 Installing Hyprland modules (theme, binds, autostart)..."
for f in kurenai.lua kurenai-binds.lua kurenai-autostart.lua; do
  if [ -e "$CFG/hypr/$f" ]; then mkdir -p "$REPLACED"; mv "$CFG/hypr/$f" "$REPLACED/"; fi
  cp "$SRC/hypr/$f" "$CFG/hypr/$f"
done

echo "3/5 Installing Quickshell config (qs -c kurenai)..."
if [ -d "$CFG/quickshell/kurenai" ]; then
  mkdir -p "$REPLACED"; mv "$CFG/quickshell/kurenai" "$REPLACED/quickshell-kurenai"
fi
cp -r "$SRC/quickshell/kurenai" "$CFG/quickshell/kurenai"

echo "4/5 Installing kurenai-ctl to $BIN..."
install -m 0755 "$SRC/bin/kurenai-ctl" "$BIN/kurenai-ctl"

echo "5/5 Preparing launcher storage..."
if [ ! -f "$STATE/launcher.json" ]; then
  printf '{\n  "favorites": [],\n  "recent": []\n}\n' > "$STATE/launcher.json"
fi

echo
echo "Installed. Nothing has been activated or started."
echo "  Health check:   $BIN/kurenai-ctl validate"
echo "  Test the shell: qs -c kurenai        (in a terminal, so you can see errors; Ctrl+C stops it)"
echo "  Enable theme:   $BIN/kurenai-ctl enable"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "  (note: $BIN is not on your PATH; use the full path above)";; esac
[ -n "${REPLACED:-}" ] && [ -d "$REPLACED" ] && echo "  Replaced files were moved to: $REPLACED"
exit 0
