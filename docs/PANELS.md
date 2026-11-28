# Panels: quick settings, media, calendar, on-screen display, power menu

[Back to the README](../README.md)

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

## Media, calendar, on-screen display, power menu
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
