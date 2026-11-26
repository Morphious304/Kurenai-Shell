pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland 0.55+ in Lua mode parses dispatchers as Lua expressions, so the classic
// "workspace 3" string is rejected. HyprlandWorkspace.activate() is documented as the
// classic form, so we dispatch ourselves and branch on Hyprland.usingLua.
// Workspace targets are passed as quoted strings, which is the form the Hyprland wiki
// and Quickshell's own Lua dispatch use (focus({ workspace = "3" })).
Singleton {
    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
        else
            Hyprland.dispatch(`workspace ${id}`);
    }

    // step > 0: next open workspace, step < 0: previous
    function cycleWorkspace(step) {
        const rel = step > 0 ? "e+1" : "e-1";
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${rel}" })`);
        else
            Hyprland.dispatch(`workspace ${rel}`);
    }

    // The screen that currently has focus, so transient panels appear where you are looking.
    // Falls back to the first screen while Hyprland has not reported a focused monitor.
    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor;
        const list = Quickshell.screens;
        if (m) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].name === m.name) return list[i];
            }
        }
        return list.length > 0 ? list[0] : null;
    }

    // True while the focused workspace has a fullscreen window. A fullscreen window is drawn above the
    // bar (layer "top"), so anything that normally attaches to the bar has to float instead.
    readonly property bool fullscreen: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.hasFullscreen : false

    // hasFullscreen only changes when the workspace object is refreshed, so nudge it on the
    // `fullscreen` event (see Hyprland wiki: IPC). Cheap: one request per fullscreen toggle.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") Hyprland.refreshWorkspaces();
        }
    }
}
