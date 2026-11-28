import QtQuick
import QtQuick.Effects

// Real blur, loaded through a Loader (see Wallpaper.qml): if QtQuick.Effects is not available on this
// system, only THIS file fails to load and the wallpaper is simply shown softened but unblurred.
MultiEffect {
    property Item target
    source: target
    blurEnabled: true
    blurMax: 40
    blur: 1.0
    saturation: -0.1
}
