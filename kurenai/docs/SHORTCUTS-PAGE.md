# The keyboard shortcuts page

[Back to the README](../README.md)

A cheat sheet that is **read from your real config, so it cannot go stale**. Type to filter (every word must match: `super shift`,
`volume`, `kurenai`, a file name); Up/Down/PageUp/PageDown scroll; Esc closes.

**Where the list comes from**
1. `~/.config/hypr/hyprland.lua` and **every file it loads** (`require("keybinds")`, `pcall(require, ...)`, dotted names, `./dir/*`
   wildcards, `dofile`). Adding or removing a `require` line adds or drops that file by itself.
2. `hyprctl binds` (read-only) is the cross-check: each row is marked **not active** if your files define it but Hyprland does not have it
   (typo, unreloaded edit, `hl.unbind`), and binds that only exist while Hyprland runs appear as **Hyprland only**.

**How it reads Lua:** `BindParser.js` is a small interpreter for the subset keybind files use: variables (`mainMod`), string joins
(`mainMod .. " + Q"`), `for` loops (the workspace 1-10 binds), tables of binds, helper functions, `hl.bind`, `hl.unbind`,
`hl.define_submap`, bind functions (it lists what they dispatch). It **never runs a command and never writes anything**; it only reads files.
A `description = "..."` flag on a bind becomes its label, so the nicest way to improve a row is to add one.

**Staying current:** the files are watched; while the page is open they are also re-read every 2 s (covers editors that save by replacing
the file), and Hyprland's `configreloaded` event and opening the page refresh the check. Nothing is re-analysed unless a file's text changed.

**Row tags:** `not active` (amber) = in your files, not in Hyprland. `duplicate` (rose) = the same chord is bound twice (a real clash).
`Hyprland only` (teal) = active but built at run time. Footer `N files` opens the list of files read and anything it could not follow.

**If something looks wrong:** `kurenai-ctl shortcuts` (same as `qs -c kurenai ipc call shortcuts status`) prints every file read, how many
binds each gave, and each warning with `file:line`. Not at `~/.config/hypr/hyprland.lua`? Set `hyprMainFile` in `Config.qml`.
Limits: anything decided only while running (an `if` on window state) is skipped; Lua string patterns (`string.match`) are not evaluated.
Those binds still show up through the Hyprland cross-check.

**The key:** `SUPER + /` is in the shipped `kurenai-binds.lua`. If you installed before it existed, the installer kept your edited file and
saved the new one as `kurenai-binds.lua.new`; add this one line to the table (after the `SUPER + L` line), then `hyprctl reload`:
`{ "SUPER + SLASH",         QS .. "shortcuts toggle" },`
