# KURENAI

A Japanese anime-inspired desktop shell for **Hyprland** (Lua config, 0.55 or newer) built entirely on **Quickshell**:
top bar, notification popups and centre, application launcher (Apps / Run / Prime / Walls tabs), quick settings, media panel, calendar, on-screen display,
power menu, clipboard history, system monitor, keyboard-shortcuts page and a lock screen.

Rofi stays installed and bound as the fallback launcher, with a matching KURENAI theme. Everything below is reversible.

Written and tested against: Hyprland 0.56.2 (Lua config), Quickshell 0.3.2, Arch Linux, ThinkPad P53 (hybrid Intel/NVIDIA),
SDDM, PipeWire, NetworkManager, kitty. Other setups may work but were not tried.

- [1. What you need](#1-what-you-need)
- [2. What is in the box](#2-what-is-in-the-box)
- [3. First-time install](#3-first-time-install)
- [4. Updating](#4-updating)
- [5. Using it: shortcuts and IPC](#5-using-it-shortcuts-and-ipc)
- [6. Customising](#6-customising)
- [7. Your data and privacy](#7-your-data-and-privacy)
- [8. Troubleshooting](#8-troubleshooting)
- [9. Rollback](#9-rollback)
- [10. What is verified and what is not](#10-what-is-verified-and-what-is-not)

Detail pages (in `docs/`): [LOCK-SCREEN](docs/LOCK-SCREEN.md), [CLIPBOARD-AND-SYSMON](docs/CLIPBOARD-AND-SYSMON.md),
[LAUNCHER](docs/LAUNCHER.md), [THEME](docs/THEME.md) (wallpaper colours), [FIREFOX](docs/FIREFOX.md), [SHORTCUTS-PAGE](docs/SHORTCUTS-PAGE.md), [PANELS](docs/PANELS.md), [TROUBLESHOOTING](docs/TROUBLESHOOTING.md),
[CHANGELOG](docs/CHANGELOG.md).

---

## 1. What you need

Every optional item degrades on its own: a missing tool hides or explains that one control. Nothing here is installed
for you. Commands marked **sudo** change your system; read them before running them.

### Required

| Package | Why | Notes |
|---|---|---|
| `hyprland` 0.55 or newer | the compositor; KURENAI uses its **Lua** config API | `hyprctl version` |
| `quickshell` | runs the whole shell (`qs -c kurenai`) | `qs --version` (tested: 0.3.2) |

### Strongly recommended (looks)

| Package | Why | If missing |
|---|---|---|
| `adwaita-fonts` | "Adwaita Sans", the UI font | falls back to the default font |
| `ttf-jetbrains-mono-nerd` | numbers, key caps | falls back to a default monospace |
| `noto-fonts-cjk` | the decorative kanji (紅, 余波, 鍵) | the kanji show as boxes; no label depends on them |

### Services most desktops already run (used natively by Quickshell)

| Service | Used for | If missing |
|---|---|---|
| PipeWire (+ WirePlumber) | volume, microphone, device pickers, volume OSD | those rows dim and say why |
| NetworkManager | Wi-Fi status, on/off, saved networks | "No Wi-Fi adapter" |
| BlueZ | Bluetooth on/off, paired devices | "No adapter" |
| UPower | battery in the bar and panels | battery hidden |

### Optional

| Package | Feature | If missing |
|---|---|---|
| `rofi` | fallback launcher (`SUPER + SHIFT + SPACE`, and the Quickshell launcher falls back to it); themed by `rofi/kurenai.rasi` | no fallback launcher: install it, it is your safety net |
| `matugen` | **wallpaper colours**: shell, lock screen, Rofi and borders follow the wallpaper ([docs/THEME.md](docs/THEME.md)) | the Quick Settings tiles are hidden; built-in colours stay |
| `adw-gtk-theme`, `qt6ct`/`qt5ct`, `kitty`, `btop`, `yazi`, `zathura`, `neovim`, `spicetify`, `pacsea`, `lazygit` | **app colours**: each one you attach follows the same colours (`kurenai-ctl theme extras`) | that app is simply not offered / unchanged |
| `firefox` | **Firefox theme** (opt-in): docked tab rail / one-row horizontal tabs, detached launcher card, start page; `kurenai-ctl theme extra firefox on` ([docs/FIREFOX.md](docs/FIREFOX.md)); hide button + keys need the optional fx-autoconfig loader | not touched; nothing is attached unless you ask |
| `nvidia-prime` (provides `prime-run`) | launcher **Prime** tab | the tab says it is not installed |
| `brightnessctl` | brightness slider | row shows an install hint |
| `power-profiles-daemon` | Saver / Balanced / Performance | section hidden |
| `hyprsunset` | night-light tile | tile hidden |
| `cliphist`, `wl-clipboard`, `xdg-utils` | clipboard history (`SUPER + V`) | panel explains what to install |
| `awww` | launcher **Walls** tab sets wallpapers; lock-screen background follows your wallpaper | tab can list but not set; lock uses `Config.wallpaper`, else a generated pattern |
| `hypridle` | lock on idle and before sleep | you lock by hand or with `SUPER + L` |
| `fprintd` | fingerprint unlock | password only |
| `playerctl` | your media keys, if they call it | those keys do nothing; the panel still works |
| `libnotify` | `notify-send`, for testing notifications | testing only |
| `nm-connection-editor` | joining new Wi-Fi networks (opened, never handled by the shell) | row says to use `nmtui` or `nmcli` |
| `pwvucontrol` or `pavucontrol` | Sound shortcut | shortcut hidden |
| `blueman` or `overskride` | Bluetooth shortcut | shortcut hidden |
| `hyprshutdown` | graceful log out | log out uses Hyprland's own exit |
| `hyprlock`, `swaylock`, `gtklock`, `waylock` | only as a **fallback** "Lock" if the KURENAI lock is not running | not needed with the KURENAI lock |

Package names: `adwaita-fonts`, `ttf-jetbrains-mono-nerd`, `awww` and `hyprsunset` were confirmed in the official Arch
repositories (search results, November 2026). The rest are the names `kurenai-ctl validate` itself prints. Before installing
any optional package, ask pacman: `pacman -Si NAME` (if it says "not found", that package is not in your enabled repos:
skip it, it is optional).

`kurenai-ctl validate` checks all of the above, read-only, and prints `[ ok ]`, `[warn]`, `[FAIL]`, or `[ -- ]` (optional tool not installed) for each.

---

## 2. What is in the box

```
kurenai/
├── README.md                     this file
├── install.sh                    copies files into place after a backup; starts nothing, edits nothing
├── bin/
│   ├── kurenai-ctl               setup / start / stop / validate / rollback (run `kurenai-ctl` for the list)
│   ├── kurenai-settings          opens the Settings window (also in Rofi / the launcher); see docs/SETTINGS.md
│   ├── kurenai-conf              settings store, favourites, bind remaps, export/import (used by the window; usable alone)
│   ├── kurenai-hypr              monitors and input with an auto-revert timer (used by the window; usable alone)
│   ├── kurenai-lock-supervisor   restarts the locker if it crashes (gives up after 4 crashes in 60 s)
│   ├── kurenai-clip              clipboard-history engine (cliphist + wl-clipboard)
│   └── kurenai-sysmon            read-only system snapshot for the monitor panel
├── rofi/kurenai.rasi             Rofi theme (installed to ~/.config/rofi/themes/)
├── matugen/                      templates for wallpaper colours (installed to ~/.local/share/kurenai/matugen/)
├── extras/                       app colour templates + renderer (kitty gtk qt btop yazi zathura nvim spicetify pacsea lazygit firefox; to ~/.local/share/kurenai/extras/)
├── hypr/                         all opt-in; only kurenai.lua is KURENAI's own
│   ├── kurenai.lua               appearance (borders, gaps, rounding, shadow, motion)
│   ├── kurenai-binds.lua         15 keybinds (launcher + its Run/Prime/Walls tabs, panels, lock, clipboard, monitor, shortcuts)
│   ├── kurenai-autostart.lua     start the shell with the session
│   ├── kurenai-lock.lua          lock-screen crash recovery + supervisor start
│   └── hypridle.kurenai.conf     SAMPLE only: lock on idle / before sleep
├── quickshell/
│   ├── kurenai/                  the shell: `qs -c kurenai`
│   │   ├── shell.qml  qmldir     entry point / component registry
│   │   ├── Theme.qml             design tokens: colours, sizes, radii, fonts, timings
│   │   ├── Config.qml            behaviour settings: what each panel does, limits, tools
│   │   ├── UiState.qml           which panel is open       Compositor.qml  Hyprland dispatch, focused screen
│   │   ├── Bar.qml  Workspaces.qml  WindowTitle.qml  SysStatus.qml  Tray.qml  Clock.qml  BarItem.qml  Divider.qml  Emblem.qml
│   │   ├── NotificationStore.qml (the one notification state)  NotificationCard / Popups / Center.qml
│   │   ├── Apps.qml  Launcher.qml                      desktop-entry index and the launcher (tab host)
│   │   ├── LauncherList.qml  LauncherRun.qml  LauncherWalls.qml   the tabs (Apps+Prime share one list)
│   │   ├── Runner.qml  Walls.qml                       Run tab backend; wallpaper scan and awww calls
│   │   ├── ThemeCtl.qml                                wallpaper colours: runs kurenai-ctl theme-*, shows the state
│   │   ├── QuickSettings.qml  Audio.qml  System.qml    quick settings and the state behind it
│   │   ├── Media.qml  MediaPanel.qml                   MPRIS
│   │   ├── CalendarPanel.qml  Power.qml  PowerMenu.qml  OsdState.qml  OsdWindow.qml
│   │   ├── Clipboard.qml  ClipboardPanel.qml           clipboard history
│   │   ├── SysMon.qml  SysMonPanel.qml  MeterRow.qml   system monitor
│   │   ├── Keybinds.qml  BindParser.js  ShortcutsPanel.qml   shortcuts page
│   │   ├── PanelFrame.qml  PanelOverlay.qml  DockShape.qml  Surface.qml   shared panel look and window
│   │   ├── Btn.qml  KToggle.qml  KSlider.qml  QsSection.qml  ListBox.qml  LevelRow.qml   shared controls
│   │   └── Ipc.qml                                     `qs ipc` targets used by the keybinds
│   └── kurenai-lock/             the lock screen: a SEPARATE process, `qs -c kurenai-lock`
│       ├── shell.qml  LockController.qml  LockState.qml  LockView.qml
│       ├── Wallpaper.qml  Pattern.qml  BlurFx.qml  Petal.qml  Seal.qml
│       ├── Config.qml  Theme.qml (a COPY of the main theme)  preview.qml  qmldir
│       └── pam/password.conf  pam/fingerprint.conf
└── docs/                         detail pages
```

Where things land after `install.sh`:

| In the package | Installed to |
|---|---|
| `quickshell/kurenai`, `quickshell/kurenai-lock`, `quickshell/kurenai-settings` | `~/.config/quickshell/` |
| (written by `kurenai-ctl desktop-entry install`) | `~/.local/share/applications/kurenai-settings.desktop`, with the absolute program path (Rofi and the launcher list it) |
| `hypr/*.lua`, `hypr/hypridle.kurenai.conf` | `~/.config/hypr/` |
| `rofi/kurenai.rasi` | `~/.config/rofi/themes/` |
| `matugen/` | `~/.local/share/kurenai/matugen/` |
| `extras/` | `~/.local/share/kurenai/extras/` (nothing is attached until you run `kurenai-ctl theme extra NAME on`) |
| `bin/*` | `~/.local/bin/` (put it on your `PATH`) |
| backups, notes, favourites, Run history | `~/.local/share/kurenai/` |

Keep this package folder: the `docs/` pages are read from here.

---

## 3. First-time install

Each step is small and checked before the next. Stop and send me the output if anything prints an error.

1. **Read-only audit.** Nothing is changed.
   ```bash
   hyprctl version | head -1
   qs --version
   ls ~/.config/hypr ~/.config/quickshell 2>/dev/null
   ```
2. **Install the files.** This makes a backup first and starts nothing.
   ```bash
   cd ~/path/to/kurenai
   bash install.sh
   ```
3. **Health check** (read-only). Fix any `[warn]` you care about. Missing optional tools are normal.
   ```bash
   kurenai-ctl validate
   ```
4. **Test the shell in the foreground**, with live logs. `Ctrl+C` quits and leaves your desktop as it was.
   ```bash
   kurenai-ctl debug
   ```
   Check the bar, workspace clicks, `notify-send 'KURENAI' 'hello'` and each panel before continuing.
   Two things must not appear: a second bar, and `Could not register notification server`. Either means another
   notification daemon (mako, dunst, swaync) still owns the service: see step 7.
5. **Enable the theme** (one marked line added to `hyprland.lua`; a backup is made first).
   ```bash
   kurenai-ctl enable
   hyprctl configerrors        # an empty result means no errors
   ```
6. **Keybinds.** Look for clashes first, then enable.
   ```bash
   kurenai-ctl binds-check
   kurenai-ctl enable-binds
   kurenai-ctl binds-check     # each KURENAI chord should now be bound exactly once
   ```
   Rofi fallback: `SUPER + SHIFT + SPACE`. It works even if Quickshell is not running.
7. **Notifications.** Only one program may own `org.freedesktop.Notifications`.
   ```bash
   kurenai-ctl notif-status      # who owns it now, where it is started
   kurenai-ctl notif-takeover    # stops the running mako/dunst/swaync (remembers which)
   kurenai-ctl start
   notify-send 'KURENAI' 'hello'
   ```
   Also comment out the old daemon's autostart in your Hyprland config. Undo any time: `kurenai-ctl notif-restore`.
8. **Start with the session** (one marked line).
   ```bash
   kurenai-ctl enable-autostart
   ```
9. **Lock screen, in this order.** Read [docs/LOCK-SCREEN.md](docs/LOCK-SCREEN.md) first. The short version:
   `kurenai-ctl lock-preview` (real password check, locks nothing) then `enable-lock`, `lock-start`, open a TTY with
   `Ctrl+Alt+F3` as a safety net, and only then `kurenai-ctl lock`.
10. **Optional:** `kurenai-ctl lock-hypridle` (lock on idle), clipboard history ([docs](docs/CLIPBOARD-AND-SYSMON.md)),
    brightness OSD (`kurenai-ctl media-binds` prints the one-line change, applies nothing).

---

## 4. Updating

`install.sh` is safe to re-run. It never edits `hyprland.lua` and never starts or stops anything.

```bash
kurenai-ctl backup                       # optional: the installer also makes one
cd ~/path/to/new/kurenai
bash install.sh
kurenai-ctl validate
kurenai-ctl restart                      # the shell picks up the new QML
```

What the installer does with what you already have:

| Your file | What happens |
|---|---|
| `quickshell/kurenai/` (including **your edits to `Theme.qml` and `Config.qml`**) | moved to `~/.local/share/kurenai/replaced-<timestamp>/`, the new tree installed. **Re-apply your edits from there.** |
| `quickshell/kurenai-lock/` (incl. its `Config.qml`) | the same |
| `hypr/kurenai.lua` | the same (it is KURENAI's own) |
| `hypr/kurenai-binds.lua`, `kurenai-autostart.lua`, `kurenai-lock.lua` | **kept if you changed them**; the new version is saved as `<file>.new`. Compare: `diff ~/.config/hypr/kurenai-binds.lua{,.new}` |
| `bin/*` | replaced (they hold no settings) |
| favourites, backups, clipboard pins | untouched |

After an update that changed the lock screen: `kurenai-ctl lock-stop && kurenai-ctl lock-start` (refused while locked).
After you edit the main `Theme.qml`: `kurenai-ctl lock-sync-theme` copies it into the lock config.

---

## 5. Using it: shortcuts and IPC

The **live** list of every shortcut in your own config is the shortcuts page: `SUPER + /`
(details: [docs/SHORTCUTS-PAGE.md](docs/SHORTCUTS-PAGE.md)). It reads your files, so it cannot go stale. The table below is the
static copy of what `kurenai-binds.lua` ships.

| Keys | Does |
|---|---|
| `SUPER + SPACE` | application launcher (falls back to Rofi if the shell is not running) |
| `SUPER + SHIFT + SPACE` | Rofi directly (KURENAI theme if installed) |
| `SUPER + SHIFT + R` | launcher on the **Run** tab |
| `SUPER + SHIFT + P` | launcher on the **Prime** tab (apps on the NVIDIA GPU) |
| `SUPER + SHIFT + W` | launcher on the **Walls** tab (wallpaper switcher) |
| `SUPER + N` | notification centre |
| `SUPER + SHIFT + N` | Do Not Disturb on/off |
| `SUPER + A` | quick settings |
| `SUPER + C` | calendar (clicking the clock does the same) |
| `SUPER + SHIFT + M` | media panel |
| `SUPER + ESCAPE` | power menu |
| `SUPER + L` | lock the screen |
| `SUPER + V` | clipboard history |
| `SUPER + I` | system monitor (also the chart button in quick settings) |
| `SUPER + /` | keyboard shortcuts page |

Inside panels (every panel: `Esc` closes, click outside closes):

| Panel | Keys |
|---|---|
| Launcher | type to filter, `Up/Down` or `Ctrl+N/P/J/K` move, `Enter` launches, `Ctrl+F` favourite, `Tab` / `Ctrl+1..4` switch tab. Other tabs: [docs/LAUNCHER.md](docs/LAUNCHER.md) |
| Clipboard | `Enter` copies the entry back (paste with your usual `Ctrl+V`), `Ctrl+P` pin, `Shift+Delete` delete, `Tab` History/Pinned |
| Shortcuts | type to filter (every word must match), `Up/Down`, `PageUp/PageDown`, `Home/End` |
| Calendar | arrows move the selected day, `PageUp/PageDown` change month, `Home` goes to today |
| Quick settings | `Tab` moves between controls, `Space/Enter` activates, `Left/Right` moves sliders |
| Power menu | nothing is pre-focused; Log out, Reboot and Shut down need a **second** click (it cancels itself after 10 s) |

There is deliberately no bind on `Ctrl+X`, `Ctrl+C` or `Ctrl+V`: a compositor-level bind would swallow them in every app.

IPC (the keybinds use these; verify the real list with `qs -c kurenai ipc show`):

```
qs -c kurenai ipc call launcher toggle|open|close
qs -c kurenai ipc call launcher openTab|toggleTab apps|run|prime|walls
qs -c kurenai ipc call notifications toggle|open|close|dnd|clear
qs -c kurenai ipc call quicksettings toggle|open|close
qs -c kurenai ipc call media toggle|playpause|next|previous
qs -c kurenai ipc call calendar toggle|close
qs -c kurenai ipc call powermenu toggle|close
qs -c kurenai ipc call shortcuts toggle|open|close|rescan|status
qs -c kurenai ipc call clipboard toggle|close|pause|resume
qs -c kurenai ipc call sysmon toggle|close
qs -c kurenai ipc call osd brightness
qs -c kurenai ipc call shell closeAll
qs -c kurenai-lock ipc call lock lock        # the lock screen is a separate process; there is no unlock call
```

---

## 6. Customising

Quickshell reloads QML when you save a file, so most changes appear immediately.

| To change | Edit | Notes |
|---|---|---|
| Colours that follow the wallpaper | Quick Settings, or `kurenai-ctl theme ...` | [docs/THEME.md](docs/THEME.md) |
| Firefox theme (opt-in) | `kurenai-ctl theme extra firefox on` | [docs/FIREFOX.md](docs/FIREFOX.md) |
| Fixed (built-in) colours | `~/.config/quickshell/kurenai/Theme.qml` | the `defaults` table; with wallpaper colours on, these are only the fallback. Roles: `bg surface raised panelBg`, `text text2 muted`, `accent accentText accentDeep teal rose amber`. Keep small red text on `accentText`, not `accent` (contrast) |
| Fonts | `Theme.qml`: `fontUi`, `fontMono`, `fontDisplay` | check what you have with `fc-list \| grep -i NAME` |
| Sizes, spacing, radii | `Theme.qml`: `s1..s6` (4 px unit), `rSm/rMd/rLg`, `barHeight`, `*Width` | |
| Animation speed | `Theme.qml`: `durFast 120`, `durBase 220`, `durSlow 320` (ms) | |
| Clock format | `Theme.qml`: `timeFormat` | |
| Terminal for terminal apps, launcher size, popup limits and timeouts | `Config.qml` | |
| Which OSDs show | `Config.qml`: `osdVolume osdMic osdBrightness osdMediaPlayPause osdMediaTrack` | |
| Panels hang from the bar or float | `Config.qml`: `launcherDocked`, `quickSettingsDocked`, `popoverDocked` | |
| Brightness curve | `Config.qml`: `brightnessExponent`, `brightnessMin` | must equal the `-eN -nM` your brightness keys use |
| Clipboard retention / disable | `Config.qml`: `clipboardRetentionDays`, `clipboardEnabled` | |
| Wallpaper folders, transition, grid size; Run history | `Config.qml`: `wallpaperDirs`, `wallpaperTransition`, `wallpaperColumns`, `runHistory`... | [docs/LAUNCHER.md](docs/LAUNCHER.md) |
| Where the shortcuts page reads | `Config.qml`: `hyprMainFile` | only if your config is not at `~/.config/hypr/hyprland.lua` |
| Window borders, gaps, rounding, blur | top of `~/.config/hypr/kurenai.lua` and the values below it | `ENABLE_BLUR` is off: it costs GPU on hybrid-graphics laptops. `FLOAT_ACCENT` gives floating windows a teal frame |
| Keybinds | `~/.config/hypr/kurenai-binds.lua` | one `{ "CHORD", command }` per line; then `hyprctl reload` |

After editing the main `Theme.qml`, run `kurenai-ctl lock-sync-theme` so the lock screen matches.
Your edits live in your installed copy; an update moves it aside (section 4), so keep a note of what you changed.

---

## 7. Your data and privacy

| What | Where | Notes |
|---|---|---|
| Launcher favourites and recents (Apps and Prime) | `~/.local/share/kurenai/launcher.json` | desktop-entry ids only. Reset: `kurenai-ctl reset-launcher` |
| Run-tab command history | `~/.local/share/kurenai/runhistory.json` (mode 600) | the last 50 commands you ran from the Run tab; a command starting with a space is never saved; `Config.runHistory = false` saves none. Reset: `kurenai-ctl reset-launcher` |
| Current wallpaper | awww's own cache (`~/.cache/awww`) | KURENAI saves nothing about wallpapers |
| Notification history | memory only | gone when Quickshell stops |
| Clipboard history | `~/.cache/cliphist/db` (mode 600) | 30 days, then deleted. Pause or wipe any time. [Details](docs/CLIPBOARD-AND-SYSMON.md) |
| Clipboard pins | `~/.local/share/kurenai/clipboard/pins/` (mode 700) | until you remove them |
| Backups | `~/.local/share/kurenai/backups/<timestamp>/` | copies of `~/.config/hypr` and `~/.config/quickshell`. They can contain anything you keep in those folders |
| Lock-screen log | `$XDG_RUNTIME_DIR/kurenai-lock.log` | states and counts only, never passwords |

There is no network code, no telemetry and no remote assets. Wi-Fi passwords are never typed into, stored by or passed through the
shell. Nothing runs through `sudo`. Notification text and clipboard text are shown as plain text and never interpreted as QML or commands.

---

## 8. Troubleshooting

Start here: `kurenai-ctl validate`. The full list is in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). The four you are most likely to hit:

| Symptom | Cause and fix |
|---|---|
| Two bars, or `Could not register notification server` | a second `qs -c kurenai` was started by hand. Use `kurenai-ctl start` / `restart` only. Check with `kurenai-ctl validate` |
| Notifications go nowhere | another daemon owns the service: `kurenai-ctl notif-status`, then `notif-takeover` |
| A panel key does nothing | the bind is missing or clashes: `kurenai-ctl binds-check`; or open the shortcuts page and search the key |
| Screen is grey or stuck after locking | `Ctrl+Alt+F3`, log in, `kurenai-ctl lock-recover`, switch back. Full steps in [docs/LOCK-SCREEN.md](docs/LOCK-SCREEN.md) |

Logs: `kurenai-ctl logs` (running shell), `kurenai-ctl debug` (foreground), `qs log -c kurenai-lock` (locker).

---

## 9. Rollback

Nothing is deleted at any step; everything is moved aside or copied. Rofi, your wallpaper service and your personal files are never touched.

| You want | Run |
|---|---|
| Undo everything KURENAI added | `kurenai-ctl rollback` |
| The same, and also put `hyprland.lua` back from the latest backup | `kurenai-ctl restore` |
| Only stop the shell and bring your old notification daemon back | `kurenai-ctl notif-restore` |
| Only remove one hook | `kurenai-ctl disable`, `disable-binds`, `disable-autostart` or `disable-lock` |
| Stop it for now, keep everything installed | `kurenai-ctl stop` |

`rollback` stops the shell and the locker, removes **all four** marked hook lines from `hyprland.lua`, restores the notification daemon
you had, moves the KURENAI files to `~/.local/share/kurenai/removed-<timestamp>/` and reloads Hyprland. It refuses to run while the
screen is locked. To go back to KURENAI afterwards, re-run `install.sh` and the `enable` commands.

Manual rollback, if `kurenai-ctl` itself is not working:

1. Remove the lines ending in `KURENAI-HOOK`, `KURENAI-BINDS-HOOK`, `KURENAI-AUTOSTART-HOOK` and `KURENAI-LOCK-HOOK` from `~/.config/hypr/hyprland.lua`.
2. `pkill -f 'qs.*-c kurenai'`, then restart your old notification daemon (for example `mako &`).
3. Restore from `~/.local/share/kurenai/backups/latest/hypr` and `.../quickshell` if you need the exact earlier files.
4. `hyprctl reload`.

Rofi works the whole time: `rofi -show drun`.

---

## 10. What is verified and what is not

Be clear about what each claim rests on.

**Checked in a sandbox (not on your machine):** the shortcuts parser (unit tests over the official Hyprland example config and
KURENAI's own binds), QML syntax (`qmllint`, which does not know Quickshell types, so only real syntax errors count), shell script
syntax (`bash -n`), and the Quickshell v0.2.0 documentation for the APIs used.

**Reported working by you:** the 4b.1 + shortcuts + meter-fix build installs and `kurenai-ctl validate` / `restart` show no errors.

**Not verified on your machine, and not claimed:** the exact text `hyprctl binds` prints for Lua binds on 0.56.2 (the shortcuts page
cross-check relies on it), how the file watcher behaves with your editor (a 2 s re-read is the backup), multi-monitor and fractional
scaling behaviour, fingerprint unlock, hypridle idle locking, and every optional tool you have not installed.

Against the original project's "definition of done":

| Item | State |
|---|---|
| Palette and consistency across bar and panels | one `Theme.qml`; artboard of every panel published |
| Bar shows real information; workspaces reflect Hyprland and switch | implemented; confirm on your screen |
| Launcher discovers installed apps; Rofi remains | implemented; Rofi untouched, plus an optional matching theme |
| App colours (kitty, gtk, qt, btop, yazi, zathura, nvim, spicetify) | rendered and syntax-checked for all 720 generated palettes with contrast checks, attach/detach round trip verified in a fake home to restore your original files byte for byte (one exception: a file that had no final newline gets one); Neovim 0.9.5 loaded 80 generated colourschemes and picked up a live colour change; **none of the other apps was run here**, see [docs/THEME.md](docs/THEME.md) |
| Firefox theme (CSS layer, start page, script layer) | install/undo/profile detection/colours run in a fake home with a fake `firefox`; CSS parsed with postcss; script logic run against a mock DOM. **Version 4 was run in a real Firefox 160.0.1** with real key presses (one-row tabs, detached launcher card, hide states, new tab page, start page) under a virtual-display test rig; **not reproduced:** your Hyprland session, real profile/add-ons, hover feel. See [docs/FIREFOX.md](docs/FIREFOX.md) |
| Wallpaper colours (matugen) | real matugen 4.2.0 run over 720 generated palettes (40 test images x 9 schemes x 2 accent modes) and checked by the same guard code as Theme.qml, the Hyprland loader and real Rofi; **QML behaviour and `hyprctl reload` not run on a real desktop by me**, see [docs/THEME.md](docs/THEME.md) |
| KURENAI Settings window (15 pages) | every page loads and the main controls work in an offscreen Qt Quick rig with stand-in Quickshell modules that run the real `kurenai-*` scripts in a throwaway home (20 + 15 scripted click/key checks; CLI suites 69 + 37 + 39); **never started under real Quickshell, Hyprland, matugen or awww by me**, see [docs/SETTINGS.md](docs/SETTINGS.md) |
| Launcher tabs: Apps, Run, Prime, Walls | written and syntax/logic-checked in a sandbox; **not run on a real desktop by me**, see [docs/LAUNCHER.md](docs/LAUNCHER.md) |
| Notifications, history, Do Not Disturb share one state | implemented (`NotificationStore.qml`) |
| Quick settings act on real devices, hide what is missing | implemented; per-control behaviour in the table in section 1 |
| Works on laptop screen and external monitor | designed for it; not tested here |
| Existing Hyprland settings intact | hooks are single marked lines; backups first |
| Starts, restarts, reloads without duplicates | `qs -n`, single-instance checks in `kurenai-ctl` |
| Missing optional tools degrade gracefully | yes, see section 1 |
| Install, validate, troubleshoot, rollback documented | this file and `docs/` |
