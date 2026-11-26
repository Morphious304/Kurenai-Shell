import QtQuick

// Fallback background when there is no wallpaper image: charcoal, a faint seigaiha (wave) pattern,
// and a vermilion glow. Drawn once, no images needed.
Item {
    id: root

    property real u: 1

    Rectangle { anchors.fill: parent; color: Theme.bg }

    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = Math.max(24, 64 * root.u);
            ctx.strokeStyle = "rgba(244, 232, 190, 0.07)";
            ctx.lineWidth = Math.max(1, 1.4 * root.u);
            for (let row = 0; row * r * 0.5 < height + r; row++) {
                const y = row * r * 0.5;
                for (let col = -1; col * r < width + r; col++) {
                    const x = col * r + (row % 2 ? r / 2 : 0);
                    for (let k = 1; k <= 3; k++) {
                        ctx.beginPath();
                        ctx.arc(x, y, r * k / 3.2, Math.PI, 0);
                        ctx.stroke();
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00F04436" }
            GradientStop { position: 1.0; color: "#38F04436" }
        }
    }
}
