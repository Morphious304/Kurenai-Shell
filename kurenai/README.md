# KURENAI, phase 2

Hyprland (Lua config, 0.55+) theme + Quickshell shell: top bar, notification popups and centre,
application launcher, IPC. Phase 3 adds quick settings; phase 4 the optional panels.

```
install.sh                       copies files into place after a backup; starts nothing, edits nothing
bin/kurenai-ctl                  see `kurenai-ctl` for the full command list
hypr/kurenai.lua                 appearance only (borders, gaps, rounding, shadow, motion)
hypr/kurenai-binds.lua           opt-in keybinds (launcher, notifications, DND, Rofi fallback)
hypr/kurenai-autostart.lua       opt-in session autostart
quickshell/kurenai/              run with:  qs -c kurenai
  Theme.qml Config.qml           design tokens / behaviour settings
  UiState.qml Compositor.qml     overlay open-flags / Hyprland dispatch + focused screen
  NotificationStore.qml          the one notification state (server, history, popups, DND)
  NotificationCard/Popups/Center.qml
  Apps.qml Launcher.qml          desktop-entry index, search, favourites, recents / the launcher UI
  Surface.qml PanelOverlay.qml   shared panel look / shared popover window (focus, click-outside, Esc)
  Ipc.qml                        qs ipc targets used by the keybinds
  Bar.qml Workspaces.qml WindowTitle.qml SysStatus.qml Tray.qml Clock.qml BarItem.qml Divider.qml Emblem.qml
```

## IPC (verify with `qs -c kurenai ipc show`)
```
qs -c kurenai ipc call launcher toggle|open|close
qs -c kurenai ipc call notifications toggle|open|close|dnd|clear
qs -c kurenai ipc call shell closeAll
```

## Customise
- Colours, sizes, fonts, timings: `Theme.qml`. Terminal for Terminal=true apps, popup limits/timeouts, launcher size: `Config.qml`.
- Hyprland: top of `hypr/kurenai.lua` (`ENABLE_BLUR`, `FLOAT_ACCENT`). Keybinds: `hypr/kurenai-binds.lua`.
- Quickshell live-reloads QML on save.

## Local data
`~/.local/share/kurenai/launcher.json` holds favourite/recent desktop-entry ids only. Reset: `kurenai-ctl reset-launcher`.
Notification history lives in memory only (it is cleared when Quickshell stops).
