import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: controller

    property bool btEnabled: false
    property bool btConnected: false
    property bool btRefreshing: false
    property bool btScanning: false
    property bool btBusy: false
    property var btPairedDevices: []
    property var btAvailableDevices: []
    property string btStatusText: ""

    property alias btStatusProc: btStatusProc
    property alias btPairedProc: btPairedProc
    property alias btDevicesProc: btDevicesProc
    property alias btPowerProc: btPowerProc
    property alias btScanProc: btScanProc
    property alias btActionProc: btActionProc

    function refreshBluetooth() {
        if (!btStatusProc.running) btStatusProc.running = true
        if (!btPairedProc.running) {
            controller.btRefreshing = true
            controller.btPairedDevices = []
            controller.btConnected = false
            btPairedProc.running = true
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-lc", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && p=1 || p=0; bluetoothctl devices Connected 2>/dev/null | grep -q '^Device ' && c=1 || c=0; printf '%s|%s\\n' \"$p\" \"$c\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim().split("|")
                controller.btEnabled = (out[0] || "0") === "1"
                controller.btConnected = (out[1] || "0") === "1"
            }
        }
    }

    Process {
        id: btPairedProc
        command: ["bash", "-lc", "bluetoothctl devices 2>/dev/null | while read -r tag mac name; do [ \"$tag\" = \"Device\" ] || continue; info=$(bluetoothctl info \"$mac\" 2>/dev/null); echo \"$info\" | grep -q 'Paired: yes' || continue; echo \"$info\" | grep -q 'Connected: yes' && connected=1 || connected=0; battery=$(echo \"$info\" | grep -Eo 'Battery Percentage:.*\\([0-9]+\\)' | grep -Eo '\\([0-9]+\\)' | tr -d '()' | head -n1); if [ -z \"$battery\" ]; then battery=$(echo \"$info\" | grep -Eo 'Battery Percentage:[[:space:]]*[0-9]+%' | grep -Eo '[0-9]+' | head -n1); fi; [ -z \"$battery\" ] && battery=-1; printf '%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$connected\" \"$battery\" \"$name\"; done"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length === 0) return
                const parts = line.split("\t")
                if (parts.length < 4) return

                const current = controller.btPairedDevices.slice()
                const connected = parts[1] === "1"
                current.push({
                    mac: parts[0],
                    connected: connected,
                    battery: parseInt(parts[2], 10),
                    name: parts.slice(3).join("\t")
                })
                controller.btPairedDevices = current
                if (connected) controller.btConnected = true
            }
        }
        onExited: {
            controller.btPairedDevices.sort((a, b) => {
                if (a.connected !== b.connected) return a.connected ? -1 : 1
                return a.name.localeCompare(b.name)
            })
            controller.btAvailableDevices = []
            btDevicesProc.running = true
        }
    }

    Process {
        id: btDevicesProc
        command: ["bash", "-lc", "bluetoothctl devices 2>/dev/null | while read -r tag mac name; do [ \"$tag\" = \"Device\" ] || continue; info=$(bluetoothctl info \"$mac\" 2>/dev/null); battery=$(echo \"$info\" | grep -Eo 'Battery Percentage:.*\\([0-9]+\\)' | grep -Eo '\\([0-9]+\\)' | tr -d '()' | head -n1); if [ -z \"$battery\" ]; then battery=$(echo \"$info\" | grep -Eo 'Battery Percentage:[[:space:]]*[0-9]+%' | grep -Eo '[0-9]+' | head -n1); fi; [ -z \"$battery\" ] && battery=-1; printf '%s\\t%s\\t%s\\n' \"$mac\" \"$battery\" \"$name\"; done"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length === 0) return
                const parts = line.split("\t")
                if (parts.length < 3) return

                const mac = parts[0]
                const battery = parseInt(parts[1], 10)
                const name = parts.slice(2).join("\t")

                for (let i = 0; i < controller.btPairedDevices.length; i++) {
                    if (controller.btPairedDevices[i].mac === mac) return
                }

                const current = controller.btAvailableDevices.slice()
                for (let i = 0; i < current.length; i++) {
                    if (current[i].mac === mac) return
                }

                current.push({ mac: mac, battery: battery, name: name })
                current.sort((a, b) => a.name.localeCompare(b.name))
                controller.btAvailableDevices = current
            }
        }
        onExited: controller.btRefreshing = false
    }

    Process {
        id: btPowerProc
        property bool targetEnabled: false
        command: ["bluetoothctl", "power", targetEnabled ? "on" : "off"]
        onStarted: controller.btBusy = true
        onExited: {
            controller.btBusy = false
            controller.btStatusText = targetEnabled ? "Bluetooth enabled" : "Bluetooth disabled"
            controller.refreshBluetooth()
        }
    }

    Process {
        id: btScanProc
        command: ["bash", "-lc", "timeout 8s bluetoothctl scan on >/dev/null 2>&1"]
        onStarted: {
            controller.btScanning = true
            controller.btStatusText = "Scanning for devices..."
        }
        onExited: {
            controller.btScanning = false
            controller.btStatusText = "Scan finished"
            controller.refreshBluetooth()
        }
    }

    Process {
        id: btActionProc
        property string mode: ""
        property string mac: ""
        property string deviceName: ""
        command: {
            if (mode === "connect") return ["bluetoothctl", "connect", mac]
            if (mode === "disconnect") return ["bluetoothctl", "disconnect", mac]
            if (mode === "pairconnect") return ["bash", "-lc", "bluetoothctl pair " + mac + " && bluetoothctl trust " + mac + " && bluetoothctl connect " + mac]
            return ["bash", "-lc", "true"]
        }
        onStarted: {
            controller.btBusy = true
            if (mode === "disconnect") controller.btStatusText = "Disconnecting " + deviceName + "..."
            else if (mode === "pairconnect") controller.btStatusText = "Pairing " + deviceName + "..."
            else controller.btStatusText = "Connecting " + deviceName + "..."
        }
        onExited: code => {
            controller.btBusy = false
            if (code === 0) {
                if (mode === "disconnect") controller.btStatusText = "Disconnected " + deviceName
                else controller.btStatusText = "Connected " + deviceName
            } else {
                controller.btStatusText = "Action failed for " + deviceName
            }
            controller.refreshBluetooth()
        }
    }
}
