# The lock screen (`qs -c kurenai-lock`)

[Back to the README](../README.md)

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

