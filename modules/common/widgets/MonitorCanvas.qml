import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var monitorConfig
    property real padding: 20
    property int selectedIndex: 0
    property var previewPositions: ({})
    property bool dragHasOverlap: false

    implicitHeight: 220

    property var bounds: {
        let minX = Infinity, minY = Infinity
        let maxX = -Infinity, maxY = -Infinity
        const mons = monitorConfig.monitors
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i]
            const w = monitorConfig.logicalWidth(m) || 1920
            const h = monitorConfig.logicalHeight(m) || 1080
            // committed positions only: using the drag preview here rescales the canvas under the cursor
            const px = m.x ?? 0
            const py = m.y ?? 0
            minX = Math.min(minX, px)
            minY = Math.min(minY, py)
            maxX = Math.max(maxX, px + w)
            maxY = Math.max(maxY, py + h)
        }
        if (minX === Infinity) return { minX: 0, minY: 0, width: 1920, height: 1080 }
        // fixed empty margin so a monitor can be dropped beyond the others (bounds can't follow the drag)
        const padX = Math.max(...mons.map(m => monitorConfig.logicalWidth(m) || 1920))
        const padY = Math.max(...mons.map(m => monitorConfig.logicalHeight(m) || 1080)) / 2
        minX -= padX; maxX += padX; minY -= padY; maxY += padY
        return { minX, minY, width: Math.max(100, maxX - minX), height: Math.max(100, maxY - minY) }
    }

    property real scaleFactor: {
        if (bounds.width === 0 || bounds.height === 0) return 0.1
        const scaleX = (canvas.width  - padding * 2) / bounds.width
        const scaleY = (canvas.height - padding * 2) / bounds.height
        return Math.min(scaleX, scaleY)
    }

    property point offset: Qt.point(
        (canvas.width  - bounds.width  * scaleFactor) / 2 - bounds.minX * scaleFactor,
        (canvas.height - bounds.height * scaleFactor) / 2 - bounds.minY * scaleFactor
    )

    function checkOverlap(monitors, idx) {
        const a = monitors[idx]
        if (a.disabled) return false
        const aw = monitorConfig.logicalWidth(a)
        const ah = monitorConfig.logicalHeight(a)
        let touching = false, hasOther = false
        for (let i = 0; i < monitors.length; i++) {
            if (i === idx) continue
            if (monitors[i].disabled) continue
            hasOther = true
            const b = monitors[i]
            const bw = monitorConfig.logicalWidth(b)
            const bh = monitorConfig.logicalHeight(b)
            if (a.x < b.x + bw && a.x + aw > b.x &&
                a.y < b.y + bh && a.y + ah > b.y) {
                return true
            }
            // shares an edge with positive length along the other axis
            const yShare = a.y < b.y + bh && a.y + ah > b.y
            const xShare = a.x < b.x + bw && a.x + aw > b.x
            if ((yShare && (a.x + aw === b.x || b.x + bw === a.x)) ||
                (xShare && (a.y + ah === b.y || b.y + bh === a.y)))
                touching = true
        }
        // a floating monitor counts as invalid, same as an overlap
        return hasOther && !touching
    }

    function computeNormalized(monitors, changedIdx, newX, newY) {
        let m = monitors.slice().map(mon => Object.assign({}, mon))
        m[changedIdx].x = newX
        m[changedIdx].y = newY
        let minX = Infinity, minY = Infinity
        for (let i = 0; i < m.length; i++) {
            if (m[i].disabled) continue
            minX = Math.min(minX, m[i].x)
            minY = Math.min(minY, m[i].y)
        }
        if (minX !== Infinity && minX !== 0) {
            for (let i = 0; i < m.length; i++) {
                if (!m[i].disabled) m[i].x -= minX
            }
        }
        if (minY !== Infinity && minY !== 0) {
            for (let i = 0; i < m.length; i++) {
                if (!m[i].disabled) m[i].y -= minY
            }
        }
        return m
    }

    function updatePreview(idx, newX, newY) {
        // raw (un-normalized) positions: other monitors stay put while dragging; normalizing happens on commit
        let m = monitorConfig.monitors.map(mon => Object.assign({}, mon))
        m[idx].x = newX
        m[idx].y = newY
        root.dragHasOverlap = checkOverlap(m, idx)
    }

    function commitPosition(idx, newX, newY) {
        const normalized = computeNormalized(monitorConfig.monitors, idx, newX, newY)
        root.previewPositions = {}
        for (let i = 0; i < normalized.length; i++) {
            const old = monitorConfig.monitors[i]
            if (normalized[i].x === old.x && normalized[i].y === old.y) continue
            // updateMonitor records the change in _pendingChanges, which save() requires
            monitorConfig.updateMonitor(i, { x: normalized[i].x, y: normalized[i].y })
            monitorConfig.applyAndSave(i)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Item {
            id: canvas
            anchors.fill: parent

            Repeater {
                model: root.monitorConfig.monitors.length
                delegate: MonitorRect {
                    required property int index
                    monitor: root.monitorConfig.monitors[index]
                    monitorIndex: index
                    monitorConfig: root.monitorConfig
                    scaleFactor: root.scaleFactor
                    canvasOffset: root.offset
                    allMonitors: root.monitorConfig.monitors
                    isSelected: index === root.selectedIndex
                    previewPositions: root.previewPositions
                    hasOverlap: root.dragHasOverlap && isDragging

                    onMonitorClicked: (idx) => root.selectedIndex = idx
                    onPositionDragging: (idx, x, y) => root.updatePreview(idx, x, y)
                    onPositionCommitted: (idx, x, y) => {
                        const hadOverlap = root.dragHasOverlap
                        root.previewPositions = {}
                        root.dragHasOverlap = false
                        if (!hadOverlap)
                            root.commitPosition(idx, x, y)
                    }
                }
            }
        }
    }
}