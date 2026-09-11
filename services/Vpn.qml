pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * VPN service with nmcli.
 */
Singleton {
    id: root

    property list<var> vpnList: []
    readonly property var activeVpn: vpnList.find(v => v.active) ?? null
    readonly property bool isConnected: activeVpn !== null
    readonly property string activeVpnName: activeVpn ? activeVpn.name : ""
    readonly property string activeVpnType: activeVpn ? activeVpn.type : ""

    property bool isConnecting: connectProc.running || interactiveProc.running
    property string connectingUuid: ""
    property string connectingName: ""
    property string lastConnectedUuid: ""

    readonly property list<var> friendlyVpnList: {
        const copy = [...vpnList];
        copy.sort((a, b) => {
            if (a.active && !b.active) return -1;
            if (!a.active && b.active) return 1;
            return (a.name || "").localeCompare(b.name || "");
        });
        return copy;
    }

    readonly property string materialSymbol: isConnected
        ? "vpn_key"
        : (isConnecting ? "vpn_key_alert" : "vpn_key_off")

    readonly property string statusText: isConnected
        ? activeVpnName
        : (isConnecting ? Translation.tr("Connecting...") : Translation.tr("Disconnected"))

    property var authRequiredUuids: ({})

    property bool _pendingUpdate: false

    function isAuthRequired(uuid) {
        return Boolean(authRequiredUuids[uuid]);
    }

    function update() {
        if (fetchProc.running) {
            _pendingUpdate = true;
            return;
        }
        fetchProc.running = true;
    }

    function cancelConnect() {
        if (connectProc.running) connectProc.running = false;
        if (interactiveProc.running) interactiveProc.running = false;
        connectingUuid = "";
        connectingName = "";
    }

    function connectVpnInteractive(uuid, name = "") {
        if (!uuid) return;
        cancelConnect();

        const targetName = name || (vpnList.find(v => v.uuid === uuid)?.name ?? "");
        connectingUuid = uuid;
        connectingName = targetName;
        lastConnectedUuid = uuid;
        interactiveProc.targetUuid = uuid;
        interactiveProc.targetName = targetName;
        interactiveProc.exec(["python3", `${Directories.scriptPath}/vpn/connect_vpn_gui.py`, uuid, targetName]);
    }

    function connectVpn(uuid, name = "") {
        if (!uuid || isConnecting) return;
        if (isAuthRequired(uuid)) {
            connectVpnInteractive(uuid, name);
            return;
        }
        connectingUuid = uuid;
        connectingName = name || (vpnList.find(v => v.uuid === uuid)?.name ?? "");
        lastConnectedUuid = uuid;
        connectProc.targetUuid = uuid;
        connectProc.targetName = connectingName;
        connectProc.exec(["nmcli", "connection", "up", "uuid", uuid]);
    }

    function disconnectVpn(uuid) {
        if (!uuid) return;
        disconnectProc.exec(["nmcli", "connection", "down", "uuid", uuid]);
    }

    function toggleVpn() {
        if (isConnected) {
            if (activeVpn && activeVpn.uuid) {
                disconnectVpn(activeVpn.uuid);
            }
        } else {
            if (lastConnectedUuid && vpnList.some(v => v.uuid === lastConnectedUuid)) {
                connectVpn(lastConnectedUuid);
            } else if (vpnList.length > 0) {
                connectVpn(vpnList[0].uuid, vpnList[0].name);
            }
        }
    }

    function disconnectAll() {
        for (const vpn of vpnList) {
            if (vpn.active) {
                disconnectVpn(vpn.uuid);
            }
        }
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    Process {
        id: fetchProc
        running: true
        command: ["nmcli", "-g", "NAME,UUID,TYPE,DEVICE,ACTIVE,STATE", "connection", "show"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const vpnTypes = ["vpn", "wireguard", "tun", "tap", "ipsec"];
                const PLACEHOLDER = "\u0000";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");
                const list = [];

                for (const line of lines) {
                    if (!line) continue;
                    const parts = line.replace(rep, PLACEHOLDER).split(":");
                    if (parts.length >= 5) {
                        const type = parts[2]?.toLowerCase() ?? "";
                        if (vpnTypes.includes(type)) {
                            const name = (parts[0] || "").replace(rep2, ":");
                            const uuid = parts[1] || "";
                            const device = parts[3] || "";
                            const active = parts[4] === "yes";
                            const state = parts[5] || "";

                            if (active) {
                                root.lastConnectedUuid = uuid;
                            }

                            list.push({
                                name: name,
                                uuid: uuid,
                                type: type,
                                device: device,
                                active: active,
                                state: state
                            });
                        }
                    }
                }
                root.vpnList = list;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root._pendingUpdate) {
                root._pendingUpdate = false;
                fetchProc.running = true;
            }
        }
    }

    Process {
        id: connectProc
        property string targetUuid: ""
        property string targetName: ""
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stderr: StdioCollector {
            id: connectStderr
        }
        stdout: StdioCollector {
            id: connectStdout
        }
        onExited: (exitCode, exitStatus) => {
            const uuid = connectProc.targetUuid;
            const name = connectProc.targetName;
            root.connectingUuid = "";
            root.connectingName = "";
            root.update();

            if (exitCode !== 0) {
                const err = connectStderr.text.trim() || connectStdout.text.trim();
                const isAuthError = err.includes("No valid secrets") ||
                                    err.includes("cannot ask without '--ask'") ||
                                    err.includes("Secrets were required") ||
                                    err.includes("password for") ||
                                    err.includes("failed verification");

                if (isAuthError && uuid) {
                    const newMap = Object.assign({}, root.authRequiredUuids);
                    newMap[uuid] = true;
                    root.authRequiredUuids = newMap;

                    // Automatically launch GUI prompt
                    root.connectVpnInteractive(uuid, name);
                } else {
                    Quickshell.execDetached(["notify-send",
                        Translation.tr("VPN Connection Failed"),
                        err || Translation.tr("Failed to connect to VPN"),
                        "-a", "Shell",
                        "-i", "network-vpn"
                    ]);
                }
            } else if (uuid && root.authRequiredUuids[uuid]) {
                const newMap = Object.assign({}, root.authRequiredUuids);
                delete newMap[uuid];
                root.authRequiredUuids = newMap;
            }
        }
    }

    Process {
        id: interactiveProc
        property string targetUuid: ""
        property string targetName: ""
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stderr: StdioCollector {
            id: interactiveStderr
        }
        stdout: StdioCollector {
            id: interactiveStdout
        }
        onExited: (exitCode, exitStatus) => {
            const uuid = interactiveProc.targetUuid;
            const name = interactiveProc.targetName;
            root.connectingUuid = "";
            root.connectingName = "";
            root.update();

            if (exitCode === 0) {
                if (uuid && root.authRequiredUuids[uuid]) {
                    const newMap = Object.assign({}, root.authRequiredUuids);
                    delete newMap[uuid];
                    root.authRequiredUuids = newMap;
                }
                Quickshell.execDetached(["notify-send",
                    Translation.tr("VPN Connected"),
                    Translation.tr("Connected to %1").arg(name || uuid),
                    "-a", "Shell",
                    "-i", "network-vpn"
                ]);
            } else if (exitCode === 130) {
                // Cancelled by user
            } else {
                const err = interactiveStderr.text.trim() || interactiveStdout.text.trim();
                Quickshell.execDetached(["notify-send",
                    Translation.tr("VPN Connection Failed"),
                    err || Translation.tr("Failed to connect to VPN"),
                    "-a", "Shell",
                    "-i", "network-vpn"
                ]);
            }
        }
    }

    Process {
        id: disconnectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        onExited: (exitCode, exitStatus) => {
            root.update();
        }
    }
}
