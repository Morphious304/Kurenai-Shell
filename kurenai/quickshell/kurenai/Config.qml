pragma Singleton
import QtQuick
import Quickshell

// KURENAI behaviour settings (things you might want to change that are not visual design).
// Design tokens (colours, sizes, fonts) live in Theme.qml.
Singleton {
    // ---- launcher ----------------------------------------------------------
    readonly property string terminal: "kitty"          // used for apps whose .desktop file says Terminal=true
    readonly property int launcherMaxResults: 40
    readonly property int launcherVisibleRows: 7
    readonly property int launcherMaxRecent: 8

    // ---- notifications -----------------------------------------------------
    readonly property int maxPopups: 4
    readonly property int popupTimeoutLow: 4000         // ms
    readonly property int popupTimeoutNormal: 7000
    // critical notifications never time out: they stay until you dismiss them
}
