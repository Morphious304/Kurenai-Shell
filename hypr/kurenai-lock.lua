-- ~/.config/hypr/kurenai-lock.lua
-- Hyprland side of the KURENAI lock screen. OPT-IN: `kurenai-ctl enable-lock`.
--
-- 1. allow_session_lock_restore: if the lock process ever crashes while the screen is locked, Hyprland
--    keeps it locked and lets a NEW locker take over. Without this the screen stays on the compositor's
--    placeholder until you restart Hyprland. (kurenai-lock-supervisor restarts the locker and it re-locks.)
-- 2. Starts the supervisor with the session. hl.on("hyprland.start") runs once per session; a plain
--    hl.exec_cmd at top level would run again on every reload.
hl.config({
  misc = {
    allow_session_lock_restore = true,
  },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("$HOME/.local/bin/kurenai-lock-supervisor")
end)
