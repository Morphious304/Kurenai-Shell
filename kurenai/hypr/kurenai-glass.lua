-- ~/.config/hypr/kurenai-glass.lua
-- Optional "liquid glass" look for Hyprland through the hyprglass plugin (https://github.com/hyprnux/hyprglass).
-- OPT-IN: `kurenai-ctl enable-glass` (undo: `kurenai-ctl disable-glass`).
--
-- This one file does two jobs, in this order:
--   1. LOADS the plugin. hyprpm builds it into /var/cache/hyprpm/<you>/HyprGlass/hyprglass.so, but `hyprpm enable`
--      only turns it on for the running session. Loading it from the config is what makes it come back at every login,
--      and it makes the settings below apply on the FIRST pass (a plugin loaded later by `hyprpm reload` arrives
--      after this file was already read, so the `if hl.plugin.hyprglass` block below would be skipped).
--      (When a config loads a plugin, Hyprland reads the config one more time during start-up. That is expected.)
--      Do not ALSO run `hyprpm reload` at start-up: a second copy is refused ("Paused: already loaded").
--   2. CONFIGURES it. Every key below is one hyprglass documents; `hyprctl configerrors` lists any it rejects.
--
-- If the plugin is missing, was built for another Hyprland version, or anything here fails, you only lose the glass:
-- the rest of your config is untouched.

-- ---- the two knobs ------------------------------------------------------------------------------------------------
local PROFILE = "full"   -- "full": refraction, bevel, grain, glass on the shell.   "lite": lighter on the GPU (hybrid laptop).
local SO      = nil      -- full path to hyprglass.so if yours lives somewhere unusual, e.g. "/home/you/hyprglass/hyprglass.so"

-- ---- 1. load the plugin ---------------------------------------------------------------------------------------------
local function readable(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

local function find_so()
  local c = {}
  if SO and SO ~= "" then c[#c + 1] = SO end
  local env = os.getenv("KURENAI_HYPRGLASS_SO")
  if env and env ~= "" then c[#c + 1] = env end
  local user = os.getenv("USER") or os.getenv("LOGNAME")
  if user and user ~= "" then
    -- hyprpm names the folder after the repository name in hyprglass' hyprpm.toml ("HyprGlass")
    c[#c + 1] = "/var/cache/hyprpm/" .. user .. "/HyprGlass/hyprglass.so"
    c[#c + 1] = "/var/cache/hyprpm/" .. user .. "/hyprglass/hyprglass.so"
  end
  local home = os.getenv("HOME") or ""
  c[#c + 1] = home .. "/.local/share/hyprglass/hyprglass.so"      -- a manual build or a downloaded release, copied here
  for _, p in ipairs(c) do if readable(p) then return p end end
  return nil
end

if hl.plugin and hl.plugin.load and not hl.plugin.hyprglass then
  local so = find_so()
  if not so then
    print("[kurenai] hyprglass.so not found. Install it once: hyprpm add https://github.com/hyprnux/hyprglass && hyprpm enable hyprglass  (see: kurenai-ctl glass-status)")
  else
    local ok, err = pcall(hl.plugin.load, so)
    if not ok then print("[kurenai] hyprglass could not be loaded from " .. so .. ": " .. tostring(err)) end
  end
end

-- ---- 2. configure it -------------------------------------------------------------------------------------------------
-- hl.plugin.hyprglass exists only once the plugin is loaded (and not "paused" by a Hyprland version mismatch).
if not (hl.plugin and hl.plugin.hyprglass) then return end
local hg   = hl.plugin.hyprglass
local lite = (PROFILE == "lite")

-- Colours are 0xRRGGBBAA (alpha LAST, unlike Hyprland's own 0xAARRGGBB). KURENAI: charcoal glass, bone-coloured edge light.
hg.config({
  default_theme  = "dark",
  default_preset = "clear",

  tint_color = 0x24242438,                       -- charcoal #242424 at ~22% strength (raise the last two digits for more tint)
  brightness = 0.9,
  dark  = { brightness = 0.82 },
  light = { adaptive_boost = 0.5 },

  -- finish: a fine grain and a thin bone-coloured edge line. Both off in the lite profile.
  noise_strength = lite and 0.0 or 0.06,
  bevel_strength = lite and 0.0 or 0.30,
  bevel_size     = 2,
  bevel_color    = 0xF4E8BEA0,

  -- cost control
  blur_iterations      = lite and 2 or 3,
  refraction_strength  = lite and 0.2 or 0.5,
  chromatic_aberration = lite and 0.0 or 0.3,

  windows = { live_resample_fps = lite and 15 or 30 },

  -- the shell's own surfaces (bar, panels, notifications). They only show glass where they are translucent:
  -- kurenai-conf set glassOpacity 70   (100 = solid, the default)
  layers = {
    enabled           = not lite,
    mask_threshold    = 0.15,
    live_resample_fps = 20,
  },
})

-- Presets. "clear" is yours from before (it extends the built-in one), "contrasted" too; "kurenai-panel" is new.
hg.preset("clear", {
  glass_opacity = 0.9,
  blur_strength = 1.0,
  dark  = { brightness = 0.7 },
  light = { brightness = 1.2 },
})

hg.preset("contrasted", {
  inherits = "high_contrast",
  contrast = 1.2,
  adaptive_dim = 1.5,
  dark = { tint_color = 0x02142aa9 },
})

hg.preset("kurenai-panel", {                       -- calmer than windows: text sits on these
  inherits = "subtle",
  blur_strength = 1.6,
  glass_opacity = 0.95,
  dark = { brightness = 0.8 },
})

-- Layer namespaces are matched EXACTLY (they are the names the shell gives its surfaces; `hyprctl layers` lists them).
-- Listing one switches glass on for it and OFF for every layer you do not list.
if not lite then
  -- the bar is one full-width strip: glass where it is visible
  hg.layer("kurenai-bar", { preset = "kurenai-panel", mask_mode = "alpha" })

  -- panels live inside a full-screen transparent layer: "contour" gives the CARD its own edge, not the whole screen
  for _, ns in ipairs({
    "kurenai-quick-settings", "kurenai-notification-center", "kurenai-calendar", "kurenai-media",
    "kurenai-clipboard", "kurenai-launcher", "kurenai-power", "kurenai-shortcuts", "kurenai-sysmon",
    "kurenai-notifications",
  }) do
    hg.layer(ns, { preset = "kurenai-panel", mask_mode = "contour" })
  end

  -- the volume / brightness pill is small and brief: no glass (saves a blur pass every time it appears)
  hg.layer("kurenai-osd", { exclude = true })
end

-- Per-window tags (hyprglass documents these). Video and fullscreen: no glass, nothing to see through anyway.
hl.window_rule({ match = { class = "mpv" },        tag = "+hyprglass_disabled" })
hl.window_rule({ match = { fullscreen = true },    tag = "+hyprglass_disabled" })
