#!/usr/bin/env bash
# KURENAI installer. Copies files into place after a backup. It does NOT edit hyprland.lua and does
# NOT start anything; those are separate, explicit steps (see README / kurenai-ctl).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/kurenai"

[ -d "$CFG/hypr" ] || { echo "No $CFG/hypr found; is Hyprland configured for this user?" >&2; exit 1; }

# Never replace the lock screen's files while the screen is locked.
if [ "${KURENAI_FORCE:-0}" != "1" ] && command -v qs >/dev/null 2>&1 && [ "$(qs -c kurenai-lock ipc call lock status 2>/dev/null || true)" = "locked" ]; then
  echo "The locker says the screen is locked, so I refuse to change the lock screen's files." >&2
  echo "If you are reading this in your normal desktop, that state is stale (an older bug). Then either run" >&2
  echo "   kurenai-ctl lock-reset      and re-run this installer, or just" >&2
  echo "   KURENAI_FORCE=1 bash install.sh" >&2
  exit 1
fi

mkdir -p "$BIN" "$CFG/quickshell" "$STATE"

echo "1/5 Backing up current config..."
bash "$SRC/bin/kurenai-ctl" backup

TS="$(date +%Y%m%d-%H%M%S)"
REPLACED="$STATE/replaced-$TS"

echo "2/5 Installing Hyprland modules (theme, binds, autostart, lock)..."
# kurenai.lua is KURENAI's own; binds/autostart may have been edited by you, so those are
# only created if missing. If yours differs, the new version is saved as <file>.new to merge by hand.
if [ -e "$CFG/hypr/kurenai.lua" ]; then mkdir -p "$REPLACED"; mv "$CFG/hypr/kurenai.lua" "$REPLACED/"; fi
cp "$SRC/hypr/kurenai.lua" "$CFG/hypr/kurenai.lua"
for f in kurenai-binds.lua kurenai-autostart.lua kurenai-lock.lua; do
  if [ ! -e "$CFG/hypr/$f" ]; then
    cp "$SRC/hypr/$f" "$CFG/hypr/$f"
  elif ! cmp -s "$SRC/hypr/$f" "$CFG/hypr/$f"; then
    cp "$SRC/hypr/$f" "$CFG/hypr/$f.new"
    echo "     kept your existing $f; new version saved as $f.new (diff $CFG/hypr/$f $CFG/hypr/$f.new)"
  fi
done

echo "3/5 Installing Quickshell configs (qs -c kurenai, qs -c kurenai-lock)..."
if [ -d "$CFG/quickshell/kurenai" ]; then
  mkdir -p "$REPLACED"; mv "$CFG/quickshell/kurenai" "$REPLACED/quickshell-kurenai"
fi
cp -r "$SRC/quickshell/kurenai" "$CFG/quickshell/kurenai"

# the lock screen is its own config, so a mistake in one can never break the other
if [ -d "$CFG/quickshell/kurenai-lock" ]; then
  mkdir -p "$REPLACED"; mv "$CFG/quickshell/kurenai-lock" "$REPLACED/quickshell-kurenai-lock"
fi
cp -r "$SRC/quickshell/kurenai-lock" "$CFG/quickshell/kurenai-lock"
# (self-contained on purpose: a copy of the theme, not a link that could break)
cp "$CFG/quickshell/kurenai/Theme.qml" "$CFG/quickshell/kurenai-lock/Theme.qml"
# if you had customised Config.qml of the lock before, it is in $REPLACED: re-apply your edits there

echo "4/5 Installing kurenai-ctl and the lock supervisor to $BIN..."
install -m 0755 "$SRC/bin/kurenai-ctl" "$BIN/kurenai-ctl"
install -m 0755 "$SRC/bin/kurenai-lock-supervisor" "$BIN/kurenai-lock-supervisor"
cp "$SRC/hypr/hypridle.kurenai.conf" "$CFG/hypr/hypridle.kurenai.conf"      # a sample only; see: kurenai-ctl lock-hypridle

echo "5/5 Preparing launcher storage..."
if [ ! -f "$STATE/launcher.json" ]; then
  printf '{\n  "favorites": [],\n  "recent": []\n}\n' > "$STATE/launcher.json"
fi

echo
echo "Installed. Nothing has been activated or started."
echo "  Health check:   $BIN/kurenai-ctl validate"
echo "  Test the shell: $BIN/kurenai-ctl debug   (foreground with live logs; stops any running shell first, Ctrl+C quits)"
echo "  Enable theme:   $BIN/kurenai-ctl enable"
echo
echo "  LOCK SCREEN (nothing is locked or started yet). In this order:"
echo "    1. $BIN/kurenai-ctl lock-preview     real password check in a normal window, locks nothing"
echo "    2. $BIN/kurenai-ctl enable-lock      then start it: $BIN/kurenai-ctl lock-start"
echo "    3. open a second terminal on a TTY (Ctrl+Alt+F3) and keep it logged in, THEN: $BIN/kurenai-ctl lock"
echo "    4. $BIN/kurenai-ctl lock-hypridle    for lock on idle / before sleep"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "  (note: $BIN is not on your PATH; use the full path above)";; esac
[ -n "${REPLACED:-}" ] && [ -d "$REPLACED" ] && echo "  Replaced files were moved to: $REPLACED"
exit 0
