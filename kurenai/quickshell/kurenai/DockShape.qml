import QtQuick
import QtQuick.Shapes

// Silhouette of a panel that hangs from the bar, so it looks grown out of it:
//
//     ___________________________ bar ___________________________
//            ,-------------------------------------.
//           /                                       \      <- concave fillets (`fillet`)
//          |                                         |
//          |                  panel                  |
//           \_______________________________________/      <- convex corners (`corner`)
//
// Size it as: bodyWidth + 2 * fillet wide. The fillets are drawn in the outer `fillet` pixels
// on each side, so the straight panel body sits between x = fillet and x = width - fillet.
// The top edge is flush with the bar: it is filled with the bar colour (hiding the bar's
// bottom hairline there) and NOT stroked, so the join has no seam.
Shape {
    id: root

    property real fillet: Theme.rLg
    property real corner: Theme.rLg
    property color fillColor: Theme.bg           // must equal the bar colour (Bar.qml: Theme.bg)
    property color strokeColor: Theme.border     // same hairline as the bar's bottom edge

    preferredRendererType: Shape.CurveRenderer   // smooth curves without MSAA (Qt 6.6+)

    readonly property real f: Math.min(fillet, width / 4, height / 2)
    readonly property real c: Math.min(corner, width / 4, height / 2)

    // filled body
    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: -1
        startX: 0
        startY: 0
        PathArc { x: root.f; y: root.f; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: root.f; y: root.height - root.c }
        PathArc { x: root.f + root.c; y: root.height; radiusX: root.c; radiusY: root.c; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root.f - root.c; y: root.height }
        PathArc { x: root.width - root.f; y: root.height - root.c; radiusX: root.c; radiusY: root.c; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root.f; y: root.f }
        PathArc { x: root.width; y: 0; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: 0; y: 0 }
    }

    // outline: the same path, left open along the top
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.strokeColor
        strokeWidth: 1
        capStyle: ShapePath.FlatCap
        startX: 0
        startY: 0
        PathArc { x: root.f; y: root.f; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
        PathLine { x: root.f; y: root.height - root.c }
        PathArc { x: root.f + root.c; y: root.height; radiusX: root.c; radiusY: root.c; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root.f - root.c; y: root.height }
        PathArc { x: root.width - root.f; y: root.height - root.c; radiusX: root.c; radiusY: root.c; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root.f; y: root.f }
        PathArc { x: root.width; y: 0; radiusX: root.f; radiusY: root.f; direction: PathArc.Clockwise }
    }
}
