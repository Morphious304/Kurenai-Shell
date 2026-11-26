# KURENAI, phase 4a.5 (lock screen: unlock-state fix)

Hyprland (Lua config, 0.55+) theme + Quickshell shell: top bar, notification popups and centre,
docked application launcher, quick settings, media panel, calendar, on-screen display, power menu, IPC.
Phase 4b (next): clipboard history, optional system monitor.

```
install.sh                       copies files into place after a backup; starts nothing, edits nothing
bin/kurenai-ctl                  see `kurenai-ctl` for the full command list
hypr/kurenai.lua                 appearance only (borders, gaps, rounding, shadow, motion)
hypr/kurenai-binds.lua           opt-in keybinds (launcher, notifications, DND, Rofi fallback)
hypr/kurenai-autostart.lua       opt-in session autostart
quickshell/kurenai/              managed start: kurenai-ctl start   (foreground logs: kurenai-ctl debug)
  Theme.qml Config.qml           design tokens / behaviour settings
  UiState.qml Compositor.qml     overlay open-flags / Hyprland dispatch + focused screen
  NotificationStore.qml          the one notification state (server, history, popups, DND)
  NotificationCard/Popups/Center.qml
  Apps.qml Launcher.qml          desktop-entry index, search, favourites, recents / the launcher UI
  DockShape.qml PanelFrame.qml   panel hanging from the bar (concave fillets) / floating-or-docked panel body
  Audio.qml                      the one audio state (bar + panel): volume, mute, default sink/source, device lists
  System.qml                     brightness (brightnessctl), night light (hyprsunset), keep-awake flag, tool detection
  Media.qml MediaPanel.qml       the one MPRIS state / the media popover (bar item opens it)
  CalendarPanel.qml              month calendar, opened by clicking the clock (offline)
  Power.qml PowerMenu.qml        lock / suspend / log out / reboot / shut down, confirmation for the destructive ones
  OsdState.qml OsdWindow.qml     what the on-screen display shows / the single click-through pill
  QuickSettings.qml              the panel: battery + power profile, sound, brightness, Wi-Fi, Bluetooth, toggles, shortcuts
  Btn.qml KToggle.qml KSlider.qml QsSection.qml ListBox.qml LevelRow.qml   shared, keyboard-accessible controls
  Surface.qml PanelOverlay.qml   shared panel look / shared popover window (focus, click-outside, Esc)
  Ipc.qml                        qs ipc targets used by the keybinds
  Bar.qml Workspaces.qml WindowTitle.qml SysStatus.qml Tray.qml Clock.qml BarItem.qml Divider.qml Emblem.qml
```

## IPC (verify with `qs -c kurenai ipc show`)
```
qs -c kurenai ipc call launcher toggle|open|close
qs -c kurenai ipc call notifications toggle|open|close|dnd|clear
qs -c kurenai ipc call quicksettings toggle|open|close
qs -c kurenai ipc call media toggle|playpause|next|previous
qs -c kurenai ipc call calendar toggle|close
qs -c kurenai ipc call powermenu toggle|close
qs -c kurenai ipc call osd brightness
qs -c kurenai ipc call shell closeAll
```

## Customise
- Colours, sizes, fonts, timings: `Theme.qml`. Terminal for Terminal=true apps, popup limits/timeouts, launcher size: `Config.qml`.
- Hyprland: top of `hypr/kurenai.lua` (`ENABLE_BLUR`, `FLOAT_ACCENT`). Keybinds: `hypr/kurenai-binds.lua`.
- Quickshell live-reloads QML on save.

## Local data
`~/.local/share/kurenai/launcher.json` holds favourite/recent desktop-entry ids only. Reset: `kurenai-ctl reset-launcher`.
Notification history lives in memory only (it is cleared when Quickshell stops).

## Quick settings: what it needs
| Control | Uses | If missing |
|---|---|---|
| Volume, mic, device pickers | PipeWire (native) | row dims, says why |
| Brightness | `brightnessctl` | row shows an install hint |
| Wi-Fi on/off, saved networks | NetworkManager (native) | "No Wi-Fi adapter" |
| New Wi-Fi networks | `nm-connection-editor` (opened, never handled in the shell) | row disabled, says to use nmtui/nmcli |
| Bluetooth on/off, connect/disconnect paired devices | BlueZ (native) | "No adapter" |
| Power profiles | `power-profiles-daemon` | section hidden |
| Night light | `hyprsunset` | tile hidden |
| Keep awake | Wayland idle-inhibit (compositor) | n/a |
| Sound / Network / Bluetooth shortcuts | pwvucontrol or pavucontrol / nm-connection-editor / blueman-manager or overskride | shortcut hidden |

Passwords are never typed into, stored by, or passed through the shell.
Keyboard: Tab moves between controls (teal ring), Space/Enter activates, Left/Right moves sliders, Esc closes.

## Troubleshooting
- **Run ONE shell.** Start it with `kurenai-ctl start` (or the autostart hook). To see logs use `kurenai-ctl logs` for the running
  shell, or `kurenai-ctl debug` for a foreground run (it stops the running one first). A plain second `qs -c kurenai` starts a
  second shell: stacked bars, and `Could not register notification server at org.freedesktop.Notifications`.
- **`kurenai-ctl validate`** reports how many shells are running and who owns the notification service.
- **`qs list` shows nothing for KURENAI?** Without `-c`, `qs list` only looks at the *default* Quickshell config. Use `qs list --all`.
- **`binds-check` after `enable-binds`:** KURENAI's own binds are in `hyprctl binds` by then; each chord should be bound exactly once.
  Anything bound twice is a real clash. A `kurenai-binds.lua.new` next to your binds file means a newer shipped file is waiting:
  `diff ~/.config/hypr/kurenai-binds.lua{,.new}`.
- **`qt.qpa.wayland.textinput ... Trying to disable ... but 0x0 is focused`** is a Qt-internal warning that shows up when a panel
  hides (the launcher's search field lives in one). It is noise unless the launcher stops accepting typing.

## Phase 4a: media, calendar, OSD, power menu
| Feature | How it works | Needs | If missing |
|---|---|---|---|
| Media panel + bar item | Quickshell MPRIS: any player (Spotify, mpv-mpris, VLC, browsers) | a running MPRIS player | bar item hidden; panel says nothing is playing |
| Album art | local `file://` art only. **Never downloaded** | player offering a local file | fallback tile (Spotify/web players usually only give https art) |
| Calendar | plain date maths, no network. Click the clock, or `SUPER+C` | nothing | n/a |
| Volume / mic / media OSD | watches PipeWire and MPRIS, so your `wpctl`/`playerctl` keys work unchanged | nothing | n/a |
| Brightness slider + OSD | live: `udevadm monitor` reports every backlight change (Fn keys, `brightnessctl`, auto-dim) | `udevadm` (part of systemd) | slider refreshes twice a second while the panel is open; OSD needs `kurenai-ctl media-binds` |
| Power menu | `systemctl suspend/reboot/poweroff`, Hyprland exit (or `hyprshutdown`), your lock tool | a lock tool for the Lock entry | no Lock entry, never assumed |

- **Confirmation:** Log out / Reboot / Shut down need a second click (cancels itself after 10 s). Nothing is pre-focused, so opening the
  menu or pressing Enter on it never runs anything. Nothing runs through `sudo`.
- **OSD:** one pill, bottom-centre, click-through. A new event replaces the old one. It stays quiet for the first 2.5 s after the shell starts,
  while any panel is open (the panel already shows the value) and right after you switch the default audio device.
  Turn parts off in `Config.qml` (`osdVolume`, `osdMic`, `osdBrightness`, `osdMediaPlayPause`, `osdMediaTrack`).
- **Brightness curve:** `Config.brightnessExponent`/`brightnessMin` must equal the `-eN -nM` your brightness keys use (yours: 4 and 2), otherwise the
  slider/OSD and the keys disagree about "50%". `kurenai-ctl validate` checks this.
- **Keybinds (opt-in, in `kurenai-binds.lua`):** `SUPER+C` calendar, `SUPER+SHIFT+M` media, `SUPER+ESCAPE` power menu.

## Phase 4a.1 changes
- **Fixed: labels missing on centred buttons** (power-profile Saver/Balanced/Performance, Sound/Network/Bluetooth shortcuts, calendar Today,
  power-menu Cancel, media Player n/m). A sizing loop made the label zero-width. `Btn.qml` now sizes centred labels from the text itself.
- **Toggle tiles** (Do not disturb / Keep awake / Night light) are stacked (icon above label) so their names are no longer cut off.
- **Live brightness:** the slider and the brightness OSD follow Fn keys and any other brightness change immediately, no bind edits needed.
- `kurenai-ctl validate`: lock-screen hint says what to install; direct `poweroff`/`reboot` keybinds are a note, not a warning (your choice);
  checks `udevadm` and warns if more than one backlight device exists (the shell and your keys must use the same one).
- To get the **Lock** entry: install a lock screen (`sudo pacman -S hyprlock`) and run `kurenai-ctl restart`.

## The lock screen (`qs -c kurenai-lock`)

A **separate** Quickshell config and process from the main shell, on purpose: a mistake in the bar can never stop you
from locking, and the lock is always running so locking is instant (an IPC call, no start-up delay).

```
quickshell/kurenai-lock/
  shell.qml  LockController.qml   the only file that touches the compositor's session lock
  LockState.qml                   all state + authentication (PAM password, PAM fingerprint, awww wallpaper)
  LockView.qml                    the screen: clock, 紅 seal, petals, input, vertical 余波 strip
  Wallpaper/Pattern/BlurFx.qml    background (awww image, blurred) or a generated pattern
  Config.qml  Theme.qml           settings / a COPY of the main theme (kurenai-ctl lock-sync-theme refreshes it)
  pam/password.conf  pam/fingerprint.conf
  preview.qml                     the same screen in a normal window, nothing locked
bin/kurenai-lock-supervisor       restarts the locker if it crashes (gives up after 4 crashes in 60 s)
hypr/kurenai-lock.lua             allow_session_lock_restore + starts the supervisor with the session (opt-in)
hypr/hypridle.kurenai.conf        SAMPLE for lock on idle / before sleep (opt-in, merge by hand)
```

### Set it up in THIS order
1. `bash install.sh` (nothing is started or locked).
2. `kurenai-ctl lock-preview`: the real lock screen in an ordinary window with the **real** password check (and fingerprint).
   Type your password: the window closes. **This proves unlocking works before anything is locked.** Try a wrong one too.
3. `kurenai-ctl enable-lock`, then `kurenai-ctl lock-start`.
4. Switch to a text console (**Ctrl+Alt+F3**), log in there, switch back (Ctrl+Alt+F1 or F2): that is your safety net.
5. Only now: `kurenai-ctl lock` (or `SUPER+L`, or Power menu > Lock). Unlock with your password or fingerprint.
6. `kurenai-ctl lock-hypridle` for lock on idle and before sleep/lid close.

### How it behaves
- **Lock:** Wayland's `ext-session-lock`, enforced by Hyprland: every output is covered and input goes only to the lock. If the locker dies,
  the screen **stays locked**.
- **Unlock:** only when PAM says yes (password **or** fingerprint, checked in parallel). There is deliberately **no unlock IPC call**.
  Five wrong passwords in a row = a 10 s cooldown (`Config.qml`).
- **It refuses to lock** if the password PAM file is missing (locking yourself out is worse than not locking).
- **Password handling:** held only until Enter, handed to PAM, then dropped; never logged or written; the field cannot be pasted into.
  (QML strings cannot be wiped from memory: true of every QML locker.)
- **What it shows:** time, date, your user name, battery, and a **count** of unread notifications. Never notification contents.
- **Background:** the wallpaper `awww query -j` reports for each monitor, blurred and darkened; otherwise `Config.wallpaper`; otherwise a
  generated seigaiha pattern. No network.
- **Power menu:** "Lock" uses it; "Suspend" locks first (`Config.lockBeforeSuspend` in the main Config.qml).

### If something goes wrong
- **Screen stuck on Hyprland's placeholder after a locker crash:** the supervisor restarts the locker within a second and it re-locks
  (`allow_session_lock_restore` lets the new one take over). If it does not: **Ctrl+Alt+F3**, log in, run `kurenai-ctl lock-recover`, go back
  (Ctrl+Alt+F1/F2) and unlock. Last resort (ends the session, loses unsaved work): `pkill -x Hyprland`.
- `qs log -c kurenai-lock` shows the locker's log; `kurenai-ctl lock-status` and `kurenai-ctl validate` summarise the state.
- **Harden (optional):** the default PAM files live in your home, so a program running as you could edit them. `kurenai-ctl lock-harden`
  prints the steps for a root-owned PAM service.
- **Remove:** `kurenai-ctl disable-lock`, `kurenai-ctl lock-stop`; `kurenai-ctl rollback` moves everything aside (refused while locked).

### Grey screen when locking (diagnosing)
A grey screen means the compositor holds the lock but nothing is drawn on that output. Get out with
**Ctrl+Alt+F3**, log in, `kurenai-ctl lock-recover`, switch back, unlock. Then find out which path misbehaves:

1. `kurenai-ctl lock-stop && kurenai-ctl lock-start` (a clean locker)
2. `kurenai-ctl lock`  -> unlock  -> `kurenai-ctl lock` again.   *(is the SECOND lock of one process broken?)*
3. restart the locker again, then `loginctl lock-session` as the FIRST lock.   *(is the hypridle/loginctl path broken?)*
4. `pkill hypridle; hypridle -v` in a terminal, then `loginctl lock-session`: does it print that it runs `lock_cmd`?
5. `kurenai-ctl lock-diagnose` (from a TTY if needed) and send the output. The locker's log is the plain text file
   `$XDG_RUNTIME_DIR/kurenai-lock.log` (states and counts only; never passwords).

### Fixed in 4a.5: grey screen / "locker thinks it is locked"
After an unlock, the locker kept a stale state (it relied on a change signal that Quickshell did not send), so the next lock
drew an invisible UI (grey) and `lock-stop` refused because it believed the screen was still locked. The controller now keeps its own
record of the lock, cleans up itself at unlock, and every lock starts from a clean state.
- `kurenai-ctl lock-status` / `validate` tell you when the state is stale (you are on the desktop but the locker says "locked").
- `kurenai-ctl lock-reset` (run inside your graphical session) clears it: removes the re-lock flag and restarts the locker.
- The supervisor now refuses to start without `WAYLAND_DISPLAY` (a TTY) and exits when its Wayland session is gone, so a leftover
  supervisor can no longer crash-loop or block the next session's supervisor.
- hypridle was never the problem: `hypridle -v` showed it receiving the logind lock, running `lock_cmd`, and Hyprland confirming the lock.
