import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: controller

    property bool wifiEnabled: false
    property string wifiCurrentSsid: ""
    property string wifiIfname: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiRefreshing: false
    property bool wifiConnecting: false
    property string wifiPasswordSsid: ""
    property string wifiStatusText: ""

    property alias wifiSnapshotProc: wifiSnapshotProc
    property alias wifiNetworksProc: wifiNetworksProc
    property alias wifiToggleProc: wifiToggleProc
    property alias wifiConnectProc: wifiConnectProc
    property alias wifiDisconnectProc: wifiDisconnectProc

    function splitNmcliFields(line) {
        let fields = []
        let current = ""
        let escaped = false

        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                current += ch
                escaped = false
                continue
            }

            if (ch === "\\") {
                escaped = true
                continue
            }

            if (ch === ":") {
                fields.push(current)
                current = ""
                continue
            }

            current += ch
        }

        if (escaped) current += "\\"
        fields.push(current)
        return fields
    }

    function refreshWifi(rescan) {
        if (!wifiSnapshotProc.running) wifiSnapshotProc.running = true
        if (!wifiNetworksProc.running) {
            if (rescan) controller.wifiNetworks = []
            controller.wifiRefreshing = true
            wifiNetworksProc.rescan = rescan
            wifiNetworksProc.running = true
        }
    }

    Process {
        id: wifiSnapshotProc
        command: ["bash", "-lc", "enabled=$(nmcli -t -f WIFI general status 2>/dev/null | head -n1); [ \"$enabled\" = \"enabled\" ] && en=1 || en=0; line=$(nmcli -t -f ACTIVE,SSID,SIGNAL,DEVICE dev wifi list --rescan no 2>/dev/null | awk -F: '$1==\"yes\" {print; exit}'); if [ -n \"$line\" ]; then rest=${line#yes:}; dev=${rest##*:}; rest=${rest%:*}; sig=${rest##*:}; ssid=${rest%:*}; printf '%s|%s|%s|%s\\n' \"$en\" \"$sig\" \"$ssid\" \"$dev\"; else printf '%s|0||\\n' \"$en\"; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out.length === 0) return

                const parts = out.split("|")
                controller.wifiEnabled = parts[0] === "1"
                controller.wifiSignal = parseInt(parts[1] || "0", 10) || 0
                controller.wifiCurrentSsid = parts.length > 2 ? parts[2] : ""
                controller.wifiIfname = parts.length > 3 ? parts[3] : ""
            }
        }
    }

    Process {
        id: wifiNetworksProc
        property bool rescan: false
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan ? "yes" : "no"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length === 0) return

                const fields = controller.splitNmcliFields(line)
                if (fields.length < 4) return

                const connected = fields[0] === "yes"
                const ssid = fields[1].length > 0 ? fields[1] : "<hidden>"
                const signal = parseInt(fields[2], 10) || 0
                const security = fields.slice(3).join(":")

                const current = controller.wifiNetworks.slice()
                let found = -1
                for (let i = 0; i < current.length; i++) {
                    if (current[i].ssid === ssid) {
                        found = i
                        break
                    }
                }

                const entry = {
                    ssid: ssid,
                    signal: signal,
                    security: security,
                    secure: security !== "" && security !== "--",
                    connected: connected
                }

                if (found >= 0) {
                    if (connected || signal > current[found].signal) current[found] = entry
                } else {
                    current.push(entry)
                }

                current.sort((a, b) => {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    return b.signal - a.signal
                })
                controller.wifiNetworks = current

                if (connected) {
                    controller.wifiCurrentSsid = ssid
                    controller.wifiSignal = signal
                }
            }
        }
        onExited: {
            controller.wifiRefreshing = false
            if (!wifiSnapshotProc.running) wifiSnapshotProc.running = true
        }
    }

    Process {
        id: wifiToggleProc
        property bool targetEnabled: false
        command: ["nmcli", "radio", "wifi", targetEnabled ? "on" : "off"]
        onExited: {
            controller.wifiStatusText = targetEnabled ? "Wi-Fi enabled" : "Wi-Fi disabled"
            controller.wifiPasswordSsid = ""
            controller.refreshWifi(true)
        }
    }

    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        property string targetPassword: ""
        property bool fallbackToPassword: false
        command: targetPassword.length > 0
            ? ["nmcli", "device", "wifi", "connect", targetSsid, "password", targetPassword]
            : ["nmcli", "device", "wifi", "connect", targetSsid]
        onStarted: {
            controller.wifiConnecting = true
            controller.wifiStatusText = "Connecting to " + targetSsid + "..."
        }
        onExited: code => {
            controller.wifiConnecting = false
            const triedWithoutPassword = targetPassword.length === 0

            if (code === 0) {
                controller.wifiPasswordSsid = ""
                controller.wifiStatusText = "Connected to " + targetSsid
            } else if (fallbackToPassword && triedWithoutPassword) {
                controller.wifiPasswordSsid = targetSsid
                controller.wifiStatusText = "Password required for " + targetSsid
            } else {
                controller.wifiStatusText = "Failed to connect to " + targetSsid
            }

            fallbackToPassword = false
            targetPassword = ""
            controller.refreshWifi(true)
        }
    }

    Process {
        id: wifiDisconnectProc
        command: ["nmcli", "device", "disconnect", controller.wifiIfname]
        onExited: code => {
            controller.wifiStatusText = code === 0 ? "Disconnected" : "Failed to disconnect"
            controller.refreshWifi(true)
        }
    }
}
