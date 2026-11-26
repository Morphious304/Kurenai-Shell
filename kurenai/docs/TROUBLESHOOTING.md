# Troubleshooting

[Back to the README](../README.md)

First, always: `kurenai-ctl validate`. It is read-only and reports versions, services, files, how many shells are running and who
owns the notification service. Logs: `kurenai-ctl logs` (the running shell), `kurenai-ctl debug` (foreground run, `Ctrl+C` quits),
`qs log -c kurenai-lock` (the locker).

## The shell

| Symptom | Cause | Fix |
|---|---|---|
| Two bars, or `Could not register notification server at org.freedesktop.Notifications` | a second shell was started by hand (`qs -c kurenai`) | run ONE shell: `kurenai-ctl start` / `restart` / `stop`. `kurenai-ctl debug` stops the running one first |
| `qs list` shows nothing for KURENAI | without `-c`, `qs list` only looks at the default config | `qs list --all` |
| Nothing appears at all after `kurenai-ctl start` | a QML error | `kurenai-ctl debug` shows it. Send me the first error line |
| `qt.qpa.wayland.textinput ... Trying to disable ... but 0x0 is focused` | a Qt-internal warning when a panel hides (the launcher's search field lives in one) | ignore unless the launcher stops accepting typing |
| Colours or fonts look wrong after editing `Theme.qml` | a typo, or a font name that is not installed | `fc-list \| grep -i NAME`; `kurenai-ctl debug` shows QML errors |
| The lock screen does not match a changed theme | the lock config holds its own copy | `kurenai-ctl lock-sync-theme`, then `kurenai-ctl lock-stop && kurenai-ctl lock-start` |

## Notifications

| Symptom | Fix |
|---|---|
| Popups never appear | `kurenai-ctl notif-status` shows who owns the service. If mako, dunst or swaync is running: `kurenai-ctl notif-takeover`, then `kurenai-ctl start` |
| The old daemon comes back after a reboot | it is still started by your session: comment out its autostart (`notif-status` shows where) |
| You want the old daemon back | `kurenai-ctl notif-restore` |
| Testing | `notify-send 'KURENAI' 'hello'` (package `libnotify`) |

## Keybinds

| Symptom | Fix |
|---|---|
| A KURENAI key does nothing | `kurenai-ctl binds-check`; then open the shortcuts page (`qs -c kurenai ipc call shortcuts toggle`) and search the key |
| `binds-check` reports a chord bound twice | a real clash with one of your own binds: change one of them. The shortcuts page marks these `duplicate` |
| `kurenai-binds.lua.new` exists next to your binds file | a newer shipped file is waiting: `diff ~/.config/hypr/kurenai-binds.lua{,.new}` and merge by hand |
| The launcher key does nothing when the shell is stopped | it should open Rofi instead. Test once with the shell stopped: `qs -c kurenai ipc call launcher toggle; echo $?` (the fallback assumes a non-zero exit) |
| Hyprland reports config errors after `enable` | `hyprctl configerrors`; then `kurenai-ctl disable` (or `disable-binds`) puts it back |

## Panels

| Symptom | Fix |
|---|---|
| Brightness slider and your keys disagree about "50 %" | `Config.brightnessExponent` / `brightnessMin` must equal the `-eN -nM` your brightness keys use (`kurenai-ctl validate` checks this) |
| Brightness OSD never shows | with `udevadm` present it is automatic; otherwise `kurenai-ctl media-binds` prints the one-line change |
| No "Lock" entry in the power menu | start the KURENAI lock (`kurenai-ctl lock-start`) or install a fallback lock tool (see the README), then `kurenai-ctl restart` |
| Volume row dimmed | PipeWire is not reachable from the shell: check `wpctl status` |
| Album art is a placeholder | the player only offers an `https://` image. Art is never downloaded |
| Clipboard panel says it needs setup | `sudo pacman -S cliphist wl-clipboard xdg-utils`, then `kurenai-ctl restart` |
| Shortcuts page is missing rows | `kurenai-ctl shortcuts` lists every file read and each warning with `file:line` |

## Launcher tabs

| Symptom | Fix |
|---|---|
| Prime tab says `prime-run` was not found | `sudo pacman -S nvidia-prime`, then reopen the tab. `kurenai-ctl validate` shows what it found |
| An app started from Prime does not use the NVIDIA GPU | the tab only starts it through `prime-run`; Flatpak apps are sandboxed and may ignore it. Check with `nvidia-smi` |
| Walls tab: "No wallpapers found" | the message names the folder it looked in. Fix `Config.wallpaperDirs`; `kurenai-ctl validate` counts the images |
| Walls tab: "awww is installed but not answering" | start the daemon (`awww-daemon`, normally from your autostart) |
| Wallpaper does not change on Enter | the line under the grid says why. Test by hand: `awww img -t random /path/to/image` |
| Thumbnails blank or slow | blank = not decoded yet (they load 90 ms after a cell stays visible) or an unreadable file. Raise `wallpaperThumbDelay` or lower `wallpaperVisibleRows` for huge folders |
| Rofi theme not used | `kurenai-ctl rofi-theme` shows the file, whether `config.rasi` uses it, and the one line to add |
| A command typed in Run is in the history and should not be | `Ctrl+F` on that row forgets it; `kurenai-ctl reset-launcher` wipes all of it. Start a command with a space to keep it out |

## The lock screen

The short version: if the screen is stuck, press `Ctrl+Alt+F3`, log in, run `kurenai-ctl lock-recover`, switch back with
`Ctrl+Alt+F1` or `F2`, and unlock. The long version, including how to find out which lock path misbehaves, is in
[LOCK-SCREEN.md](LOCK-SCREEN.md).

| Command | Use |
|---|---|
| `kurenai-ctl lock-status` | is the locker running, is the screen locked (also reports a stale state) |
| `kurenai-ctl lock-reset` | you are on your desktop but the locker says "locked": clean restart |
| `kurenai-ctl lock-recover` | from a TTY: restart the locker if the screen is stuck |
| `kurenai-ctl lock-diagnose` | one compact report to send me (no passwords) |
| `kurenai-ctl lock-preview` | the lock screen in a normal window with the real password check; locks nothing |

Last resort, ends your session and loses unsaved work: `pkill -x Hyprland`.

## Still stuck

Send me: the output of `kurenai-ctl validate`, the first error line from `kurenai-ctl debug`, your Hyprland and Quickshell versions,
and what you expected to happen. I can only reason from what you paste; I cannot see your machine.

## Wallpaper colours

| Symptom | Cause and fix |
|---|---|
| No "Wallpaper colours" tiles in Quick Settings | matugen is not on the shell's PATH: `sudo pacman -S matugen`, then `kurenai-ctl restart` |
| Switched on, nothing changes | `kurenai-ctl theme status`; then `kurenai-ctl theme sync` prints the reason (usually awww-daemon not running, or a missing template: re-run `install.sh`) |
| Colours are grey / dull | the wallpaper is low in colour. Try `kurenai-ctl theme type vibrant`, or `theme accent vermilion` |
| Shell ignores the palette | the readability check refused it; `kurenai-ctl logs` shows "fails the contrast check". Try another scheme: `theme type next` |
| Borders did not change | `theme hypr` may be off; Hyprland may not have repainted: `hyprctl reload` |
| Want the original look back | `kurenai-ctl theme off` (or `theme reset`) |

## Firefox
See the table at the end of [FIREFOX.md](FIREFOX.md) (restart Firefox fully first; recolours show only after a restart; a New Tab Override start page needs picking again after a recolour). Firefox 160 ships the new "Nova" interface (`browser.nova.enabled`); the theme targets its element names, so an older Firefox may look different.

## App colours

| Symptom | Cause and fix |
|---|---|
| `theme extra X on` says the app is not installed | it only attaches apps it finds; install it, then run it again |
| Nothing changed in kitty | `kurenai-ctl theme extras` shows if it is attached; try `kill -USR1 $(pgrep -x kitty)` or open a new window. Make sure no later line in `kitty.conf` after the KURENAI block sets colours |
| GTK apps look unchanged | restart the app. Libadwaita apps use `gtk-4.0/gtk.css`; GTK3 apps need the `adw-gtk3-dark` theme (`gsettings get org.gnome.desktop.interface gtk-theme`). Flatpak apps need the override in docs/THEME.md |
| Qt apps unchanged | `echo $QT_QPA_PLATFORMTHEME` inside a freshly started app's terminal must print `qt6ct` (log out and in once after attaching); the qt6ct style must not be Kvantum |
| btop colours did not change | `color_theme = "kurenai"` must be in `~/.config/btop/btop.conf`; run `pkill -USR2 -x btop` |
| yazi shows an error after attaching | run `kurenai-ctl theme extra yazi off` and send me the message |
| "app colours not updated (the previous colours stay)" | the wallpaper's colours failed the terminal readability check; try `theme type vibrant` or `theme accent vermilion` |
| Get back to my own look | `kurenai-ctl theme extra NAME off` (or `theme extras reset`); copies of your original files are in `~/.local/share/kurenai/extras/backup/` |
