import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    id: page
    forceWidth: true

    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    Component.onCompleted: {
        const h = Config.options.hyprland
        // One setMany for everything: separate calls would be separate
        // processes racing to rewrite the same overrides file.
        HyprlandConfig.setMany(Object.assign({
            "decoration:rounding":                  h.decoration.rounding,
            "decoration:blur:enabled":              h.decoration.blur.enabled ? 1 : 0,
            "decoration:blur:size":                 h.decoration.blur.size,
            "decoration:blur:passes":               h.decoration.blur.passes,
            "decoration:active_opacity":            h.decoration.activeOpacity,
            "decoration:inactive_opacity":          h.decoration.inactiveOpacity,
            "general:border_size":                  h.general.borderSize,
            "general:gaps_in":                      h.general.gapsIn,
            "general:gaps_out":                     h.general.gapsOut,
            "general:layout":                       h.general.layout,
            "animations:enabled":                   h.animations.enable ? 1 : 0,
            "input:kb_layout":                      h.input.kbLayout,
            "input:numlock_by_default":             h.input.numlock ? 1 : 0,
            "input:repeat_delay":                   h.input.repeatDelay,
            "input:repeat_rate":                    h.input.repeatRate,
            "input:follow_mouse":                   h.input.followMouse,
            "input:touchpad:natural_scroll":        h.input.touchpad.naturalScroll ? 1 : 0,
            "input:touchpad:disable_while_typing":  h.input.touchpad.disableWhileTyping ? 1 : 0,
            "input:touchpad:clickfinger_behavior":  h.input.touchpad.clickfingerBehavior ? 1 : 0,
            "input:touchpad:scroll_factor":         h.input.touchpad.scrollFactor
        }, HyprlandConfig.borderColorEntries()))
    }
    MonitorConfigOption { id: monitorConfig }

    readonly property int selectedIndex: Math.min(monitorCanvas.selectedIndex, Math.max(0, monitorConfig.monitors.length - 1))
    readonly property var currentMon: monitorConfig.monitors[selectedIndex]

    // Same roles as the settings panel border color on the Interface page.
    readonly property var borderColorRoles: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"]

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // Displays
        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            title: Translation.tr("Displays")
            visible: monitorConfig.monitors.length > 0

            MonitorCanvas {
                id: monitorCanvas
                Layout.fillWidth: true
                monitorConfig: monitorConfig
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: (page.currentMon?.name ?? "")
                    + " · "
                    + (page.currentMon?.description ?? "")

                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "tv_off"
                        text: Translation.tr("Enabled")
                        enabled: monitorConfig.monitors.length > 1
                        checked: !(page.currentMon?.disabled ?? false)
                        onCheckedChanged: {
                            if (checked === !(page.currentMon?.disabled ?? false)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "aspect_ratio"
                        text: Translation.tr("Resolution & Refresh Rate")
                        textRole: "display"
                        model: (page.currentMon?.availableModes ?? [])
                            .map(mode => ({ display: mode, value: mode }))
                        currentValue: page.currentMon?.currentMode ?? ""
                        onSelected: newValue => {
                            const mode = newValue
                            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                            if (parts) {
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, {
                                    currentMode: mode,
                                    width: parseInt(parts[1]),
                                    height: parseInt(parts[2]),
                                    refreshRate: parseFloat(parts[3])
                                })
                                monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Orientation")
                        icon: "mobile_rotate"
                        currentValue: page.currentMon?.transform ?? 0
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                        options: [
                            { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                            { displayName: "90°",                    icon: "rotate_90_degrees_cw",  value: 1 },
                            { displayName: "180°",                   icon: "screen_rotation",       value: 2 },
                            { displayName: "270°",                   icon: "rotate_90_degrees_ccw", value: 3 },
                        ]
                    }

                    ConfigSwitch {
                        buttonIcon: "autoplay"
                        text: Translation.tr("Variable refresh rate (VRR)")
                        checked: page.currentMon?.vrr ?? false
                        onCheckedChanged: {
                            if (checked === (page.currentMon?.vrr ?? false)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { vrr: checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
    
                    ConfigSpinBox {
                        icon: "zoom_in"
                        text: Translation.tr("Scale")
                        value: Math.round((page.currentMon?.scale ?? 1.0) * 100)
                        from: 50; to: 300; stepSize: 25
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === (page.currentMon?.scale ?? 1.0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: newVal })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_horiz"
                        text: Translation.tr("Position X")
                        value: page.currentMon?.x ?? 0
                        from: 0; to: 7680; stepSize: 10
                        onValueChanged: {
                            if (value === (page.currentMon?.x ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { x: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swap_vert"
                        text: Translation.tr("Position Y")
                        value: page.currentMon?.y ?? 0
                        from: 0; to: 4320; stepSize: 10
                        onValueChanged: {
                            if (value === (page.currentMon?.y ?? 0)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { y: value })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("HDR & Color Management")

                NoticeBox {
                    Layout.fillWidth: true
                    visible: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported === null
                    text: Translation.tr("Couldn't confirm this display's HDR capability from its EDID. Options are shown but may not do anything.")
                }

                NoticeBox {
                    Layout.fillWidth: true
                    visible: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported === false
                    text: Translation.tr("This display's EDID does not report HDR support, so HDR options are disabled here. Open an issue in GitHub if you think this is a mistake.")
                }

                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Bit depth")
                        icon: "gradient"
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.bitdepth
                            ?? (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxBpc ?? 8)
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { bitdepth: newValue })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                        options: (() => {
                            const maxBpc = monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxBpc ?? 8
                            return [
                                { displayName: "8-bit",  icon: "filter_8", value: 8  },
                                { displayName: "10-bit", icon: "palette",   value: 10 },
                                { displayName: "12-bit", icon: "hdr_on",   value: 12 },
                            ].filter(o => o.value <= maxBpc)
                        })()
                    }

                    ConfigComboBox {
                        Layout.fillWidth: true
                        buttonIcon: "palette"
                        text: Translation.tr("Color management")
                        enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.hdrSupported !== false
                        model: [
                            { displayName: Translation.tr("Auto"),       icon: "auto_awesome",  value: "auto"    },
                            { displayName: "sRGB",                       icon: "light_mode",    value: "srgb"    },
                            { displayName: Translation.tr("Wide (P3)"),  icon: "wb_iridescent", value: "wide"    },
                            { displayName: "HDR",                        icon: "hdr_on",        value: "hdr"     },
                            { displayName: Translation.tr("HDR (EDID)"), icon: "hdr_auto",      value: "hdredid" },
                        ]
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm ?? "auto"
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { cm: newValue })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            icon: "brightness_6"
                            text: Translation.tr("SDR brightness")
                            value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrBrightness ?? 1.0) * 100)
                            from: 10; to: 300; stepSize: 5
                            onValueChanged: {
                                const newVal = value / 100.0
                                if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrBrightness ?? 1.0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrBrightness: newVal })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            icon: "contrast"
                            text: Translation.tr("SDR saturation")
                            value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrSaturation ?? 1.0) * 100)
                            from: 10; to: 200; stepSize: 5
                            onValueChanged: {
                                const newVal = value / 100.0
                                if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrSaturation ?? 1.0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrSaturation: newVal })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "wb_twilight"
                            text: Translation.tr("SDR min (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMinLuminance ?? 0
                            from: 0; to: 100; stepSize: 1
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMinLuminance ?? 0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrMinLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "wb_sunny"
                            text: Translation.tr("SDR max (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMaxLuminance ?? 250
                            from: 50; to: 2000; stepSize: 10
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.sdrMaxLuminance ?? 250)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { sdrMaxLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "nightlight"
                            text: Translation.tr("HDR min (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.minLuminance ?? 0
                            from: 0; to: 100; stepSize: 1
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.minLuminance ?? 0)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { minLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }

                        ConfigSpinBox {
                            Layout.fillWidth: true
                            icon: "hdr_strong"
                            text: Translation.tr("HDR peak (nits)")
                            value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxLuminance ?? 1000
                            from: 100; to: 10000; stepSize: 50
                            enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                            onValueChanged: {
                                if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxLuminance ?? 1000)) return
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { maxLuminance: value })
                                monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                            }
                        }
                    }

                    ConfigSpinBox {
                        icon: "hdr_weak"
                        text: Translation.tr("HDR max average luminance (nits)")
                        value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxAvgLuminance ?? 250
                        from: 50; to: 5000; stepSize: 10
                        enabled: monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdr" || monitorConfig.monitors[monitorCanvas.selectedIndex]?.cm === "hdredid"
                        onValueChanged: {
                            if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.maxAvgLuminance ?? 250)) return
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { maxAvgLuminance: value })
                            monitorConfig.saveHdr(monitorCanvas.selectedIndex)
                        }
                    }
                }
            }
        }

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Tiling Layout")
                    icon: "responsive_layout"
                    currentValue: Config.options.hyprland.general.layout
                    onSelected: newValue => {
                        Config.options.hyprland.general.layout = newValue
                        HyprlandConfig.set("general:layout", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Dwindle"),   icon: "browse",             value: "dwindle"   },
                        { displayName: Translation.tr("Master"),    icon: "auto_awesome_mosaic", value: "master"    },
                        { displayName: Translation.tr("Scrolling"), icon: "view_carousel",       value: "scrolling" },
                    ]
                }
            }
        }

        // Input
        ContentSection {
            icon: "trackpad_input"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Input")

            ContentSubsection {
                title: Translation.tr("Keyboard")

                GroupedList {
                    ConfigTextArea {
                        id: kbLayoutField
                        Layout.fillWidth: true
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard layout")
                        placeholderText: Translation.tr("e.g., us, es, latam")
                        Component.onCompleted: value = Config.options.hyprland.input.kbLayout
                        onValueChanged: kbLayoutDebounceTimer.restart()

                        Timer {
                            id: kbLayoutDebounceTimer
                            interval: 1000
                            repeat: false
                            onTriggered: {
                                Config.options.hyprland.input.kbLayout = kbLayoutField.value
                                HyprlandConfig.set("input:kb_layout", kbLayoutField.value)
                            }
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "numbers"
                        text: Translation.tr("Numlock by default")
                        checked: Config.options.hyprland.input.numlock
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.numlock) return
                            Config.options.hyprland.input.numlock = checked
                            HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "keyboard_return"
                        text: Translation.tr("Repeat delay (ms)")
                        value: Config.options.hyprland.input.repeatDelay
                        from: 100; to: 1000; stepSize: 10
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatDelay) return
                            Config.options.hyprland.input.repeatDelay = value
                            HyprlandConfig.set("input:repeat_delay", value)
                        }
                    }

                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Repeat rate")
                        value: Config.options.hyprland.input.repeatRate
                        from: 10; to: 100; stepSize: 1
                        onValueChanged: {
                            if (value === Config.options.hyprland.input.repeatRate) return
                            Config.options.hyprland.input.repeatRate = value
                            HyprlandConfig.set("input:repeat_rate", value)
                        }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Follow mouse")
                        icon: "mouse"
                        currentValue: Config.options.hyprland.input.followMouse
                        onSelected: newValue => {
                            Config.options.hyprland.input.followMouse = newValue
                            HyprlandConfig.set("input:follow_mouse", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Disabled"), icon: "mouse",     value: 0 },
                            { displayName: Translation.tr("Full"),     icon: "open_with",  value: 1 },
                            { displayName: Translation.tr("Loose"),    icon: "drag_pan",   value: 2 },
                            { displayName: Translation.tr("Explicit"), icon: "ads_click",  value: 3 },
                        ]
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Pointer & Acceleration")
                GroupedList {
                    ConfigSpinBox {
                        icon: "speed"
                        text: Translation.tr("Pointer speed (sensitivity)")
                        value: Math.round((Config.options.hyprland.input.sensitivity ?? 0.0) * 100)
                        from: -100; to: 100; stepSize: 5
                        onValueChanged: {
                            const newVal = value / 100.0
                            if (newVal === (Config.options.hyprland.input.sensitivity ?? 0.0)) return
                            Config.options.hyprland.input.sensitivity = newVal
                            HyprlandConfig.set("input:sensitivity", newVal)
                        }
                    }

                    ConfigSelectionArray {
                        text: Translation.tr("Acceleration profile")
                        icon: "near_me"
                        currentValue: Config.options.hyprland.input.accelProfile ?? "adaptive"
                        onSelected: newValue => {
                            Config.options.hyprland.input.accelProfile = newValue
                            HyprlandConfig.set("input:accel_profile", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Adaptive"), icon: "speed", value: "adaptive" },
                            { displayName: Translation.tr("Flat (Linear)"), icon: "linear_scale", value: "flat" },
                            { displayName: Translation.tr("Custom"), icon: "tune", value: "custom" },
                        ]
                    }

                    ConfigSwitch {
                        buttonIcon: "do_not_disturb_on"
                        text: Translation.tr("Force no acceleration")
                        checked: Config.options.hyprland.input.forceNoAccel ?? false
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.input.forceNoAccel ?? false)) return
                            Config.options.hyprland.input.forceNoAccel = checked
                            HyprlandConfig.set("input:force_no_accel", checked ? 1 : 0)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Mouse")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: Config.options.hyprland.input.mouse?.naturalScroll ?? false
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.input.mouse?.naturalScroll ?? false)) return
                            Config.options.hyprland.input.mouse.naturalScroll = checked
                            HyprlandConfig.set("input:natural_scroll", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "front_hand"
                        text: Translation.tr("Left handed mode")
                        checked: Config.options.hyprland.input.mouse?.leftHanded ?? false
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.input.mouse?.leftHanded ?? false)) return
                            Config.options.hyprland.input.mouse.leftHanded = checked
                            HyprlandConfig.set("input:left_handed", checked ? 1 : 0)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Touchpad")
                GroupedList {
                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Tap to click")
                        checked: Config.options.hyprland.input.touchpad.tapToClick ?? true
                        onCheckedChanged: {
                            if (checked === (Config.options.hyprland.input.touchpad.tapToClick ?? true)) return
                            Config.options.hyprland.input.touchpad.tapToClick = checked
                            HyprlandConfig.set("input:touchpad:tap_to_click", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "swap_vert"
                        text: Translation.tr("Natural scroll")
                        checked: Config.options.hyprland.input.touchpad.naturalScroll
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.naturalScroll) return
                            Config.options.hyprland.input.touchpad.naturalScroll = checked
                            HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "keyboard_hide"
                        text: Translation.tr("Disable while typing")
                        checked: Config.options.hyprland.input.touchpad.disableWhileTyping
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.disableWhileTyping) return
                            Config.options.hyprland.input.touchpad.disableWhileTyping = checked
                            HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                        }
                    }

                    ConfigSwitch {
                        buttonIcon: "touch_app"
                        text: Translation.tr("Clickfinger behavior")
                        checked: Config.options.hyprland.input.touchpad.clickfingerBehavior
                        onCheckedChanged: {
                            if (checked === Config.options.hyprland.input.touchpad.clickfingerBehavior) return
                            Config.options.hyprland.input.touchpad.clickfingerBehavior = checked
                            HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                        }
                    }

                    ConfigSpinBox {
                        icon: "swipe"
                        text: Translation.tr("Scroll factor")
                        value: Math.round(Config.options.hyprland.input.touchpad.scrollFactor * 10)
                        from: 1; to: 30; stepSize: 1
                        onValueChanged: {
                            const newVal = value / 10.0
                            if (newVal === Config.options.hyprland.input.touchpad.scrollFactor) return
                            Config.options.hyprland.input.touchpad.scrollFactor = newVal
                            HyprlandConfig.set("input:touchpad:scroll_factor", newVal)
                        }
                    }
                }
            }
        }

        // Devices
        ContentSection {
            icon: "devices"
            shape: MaterialShape.Shape.Hexagon
            title: Translation.tr("Devices")

            // Fetch device list and refresh on reload or hotplug
            Process {
                id: devicesProc
                command: ["hyprctl", "devices", "-j"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const data = JSON.parse(text)
                            const freshList = (data.mice || [])
                                .filter(d => !d.name.startsWith("ydotoold") && !d.name.startsWith("hl-virtual"))
                                .map(d => ({
                                    name: d.name,
                                    isTouchpad: d.name.includes("touchpad")
                                }))

                            // Add newly connected devices (preserves existing card state)
                            for (const dev of freshList) {
                                let exists = false
                                for (let i = 0; i < deviceListModel.count; i++) {
                                    if (deviceListModel.get(i).name === dev.name) { exists = true; break }
                                }
                                if (!exists) deviceListModel.append(dev)
                            }

                            // Remove disconnected devices
                            for (let i = deviceListModel.count - 1; i >= 0; i--) {
                                const gone = !freshList.some(d => d.name === deviceListModel.get(i).name)
                                if (gone) deviceListModel.remove(i)
                            }
                        } catch (e) {
                            console.log("[Devices] Failed to parse hyprctl devices -j:", e)
                        }
                    }
                }
            }

            // Refresh on Hyprland reload (catches hotplug events that trigger reload)
            Connections {
                target: HyprlandConfig
                function onReloaded() { devicesProc.running = true }
            }


            ListModel { id: deviceListModel }

            Repeater {
                model: deviceListModel
                delegate: Item {
                    id: deviceCard
                    required property string name
                    required property bool isTouchpad
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: cardColumn.implicitHeight

                    // Per-device state (initialized from live Hyprland config via hyprctl eval)
                    property real devSensitivity: 0.0
                    property string devAccelProfile: "adaptive"
                    property bool devNaturalScroll: false
                    property bool devTapToClick: true
                    property bool devLeftHanded: false
                    property bool collapsed: true
                    property bool loaded: false

                    Component.onCompleted: fetchDeviceState()

                    function fetchDeviceState() {
                        const luaExpr = `
local name = "${deviceCard.name}"
local f = io.open("/tmp/qs_dev_" .. name:gsub("[^%w]","_") .. ".json", "w")
local ok, res = pcall(function()
  return hl.get_config("device:" .. name .. ":sensitivity")
end)
local sens = ok and res or 0.0
local ok2, res2 = pcall(function()
  return hl.get_config("device:" .. name .. ":accel_profile")
end)
local ap = ok2 and res2 or "adaptive"
f:write('{"sensitivity":' .. tostring(sens) .. ',"accel_profile":"' .. tostring(ap) .. '"}')
f:close()
`
                        // Use hyprctl eval to read current device state
                        fetchProc.command = ["hyprctl", "eval", luaExpr.trim()]
                        fetchProc.running = true
                    }

                    Process {
                        id: fetchProc
                        onExited: {
                            // Read the written JSON file
                            const fname = "/tmp/qs_dev_" + deviceCard.name.replace(/[^\w]/g, "_") + ".json"
                            readFileProc.command = ["cat", fname]
                            readFileProc.running = true
                        }
                    }

                    Process {
                        id: readFileProc
                        stdout: StdioCollector {
                            onStreamFinished: {
                                try {
                                    const d = JSON.parse(text)
                                    deviceCard.devSensitivity = d.sensitivity ?? 0.0
                                    deviceCard.devAccelProfile = d.accel_profile ?? "adaptive"
                                } catch (e) {}
                                deviceCard.loaded = true
                            }
                        }
                    }

                    ColumnLayout {
                        id: cardColumn
                        anchors { left: parent.left; right: parent.right }
                        spacing: 2

                        // Collapsible header
                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            buttonRadius: deviceCard.collapsed
                                ? Appearance.rounding.normal
                                : Appearance.rounding.unsharpenmore
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colRipple: Appearance.colors.colLayer1Active
                            onClicked: deviceCard.collapsed = !deviceCard.collapsed

                            Behavior on buttonRadius {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            contentItem: RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                spacing: 10

                                MaterialSymbol {
                                    text: deviceCard.isTouchpad ? "trackpad_input" : "mouse"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: deviceCard.name
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSecondaryContainer
                                    elide: Text.ElideRight
                                }
                                MaterialSymbol {
                                    text: deviceCard.collapsed ? "expand_more" : "expand_less"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colSubtext
                                    Behavior on text {
                                        // No text animation – chevron flips via binding above
                                    }
                                }
                            }
                        }

                        // Collapsible body
                        Item {
                            id: collapseWrapper
                            Layout.fillWidth: true
                            visible: implicitHeight > 0
                            implicitHeight: deviceCard.collapsed ? 0 : bodyColumn.implicitHeight
                            clip: true

                            Behavior on implicitHeight {
                                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                            }

                            ColumnLayout {
                                id: bodyColumn
                                anchors { left: parent.left; right: parent.right }
                                spacing: 2

                                // Common options (all devices)
                                GroupedList {
                                    ConfigSpinBox {
                                        icon: "speed"
                                        text: Translation.tr("Sensitivity")
                                        value: Math.round((deviceCard.devSensitivity) * 100)
                                        from: -100; to: 100; stepSize: 5
                                        onValueChanged: {
                                            if (!deviceCard.loaded) return
                                            const newVal = value / 100.0
                                            if (Math.abs(newVal - deviceCard.devSensitivity) < 0.001) return
                                            deviceCard.devSensitivity = newVal
                                            HyprlandConfig.setDevice(deviceCard.name, { sensitivity: newVal })
                                        }
                                    }

                                    ConfigSelectionArray {
                                        text: Translation.tr("Accel profile")
                                        icon: "near_me"
                                        currentValue: deviceCard.devAccelProfile
                                        onSelected: newValue => {
                                            if (!deviceCard.loaded) return
                                            deviceCard.devAccelProfile = newValue
                                            HyprlandConfig.setDevice(deviceCard.name, { accel_profile: newValue })
                                        }
                                        options: [
                                            { displayName: Translation.tr("Adaptive"), icon: "speed",         value: "adaptive" },
                                            { displayName: Translation.tr("Flat"),     icon: "linear_scale",  value: "flat"     },
                                            { displayName: Translation.tr("Custom"),   icon: "tune",          value: "custom"   },
                                        ]
                                    }

                                    ConfigSwitch {
                                        buttonIcon: "swap_vert"
                                        text: Translation.tr("Natural scroll")
                                        checked: deviceCard.devNaturalScroll
                                        onCheckedChanged: {
                                            if (!deviceCard.loaded) return
                                            if (checked === deviceCard.devNaturalScroll) return
                                            deviceCard.devNaturalScroll = checked
                                            HyprlandConfig.setDevice(deviceCard.name, { natural_scroll: checked ? "true" : "false" })
                                        }
                                    }

                                    ConfigSwitch {
                                        buttonIcon: "front_hand"
                                        text: Translation.tr("Left handed mode")
                                        checked: deviceCard.devLeftHanded
                                        onCheckedChanged: {
                                            if (!deviceCard.loaded) return
                                            if (checked === deviceCard.devLeftHanded) return
                                            deviceCard.devLeftHanded = checked
                                            HyprlandConfig.setDevice(deviceCard.name, { left_handed: checked ? "true" : "false" })
                                        }
                                    }
                                }


                                // Touchpad-only options
                                GroupedList {
                                    visible: deviceCard.isTouchpad
                                    ConfigSwitch {
                                        buttonIcon: "touch_app"
                                        text: Translation.tr("Tap to click")
                                        checked: deviceCard.devTapToClick
                                        onCheckedChanged: {
                                            if (!deviceCard.loaded) return
                                            if (checked === deviceCard.devTapToClick) return
                                            deviceCard.devTapToClick = checked
                                            HyprlandConfig.setDevice(deviceCard.name, { tap_to_click: checked ? "true" : "false" })
                                        }
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }

        // Idle
        ContentSection {
            id: idleSection
            icon: "timer"
            shape: MaterialShape.Shape.Cookie12Sided
            title: Translation.tr("Idle")

            readonly property list<var> unitOptions: [
                { displayName: Translation.tr("Seconds"), icon: "timer",    value: 1    },
                { displayName: Translation.tr("Minutes"), icon: "av_timer", value: 60   },
                { displayName: Translation.tr("Hours"),   icon: "schedule", value: 3600 },
            ]

            component IdleTimerRow: ConfigRow {
                id: timerRow

                property string icon
                property string label
                property int seconds: 0
                property int displayValue: 60
                property int displayUnit: 60
                property bool loaded: false

                signal edited(int newSeconds)

                onSecondsChanged: {
                    const display = idleSection.toDisplay(timerRow.seconds)
                    timerRow.displayValue = display[0]
                    timerRow.displayUnit = display[1]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.leftMargin: 8
                    OptionalMaterialSymbol {
                        icon: timerRow.icon
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        Layout.preferredWidth: 160
                        text: timerRow.label
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillWidth: true }
                    StyledSpinBox {
                        Layout.preferredWidth: 130
                        value: timerRow.displayValue
                        from: 0
                        to: 9999
                        stepSize: 1
                        onValueChanged: {
                            if (!timerRow.loaded) return
                            timerRow.displayValue = value
                            timerRow.edited(value * timerRow.displayUnit)
                        }
                    }
                }
                StyledComboBox {
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                    textRole: "displayName"
                    model: idleSection.unitOptions
                    currentIndex: idleSection.unitOptions.findIndex(o => o.value === timerRow.displayUnit)
                    onActivated: index => {
                        timerRow.displayUnit = idleSection.unitOptions[index].value
                        timerRow.edited(timerRow.displayValue * timerRow.displayUnit)
                    }
                }
            }

            function toDisplay(seconds) {
                if (seconds <= 0)
                    return [0, 60]
                if (seconds % 3600 === 0)
                    return [seconds / 3600, 3600]
                if (seconds % 60 === 0)
                    return [seconds / 60, 60]
                return [seconds, 1]
            }

            function applyIdle() {
                HyprlandConfig.setIdle(
                    Config.options.hyprland.idle.lock,
                    Config.options.hyprland.idle.screenOff,
                    Config.options.hyprland.idle.suspend
                )
            }

            GroupedList {
                IdleTimerRow {
                    icon: "lock_clock"
                    label: Translation.tr("Lock screen")
                    seconds: Config.options.hyprland.idle.lock
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.lock = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
                IdleTimerRow {
                    icon: "monitor"
                    label: Translation.tr("Screen off")
                    seconds: Config.options.hyprland.idle.screenOff
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.screenOff = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
                IdleTimerRow {
                    icon: "bedtime"
                    label: Translation.tr("Standby")
                    seconds: Config.options.hyprland.idle.suspend
                    onEdited: newSeconds => {
                        Config.options.hyprland.idle.suspend = newSeconds
                        idleSection.applyIdle()
                    }
                    Component.onCompleted: loaded = true
                }
            }
        }

        // Visual & Aesthetics
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Visual & Aesthetics")

            GroupedList {
                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Window Rounding")
                    value: Config.options.hyprland.decoration.rounding
                    from: 0; to: 30; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.rounding) return
                        Config.options.hyprland.decoration.rounding = value
                        HyprlandConfig.set("decoration:rounding", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Blur")
                    checked: Config.options.hyprland.decoration.blur.enabled
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.decoration.blur.enabled) return
                        Config.options.hyprland.decoration.blur.enabled = checked
                        HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "blur_circular"
                    text: Translation.tr("Blur Size")
                    value: Config.options.hyprland.decoration.blur.size
                    from: 1; to: 20; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.size) return
                        Config.options.hyprland.decoration.blur.size = value
                        HyprlandConfig.set("decoration:blur:size", value)
                    }
                }

                ConfigSpinBox {
                    icon: "layers"
                    text: Translation.tr("Blur Passes")
                    value: Config.options.hyprland.decoration.blur.passes
                    from: 1; to: 6; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.passes) return
                        Config.options.hyprland.decoration.blur.passes = value
                        HyprlandConfig.set("decoration:blur:passes", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "ev_shadow"
                    text: Translation.tr("Shadows")
                    checked: Config.options.hyprland.decoration.shadow.enabled
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.decoration.shadow.enabled) return
                        Config.options.hyprland.decoration.shadow.enabled = checked
                        HyprlandConfig.set("decoration:shadow:enabled", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "blur_linear"
                    text: Translation.tr("Shadow Range")
                    value: Config.options.hyprland.decoration.shadow.range
                    from: 1; to: 50; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.shadow.range) return
                        Config.options.hyprland.decoration.shadow.range = value
                        HyprlandConfig.set("decoration:shadow:range", value)
                    }
                }

                ConfigSpinBox {
                    icon: "margin"
                    text: Translation.tr("Gaps In")
                    value: Config.options.hyprland.general.gapsIn
                    from: 0; to: 40; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsIn) return
                        Config.options.hyprland.general.gapsIn = value
                        HyprlandConfig.set("general:gaps_in", value)
                    }
                }

                ConfigSpinBox {
                    icon: "open_in_full"
                    text: Translation.tr("Gaps Out")
                    value: Config.options.hyprland.general.gapsOut
                    from: 0; to: 60; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsOut) return
                        Config.options.hyprland.general.gapsOut = value
                        HyprlandConfig.set("general:gaps_out", value)
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Active Opacity")
                    value: Math.round(Config.options.hyprland.decoration.activeOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.activeOpacity) return
                        Config.options.hyprland.decoration.activeOpacity = newVal
                        HyprlandConfig.set("decoration:active_opacity", newVal)
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Inactive Opacity")
                    value: Math.round(Config.options.hyprland.decoration.inactiveOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.inactiveOpacity) return
                        Config.options.hyprland.decoration.inactiveOpacity = newVal
                        HyprlandConfig.set("decoration:inactive_opacity", newVal)
                    }
                }
                ConfigSpinBox {
                    icon: "border_outer"
                    text: Translation.tr("Border Size")
                    value: Config.options.hyprland.general.borderSize
                    from: 0; to: 10; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.borderSize) return
                        Config.options.hyprland.general.borderSize = value
                        HyprlandConfig.set("general:border_size", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "format_paint"
                    text: Translation.tr("Custom border colors")
                    checked: Config.options.hyprland.general.borderColor.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.general.borderColor.enable) return
                        Config.options.hyprland.general.borderColor.enable = checked
                        if (checked) HyprlandConfig.applyBorderColors()
                        else HyprlandConfig.resetBorderColors()
                    }
                }
            }
            

            ContentSubsection {
                Layout.topMargin: 10
                visible: Config.options.hyprland.general.borderColor.enable
                title: Translation.tr("Border Color Management")
                GroupedList {
                    visible: Config.options.hyprland.general.borderColor.enable

                    ColorSelectionArray {
                        icon: "border_color"
                        text: Translation.tr("Active border")
                        options: page.borderColorRoles
                        currentValue: Config.options.hyprland.general.borderColor.activeRole
                        onSelected: newValue => {
                            Config.options.hyprland.general.borderColor.activeRole = newValue
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Active border opacity")
                        value: Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100)
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            // Compared as integers: the spin box only holds whole percents.
                            if (value === Math.round(Config.options.hyprland.general.borderColor.activeOpacity * 100)) return
                            Config.options.hyprland.general.borderColor.activeOpacity = value / 100.0
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ColorSelectionArray {
                        icon: "border_color"
                        text: Translation.tr("Inactive border")
                        options: page.borderColorRoles
                        currentValue: Config.options.hyprland.general.borderColor.inactiveRole
                        onSelected: newValue => {
                            Config.options.hyprland.general.borderColor.inactiveRole = newValue
                            HyprlandConfig.applyBorderColors()
                        }
                    }

                    ConfigSpinBox {
                        icon: "opacity"
                        text: Translation.tr("Inactive border opacity")
                        value: Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100)
                        from: 0; to: 100; stepSize: 5
                        onValueChanged: {
                            // Compared as integers: the spin box only holds whole percents.
                            if (value === Math.round(Config.options.hyprland.general.borderColor.inactiveOpacity * 100)) return
                            Config.options.hyprland.general.borderColor.inactiveOpacity = value / 100.0
                            HyprlandConfig.applyBorderColors()
                        }
                    }
                }
            }
        }

        // Cursor
        ContentSection {
            icon: "mouse"
            shape: MaterialShape.Shape.Arrow
            title: Translation.tr("Cursor")
            GroupedList {
                ConfigComboBox {
                    buttonIcon: "mouse"
                    fieldWidth: 70
                    text: Translation.tr("Cursor theme")
                    model: [{ displayName: Translation.tr("Default"), value: "" }]
                        .concat(SystemTheming.cursorThemes.map(t => ({ displayName: t, value: t })))
                    currentValue: SystemTheming.currentCursorTheme
                    onSelected: newValue => SystemTheming.applyCursorTheme(newValue, SystemTheming.currentCursorSize)
                }

                ConfigSpinBox {
                    id: cursorSizeSpin
                    icon: "zoom_in"
                    text: Translation.tr("Cursor size")
                    value: SystemTheming.currentCursorSize
                    from: 16; to: 64; stepSize: 2
                    onValueChanged: {
                        if (value === SystemTheming.currentCursorSize) return
                        cursorSizeApplyTimer.restart()
                    }
                    Timer {
                        id: cursorSizeApplyTimer
                        interval: 500
                        repeat: false
                        onTriggered: SystemTheming.applyCursorTheme(SystemTheming.currentCursorTheme, cursorSizeSpin.value)
                    }
                }
            }
        }

        // Autostart Apps
        ContentSection {
            icon: "app_registration"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Autostart Apps")
            Layout.fillWidth: true

            AutostartApps {}
        }

        // Animations
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.hyprland.animations.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.animations.enable) return
                        Config.options.hyprland.animations.enable = checked
                        HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Presets")
                    icon: "present_to_all"
                    currentValue: Config.options.hyprland.animations.animation
                    onSelected: newValue => {
                        Config.options.hyprland.animations.animation = newValue
                        HyprlandConfig.setAnimPreset(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Elastic"),   icon: "move_selection_right", value: "fast"   },
                        { displayName: Translation.tr("Normal"),    icon: "animation",            value: "normal" },
                        { displayName: Translation.tr("Niri Like"), icon: "mobiledata_arrows",    value: "niri"   },
                    ]
                }
            }

            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 15
                text: Translation.tr("Animation presets require a require line in your hyprland.lua. Add the following line to enable presets:") + '\n\nrequire("hyprland/shellOverrides/animations")'

                Item { Layout.fillWidth: true }

                RippleButtonWithIcon {
                    id: copySourceButton
                    property bool justCopied: false
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: justCopied ? "check" : "content_copy"
                    mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy line")
                    onClicked: {
                        copySourceButton.justCopied = true
                        Quickshell.clipboardText = 'require("hyprland/shellOverrides/animations")'
                        revertSourceTimer.restart()
                    }
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    Timer {
                        id: revertSourceTimer
                        interval: 1500
                        onTriggered: copySourceButton.justCopied = false
                    }
                }
            }
        }
    }
}