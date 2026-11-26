# KURENAI, phase 3.1 (phase 3 + control-script fixes)

Hyprland (Lua config, 0.55+) theme + Quickshell shell: top bar, notification popups and centre,
docked application launcher, quick settings, IPC. Phase 4 = optional panels (media, calendar, OSD,
power menu, clipboard).

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
