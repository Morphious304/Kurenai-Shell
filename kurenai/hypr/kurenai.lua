-- ~/.config/hypr/kurenai.lua
-- KURENAI: Hyprland appearance module (Hyprland >= 0.55, Lua config).
--
-- Appearance only. No binds, monitors, input, env or autostart live here.
-- Loaded as the LAST thing in hyprland.lua so these values win over earlier ones.
-- Each section is wrapped so one bad key cannot stop the rest of your config.

local ENABLE_BLUR  = false  -- optional, costs GPU (hybrid Intel/NVIDIA laptop: leave off first)
local FLOAT_ACCENT = true   -- floating windows get a teal frame so tiled vs floating reads at a glance

local function try(name, fn)
  local ok, err = pcall(fn)
  if not ok then print("[kurenai] section '" .. name .. "' failed: " .. tostring(err)) end
end

-- palette (Hyprland wants rgba(RRGGBBAA))
local c = {
  vermilion = "rgba(F04436ff)",
  deep      = "rgba(B8281Eff)",
  raised    = "rgba(3A3535ff)",
  teal      = "rgba(70A6A0ff)",
}

-- 1. Borders, gaps, rounding, shadow, opacity ---------------------------------
try("appearance", function()
  hl.config({
    general = {
      border_size = 2,
      gaps_in     = 4,
      gaps_out    = 8,
      col = {
        -- focus = vermilion (deepening toward one corner); unfocused = quiet raised surface
        active_border   = { colors = { c.vermilion, c.deep }, angle = 45 },
        inactive_border = c.raised,
      },
    },
    decoration = {
      rounding         = 10,
      rounding_power   = 2,
      active_opacity   = 1.0,
      inactive_opacity = 0.96,
      shadow = {
        enabled        = true,
        range          = 16,
        render_power   = 3,
        color          = 0x66000000,  -- 0xAARRGGBB
        color_inactive = 0x33000000,
      },
      blur = { enabled = ENABLE_BLUR },
    },
  })
end)

-- 2. Empty-desktop colour (no flash of the default background) ------------------
try("misc", function()
  hl.config({
    misc = {
      background_color      = 0xff242424,
      disable_hyprland_logo = true,
    },
  })
end)

-- 3. Motion: short, ease-out, state changes only --------------------------------
-- Speed unit is deciseconds: 2.2 = ~220 ms, 1.6 = ~160 ms.
-- If `hyprctl configerrors` complains about `bezier`, rename it to `curve` (the wiki shows both).
try("animations", function()
  hl.curve("kurenaiOut",  { type = "bezier", points = { {0.16, 1.0},  {0.30, 1.0} } })
  hl.curve("kurenaiSoft", { type = "bezier", points = { {0.25, 0.10}, {0.25, 1.0} } })

  hl.animation({ leaf = "global",     enabled = true, speed = 2.2, bezier = "kurenaiOut" })
  hl.animation({ leaf = "windows",    enabled = true, speed = 2.2, bezier = "kurenaiOut",  style = "popin 94%" })
  hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "kurenaiSoft", style = "popin 94%" })
  hl.animation({ leaf = "fade",       enabled = true, speed = 1.6, bezier = "kurenaiSoft" })
  hl.animation({ leaf = "border",     enabled = true, speed = 2.2, bezier = "kurenaiSoft" })
  hl.animation({ leaf = "layers",     enabled = true, speed = 1.6, bezier = "kurenaiOut",  style = "fade" })
  hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "kurenaiOut",  style = "slidefade 12%" })
end)

-- 4. Floating windows: teal frame ------------------------------------------------
-- NOTE: `border_color` as a window-rule effect is not confirmed in the Lua wiki for 0.56.
-- If it errors you will see "[kurenai] section 'floating' failed" and nothing else breaks.
if FLOAT_ACCENT then
  try("floating", function()
    hl.window_rule({
      name         = "kurenai-floating-frame",
      match        = { float = true },
      border_color = c.teal,
    })
  end)
end

-- 5. Optional blur for KURENAI shell surfaces (off by default) ------------------
-- NOTE: `ignore_alpha` as a layer-rule effect is carried over from the hyprlang layerrule docs.
if ENABLE_BLUR then
  try("blur", function()
    hl.config({ decoration = { blur = { size = 4, passes = 2, noise = 0.02 } } })
    hl.layer_rule({ match = { namespace = "kurenai-.*" }, blur = true, ignore_alpha = 0.2 })
  end)
end
