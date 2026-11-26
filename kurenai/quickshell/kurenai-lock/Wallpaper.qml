import QtQuick

// Background of one screen: the wallpaper awww reports for it, softened and darkened. No image (or a
// failed load) = the generated Pattern. The image is decoded at low resolution on purpose: it will be
// blurred anyway, and this keeps lock start-up fast and light.
Item {
    id: root

    property string source: ""
    property real u: 1
    readonly property bool hasImage: img.status === Image.Ready

    Pattern { anchors.fill: parent; u: root.u; visible: !root.hasImage }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(640, 360)
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        visible: status === Image.Ready
        onStatusChanged: LockState.log("wallpaper image status=" + status + " (1=Ready, 3=Error)")
    }

    Loader {
        anchors.fill: parent
        active: root.hasImage
        source: "BlurFx.qml"
        onLoaded: item.target = img
    }

    Rectangle { anchors.fill: parent; visible: root.hasImage; color: "#000000"; opacity: Config.dim }
}
