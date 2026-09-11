import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles as Models
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

import qs.modules.ii.sidebarRight.quickToggles.classicStyle

AbstractQuickPanel {
    id: root
    property bool editMode: false
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight
    color: "transparent"

    readonly property int maxColumns: 9
    readonly property int activeColumns: Math.min(maxColumns, Math.max(1, root.toggles.length))

    readonly property list<string> availableToggleTypes: {
        const base = [
            "network", "bluetooth", "idleInhibitor", "easyEffects", "nightLight",
            "darkMode", "cloudflareWarp", "gameMode", "screenSnip", "colorPicker",
            "onScreenKeyboard", "mic", "audio", "notifications", "powerProfile",
            "musicRecognition", "antiFlashbang"
        ];
        return WM.compositor === "hyprland" ? base : base.filter(t => t !== "gameMode");
    }

    readonly property list<string> defaultToggles: [
        "network",
        "bluetooth",
        "nightLight",
        "gameMode",
        "idleInhibitor",
        "easyEffects",
        "cloudflareWarp"
    ]

    readonly property list<string> toggles: {
        if (!Config.ready) return defaultToggles;
        const conf = Config.options?.sidebar?.quickToggles?.classic?.toggles;
        if (!conf || conf.length === 0) return defaultToggles;
        return WM.compositor === "hyprland" ? conf : conf.filter(t => t !== "gameMode");
    }

    readonly property list<string> unusedToggles: {
        return availableToggleTypes.filter(t => !root.toggles.includes(t));
    }

    function addToggle(type: string): void {
        let current = Array.from(root.toggles);
        if (!current.includes(type)) {
            current.push(type);
            saveToggles(current);
        }
    }

    function removeToggle(type: string): void {
        let current = Array.from(root.toggles);
        const idx = current.indexOf(type);
        if (idx !== -1) {
            current.splice(idx, 1);
            saveToggles(current);
        }
    }

    function saveToggles(newList: var): void {
        if (!Config.options.sidebar.quickToggles.classic) {
            Config.options.sidebar.quickToggles.classic = {};
        }
        Config.options.sidebar.quickToggles.classic.toggles = newList;
    }

    function openMenuForType(type: string): void {
        switch (type) {
            case "network":
                root.openWifiDialog();
                break;
            case "bluetooth":
                root.openBluetoothDialog();
                break;
            case "nightLight":
                root.openNightLightDialog();
                break;
            case "audio":
                root.openAudioOutputDialog();
                break;
            case "mic":
                root.openAudioInputDialog();
                break;
        }
    }

    // Toggle models
    Models.NetworkToggle { id: networkModel }
    Models.BluetoothToggle { id: bluetoothModel }
    Models.NightLightToggle { id: nightLightModel }
    Models.GameModeToggle { id: gameModeModel }
    Models.IdleInhibitorToggle { id: idleInhibitorModel }
    Models.EasyEffectsToggle { id: easyEffectsModel }
    Models.CloudflareWarpToggle { id: cloudflareWarpModel }
    Models.DarkModeToggle { id: darkModeModel }
    Models.ScreenSnipToggle { id: screenSnipModel }
    Models.ColorPickerToggle { id: colorPickerModel }
    Models.OnScreenKeyboardToggle { id: onScreenKeyboardModel }
    Models.MicToggle { id: micModel }
    Models.AudioToggle { id: audioModel }
    Models.NotificationToggle { id: notificationsModel }
    Models.PowerProfilesToggle { id: powerProfileModel }
    Models.MusicRecognitionToggle { id: musicRecognitionModel }
    Models.AntiFlashbangToggle { id: antiFlashbangModel }

    function getModelForType(type: string): var {
        switch (type) {
            case "network": return networkModel;
            case "bluetooth": return bluetoothModel;
            case "nightLight": return nightLightModel;
            case "gameMode": return gameModeModel;
            case "idleInhibitor": return idleInhibitorModel;
            case "easyEffects": return easyEffectsModel;
            case "cloudflareWarp": return cloudflareWarpModel;
            case "darkMode": return darkModeModel;
            case "screenSnip": return screenSnipModel;
            case "colorPicker": return colorPickerModel;
            case "onScreenKeyboard": return onScreenKeyboardModel;
            case "mic": return micModel;
            case "audio": return audioModel;
            case "notifications": return notificationsModel;
            case "powerProfile": return powerProfileModel;
            case "musicRecognition": return musicRecognitionModel;
            case "antiFlashbang": return antiFlashbangModel;
            default: return null;
        }
    }

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    Column {
        id: mainColumn
        spacing: 10
        anchors.horizontalCenter: parent.horizontalCenter

        // Active toggles container
        Rectangle {
            id: activeGroup
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: activeGrid.implicitWidth + 16
            implicitHeight: activeGrid.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Grid {
                id: activeGrid
                anchors.centerIn: parent
                columns: root.activeColumns
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.toggles
                    ClassicQuickToggleButton {
                        required property string modelData
                        buttonType: modelData
                        toggleModel: root.getModelForType(modelData)
                        editMode: root.editMode
                        isUnused: false
                        onRemoveRequested: root.removeToggle(modelData)
                        onOpenMenu: root.openMenuForType(modelData)
                    }
                }
            }
        }

        // Edit mode: divider + available toggles
        FadeLoader {
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.editMode
            sourceComponent: Column {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: unusedGroup.implicitWidth
                    implicitHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("Available toggles (click to add)")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }

                Rectangle {
                    id: unusedGroup
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: unusedGrid.implicitWidth + 16
                    implicitHeight: unusedGrid.implicitHeight + 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    Grid {
                        id: unusedGrid
                        anchors.centerIn: parent
                        columns: Math.min(root.maxColumns, Math.max(1, root.unusedToggles.length))
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: root.unusedToggles
                            ClassicQuickToggleButton {
                                required property string modelData
                                buttonType: modelData
                                toggleModel: root.getModelForType(modelData)
                                editMode: root.editMode
                                isUnused: true
                                onAddRequested: root.addToggle(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
