# Wallpaper colours (matugen)

[Back to the README](../README.md)

When this is on, every wallpaper you set recolours the shell, the launcher, Quick Settings, the lock screen (including the
petals in the password field), the Rofi theme and the Hyprland window borders. It is **off by default**; with it off nothing
changes, and `kurenai-ctl theme off` always goes back to the original vermilion-and-charcoal colours.

Needs `matugen` (Arch: `sudo pacman -S matugen`). Written and tested against matugen **4.2.0**; 2.4.1 also works.

## Turn it on

1. Install matugen.
2. `Quick Settings > Wallpaper colours`, or `kurenai-ctl theme on`. It colours the wallpaper awww is showing right now.
3. Set a wallpaper from the launcher's **Walls** tab: the colours follow shortly after the wallpaper is applied (the shell fades between them).

## What follows the wallpaper

| Part | How | When it updates |
|---|---|---|
| Bar, panels, launcher, notifications, Quick Settings | `~/.local/share/kurenai/palette.json`, read by `Theme.qml` | live, with a fade |
| Lock screen: glow, password pill, side column, petals, pattern | the same file, read by the lock process | next time the lock screen starts or the file changes |
| Rofi (`kurenai.rasi`) | regenerated at `~/.config/rofi/themes/kurenai.rasi` | next time Rofi opens |
| Hyprland borders and empty-desktop colour | `~/.config/hypr/kurenai-colors.lua`, read by `kurenai.lua`; applied with `hyprctl reload` | on each change |
| Warning amber | fixed on purpose (a warning must look like a warning) | never |

Apps outside the shell (kitty, GTK, Qt, btop, yazi, zathura, Neovim, Spicetify, Firefox) are separate opt-in extras: see "App colours" below (Firefox has its own page, [FIREFOX.md](FIREFOX.md)). Icons are not touched.

## Commands

| Command | Does |
|---|---|
| `kurenai-ctl theme` (or `theme status`) | state, scheme, which image the colours came from |
| `kurenai-ctl theme on` / `off` | follow the wallpaper / back to built-in colours (every part, instantly) |
| `kurenai-ctl theme sync` | recolour from the wallpaper awww shows now |
| `kurenai-ctl theme type <name>` or `next` | `tonal-spot` (default) `vibrant` `fidelity` `expressive` `neutral` `monochrome` `content` `fruit-salad` `rainbow` |
| `kurenai-ctl theme contrast N` | `-1` .. `1`, `0` = standard |
| `kurenai-ctl theme accent wallpaper\|vermilion` | `vermilion` keeps the hanko-red accent; only the greys/neutrals follow the wallpaper |
| `kurenai-ctl theme hypr on\|off`, `theme rofi on\|off` | stop Hyprland borders / Rofi from following |
| `kurenai-ctl theme reset` | built-in colours everywhere and forget the settings |
| `kurenai-ctl theme-apply [--auto] <image>` | colours from one specific image |
| `qs -c kurenai ipc call theme toggle\|sync\|next` | the same from a key |

Settings live in `~/.local/share/kurenai/theme.conf` (plain `key=value`).

## How it works (so you can fix it)

1. `kurenai-ctl theme-apply` runs `matugen image <file> -m dark -t scheme-<type>` with a config it writes itself
   (`~/.local/share/kurenai/matugen.toml`); your own `~/.config/matugen` is never read or changed.
2. Three templates in `~/.local/share/kurenai/matugen/` are rendered into `~/.local/share/kurenai/next/`, sanity-checked, and only
   then copied into place. If anything fails, the colours you already have stay.
3. `Theme.qml` re-checks the palette before using it: every colour well-formed and every text/background pair readable
   (body text 7:1, secondary 4.5:1). Two colours are adjusted instead of rejected (the "deep" accent is darkened, accent text is
   lightened when needed). If a palette still fails, the built-in colours are used and a line is logged.
4. Colour roles: `bg` = surface container, `surface` = container high, `raised` = container highest, `text` = on-surface,
   `accent` = primary, `teal` = secondary, `rose` = tertiary.

Animated GIF wallpapers: matugen reads the first frame.

## Known limits

- Dark mode only.
- A very low-contrast wallpaper (flat grey, near-black) gives a muted, grey UI. That is correct matugen behaviour; try
  `theme type vibrant` or `theme accent vermilion`.
- Hyprland re-reads its config on every change (`hyprctl reload`), which can flash for a frame; switch off with `theme hypr off`.
- matugen 4.x needs `--prefer` when there is no terminal and 2.x rejects it; `kurenai-ctl` asks matugen which it supports.

## App colours (kitty, GTK, Qt, btop, yazi, zathura, Neovim, Spicetify, Firefox)

The same colours can follow into other apps. Each app is **off until you attach it**, one at a time:

```
kurenai-ctl theme extras              what exists, what is attached, what is missing
kurenai-ctl theme extra kitty on      attach (prints exactly what it changed in that app's own config)
kurenai-ctl theme extra kitty off     detach: your own settings come back, generated files are removed
kurenai-ctl theme extras follow off   apps keep their last colours when the wallpaper changes (Quick Settings > App colours)
kurenai-ctl theme extras reset        detach everything
```

Attached apps are filled from the same colours as the shell (`palette.json`, or the built-in KURENAI colours while wallpaper
colours are off), so they always match it. `theme off` puts built-in KURENAI colours into the attached apps; `theme extra NAME off`
returns the app to *your* own look instead. Before any change to a config file of yours, a copy goes to
`~/.local/share/kurenai/extras/backup/`. Changes inside your files are one clearly marked block
(`>>> KURENAI colours ... <<<`) or one setting; `off` removes exactly that (a file of yours that had no final newline ends up with one).

| App | Generated file(s) | What `on` changes in your config | Picks up a change |
|---|---|---|---|
| **kitty** | `~/.config/kitty/kurenai-colors.conf` (colours only: your opacity, blur and fonts stay yours; the 16 ANSI colours keep red=red, green=green) | one block `include kurenai-colors.conf` at the end of `kitty.conf` (last setting wins over your own theme include) | open windows, by themselves (SIGUSR1) |
| **GTK 3/4** | a managed block in `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css` (libadwaita colour names) | sets the GTK theme to `adw-gtk3-dark` and colour scheme to dark (your old theme is saved and restored by `off`); needs the `adw-gtk-theme` package | new windows; GTK3 windows are nudged to reload; GTK4 windows that are open need a restart |
| **Qt** | `~/.config/qt6ct/colors/kurenai.conf` and `qt5ct/colors/kurenai.conf` | in `qt6ct.conf` / `qt5ct.conf`: `custom_palette=true`, `color_scheme_path=...` (old values saved); writes `~/.local/share/kurenai/qt-env` so `kurenai.lua` sets `QT_QPA_PLATFORMTHEME=qt6ct` (only if you have not set it yourself) | restart the Qt app |
| **btop** | `~/.config/btop/themes/kurenai.theme` (background transparent) | `color_theme = "kurenai"` in `btop.conf` (old value saved) | running btop, by itself (SIGUSR2) |
| **yazi** | `~/.config/yazi/flavors/kurenai.yazi/flavor.toml` | a managed `[flavor]` block in `theme.toml` (left alone, with a note, if you already have a `[flavor]` section) | restart yazi |
| **zathura** | `~/.config/zathura/kurenai-colors` | a managed `include kurenai-colors` block in `zathurarc` | new windows |
| **Neovim** | `~/.config/nvim/colors/kurenai.lua` and `plugin/kurenai-watch.lua` | nothing in your config. You choose the scheme: `vim.cmd.colorscheme("kurenai")`. The watcher reloads it live while it is active. Transparent background by default; `vim.g.kurenai_transparent = false` for a solid one | running Neovim, while `kurenai` is the active scheme |
| **Spicetify** | `~/.config/spicetify/Themes/kurenai/color.ini` (+ an empty `user.css` that is never overwritten) | nothing. You run `spicetify config current_theme kurenai` and, with Spotify closed, `spicetify apply` yourself, because applying patches Spotify | after `spicetify apply` |
| **Firefox** | `chrome/kurenai/*.css` in your Firefox profile and a start page in `~/.local/share/kurenai/firefox/` | a marked `@import` block at the top of `userChrome.css` and `userContent.css`, one marked block in `user.js`; details, undo and the unverified list in [FIREFOX.md](FIREFOX.md) | **after a Firefox restart** |

### Qt: two things to know
- Qt only reads the colour scheme if `QT_QPA_PLATFORMTHEME` is set. `kurenai.lua` sets it to `qt6ct` for apps started after the next Hyprland config load; a variable you set yourself wins. One variable can only name one plugin, so Qt5 apps (which need `qt5ct`) stay unthemed.
- If qt6ct/qt5ct uses the **Kvantum** style, Kvantum's own theme supplies the colours and ignores this scheme. Use the Fusion style in qt6ct to see the wallpaper colours.

### Flatpak apps
Flatpak apps cannot see `~/.config/gtk-4.0` or `gtk-3.0` by default. If you want them themed, these two commands are yours to run (they change Flatpak permissions, so they are never run automatically):
```
flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro
flatpak install flathub org.gtk.Gtk3theme.adw-gtk3-dark
```

### Safety
- If the wallpaper's colours would be hard to read in a terminal or editor (text under 7:1, ANSI colours under 4.5:1 on the background), the app files are **not** updated and the previous ones stay; the reason is printed.
- Nothing is written outside the paths in the table. Spicetify and Neovim configs are never edited.
