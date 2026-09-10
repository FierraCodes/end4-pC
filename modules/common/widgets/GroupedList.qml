import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    default property list<Item> items
    property real bigRadius: Appearance.rounding.normal
    property real smallRadius: Appearance.rounding.unsharpenmore
    property color bgcolor: Appearance.colors.colLayer1
    property real itemVerticalPadding: 24
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.items.length
            delegate: Rectangle {
                id: rowRect
                required property int index
                readonly property Item child: root.items[index] ?? null
                readonly property bool childVisible: child?.visible ?? true

                // isFirst/isLast among the visible rows only
                readonly property bool isFirst: {
                    for (let i = 0; i < index; i++) {
                        if (root.items[i]?.visible !== false) return false
                    }
                    return true
                }
                readonly property bool isLast: {
                    for (let i = index + 1; i < root.items.length; i++) {
                        if (root.items[i]?.visible !== false) return false
                    }
                    return true
                }

                Layout.fillWidth: true
                visible: childVisible
                implicitHeight: childVisible
                    ? (child?.implicitHeight ?? 0) + root.itemVerticalPadding
                    : 0
                color: root.bgcolor
                topLeftRadius:     isFirst ? root.bigRadius : root.smallRadius
                topRightRadius:    isFirst ? root.bigRadius : root.smallRadius
                bottomLeftRadius:  isLast  ? root.bigRadius : root.smallRadius
                bottomRightRadius: isLast  ? root.bigRadius : root.smallRadius

                Component.onCompleted: {
                    if (child) {
                        child.parent = contentArea
                        child.Layout.fillWidth = true
                    }
                }

                ColumnLayout {
                    id: contentArea
                    anchors { fill: parent; margins: 8 }
                    spacing: 0
                }
            }
        }
    }
}