# Clipboard history and system monitor

[Back to the README](../README.md)

Text **and images**, searchable, with a **History** tab (auto-deleted after 30 days) and a **Pinned** tab (kept until you remove them).
Engine: `cliphist` + `wl-clipboard`, driven by the helper `~/.local/bin/kurenai-clip`.

| Key | Action |
|---|---|
| `Enter` / click | copy the entry back onto the clipboard, then paste in your app with the usual **Ctrl+V** |
| `Ctrl+P` | pin / unpin | 
| `Shift+Delete` (or `Delete` on an empty search) | delete the entry |
| `Tab` | switch History / Pinned |
| switch in the header | pause / resume recording |

**Why there are no Ctrl+X / Ctrl+C / Ctrl+V binds:** those keys already work inside every application, and a compositor-level bind
would *swallow* them (copy and paste would stop working, and Ctrl+C would no longer interrupt a program in the terminal). Whatever
those keys copy is recorded automatically. The only new clipboard shortcut is `SUPER+V`.

### Privacy: exactly what happens to your clipboard
- Everything stays on this machine; there is no network code. Clipboard contents are **never written to a log** (the panel and the helper
  contain no logging of entries; checked).
- History lives in cliphist's database `~/.cache/cliphist/db` (kept private: mode 600) and **persists across reboots** until it expires,
  you delete it, or you clear it. Pins are copies kept in `~/.local/share/kurenai/clipboard/pins/` (mode 700).
- **Auto-clear:** history older than `Config.clipboardRetentionDays` (30) is deleted at start, every 6 hours and whenever the panel opens.
  cliphist 0.7.0 does not store timestamps, so the helper records the time of each copy itself (`times.tsv`). An entry whose time is
  unknown starts its 30 days when first noticed. **Pinned items are never auto-deleted.**
- **Pause** stops recording completely. `Config.clipboardEnabled = false` means nothing is ever recorded.
- **Password managers:** if an app clears the clipboard (most managers do after a timeout), cliphist removes that last entry. I could **not**
  confirm that cliphist ignores "sensitive" hints, so a copied password can be recorded until the manager clears it: pause recording while
  you work with secrets, or delete the entry (`Shift+Delete`).
- Decoded image previews live only in `$XDG_RUNTIME_DIR` (memory, private) and are removed when the panel closes.
- `kurenai-ctl clip-wipe` (asks first) or "Clear history..." in the panel (two clicks) deletes the history; pins are kept.
- Items bigger than `Config.clipboardMaxStoreMB` (10 MB) are not recorded (cliphist's own default is 5 MB, too small for screenshots).

## System monitor (`SUPER+I`, or the chart button in quick settings)
CPU, memory (+swap), CPU temperature (if a sensor exists), battery, and storage (`/`, `/home`, `/boot`, one line per real filesystem).
It reads data **only while the panel is open** (every `Config.sysmonInterval` ms, via the read-only helper `kurenai-sysmon`); closed = zero cost.
