import QtQuick
import Quickshell

// KURENAI Settings: its own small Quickshell config, so it works with the shell stopped.
//   qs -c kurenai-settings        (or the "KURENAI Settings" entry in Rofi / the launcher / kurenai-settings)
// It only talks to the kurenai-* programs (kurenai-ctl, kurenai-conf, kurenai-hypr, kurenai-clip).
ShellRoot {
    FloatingWindow {
        id: win
        title: "KURENAI Settings"
        implicitWidth: 1120
        implicitHeight: 740
        minimumSize: Qt.size(820, 560)
        color: Theme.bg
        onVisibleChanged: if (!visible) Qt.quit()

        SettingsWindow { anchors.fill: parent }
    }
}
