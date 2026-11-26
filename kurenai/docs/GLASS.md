# Glass (the hyprglass plugin)

[Back to the README](../README.md)

Optional. KURENAI works without it. The plugin is [hyprglass](https://github.com/hyprnux/hyprglass): blur, edge bend, a thin edge line and grain behind translucent windows and behind the shell's own bar and panels.

## What each side does

| Part | Who does it |
|---|---|
| Builds and installs the plugin | you, once, with `hyprpm` (as your own user) |
| Loads it at EVERY login and applies the settings | `kurenai-glass.lua`, switched on by `kurenai-ctl enable-glass` |
| Makes the bar and panels see-through | `kurenai-conf set glassOpacity 72` (Settings > Bar and panels > Glass opacity) |
| Makes your windows see-through | the app itself (for kitty: `background_opacity 0.8` in kitty.conf) |

Glass only shows where something is translucent. A solid window has nothing to look through.

## Set up (4 steps)

1. Install the plugin once:
   ```
   hyprpm add https://github.com/hyprnux/hyprglass
   hyprpm enable hyprglass
   ```
   hyprpm builds it against YOUR Hyprland (it needs the Hyprland headers; `hyprpm update` fetches them). It stores the file in `/var/cache/hyprpm/<you>/HyprGlass/hyprglass.so`.
2. Remove the old glass block you pasted into `hyprland.lua` (the `if hl.plugin.hyprglass then ... end` part) and any `hyprpm reload` / `hl.plugin.load` line. KURENAI's module replaces them. Two loaders = the second copy is refused ("Paused: already loaded").
3. `kurenai-ctl enable-glass`
4. `kurenai-conf set glassOpacity 72` (optional: only the shell)

Check: `kurenai-ctl glass-status`. Undo: `kurenai-ctl disable-glass` and `kurenai-conf reset glassOpacity`.

## Why it did not start by itself (the usual causes)

- `hyprpm enable` only marks the plugin as wanted and loads it into the session you are in. Nothing loads it at the next login unless something runs `hyprpm reload` or the config loads it.
- Even with `hyprpm reload` at start, the plugin arrives AFTER your config was read, so a block guarded by `if hl.plugin.hyprglass then` is skipped. That is why the module loads the plugin itself, first, and configures it second (Hyprland then reads the config once more, which is expected).
- After a Hyprland update the plugin can be "Paused: built for Hyprland 0.57, running 0.58". `hyprpm update`, then log out and in. `hyprctl plugin list` shows the reason.

## The two knobs in kurenai-glass.lua

- `PROFILE = "full"` or `"lite"`. Lite: no grain, no edge line, less bend, 2 blur passes, no glass on the shell (windows only). Use it on battery or if the GPU struggles.
- `SO = "/path/to/hyprglass.so"` if you keep the file somewhere unusual. It also looks in `~/.local/share/hyprglass/hyprglass.so`, and in `$KURENAI_HYPRGLASS_SO`.

The file is yours to edit; the installer never overwrites a changed copy (it saves the new one as `.new`).

## What is configured

- Charcoal glass (`#242424` at about 22%), dark theme, your `clear` and `contrasted` presets kept as they were, one new preset `kurenai-panel` for the shell.
- The shell's layers by their exact names: `kurenai-bar` (full-width strip), the ten panel and popup layers (`contour` mode, so the CARD gets its own edge and not the whole transparent screen layer), `kurenai-osd` excluded.
- Glass off for `mpv` and for fullscreen windows.
- The layers you had listed (`waybar`, `swaync`, `quickshell:bezel`, `debug-panel`) were the plugin README's examples and are not part of KURENAI; they are not in the module. Your old block is in the backup `kurenai-ctl enable-glass` makes.

## Cost

Blur and refraction run on the GPU every time something moves behind the glass. On a hybrid laptop Hyprland usually draws on the integrated GPU (I have not checked which one yours uses). If it gets warm or sluggish: `PROFILE = "lite"`, or `kurenai-ctl disable-glass`.

## Verified, and not

Verified here: every key the module passes to the plugin exists in the plugin's source (checked against its option list, with a deliberate typo as a control); the module loads in the real Hyprland 0.57.0 Lua engine (`hl.plugin.load` and `hl.window_rule` exist) and `--verify-config` accepts it, with and without the plugin file present; the hook, status, disable and rollback behave in a throwaway home; the shell renders in a real Quickshell with the bar and cards translucent at 70% and byte-identical to before at 100%.

NOT verified: the plugin itself was never run, because this sandbox has no GPU and Hyprland cannot start here. So I have not seen the glass, and the numbers (tint, bevel, grain, blur) are starting points chosen from the plugin's documentation, not tuned by eye. Panel text contrast under glass depends on your wallpaper: the built-in 95% panels were designed for 10:1, a 72% panel over a bright wallpaper is lower. If text gets hard to read, raise `glassOpacity` first.
