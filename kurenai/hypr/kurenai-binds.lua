-- ~/.config/hypr/kurenai-binds.lua
-- KURENAI keybinds. OPT-IN: nothing loads this until you run `kurenai-ctl enable-binds`,
-- and `kurenai-ctl binds-check` shows any clash with your existing binds first.
--
-- Each entry is { chord, shell command }. Edit the chords here; keep one entry per line,
-- starting with `{ "` (kurenai-ctl reads this file to run the conflict check).
--
-- NOTE: there is deliberately NO bind for Ctrl+X / Ctrl+C / Ctrl+V. Those keys already work in every application, and a
-- compositor-level bind would swallow them: copy/paste would stop working and Ctrl+C would no longer interrupt programs
-- in the terminal. The clipboard history records whatever those keys copy, with no help from a bind.
--
-- The launcher bind falls back to Rofi if the Quickshell IPC call fails, so you are never
-- left without a launcher. (Assumes `qs ipc call` exits non-zero when no shell is running;
-- verify once with the shell stopped: qs -c kurenai ipc call launcher toggle; echo $?)

local QS   = "qs -c kurenai ipc call "
-- The Rofi fallback uses the KURENAI Rofi theme when it is installed (kurenai-ctl rofi-theme), plain Rofi otherwise.
-- (An if/else, not `||`: cancelling Rofi exits non-zero and must not open a second one.)
-- Change it to your usual Rofi invocation if you like.
local ROFI = [[sh -c 'if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes/kurenai.rasi" ]; then exec rofi -show drun -show-icons -theme kurenai; else exec rofi -show drun; fi']]

local binds = {
  { "SUPER + SPACE",         QS .. "launcher toggle || " .. ROFI },
  { "SUPER + SHIFT + SPACE", "command -v rofi >/dev/null && " .. ROFI },
  -- launcher tabs: the same key again closes it; from another tab it just switches. (Tab / Ctrl+1..4 also switch inside the launcher.)
  { "SUPER + SHIFT + R",     QS .. "launcher toggleTab run" },          -- Run: type a command
  { "SUPER + SHIFT + P",     QS .. "launcher toggleTab prime" },        -- Prime: start an app on the NVIDIA GPU
  { "SUPER + SHIFT + W",     QS .. "launcher toggleTab walls" },        -- Walls: wallpaper switcher
  { "SUPER + N",             QS .. "notifications toggle" },
  { "SUPER + SHIFT + N",     QS .. "notifications dnd" },
  { "SUPER + A",             QS .. "quicksettings toggle" },
  { "SUPER + C",             QS .. "calendar toggle" },
  { "SUPER + SHIFT + M",     QS .. "media toggle" },
  { "SUPER + ESCAPE",        QS .. "powermenu toggle" },
  { "SUPER + L",             "qs -c kurenai-lock ipc call lock lock" },
  { "SUPER + V",             QS .. "clipboard toggle" },
  { "SUPER + I",             QS .. "sysmon toggle" },
  { "SUPER + SLASH",         QS .. "shortcuts toggle" },                -- keyboard shortcuts page (reads your Lua config live)
}

-- Chord changes made with `kurenai-conf binds set ...` (or the KURENAI settings window) live in ~/.config/kurenai/binds.conf,
-- one line each:  DEFAULT CHORD => NEW CHORD    ("-" as the new chord switches that bind off).
-- The table above is never rewritten; a missing or unreadable file leaves every default chord in place.
local overrides = {}
pcall(function()
  local conf = os.getenv("XDG_CONFIG_HOME")
  if not conf or conf == "" then conf = (os.getenv("HOME") or "") .. "/.config" end
  local fh = io.open(conf .. "/kurenai/binds.conf", "r")
  if not fh then return end
  for line in fh:lines() do
    local d, n = line:gsub("\r$", ""):match("^(.-) => (.+)$")
    if d and n then overrides[d] = n end
  end
  fh:close()
end)

for _, b in ipairs(binds) do
  local chord = b[1]
  local o = overrides[chord]
  if o == "-" then chord = nil elseif o then chord = o end
  if chord then
    local ok, err = pcall(function() hl.bind(chord, hl.dsp.exec_cmd(b[2])) end)
    if not ok then print("[kurenai] bind '" .. chord .. "' failed: " .. tostring(err)) end
  end
end
