#!/usr/bin/env bash
# KURENAI installer (launcher tabs + Rofi theme). Copies files into place after a backup. It does NOT edit hyprland.lua and does
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

echo "1/6 Backing up current config..."
bash "$SRC/bin/kurenai-ctl" backup

TS="$(date +%Y%m%d-%H%M%S)"
REPLACED="$STATE/replaced-$TS"

echo "2/6 Installing Hyprland modules (theme, binds, autostart, lock)..."
# kurenai.lua is KURENAI's own; binds/autostart may have been edited by you, so those are
# only created if missing. If yours differs, the new version is saved as <file>.new to merge by hand.
if [ -e "$CFG/hypr/kurenai.lua" ]; then mkdir -p "$REPLACED"; mv "$CFG/hypr/kurenai.lua" "$REPLACED/"; fi
cp "$SRC/hypr/kurenai.lua" "$CFG/hypr/kurenai.lua"
# sha256 of the kurenai-binds.lua the PREVIOUS release shipped. If yours is byte-for-byte that file you never
# edited it, so the new one can replace it (the backup above has your copy). Anything else is kept.
PREV_BINDS_SHA="a6498c7f57a3c3ceab2e83b8c4a3f37caf4dec01a7f7c9c51fe578048ffdbdd8"
for f in kurenai-binds.lua kurenai-autostart.lua kurenai-lock.lua; do
  if [ ! -e "$CFG/hypr/$f" ]; then
    cp "$SRC/hypr/$f" "$CFG/hypr/$f"
  elif ! cmp -s "$SRC/hypr/$f" "$CFG/hypr/$f"; then
    if [ "$f" = "kurenai-binds.lua" ] && [ "$(sha256sum "$CFG/hypr/$f" | cut -d' ' -f1)" = "$PREV_BINDS_SHA" ]; then
      cp "$SRC/hypr/$f" "$CFG/hypr/$f"
      echo "     $f was the unmodified previous version: updated (adds the Run / Prime / Walls keys; your old copy is in the backup)"
    else
      cp "$SRC/hypr/$f" "$CFG/hypr/$f.new"
      echo "     kept your existing $f; new version saved as $f.new (diff $CFG/hypr/$f $CFG/hypr/$f.new)"
    fi
  fi
done

echo "3/6 Installing Quickshell configs (qs -c kurenai, qs -c kurenai-lock)..."
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

echo "4/6 Installing kurenai-ctl and the lock supervisor to $BIN..."
install -m 0755 "$SRC/bin/kurenai-ctl" "$BIN/kurenai-ctl"
install -m 0755 "$SRC/bin/kurenai-lock-supervisor" "$BIN/kurenai-lock-supervisor"
install -m 0755 "$SRC/bin/kurenai-clip" "$BIN/kurenai-clip"          # clipboard-history engine
install -m 0755 "$SRC/bin/kurenai-sysmon" "$BIN/kurenai-sysmon"      # read-only snapshot for the system monitor
mkdir -p "$STATE/clipboard/pins" && chmod 700 "$STATE/clipboard" "$STATE/clipboard/pins"   # pins/history metadata: private
cp "$SRC/hypr/hypridle.kurenai.conf" "$CFG/hypr/hypridle.kurenai.conf"      # a sample only; see: kurenai-ctl lock-hypridle

echo "5/6 Preparing launcher storage and the Rofi theme..."
if [ ! -f "$STATE/launcher.json" ]; then
  printf '{\n  "favorites": [],\n  "recent": [],\n  "primeFavorites": [],\n  "primeRecent": []\n}\n' > "$STATE/launcher.json"
fi
# the Run tab's command history can contain secrets typed into commands: private to you from the start
if [ ! -f "$STATE/runhistory.json" ]; then
  ( umask 077; printf '{\n  "commands": []\n}\n' > "$STATE/runhistory.json" )
fi
chmod 600 "$STATE/runhistory.json" 2>/dev/null || true
# Rofi theme: a file of its own in ~/.config/rofi/themes. Your config.rasi is never touched.
mkdir -p "$CFG/rofi/themes"
if [ -e "$CFG/rofi/themes/kurenai.rasi" ] && ! cmp -s "$SRC/rofi/kurenai.rasi" "$CFG/rofi/themes/kurenai.rasi"; then
  # a file made by `kurenai-ctl theme` (wallpaper colours) is generated, not yours: no backup needed
  if ! grep -q 'WALLPAPER VERSION' "$CFG/rofi/themes/kurenai.rasi"; then
    mkdir -p "$REPLACED"; mv "$CFG/rofi/themes/kurenai.rasi" "$REPLACED/rofi-kurenai.rasi"
  fi
fi
cp "$SRC/rofi/kurenai.rasi" "$CFG/rofi/themes/kurenai.rasi"

echo "6/6 Preparing wallpaper colours (matugen templates; off until you switch it on)..."
# templates: ours, replaced on every install. The palette file always exists (an empty one = built-in colours),
# so the shell and the lock screen have something to watch from the first start.
if [ -d "$STATE/matugen" ]; then mkdir -p "$REPLACED"; mv "$STATE/matugen" "$REPLACED/matugen-templates"; fi
cp -r "$SRC/matugen" "$STATE/matugen"
cp "$SRC/rofi/kurenai.rasi" "$STATE/matugen/kurenai.default.rasi"
[ -f "$STATE/palette.json" ] || printf '{\n  "enabled": false\n}\n' > "$STATE/palette.json"
[ -f "$CFG/hypr/kurenai-colors.lua" ] || cp "$SRC/hypr/kurenai-colors.lua" "$CFG/hypr/kurenai-colors.lua"
# app colours (kitty, gtk, qt, btop, yazi, zathura, nvim, spicetify, firefox): our templates; your attach state and saved settings stay
mkdir -p "$STATE/extras"
for d in "$SRC"/extras/*/; do n="$(basename "$d")"; rm -rf "$STATE/extras/$n"; cp -r "$d" "$STATE/extras/$n"; done
cp "$SRC"/extras/*.awk "$STATE/extras/"
THEME_ON=0; grep -qx 'enabled=1' "$STATE/theme.conf" 2>/dev/null && THEME_ON=1
if [ "$THEME_ON" = 0 ] && grep -q '^extras=.' "$STATE/theme.conf" 2>/dev/null; then
  "$BIN/kurenai-ctl" theme extras apply 2>/dev/null || true
fi
if [ "$THEME_ON" = 1 ]; then
  # the files above were just reset to the defaults; recolour from the current wallpaper again
  # (if this fails the built-in colours stay, nothing breaks)
  { [ -s "$STATE/theme.source" ] && [ -r "$(cat "$STATE/theme.source")" ] && "$BIN/kurenai-ctl" theme-apply --auto "$(cat "$STATE/theme.source")"; } 2>/dev/null \
    || "$BIN/kurenai-ctl" theme-sync --force --auto 2>/dev/null || echo "     (wallpaper colours are on but could not be re-applied now: kurenai-ctl theme sync)"
fi

echo
echo "Installed. Nothing has been activated or started."
echo "  Health check:   $BIN/kurenai-ctl validate"
echo "  Test the shell: $BIN/kurenai-ctl debug   (foreground with live logs; stops any running shell first, Ctrl+C quits)"
echo "  Enable theme:   $BIN/kurenai-ctl enable"
echo "  Clipboard history is recorded LOCALLY once the shell runs (cliphist, in ~/.cache/cliphist) and deleted after 30 days."
echo "  Pause it any time with the switch in the clipboard panel (SUPER+V); 'kurenai-ctl clip-wipe' deletes it all."
echo
echo "  LOCK SCREEN (nothing is locked or started yet). In this order:"
echo "    1. $BIN/kurenai-ctl lock-preview     real password check in a normal window, locks nothing"
echo "    2. $BIN/kurenai-ctl enable-lock      then start it: $BIN/kurenai-ctl lock-start"
echo "    3. open a second terminal on a TTY (Ctrl+Alt+F3) and keep it logged in, THEN: $BIN/kurenai-ctl lock"
echo "    4. $BIN/kurenai-ctl lock-hypridle    for lock on idle / before sleep"
echo
echo "  LAUNCHER TABS (new): Apps | Run | Prime | Walls. Open the launcher, then Tab / Shift+Tab or Ctrl+1..4 switch tabs."
echo "    From a terminal:  qs -c kurenai ipc call launcher openTab run|prime|walls"
echo "    Keys (in kurenai-binds.lua): SUPER+SHIFT+R Run, SUPER+SHIFT+P Prime, SUPER+SHIFT+W Walls"
echo "    Prime needs prime-run (pacman -S nvidia-prime); Walls needs awww (and finds images under ~/Pictures/Wallpapers, subfolders included)."
echo "  ROFI THEME (new): installed to $CFG/rofi/themes/kurenai.rasi. Try:  rofi -show drun -show-icons -theme kurenai"
echo "    Make it Rofi's default:  $BIN/kurenai-ctl rofi-theme   (prints the one line to add; nothing edits your Rofi config)"
echo
echo "  WALLPAPER COLOURS (new, needs matugen: sudo pacman -S matugen): off until you turn it on."
echo "    Quick Settings > Wallpaper colours, or:  $BIN/kurenai-ctl theme on     (then every wallpaper you set recolours the shell)"
echo "    Back to the original colours:  $BIN/kurenai-ctl theme off     Overview: $BIN/kurenai-ctl theme status"
echo
echo "  APP COLOURS (new): kitty, GTK, Qt, btop, yazi, zathura, Neovim, Spicetify can follow the same colours. Nothing is attached yet."
echo "    $BIN/kurenai-ctl theme extras             see what is available;   $BIN/kurenai-ctl theme extra kitty on   attach one"
echo "    Each 'on' prints exactly what it changes in that app's config (after a backup); 'off' undoes it. docs/THEME.md"
echo "  FIREFOX (new, opt-in): $BIN/kurenai-ctl theme extra firefox on     (restart Firefox afterwards; not yet run in Firefox 160, see docs/FIREFOX.md)"
echo
echo "  SHORTCUTS PAGE: works right away from a terminal:  qs -c kurenai ipc call shortcuts toggle"
if ! grep -q 'shortcuts toggle' "$CFG/hypr/kurenai-binds.lua" 2>/dev/null; then
  echo "  For a key, add ONE line to the table in $CFG/hypr/kurenai-binds.lua (after the SUPER + L line):"
  echo '      { "SUPER + SLASH",         QS .. "shortcuts toggle" },'
  echo "  then: hyprctl reload   (the page itself needs no reload: it follows your config files live)"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) echo "  (note: $BIN is not on your PATH; use the full path above)";; esac
[ -n "${REPLACED:-}" ] && [ -d "$REPLACED" ] && echo "  Replaced files were moved to: $REPLACED"
exit 0
