-- ~/.config/hypr/kurenai-autostart.lua
-- Starts the KURENAI shell with the session. OPT-IN: `kurenai-ctl enable-autostart`.
--
-- hl.on("hyprland.start") runs once per session (a plain hl.exec_cmd at top level would run
-- again on every `hyprctl reload`). -n = do nothing if a KURENAI shell is already running,
-- -d = detach. Remove this hook with `kurenai-ctl disable-autostart`.

hl.on("hyprland.start", function()
  hl.exec_cmd("qs -n -d -c kurenai")
end)
