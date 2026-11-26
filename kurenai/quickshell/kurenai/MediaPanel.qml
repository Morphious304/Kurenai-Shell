import QtQuick
import Quickshell

// Compact media panel for any MPRIS player. Opened from the bar's media item or:
//   qs -c kurenai ipc call media toggle
PanelOverlay {
    id: root

    open: UiState.mediaOpen
    place: "top-right"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-media"
    onDismissed: UiState.mediaOpen = false

    PanelFrame {
        id: frame
        docked: root.docked
        bodyWidth: 340
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s3

            // ---------------------------------------------------------------- empty state
            Column {
                visible: !Media.has
                width: parent.width
                spacing: Theme.s2
                topPadding: Theme.s3
                bottomPadding: Theme.s3
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.icons.music
                    font.family: Theme.fontIcon
                    font.pixelSize: 30
                    color: Theme.raised
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing is playing"
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 1
                    font.weight: Font.DemiBold
                    color: Theme.text2
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Start a player that supports MPRIS (Spotify, mpv, VLC, a browser tab...) and it appears here."
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
            }

            // ---------------------------------------------------------------- which player
            Row {
                visible: Media.has
                width: parent.width
                height: 24
                spacing: Theme.s2
                Text {
                    width: parent.width - (switchBtn.visible ? switchBtn.width + Theme.s2 : 0)
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: Media.identity
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    font.letterSpacing: 0.5
                    color: Theme.muted
                }
                Btn {
                    id: switchBtn
                    visible: Media.list.length > 1
                    width: 76
                    height: 24
                    flat: true
                    center: true
                    text: "Player " + Media.playerIndex + "/" + Media.list.length
                    onClicked: Media.cyclePlayer()
                }
            }

            // ---------------------------------------------------------------- artwork + text
            Row {
                visible: Media.has
                width: parent.width
                spacing: Theme.s3

                Rectangle {                      // artwork frame (local files only)
                    id: art
                    width: 92
                    height: 92
                    radius: 3
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    Image {
                        id: img
                        anchors.fill: parent
                        anchors.margins: 1
                        source: Media.artSource
                        visible: status === Image.Ready
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(184, 184)
                    }
                    Text {                       // fallback tile
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        text: Theme.icons.music
                        font.family: Theme.fontIcon
                        font.pixelSize: 30
                        color: Theme.rose
                    }
                }

                Column {
                    width: parent.width - art.width - Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: Media.title !== "" ? Media.title : "Unknown title"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 2
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: Media.artist
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase
                        color: Theme.teal
                    }
                    Text {
                        visible: text !== ""
                        width: parent.width
                        text: Media.album
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                    }
                }
            }

            // ---------------------------------------------------------------- progress (when the player reports it)
            Row {
                visible: Media.has && Media.hasPosition
                width: parent.width
                height: 24
                spacing: Theme.s2
                Text {
                    width: 38
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: Media.fmt(Media.position)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
                KSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 38 * 2 - Theme.s2 * 2
                    from: 0
                    to: Math.max(1, Media.length)
                    step: 5
                    value: Media.position
                    fillColor: Theme.teal
                    enabled: Media.canSeek            // dimmed and inert for players that cannot seek
                    onMoved: v => Media.seekTo(v)
                }
                Text {
                    width: 38
                    height: parent.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: Media.fmt(Media.length)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
            }

            // ---------------------------------------------------------------- transport controls
            Row {
                visible: Media.has
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.s3
                Btn {
                    width: 44; height: 38; center: true
                    icon: Theme.icons.prev
                    enabled: Media.canPrev
                    onClicked: Media.previous()
                }
                Btn {
                    width: 56; height: 38; center: true
                    icon: Media.playing ? Theme.icons.pause : Theme.icons.play
                    checked: true                     // the one filled control
                    enabled: Media.canToggle
                    onClicked: Media.togglePlaying()
                }
                Btn {
                    width: 44; height: 38; center: true
                    icon: Theme.icons.next
                    enabled: Media.canNext
                    onClicked: Media.next()
                }
            }
        }
    }
}
