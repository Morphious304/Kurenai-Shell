-- Installed by `kurenai-ctl theme extra nvim on`. Reloads the KURENAI colorscheme in a running Neovim when the wallpaper
-- colours change. It only acts while `:colorscheme kurenai` is the active scheme, and does nothing otherwise.
local uv = vim.uv or vim.loop
local path = vim.fn.stdpath("config") .. "/colors/kurenai.lua"
if not (uv and uv.new_fs_event) or vim.fn.filereadable(path) == 0 then return end

local handle = uv.new_fs_event()
local pending = false
local function reload()
  if pending then return end
  pending = true
  vim.defer_fn(function()          -- the file is rewritten in a few steps: wait until it settles
    pending = false
    if vim.g.colors_name == "kurenai" then pcall(vim.cmd, "colorscheme kurenai") end
  end, 200)
end
handle:start(path, {}, vim.schedule_wrap(reload))
