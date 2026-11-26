# Changelog

[Back to the README](../README.md)

Newest first. Only user-visible changes and fixes.

## Final (this package)
- Documentation consolidated: one README plus the pages in `docs/`. No code changes in this step.

## Meter fix
- **System monitor:** the battery bar now treats *empty* as the problem (teal above 30 %, amber at 30 % or less, vermilion at 15 % or less).
  Before, it used the same "fuller is worse" colours as CPU and memory, so a full battery showed red and a low one showed teal.
  Changed files: `MeterRow.qml` (new `lowIsBad` property), `SysMonPanel.qml`.

## 4b.1 + 4a.6
- Keyboard shortcuts page merged with clipboard history and the system monitor. `SUPER + /` opens the shortcuts page.
- IPC labels for the clipboard and monitor binds added to the shortcuts page.

## 4b
- Clipboard history (`SUPER + V`) with History and Pinned tabs, and the system monitor (`SUPER + I`).

## 4a.6
- Keyboard shortcuts page that reads your Lua config live.

## 4a.5: grey screen / "locker thinks it is locked"
After an unlock, the locker kept a stale state (it relied on a change signal that Quickshell did not send), so the next lock
drew an invisible UI (grey) and `lock-stop` refused because it believed the screen was still locked. The controller now keeps its own
record of the lock, cleans up itself at unlock, and every lock starts from a clean state.
- `kurenai-ctl lock-status` / `validate` tell you when the state is stale (you are on the desktop but the locker says "locked").
- `kurenai-ctl lock-reset` (run inside your graphical session) clears it: removes the re-lock flag and restarts the locker.
- The supervisor refuses to start without `WAYLAND_DISPLAY` (a TTY) and exits when its Wayland session is gone, so a leftover
  supervisor can no longer crash-loop or block the next session's supervisor.
- hypridle was never the problem: `hypridle -v` showed it receiving the logind lock, running `lock_cmd`, and Hyprland confirming the lock.

## 4a.1
- **Fixed: labels missing on centred buttons** (power-profile Saver/Balanced/Performance, Sound/Network/Bluetooth shortcuts, calendar Today,
  power-menu Cancel, media Player n/m). A sizing loop made the label zero-width. `Btn.qml` now sizes centred labels from the text itself.
- **Toggle tiles** (Do not disturb / Keep awake / Night light) are stacked (icon above label) so their names are no longer cut off.
- **Live brightness:** the slider and the brightness OSD follow Fn keys and any other brightness change immediately, no bind edits needed.
- `kurenai-ctl validate`: lock-screen hint says what to install; direct `poweroff`/`reboot` keybinds are a note, not a warning (your choice);
  checks `udevadm` and warns if more than one backlight device exists (the shell and your keys must use the same one).

## 4a
- Media panel and bar item (MPRIS), calendar, on-screen display, power menu.

## Earlier
- Core shell (bar, notifications, launcher, quick settings, Hyprland theme), lock screen, installer and `kurenai-ctl`.
