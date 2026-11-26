/* ~/.config/rofi/themes/kurenai.rasi   (WALLPAPER VERSION: written by kurenai-ctl theme-apply; `kurenai-ctl theme reset` restores the fixed colours)
 * KURENAI for Rofi: the same charcoal, bone and vermilion as the shell, so the fallback launcher
 * looks like the real one. Colours are the tokens from quickshell/kurenai/Theme.qml.
 *
 * Try it once:        rofi -show drun -show-icons -theme kurenai
 * Make it the default: add  @theme "kurenai"  as the first line of ~/.config/rofi/config.rasi
 *                      (kurenai-ctl rofi-theme explains this; nothing edits your config for you)
 * Undo:               delete this file / remove that line.
 *
 * Rofi cannot draw the shell's docked shape or blur: it matches in colour, type and spacing.
 */

* {
    /* tokens */
    bg:          #{{colors.surface_container.default.hex_stripped}}F2;   /* panelBg: charcoal, 95% */
    surface:     {{colors.surface_container_high.default.hex}};
    raised:      {{colors.surface_container_highest.default.hex}};
    text:        {{colors.on_surface.default.hex}};
    text2:       {{colors.on_surface_variant.default.hex}};     /* ivory */
    muted:       {{colors.outline.default.hex}};
    accent:      {{colors.primary.default.hex}};
    accent-text: {{colors.primary.default.hex}};
    ink:         {{colors.on_primary.default.hex}};
    teal:        {{colors.secondary.default.hex}};
    amber:       #F0A333;
    line:        #{{colors.on_surface.default.hex_stripped}}1F;   /* bone at 12% */
    line-strong: #{{colors.on_surface.default.hex_stripped}}47;   /* bone at 28% */

    font: "Adwaita Sans 11";
    background-color: transparent;
    text-color: @text;
    border-color: @line;
    spacing: 0;
    margin: 0;
    padding: 0;
}

window {
    location: north;
    anchor: north;
    y-offset: 160px;
    width: 560px;
    background-color: @bg;
    border: 1px;
    border-color: @line-strong;
    border-radius: 14px;
    children: [ mainbox ];
}

mainbox {
    padding: 12px;
    spacing: 8px;
    children: [ inputbar, message, listview, mode-switcher ];
}

/* search field */
inputbar {
    padding: 10px 12px;
    spacing: 10px;
    background-color: @surface;
    border: 1px;
    border-color: @line;
    border-radius: 10px;
    children: [ prompt, entry, textbox-seal ];
}
inputbar focused {
    border-color: @accent;
}
prompt {
    text-color: @accent-text;
    vertical-align: 0.5;
}
entry {
    text-color: @text;
    placeholder: "Search";
    placeholder-color: @muted;
    cursor-color: @accent;
    vertical-align: 0.5;
}
textbox-seal {            /* the small hanko seal */
    str: "紅";
    font: "Noto Serif CJK JP Bold 11";
    text-color: @ink;
    background-color: @accent;
    border-radius: 6px;
    padding: 2px 5px;
    vertical-align: 0.5;
    expand: false;
}

/* messages ("no matches", errors) */
message {
    padding: 8px 12px;
    background-color: @surface;
    border-radius: 6px;
}
textbox {
    text-color: @text2;
}

/* results */
listview {
    lines: 8;
    columns: 1;
    fixed-height: true;
    scrollbar: false;
    spacing: 2px;
    border: 0;
}
element {
    padding: 8px 12px;
    spacing: 12px;
    border-radius: 10px;
    background-color: transparent;
    text-color: @text;
}
element selected.normal {
    background-color: @raised;
    text-color: @text;
}
element alternate.normal {
    background-color: transparent;
}
element normal.active, element selected.active {
    text-color: @teal;
}
element normal.urgent, element selected.urgent {
    text-color: @amber;
}
element-icon {
    size: 26px;
    vertical-align: 0.5;
}
element-text {
    text-color: inherit;
    vertical-align: 0.5;
}

/* mode tabs (drun / run / ...), if you start Rofi with more than one mode */
mode-switcher {
    spacing: 4px;
}
button {
    padding: 6px 10px;
    border-radius: 6px;
    background-color: transparent;
    text-color: @muted;
    horizontal-align: 0.5;
}
button selected {
    background-color: @raised;
    text-color: @text;
}
