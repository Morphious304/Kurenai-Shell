# KURENAI, phase 1

Hyprland (Lua config, 0.55+) theme module + Quickshell top bar.

```
install.sh                     copies files into place after a backup; does not edit hyprland.lua
bin/kurenai-ctl                backup | enable | disable | validate | stop | rollback | restore
hypr/kurenai.lua               appearance only (borders, gaps, rounding, shadow, motion)
quickshell/kurenai/            run with:  qs -c kurenai
  Theme.qml                    every colour, size, radius, font, timing and glyph
  UiState.qml                  shared open/closed flags (panels arrive in later phases)
  Compositor.qml               Lua-vs-classic Hyprland dispatch helper
  Bar.qml  Workspaces.qml  WindowTitle.qml  Status.qml  Tray.qml  Clock.qml
  BarItem.qml  Divider.qml  Emblem.qml  shell.qml  qmldir
```

Customise first in `Theme.qml` (palette, fonts, `timeFormat`) and at the top of `hypr/kurenai.lua`
(`ENABLE_BLUR`, `FLOAT_ACCENT`). Quickshell live-reloads QML on save.
