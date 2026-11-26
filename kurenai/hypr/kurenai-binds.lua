-- ~/.config/hypr/kurenai-binds.lua
-- KURENAI keybinds. OPT-IN: nothing loads this until you run `kurenai-ctl enable-binds`,
-- and `kurenai-ctl binds-check` shows any clash with your existing binds first.
--
-- Each entry is { chord, shell command }. Edit the chords here; keep one entry per line,
-- starting with `{ "` (kurenai-ctl reads this file to run the conflict check).
--
-- The launcher bind falls back to Rofi if the Quickshell IPC call fails, so you are never
-- left without a launcher. (Assumes `qs ipc call` exits non-zero when no shell is running;
-- verify once with the shell stopped: qs -c kurenai ipc call launcher toggle; echo $?)

local QS   = "qs -c kurenai ipc call "
local ROFI = "rofi -show drun"      -- change to your usual Rofi invocation

local binds = {
  { "SUPER + SPACE",         QS .. "launcher toggle || " .. ROFI },
  { "SUPER + SHIFT + SPACE", "command -v rofi >/dev/null && " .. ROFI },
  { "SUPER + N",             QS .. "notifications toggle" },
  { "SUPER + SHIFT + N",     QS .. "notifications dnd" },
  { "SUPER + A",             QS .. "quicksettings toggle" },
}

for _, b in ipairs(binds) do
  local ok, err = pcall(function() hl.bind(b[1], hl.dsp.exec_cmd(b[2])) end)
  if not ok then print("[kurenai] bind '" .. b[1] .. "' failed: " .. tostring(err)) end
end
