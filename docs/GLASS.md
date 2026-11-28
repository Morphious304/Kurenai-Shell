# Glass (the hyprglass plugin)

[Back to the README](../README.md)

Optional. KURENAI works without it. The plugin is [hyprglass](https://github.com/hyprnux/hyprglass): blur, edge bend, a thin edge line and grain behind translucent windows and behind the shell's own bar and panels.

## If it froze your machine (read this first)

The first version of `kurenai-glass.lua` loaded the plugin WHILE Hyprland was still reading its config. hyprglass documents that route as able to stop Hyprland from ever finishing its start ("Hyprland never finishes starting with the plugin in hyprland.lua"). Loading the same file from a running session (`hyprpm reload`) is the route that worked for you, so the current version does that.

**Get your desktop back (no sudo, nothing is deleted):**
1. Open a TTY: `Ctrl+Alt+F3` at the login screen (SDDM) BEFORE you log in. If the machine is frozen solid, hold the power button, boot, and do this first.
   If you cannot reach a TTY at all: at the boot menu press `e`, add `systemd.unit=multi-user.target` to the `linux` line, boot, log in on the text console.
2. Log in there and run: `kurenai-ctl disable-glass`
   (If `kurenai-ctl` is not on PATH: `~/.local/bin/kurenai-ctl disable-glass`.) It removes ONE line from `~/.config/hypr/hyprland.lua` and keeps a copy next to it.
   Without kurenai-ctl: `sed -i '/KURENAI-GLASS-HOOK/d' ~/.config/hypr/hyprland.lua`.
3. Log in to the desktop as usual.

**Then update:** install the new KURENAI (`./install.sh`). It REPLACES the old `kurenai-glass.lua` on purpose (your old copy goes to `~/.local/share/kurenai/replaced-*/kurenai-glass.lua.v1`; a `PROFILE = "lite"` choice is carried over). Do not keep the old file.

**Confirm what happened (read-only, run from a TTY or the desktop):**
- `kurenai-ctl glass-status` is the one-stop report: hook, loader mode, safety state, last lines of the start log, hyprpm, running plugin, config errors.
- Did the whole machine freeze, or only Hyprland? If Ctrl+Alt+F3 still gave a login prompt, only Hyprland hung. If the keyboard was dead too (Caps Lock light does not toggle), it is the GPU or kernel: look at `journalctl -b -1 -k --no-pager | grep -iE "nvidia|NVRM|Xid|i915|drm|hang|timeout"` (`-b -1` = the previous boot).
- The end of the previous boot: `journalctl -b -1 --no-pager | tail -80`.
- Hyprland's own crash report and log, if it got that far: `ls -t ~/.cache/hyprland | head`, then read the newest file.
- Anything in your OWN config that waits for a command at the top level (the plugin documents this as the usual cause): `grep -nE 'popen|os\.execute|hyprctl|hyprpm|plugin' ~/.config/hypr/*.lua` (lines inside `hl.on("hyprland.start", ...)` are fine; a bare line at the top is not).
- `hyprpm list` and `hyprctl version`: the plugin must be built for the Hyprland you run (`hyprpm update` after a Hyprland update).

## What each side does

| Part | Who does it |
|---|---|
| Builds and installs the plugin | you, once, with `hyprpm` (as your own user) |
| Loads it at every login | `kurenai-glass.lua` starts `~/.local/bin/kurenai-glass-start` when Hyprland is READY (the `hyprland.start` event) |
| Applies the glass settings | `kurenai-glass.lua`, once the plugin exists (the start script re-reads the config) |
| Makes the bar and panels see-through | `kurenai-conf set glassOpacity 72` (Settings > Bar and panels > Glass opacity) |
| Makes your windows see-through | the app itself (for kitty: `background_opacity 0.8` in kitty.conf) |

Glass only shows where something is translucent. A solid window has nothing to look through.

## Set up

1. Install the plugin once: `hyprpm add https://github.com/hyprnux/hyprglass` then `hyprpm enable hyprglass`.
2. Remove the old glass block you pasted into `hyprland.lua` (the `if hl.plugin.hyprglass then ... end` part) and any `hyprpm reload` / `hl.plugin.load` line. KURENAI's module replaces them. Two loaders = the second copy is refused ("Paused: already loaded").
3. `kurenai-ctl enable-glass`, then log out and in. (It loads at the next login; to try it now without logging out, run `hyprpm reload -n` once yourself.)
4. Optional: `kurenai-conf set glassOpacity 72` (shell only).

Undo: `kurenai-ctl disable-glass` and `kurenai-conf reset glassOpacity`.

## The safety net

`kurenai-glass-start` writes `~/.local/state/kurenai/glass.starting` first thing and deletes it after 30 s of the session still being alive. If the machine freezes or Hyprland dies inside those 30 s, the stamp is left behind, and the NEXT start:
- writes `glass.disabled`, loads nothing, shows a notification, and `kurenai-glass.lua` skips the whole glass config;
- stays off until you run `kurenai-ctl glass-reset` (after you have found out why: `kurenai-ctl glass-status` shows the log).

Limits: a freeze later than 30 s after login is not caught (use `disable-glass` from a TTY). A hard power-off within 30 s of logging in also trips it; `glass-reset` undoes that. The log is `~/.local/state/kurenai/glass-start.log`.

## Knobs in kurenai-glass.lua

- `PROFILE = "full"` or `"lite"`. Lite: no grain, no edge line, less bend, 2 blur passes, no glass on the shell (windows only). Use it on battery or if the GPU struggles.
- `LOADER = "start"` (default) | `"none"` (you load it yourself, e.g. `hyprpm reload -n` by hand) | `"config"` (the old route, can stop Hyprland from starting).
- `SO = "/path/to/hyprglass.so"`, only for `LOADER = "config"`.

The file is yours to edit; the installer never overwrites an edited version 2 file (it saves the new one as `.new`).

## What is configured

- Charcoal glass (`#242424` at about 22%), dark theme, your `clear` and `contrasted` presets kept as they were, one new preset `kurenai-panel` for the shell.
- The shell's layers by their exact names: `kurenai-bar` (full-width strip), the ten panel and popup layers (`contour` mode, so the CARD gets its own edge and not the whole transparent screen layer), `kurenai-osd` excluded.
- Glass off for `mpv` and for fullscreen windows.
- The layers you had listed (`waybar`, `swaync`, `quickshell:bezel`, `debug-panel`) were the plugin README's examples and are not part of KURENAI; they are not in the module. Your old block is in the backup `kurenai-ctl enable-glass` makes.

## Cost

Blur and refraction run on the GPU every time something moves behind the glass. On a hybrid laptop Hyprland usually draws on the integrated GPU (check which one yours uses). If it gets warm or sluggish: `PROFILE = "lite"`, or `kurenai-ctl disable-glass`.

## Verified, and not

Verified here: every key the module passes to the plugin exists in the plugin's source (checked against its option list, with a deliberate typo as a control); the module loads in the real Hyprland 0.57.0 Lua engine and `--verify-config` accepts it in all three loader modes and with the safety switch present; the start script, the stale-stamp trip, the SIGTERM and hard-kill cases, the hook, status, disable, reset and rollback behave in a throwaway home with a fake `hyprctl` and `hyprpm`; the upgrade from the first version replaces it and keeps a backup; the shell renders in a real Quickshell with the bar and cards translucent at 70% and unchanged at 100%.

NOT verified: the plugin itself was never run, because this sandbox has no GPU and Hyprland cannot start here. I have not reproduced your freeze. That loading during the config read is the cause is an inference from the plugin's documentation plus your observation that `hyprpm reload` works; it is not confirmed. If the new version also freezes, the safety net switches glass off at the next start and the log says how far it got: send me `kurenai-ctl glass-status` and the `journalctl` lines above. The look (tint, bevel, grain, blur numbers) is untuned.
