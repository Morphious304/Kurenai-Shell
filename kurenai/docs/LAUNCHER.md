# Launcher tabs and the Rofi theme

[Back to the README](../README.md)

Open the launcher with `SUPER + SPACE`. Under the search field there are four tabs.

| Tab | Does | Needs |
|---|---|---|
| **Apps** | your desktop entries, favourites first (as before) | nothing |
| **Run** | type a command, press Enter; recent commands and programs on your `PATH` are suggested | nothing |
| **Prime** | the same apps, started through `prime-run` so they render on the NVIDIA GPU | `prime-run` (Arch: package `nvidia-prime`) |
| **Walls** | thumbnails of every wallpaper under `~/Pictures/Wallpapers` (subfolders too); Enter sets one | `awww` (and its daemon running) |

Your search text stays when you switch tabs, so you can type `blender` in Apps and press `Tab` to run it on the NVIDIA GPU.

## Keys

| Keys | Does |
|---|---|
| `Tab` / `Shift+Tab`, `Ctrl+1` .. `Ctrl+4` | next / previous tab, jump to a tab |
| `SUPER + SHIFT + R`, `SUPER + SHIFT + P`, `SUPER + SHIFT + W` | open straight on Run, Prime, Walls (same key again closes it) |
| `Up/Down`, `Ctrl+N/P`, `Ctrl+J/K`, `PageUp/PageDown` | move |
| `Enter` | launch / run / set the wallpaper |
| `Shift+Enter` | Run: in your terminal. Walls: set it and keep the launcher open |
| `Ctrl+F` | favourite (Apps, Prime). Run: forget the highlighted history entry |
| `Ctrl+E` | Run: copy the highlighted row into the search field to edit it. Walls: big preview |
| `Esc` | close (in the Walls preview it closes the preview first) |

From a terminal: `qs -c kurenai ipc call launcher openTab run` (or `prime`, `walls`, `apps`), and `toggleTab` for the "same key again closes" behaviour.
The three `SUPER + SHIFT` keys are in `kurenai-binds.lua`; `SUPER + R` was avoided on purpose because Hyprland's example config uses it for the menu.

## Run tab

- Row 0 is exactly what you typed. Enter runs it as `sh -c "<text>"`, detached, so it keeps running if the shell restarts. Output is not shown.
- `Shift+Enter` runs it in your terminal (`Config.terminal`) and waits for Enter before closing, so you can read the output.
- Suggestions below row 0 are your history and, while you type the first word, programs found on `PATH`. Picking one runs exactly the row shown.
- Nothing is run through `sudo` for you. A command that needs it is yours to type.
- **History** is saved to `~/.local/share/kurenai/runhistory.json` (mode 600, last 50 commands). A command that **starts with a space is never saved**
  (like a shell's `ignorespace`), so type ` secret-thing` with a leading space. `Config.runHistory = false` saves nothing.
  `kurenai-ctl reset-launcher` wipes it.

## Prime tab

- Runs `prime-run <the app's command>`. The `%u`/`%F` placeholders of the desktop entry are dropped. `Terminal=true` apps open in your terminal; apps with a
  `Path=` start in that folder.
- The rows carry an `NV` marker. Favourites here are separate from the Apps tab.
- **Flatpak apps** run in a sandbox and may ignore `prime-run`; those rows say so. This tab only starts the app through `prime-run`: whether the app then uses
  the NVIDIA GPU depends on the app (check with `nvidia-smi` or your usual tool).
- No `prime-run`? The tab says so and how to install it. It checks again every time you open the tab.

## Walls tab

- **Finding images:** one `find` over every folder in `Config.wallpaperDirs` (default `~/Pictures/Wallpapers`), subfolders and symlinked folders included, for
  `Config.wallpaperExtensions` (jpg, jpeg, png, webp, gif, bmp, tga, tiff). It runs in the background when you open the tab and again after 60 s. A folder that is a
  symlink to another folder inside the same tree shows its images twice.
- **Fast with hundreds of files:** the grid only builds the cells on screen; a cell loads its thumbnail only after it has stayed visible for 90 ms
  (`Config.wallpaperThumbDelay`), and decodes it at about twice the cell size, not at full resolution. Flicking quickly through a big folder decodes almost nothing.
- **Animated GIFs:** the grid shows the first frame with a `GIF` badge. The big preview (`Ctrl+E`) plays the animation (`Config.wallpaperAnimatePreview`).
- **Preview never changes your wallpaper.** Moving the selection only moves the highlight. `Enter` sets it with
  `awww img -t random <file>`; the transition is `Config.wallpaperTransition` (any of awww's documented values: none simple fade left right top bottom wipe wave grow center any outer random)
  and `Config.wallpaperTransitionDuration` (seconds, 0 = awww's default). A mistyped transition falls back to `random`.
- The wallpaper that is on screen now (`awww query -j`) is ticked and pre-selected. The lock screen reads the same call, so its background follows.
- awww remembers the wallpaper across restarts in its own cache (`~/.cache/awww`), so KURENAI saves nothing for this.
- A big animated GIF can take a few seconds the first time awww processes it; the line under the grid says "Applying..." and then "Wallpaper set", or why it failed
  (for example the daemon is not running: `awww-daemon`).
- On several monitors the image goes to all of them (awww's default when no output is named).

## Settings (`Config.qml`)

| Setting | Default |
|---|---|
| `runHistory`, `runHistoryMax` | `true`, `50` |
| `primeCommand` | `"prime-run"` |
| `wallpaperDirs` | `["~/Pictures/Wallpapers"]` |
| `wallpaperExtensions` | jpg jpeg png webp gif bmp tga tiff |
| `wallpaperTransition`, `wallpaperTransitionDuration` | `"random"`, `0` |
| `wallpaperColumns`, `wallpaperVisibleRows` | `3`, `3` |
| `wallpaperThumbDelay` | `90` ms |
| `wallpaperAnimatePreview` | `true` |

## The Rofi theme

`rofi/kurenai.rasi` is installed to `~/.config/rofi/themes/kurenai.rasi`. It uses the shell's colours and fonts (charcoal panel, bone text, vermilion accents, the 紅 seal).

- The Rofi fallback keys already use it when the file exists, and plain Rofi otherwise.
- Try it once: `rofi -show drun -show-icons -theme kurenai`
- Make it Rofi's default: `kurenai-ctl rofi-theme` prints the single line (`@theme "kurenai"`) to put at the top of `~/.config/rofi/config.rasi`. Nothing edits your Rofi config.
- Undo: delete that line (and the file, if you like).
- Rofi cannot draw the shell's docked shape or blur, so it matches in colour, type and spacing only.

## What is verified

Checked in a sandbox: QML syntax (`qmllint`), the JavaScript logic of the Run, Prime and Walls tabs (24 checks), the `find` / `sh -c` commands, `bash -n` on the scripts,
the installer over an older install in a throw-away home folder, and the theme file with a real Rofi 1.7.5 (it parses and renders; your Arch Rofi may differ slightly).
Documented by the awww man pages: `awww img [OPTIONS] <path>`, `-t` / `--transition-type` with `random`, `--transition-duration`, `awww query -j`.

**Not run on your machine:** the tabs themselves (there is no Quickshell in the sandbox), `prime-run` (its package and behaviour are from memory, not re-verified),
the list of image formats awww accepts (the man page does not give it, so the extension list is a reasonable guess), and how smooth the Walls grid is with your biggest folders.
If something is off, `kurenai-ctl debug` shows the first QML error.
