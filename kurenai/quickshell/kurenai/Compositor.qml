pragma Singleton
import Quickshell
import Quickshell.Hyprland

// Hyprland 0.55+ in Lua mode parses dispatchers as Lua expressions, so the classic
// "workspace 3" string is rejected. HyprlandWorkspace.activate() is documented as the
// classic form, so we dispatch ourselves and branch on Hyprland.usingLua.
Singleton {
    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
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
}
