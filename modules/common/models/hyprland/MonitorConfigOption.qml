pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../"

NestableObject {
    id: root

    property var monitors: []

    Component.onCompleted: {
        if (WM.compositor === "hyprland")
            fetchProc.running = true
    }

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    function _buildLuaLine(m) {
        if (m.disabled)
            return `hl.monitor({ output = "${m.name}", disabled = true })`

        const pos = `${Math.max(0, m.x)}x${Math.max(0, m.y)}`
        let line = `hl.monitor({ output = "${m.name}", mode = "${m.currentMode}", position = "${pos}", scale = ${m.scale}`

        if (m.transform && m.transform !== 0)
            line += `, transform = ${m.transform}`

        if (m.vrr !== undefined && m.vrr !== false)
            line += `, vrr = ${m.vrr ? 1 : 0}`

        line += ` })`
        return line
    }

    function save() {
        if (root.monitors.length === 0) return
        if (root.monitors.some(m => !m.name)) return

        const lines = root.monitors.map(m => {
            const line = root._buildLuaLine(m)
            console.log(`[MonitorConfig] saving line: "${line}"`)
            return line
        }).join("\n")

        console.log(`[MonitorConfig] full file:\n${lines}`)

        const escaped = lines.replace(/'/g, "'\\''")
        saveProc.command = ["bash", "-c",
            `printf '%s\n' '${escaped}' > ~/.config/hypr/monitors.lua`]
        saveProc.running = true
    }

    function applyMonitor(m) {
        if (!m.name) return
        const luaLine = root._buildLuaLine(m)
        Quickshell.execDetached(["hyprctl", "eval", luaLine])
    }

    function applyAndSave(index) {
        root.applyMonitor(root.monitors[index])
        root.save()
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => {
                        let w = m.width ?? 0
                        let h = m.height ?? 0
                        let rr = m.refreshRate ?? 60
                        let currMode = ""

                        if (m.availableModes && m.availableModes.length > 0) {
                            if (w === 0 || h === 0) {
                                const first = m.availableModes[0]
                                const parts = first.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                                if (parts) {
                                    w = parseInt(parts[1])
                                    h = parseInt(parts[2])
                                    rr = parseFloat(parts[3])
                                }
                                currMode = first
                            } else {
                                const formatted = `${w}x${h}@${rr.toFixed(2)}Hz`
                                const matched = m.availableModes.find(mode => mode === formatted)
                                currMode = matched ?? formatted
                            }
                        } else {
                            if (w === 0 || h === 0) {
                                w = 1920
                                h = 1080
                                rr = 60
                            }
                            currMode = `${w}x${h}@${rr.toFixed(2)}Hz`
                        }

                        return {
                            name:          m.name,
                            description:   m.description ?? [m.make, m.model].filter(s => s && s !== "Unknown").join(" "),
                            width:         w,
                            height:        h,
                            refreshRate:   rr,
                            x:             Math.max(0, m.x ?? 0),
                            y:             Math.max(0, m.y ?? 0),
                            scale:         m.scale ?? 1.0,
                            transform:     m.transform ?? 0,
                            disabled:      m.disabled ?? false,
                            vrr:           m.vrr ?? false,
                            availableModes: m.availableModes ?? [],
                            currentMode:   currMode
                        }
                    })
                } catch(e) {
                    console.log("[MonitorConfig] Error parsing JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }

    Process {
        id: saveProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}