//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    property string time
    property string gpuTemp
    property string cpuTemp
    property string cpuUsage
    property string gpuUsage
    property string ramUsage

    property bool quickMenuVisible: false
    property string quickMenuType: ""
    property var quickMenuScreen: null
    property real quickMenuRightMargin: 10
    property int quickMenuWidth: 340

    property bool wifiEnabled: false
    property string wifiCurrentSsid: ""
    property string wifiIfname: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiRefreshing: false
    property bool wifiConnecting: false
    property string wifiPasswordSsid: ""
    property string wifiStatusText: ""

    property bool btEnabled: false
    property bool btConnected: false
    property bool btRefreshing: false
    property bool btScanning: false
    property bool btBusy: false
    property var btPairedDevices: []
    property var btAvailableDevices: []
    property string btStatusText: ""

    Theme {id: theme}

    readonly property var activePlayer: {
        for (let i = 0; i < Mpris.players.values.length; i++) {
            if (Mpris.players.values[i].playbackState === MprisPlaybackState.Playing) {
                return Mpris.players.values[i]
            }
        }
        return Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    }

    property var defaultSink: Pipewire.defaultAudioSink

    // Using PwObjectTracker to ensure the object is bound and updated
    PwObjectTracker {
        objects: [defaultSink]
      }

    function getCurrentVolume() {
        if (!defaultSink?.audio) return 0
        
        if (defaultSink.audio.volumes && defaultSink.audio.volumes.length > 0) {
            let sum = 0
            for (let i = 0; i < defaultSink.audio.volumes.length; i++) {
                sum += defaultSink.audio.volumes[i]
            }
            return sum / defaultSink.audio.volumes.length
        }
        
        return defaultSink.audio.volume || 0
    }

    function setVolume(newVolume) {
        if (!defaultSink?.audio) return
        
        newVolume = Math.max(0.0, Math.min(1.0, newVolume))
        
        if (defaultSink.audio.volumes) {
            let newVolumes = []
            for (let i = 0; i < defaultSink.audio.volumes.length; i++) {
                newVolumes.push(newVolume)
            }
            defaultSink.audio.volumes = newVolumes
        }
    }

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

    function wifiGlyph() {
        if (!root.wifiEnabled) return "󰖪"
        if (root.wifiCurrentSsid === "") return "󰤯"
        if (root.wifiSignal >= 80) return "󰤨"
        if (root.wifiSignal >= 60) return "󰤥"
        if (root.wifiSignal >= 40) return "󰤢"
        if (root.wifiSignal >= 20) return "󰤟"
        return "󰤯"
    }

    function bluetoothGlyph() {
        if (!root.btEnabled) return "󰂲"
        if (root.btConnected) return "󰂱"
        return "󰂯"
    }

    function openQuickMenu(type, screenRef, rightMargin) {
        if (root.quickMenuVisible && root.quickMenuType === type && root.quickMenuScreen === screenRef) {
            root.closeQuickMenu()
            return
        }

        root.quickMenuType = type
        root.quickMenuScreen = screenRef
        root.quickMenuRightMargin = rightMargin
        root.quickMenuVisible = true

        if (type === "wifi") {
            root.btStatusText = ""
            root.refreshWifi(true)
        } else if (type === "bluetooth") {
            root.wifiPasswordSsid = ""
            root.wifiStatusText = ""
            root.refreshBluetooth()
        }
    }

    function closeQuickMenu() {
        root.quickMenuVisible = false
        root.quickMenuScreen = null
        root.wifiPasswordSsid = ""
    }

    function refreshWifi(rescan) {
        if (!wifiSnapshotProc.running) wifiSnapshotProc.running = true
        if (!wifiNetworksProc.running) {
            if (rescan) root.wifiNetworks = []
            root.wifiRefreshing = true
            wifiNetworksProc.rescan = rescan
            wifiNetworksProc.running = true
        }
    }

    function refreshBluetooth() {
        if (!btStatusProc.running) btStatusProc.running = true
        if (!btPairedProc.running) {
            root.btRefreshing = true
            root.btPairedDevices = []
            root.btConnected = false
            btPairedProc.running = true
        }
    }
       
    Process {
        id: dateProc
        command: ["date", "+%I:%M %p"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.time = this.text
        }
    }

    Process {
        id: gpuTempProc
        command: ["bash", "-c", "cat /sys/class/hwmon/hwmon1/temp1_input | awk '{printf \"%.0f\", $1 / 1000}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpuTemp = this.text
            }
        }
    }

    Process {
        id: cpuTempProc
        command: ["bash", "-c", "cat /sys/class/hwmon/hwmon2/temp1_input | awk '{printf \"%.0f\", $1 / 1000}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTemp = this.text
            }
        }
    }

    Process {
        id: ramUsageProc
        command: ["bash", "-c", "free | grep Mem | awk '{printf \"%.0f\", $3/$2 * 100}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.ramUsage = this.text
            }
        }
    }

    Process {
        id: gpuUsageProc
        command: ["cat", "/sys/class/drm/card1/device/gpu_busy_percent"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpuUsage = this.text.trim()
            }
        }
    }

    Process {
        id: cpuUsageProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{printf \"%.0f\", 100 - $8}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuUsage = this.text.trim()
            }
        }
      }

    Process {
        id: pavucontrolProcess
        command: ["pavucontrol"]
    }
    
    Process {
        id: networkManagerDmenuProcess
        command: ["networkmanager_dmenu"]
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
                root.wifiEnabled = parts[0] === "1"
                root.wifiSignal = parseInt(parts[1] || "0", 10) || 0
                root.wifiCurrentSsid = parts.length > 2 ? parts[2] : ""
                root.wifiIfname = parts.length > 3 ? parts[3] : ""
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

                const fields = root.splitNmcliFields(line)
                if (fields.length < 4) return

                const connected = fields[0] === "yes"
                const ssid = fields[1].length > 0 ? fields[1] : "<hidden>"
                const signal = parseInt(fields[2], 10) || 0
                const security = fields.slice(3).join(":")

                const current = root.wifiNetworks.slice()
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
                root.wifiNetworks = current

                if (connected) {
                    root.wifiCurrentSsid = ssid
                    root.wifiSignal = signal
                }
            }
        }
        onExited: {
            root.wifiRefreshing = false
            if (!wifiSnapshotProc.running) wifiSnapshotProc.running = true
        }
    }

    Process {
        id: wifiToggleProc
        property bool targetEnabled: false
        command: ["nmcli", "radio", "wifi", targetEnabled ? "on" : "off"]
        onExited: {
            root.wifiStatusText = targetEnabled ? "Wi-Fi enabled" : "Wi-Fi disabled"
            root.wifiPasswordSsid = ""
            root.refreshWifi(true)
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
            root.wifiConnecting = true
            root.wifiStatusText = "Connecting to " + targetSsid + "..."
        }
        onExited: code => {
            root.wifiConnecting = false
            const triedWithoutPassword = targetPassword.length === 0

            if (code === 0) {
                root.wifiPasswordSsid = ""
                root.wifiStatusText = "Connected to " + targetSsid
            } else if (fallbackToPassword && triedWithoutPassword) {
                root.wifiPasswordSsid = targetSsid
                root.wifiStatusText = "Password required for " + targetSsid
                if (root.quickMenuVisible && root.quickMenuType === "wifi") wifiPasswordInput.forceActiveFocus()
            } else {
                root.wifiStatusText = "Failed to connect to " + targetSsid
            }

            fallbackToPassword = false
            targetPassword = ""
            root.refreshWifi(true)
        }
    }

    Process {
        id: wifiDisconnectProc
        command: ["nmcli", "device", "disconnect", root.wifiIfname]
        onExited: code => {
            root.wifiStatusText = code === 0 ? "Disconnected" : "Failed to disconnect"
            root.refreshWifi(true)
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-lc", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && p=1 || p=0; bluetoothctl devices Connected 2>/dev/null | grep -q '^Device ' && c=1 || c=0; printf '%s|%s\\n' \"$p\" \"$c\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim().split("|")
                root.btEnabled = (out[0] || "0") === "1"
                root.btConnected = (out[1] || "0") === "1"
            }
        }
    }

    Process {
        id: btPairedProc
        command: ["bash", "-lc", "bluetoothctl devices 2>/dev/null | while read -r tag mac name; do [ \"$tag\" = \"Device\" ] || continue; info=$(bluetoothctl info \"$mac\" 2>/dev/null); echo \"$info\" | grep -q 'Paired: yes' || continue; echo \"$info\" | grep -q 'Connected: yes' && connected=1 || connected=0; printf '%s\\t%s\\t%s\\n' \"$mac\" \"$connected\" \"$name\"; done"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length === 0) return
                const parts = line.split("\t")
                if (parts.length < 3) return

                const current = root.btPairedDevices.slice()
                const connected = parts[1] === "1"
                current.push({
                    mac: parts[0],
                    connected: connected,
                    name: parts.slice(2).join("\t")
                })
                root.btPairedDevices = current
                if (connected) root.btConnected = true
            }
        }
        onExited: {
            root.btPairedDevices.sort((a, b) => {
                if (a.connected !== b.connected) return a.connected ? -1 : 1
                return a.name.localeCompare(b.name)
            })
            root.btAvailableDevices = []
            btDevicesProc.running = true
        }
    }

    Process {
        id: btDevicesProc
        command: ["bash", "-lc", "bluetoothctl devices 2>/dev/null | while read -r tag mac name; do [ \"$tag\" = \"Device\" ] || continue; printf '%s\\t%s\\n' \"$mac\" \"$name\"; done"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length === 0) return
                const parts = line.split("\t")
                if (parts.length < 2) return

                const mac = parts[0]
                const name = parts.slice(1).join("\t")

                for (let i = 0; i < root.btPairedDevices.length; i++) {
                    if (root.btPairedDevices[i].mac === mac) return
                }

                const current = root.btAvailableDevices.slice()
                for (let i = 0; i < current.length; i++) {
                    if (current[i].mac === mac) return
                }

                current.push({ mac: mac, name: name })
                current.sort((a, b) => a.name.localeCompare(b.name))
                root.btAvailableDevices = current
            }
        }
        onExited: root.btRefreshing = false
    }

    Process {
        id: btPowerProc
        property bool targetEnabled: false
        command: ["bluetoothctl", "power", targetEnabled ? "on" : "off"]
        onStarted: root.btBusy = true
        onExited: {
            root.btBusy = false
            root.btStatusText = targetEnabled ? "Bluetooth enabled" : "Bluetooth disabled"
            root.refreshBluetooth()
        }
    }

    Process {
        id: btScanProc
        command: ["bash", "-lc", "timeout 8s bluetoothctl scan on >/dev/null 2>&1"]
        onStarted: {
            root.btScanning = true
            root.btStatusText = "Scanning for devices..."
        }
        onExited: {
            root.btScanning = false
            root.btStatusText = "Scan finished"
            root.refreshBluetooth()
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
            root.btBusy = true
            if (mode === "disconnect") root.btStatusText = "Disconnecting " + deviceName + "..."
            else if (mode === "pairconnect") root.btStatusText = "Pairing " + deviceName + "..."
            else root.btStatusText = "Connecting " + deviceName + "..."
        }
        onExited: code => {
            root.btBusy = false
            if (code === 0) {
                if (mode === "disconnect") root.btStatusText = "Disconnected " + deviceName
                else root.btStatusText = "Connected " + deviceName
            } else {
                root.btStatusText = "Action failed for " + deviceName
            }
            root.refreshBluetooth()
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            if (!wifiSnapshotProc.running) wifiSnapshotProc.running = true
            if (root.quickMenuVisible && root.quickMenuType === "wifi") root.refreshWifi(false)
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!btStatusProc.running) btStatusProc.running = true
            if (root.quickMenuVisible && root.quickMenuType === "bluetooth" && !btPairedProc.running) root.refreshBluetooth()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            dateProc.running = true
            gpuTempProc.running = true
            cpuTempProc.running = true
            cpuUsageProc.running = true
            gpuUsageProc.running = true
            ramUsageProc.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            property var modelData: modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 42
            color: "transparent"

            margins {
                left: 10
                right: 10
                top: 5
            }

            // LEFT SECTION
            Row {
                id: leftModules
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Workspaces
                Rectangle {
                    implicitHeight: 35
                    implicitWidth: wsRow.width + 28
                    radius: 15
                    color: theme.bgColor

                    Row {
                        id: wsRow
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                width: 16
                                height: 25
                                radius: 6
                                color: modelData.focused ? theme.accentColor : "transparent"

                                CryoText {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: modelData.focused ? theme.fgColor : theme.fgColor
                                }
                            }
                        }
                    }
                }

                // Window Title
                Rectangle {
                    implicitHeight: 35
                    implicitWidth: Math.min(windowText.implicitWidth + 25, 300)
                    radius: 15
                    color: theme.bgColor

                    CryoText {
                        id: windowText
                        anchors.centerIn: parent
                        text: Hyprland.activeToplevel?.title || "Empty"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 250)
                    }
                }

                // Media
                Rectangle {
                    implicitHeight: 35
                    implicitWidth: Math.min(mediaContent.width + 24, 300)
                    radius: 15
                    color: theme.bgColor
                    visible: activePlayer !== null

                        Row {
                            id: mediaContent
                            anchors.centerIn: parent
                            spacing: 6

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 7
                            color: mediaIconMouse.containsMouse
                                ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            CryoText {
                                anchors.centerIn: parent
                                text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "󰝚" : "󰏤"
                            }

                            MouseArea {
                                id: mediaIconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }

                        CryoText {
                            text: (activePlayer?.trackTitle || "Unknown") + " - " + (activePlayer?.trackArtist || "Unknown")
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 200)
                        }
                    }
                }
            }

            // CENTER SECTION
            Rectangle {
                id: centerModule
                anchors.centerIn: parent
                implicitHeight: 35
                implicitWidth: dateText.implicitWidth + 25
                radius: 15
                color: theme.bgColor

                CryoText {
                    id: dateText
                    anchors.centerIn: parent
                    text: root.time
                }
            }

            // RIGHT SECTION
            Row {
                id: rightModules
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    id: tempSectionContainer
                    implicitHeight: 35
                    implicitWidth: tempSection.width + 24
                    radius: 15
                    color: theme.bgColor

                    Row {
                        id: tempSection
                        anchors.centerIn: parent
                        spacing: 8

                        Row {
                            spacing: 4
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 7
                                color: cpuTempHover.containsMouse
                                    ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 140 } }
                                CryoText {
                                    anchors.centerIn: parent
                                    text: ""
                                }
                                MouseArea {
                                    id: cpuTempHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                            CryoText { text: root.cpuTemp + "°C" }
                        }

                        Row {
                            spacing: 4
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 7
                                color: gpuTempHover.containsMouse
                                    ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 140 } }
                                CryoText {
                                    anchors.centerIn: parent
                                    text: "󰢮"
                                }
                                MouseArea {
                                    id: gpuTempHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                            CryoText { text: root.gpuTemp + "°C" }
                        }
                    }
                }

                Rectangle {
                    id: usageSectionContainer
                    implicitHeight: 35
                    implicitWidth: 220
                    radius: 15
                    color: theme.bgColor

                    Row {
                      id: usageSection
                      anchors.centerIn: parent
                      spacing: 10

                      Row {
                        spacing: 4
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 7
                            color: cpuUsageHover.containsMouse
                                ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            CryoText { anchors.centerIn: parent; text: "" }
                            MouseArea { id: cpuUsageHover; anchors.fill: parent; hoverEnabled: true }
                        }
                        CryoText { text: root.cpuUsage + "%" }
                      }

                      Row {
                        spacing: 4
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 7
                            color: gpuUsageHover.containsMouse
                                ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            CryoText { anchors.centerIn: parent; text: "󰢮" }
                            MouseArea { id: gpuUsageHover; anchors.fill: parent; hoverEnabled: true }
                        }
                        CryoText { text: root.gpuUsage + "%" }
                      }

                      Row {
                        spacing: 4
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 7
                            color: ramUsageHover.containsMouse
                                ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            CryoText { anchors.centerIn: parent; text: "" }
                            MouseArea { id: ramUsageHover; anchors.fill: parent; hoverEnabled: true }
                        }
                        CryoText { text: root.ramUsage + "%" }
                      }
                  }
                }
                
                Rectangle {
                  id: essentialSection
                  implicitHeight: 35
                  implicitWidth: essentialRow.width + 24
                  radius: 15
                  color: theme.bgColor
                  function menuRightMarginFor(item) {
                      const centerX = rightModules.x + essentialSection.x + essentialRow.x + item.x + (item.width / 2)
                      const rawRight = bar.width + bar.margins.right - centerX - root.quickMenuWidth / 2
                      const minRight = bar.margins.right
                      const maxRight = Math.max(minRight, bar.width - root.quickMenuWidth + bar.margins.right)
                      return Math.max(minRight, Math.min(maxRight, rawRight))
                  }

                  Row {
                    id: essentialRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        id: wifiButton
                        width: 22
                        height: 22
                        radius: 8
                        color: (root.quickMenuVisible && root.quickMenuType === "wifi" && root.quickMenuScreen === bar.screen) || wifiMouse.containsMouse
                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        CryoText {
                            id: wifiGlyphText
                            anchors.centerIn: parent
                            text: root.wifiGlyph()
                            color: root.wifiEnabled ? theme.fgColor : Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                        }

                        MouseArea {
                            id: wifiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    networkManagerDmenuProcess.running = true
                                } else {
                                    root.openQuickMenu("wifi", bar.screen, essentialSection.menuRightMarginFor(wifiButton))
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: btButton
                        width: 22
                        height: 22
                        radius: 8
                        color: (root.quickMenuVisible && root.quickMenuType === "bluetooth" && root.quickMenuScreen === bar.screen) || btMouse.containsMouse
                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                            : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        CryoText {
                            anchors.centerIn: parent
                            text: root.bluetoothGlyph()
                            color: root.btEnabled ? theme.fgColor : Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.openQuickMenu("bluetooth", bar.screen, essentialSection.menuRightMarginFor(btButton))
                            }
                        }
                    }

                    Row {
                      spacing: 4

                      Rectangle {
                        width: 22
                        height: 22
                        radius: 8
                        color: volumeHover.containsMouse
                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }

                        CryoText {
                          anchors.centerIn: parent
                          text: {
                            let icon = ""
                            const vol = (getCurrentVolume() || 0) * 100
                            if (vol === 0) icon = ""
                            else if (vol < 60) icon = ""
                            if (defaultSink?.audio?.muted) icon = ""
                            return icon
                          }
                        }

                        MouseArea {
                          id: volumeHover
                          anchors.fill: parent
                          hoverEnabled: true
                        }
                      }

                      CryoText {
                      id: pipewireText
                      text: {
                        let icon = "  "
                        let vol = (getCurrentVolume() || 0) * 100

                        if (vol === 0) {
                          icon = "  "
                        } else if (vol < 60) {
                          icon = "  "
                        }

                        if (defaultSink?.audio?.muted){
                          icon = "  "
                        }

                        if (defaultSink?.audio){
                          vol =  (vol).toFixed(0)
                        }
                        return vol + "%"
                      }

                      MouseArea {
                        anchors.fill: parent
                        onWheel: wheel => {
                          const delta = wheel.angleDelta.y / 120
                          const volumeChange = delta * 0.05
                          const currentVol = getCurrentVolume()

                          const newVolume = currentVol + volumeChange
                          setVolume(newVolume)
                        }

                        onClicked: mouse => {
                          if (mouse.button === Qt.LeftButton) {
                           pavucontrolProcess.running = true
                          }
                        }
                      }
                      }
                    }
                  }
                }


                Rectangle {
                    implicitHeight: 35
                    implicitWidth: sysTraySection.width + 30
                    radius: 15
                    color: theme.bgColor

                    Row {
                        id: sysTraySection
                        spacing: 6
                        anchors.centerIn: parent

                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                width: 22
                                height: 22
                                radius: 7
                                color: trayMouseArea.containsMouse
                                    ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                    : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 140 }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: modelData.icon
                                }

                                MouseArea {
                                    id: trayMouseArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            modelData.activate()
                                        } else if (mouse.button === Qt.RightButton) {
                                            const globalPos = mapToGlobal(mouse.x, mouse.y)
                                            modelData.display(bar, globalPos.x, globalPos.y)
                                        }
                                    }

                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 500
                                    ToolTip.text: modelData.tooltip || modelData.title || modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: quickMenuWindow
            property var modelData: modelData
            property bool activeForScreen: root.quickMenuVisible && root.quickMenuScreen === quickMenuWindow.screen
            visible: activeForScreen

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            margins {
                top: 0
                bottom: 0
                left: 0
                right: 0
            }
            color: "transparent"

            Item {
                anchors.fill: parent
                focus: quickMenuWindow.activeForScreen

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onPressed: {
                        root.closeQuickMenu()
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.closeQuickMenu()
                        event.accepted = true
                    }
                }

                Item {
                    id: trayHost
                    x: parent.width - root.quickMenuRightMargin - root.quickMenuWidth
                    y: quickMenuWindow.activeForScreen ? 49 : 36
                    width: root.quickMenuWidth
                    height: root.quickMenuType === "wifi" ? 390 : 430
                    opacity: quickMenuWindow.activeForScreen ? 1 : 0

                    Behavior on y {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }

                Rectangle {
                    anchors.fill: trayHost
                    radius: 15
                    color: Qt.rgba(theme.bgColor.r, theme.bgColor.g, theme.bgColor.b, 0.95)
                    border.width: 1
                    border.color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.10)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            CryoText {
                                text: root.quickMenuType === "wifi" ? "󰤨  Wi-Fi" : "󰂯  Bluetooth"
                                color: theme.fgColor
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: closeMenuMouse.containsMouse
                                    ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.25)
                                    : "transparent"

                                CryoText {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                }

                                MouseArea {
                                    id: closeMenuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.closeQuickMenu()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.10)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.quickMenuType === "wifi"
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                CryoText {
                                    text: root.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.82)
                                }
                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 54
                                    height: 24
                                    radius: 12
                                    color: root.wifiEnabled
                                        ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.75)
                                        : Qt.rgba(1, 1, 1, 0.14)

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        y: 2
                                        x: root.wifiEnabled ? 32 : 2
                                        color: theme.fgColor
                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!wifiToggleProc.running) {
                                                wifiToggleProc.targetEnabled = !root.wifiEnabled
                                                wifiToggleProc.running = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: wifiRefreshMouse.containsMouse
                                        ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                        : "transparent"
                                    CryoText {
                                        anchors.centerIn: parent
                                        text: root.wifiRefreshing ? "󰑐" : "󰑓"
                                    }
                                    MouseArea {
                                        id: wifiRefreshMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!root.wifiRefreshing) root.refreshWifi(true)
                                        }
                                    }
                                }
                            }

                            CryoText {
                                Layout.fillWidth: true
                                visible: root.wifiStatusText.length > 0
                                text: root.wifiStatusText
                                font.pixelSize: 11
                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.7)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.wifiPasswordSsid.length > 0 ? 36 : 0
                                visible: root.wifiPasswordSsid.length > 0
                                radius: 8
                                color: Qt.rgba(0, 0, 0, 0.22)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    TextInput {
                                        id: wifiPasswordInput
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: theme.fgColor
                                        font.family: "Jetbrains Mono"
                                        font.pixelSize: 12
                                        echoMode: TextInput.Password
                                        verticalAlignment: TextInput.AlignVCenter
                                        onTextChanged: wifiConnectProc.targetPassword = text
                                        Keys.onReturnPressed: {
                                            if (!root.wifiConnecting && text.length > 0) {
                                                wifiConnectProc.targetSsid = root.wifiPasswordSsid
                                                wifiConnectProc.targetPassword = text
                                                wifiConnectProc.running = true
                                                text = ""
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 6
                                        color: Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.85)

                                        CryoText {
                                            anchors.centerIn: parent
                                            text: "→"
                                            font.pixelSize: 12
                                            color: theme.bgColor
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (!root.wifiConnecting && wifiPasswordInput.text.length > 0) {
                                                    wifiConnectProc.targetSsid = root.wifiPasswordSsid
                                                    wifiConnectProc.targetPassword = wifiPasswordInput.text
                                                    wifiConnectProc.running = true
                                                    wifiPasswordInput.text = ""
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.20)
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    model: root.wifiNetworks
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 42
                                        radius: 8
                                        color: wifiNetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            CryoText {
                                                text: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤥" : "󰤟"
                                                color: modelData.connected ? theme.accentColor : theme.fgColor
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                CryoText {
                                                    text: modelData.ssid
                                                    font.pixelSize: 12
                                                    color: modelData.connected ? theme.accentColor : theme.fgColor
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                CryoText {
                                                    text: (modelData.secure ? "󰌾 " + modelData.security : "Open") + " · " + modelData.signal + "%"
                                                    font.pixelSize: 10
                                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                                                }
                                            }

                                            CryoText {
                                                visible: modelData.connected
                                                text: "Connected"
                                                font.pixelSize: 10
                                                color: theme.accentColor
                                            }
                                        }

                                        MouseArea {
                                            id: wifiNetMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (root.wifiConnecting || wifiDisconnectProc.running) return
                                                if (modelData.connected) {
                                                    if (root.wifiIfname.length > 0) {
                                                        wifiDisconnectProc.running = true
                                                    } else {
                                                        root.wifiStatusText = "No active Wi-Fi device found"
                                                    }
                                                    return
                                                }
                                                if (modelData.ssid === "<hidden>") {
                                                    root.wifiStatusText = "Hidden networks require manual setup"
                                                    return
                                                }
                                                if (modelData.secure) {
                                                    root.wifiPasswordSsid = ""
                                                    wifiConnectProc.targetSsid = modelData.ssid
                                                    wifiConnectProc.targetPassword = ""
                                                    wifiConnectProc.fallbackToPassword = true
                                                    wifiConnectProc.running = true
                                                } else {
                                                    wifiConnectProc.targetSsid = modelData.ssid
                                                    wifiConnectProc.targetPassword = ""
                                                    wifiConnectProc.fallbackToPassword = false
                                                    wifiConnectProc.running = true
                                                }
                                            }
                                        }
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        width: 4
                                    }
                                }

                                CryoText {
                                    anchors.centerIn: parent
                                    visible: root.wifiNetworks.length === 0 && !root.wifiRefreshing
                                    text: root.wifiEnabled ? "No networks found" : "Wi-Fi is off"
                                    font.pixelSize: 12
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                                }

                                CryoText {
                                    anchors.centerIn: parent
                                    visible: root.wifiRefreshing
                                    text: "Scanning..."
                                    font.pixelSize: 12
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.quickMenuType === "bluetooth"
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                CryoText {
                                    text: root.btEnabled ? "Bluetooth on" : "Bluetooth off"
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.82)
                                }
                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 54
                                    height: 24
                                    radius: 12
                                    color: root.btEnabled
                                        ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.75)
                                        : Qt.rgba(1, 1, 1, 0.14)

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        y: 2
                                        x: root.btEnabled ? 32 : 2
                                        color: theme.fgColor
                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!btPowerProc.running && !root.btBusy) {
                                                btPowerProc.targetEnabled = !root.btEnabled
                                                btPowerProc.running = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 50
                                    height: 24
                                    radius: 7
                                    color: btScanMouse.containsMouse
                                        ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.24)
                                        : "transparent"
                                    CryoText {
                                        anchors.centerIn: parent
                                        text: root.btScanning ? "..." : "Scan"
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        id: btScanMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!root.btScanning && !btScanProc.running) btScanProc.running = true
                                        }
                                    }
                                }
                            }

                            CryoText {
                                Layout.fillWidth: true
                                visible: root.btStatusText.length > 0
                                text: root.btStatusText
                                font.pixelSize: 11
                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.7)
                            }

                            CryoText {
                                text: "Paired Devices"
                                font.pixelSize: 11
                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.7)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.20)
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    model: root.btPairedDevices

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 40
                                        radius: 8
                                        color: btPairedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            CryoText {
                                                text: modelData.connected ? "󰂱" : "󰂲"
                                                color: modelData.connected ? theme.accentColor : theme.fgColor
                                            }

                                            CryoText {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: modelData.connected ? theme.accentColor : theme.fgColor
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            CryoText {
                                                text: modelData.connected ? "Disconnect" : "Connect"
                                                font.pixelSize: 10
                                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.68)
                                            }
                                        }

                                        MouseArea {
                                            id: btPairedMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (root.btBusy) return
                                                btActionProc.mode = modelData.connected ? "disconnect" : "connect"
                                                btActionProc.mac = modelData.mac
                                                btActionProc.deviceName = modelData.name
                                                btActionProc.running = true
                                            }
                                        }
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        width: 4
                                    }
                                }

                                CryoText {
                                    anchors.centerIn: parent
                                    visible: root.btPairedDevices.length === 0 && !root.btRefreshing
                                    text: "No paired devices"
                                    font.pixelSize: 11
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                                }
                            }

                            CryoText {
                                text: "Available Devices"
                                font.pixelSize: 11
                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.7)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: Qt.rgba(0, 0, 0, 0.20)
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    model: root.btAvailableDevices

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 40
                                        radius: 8
                                        color: btAvailMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            CryoText {
                                                text: "󰂲"
                                                color: theme.fgColor
                                            }

                                            CryoText {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: theme.fgColor
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            CryoText {
                                                text: "Pair"
                                                font.pixelSize: 10
                                                color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.68)
                                            }
                                        }

                                        MouseArea {
                                            id: btAvailMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (root.btBusy) return
                                                btActionProc.mode = "pairconnect"
                                                btActionProc.mac = modelData.mac
                                                btActionProc.deviceName = modelData.name
                                                btActionProc.running = true
                                            }
                                        }
                                    }

                                    ScrollBar.vertical: ScrollBar {
                                        active: true
                                        width: 4
                                    }
                                }

                                CryoText {
                                    anchors.centerIn: parent
                                    visible: root.btAvailableDevices.length === 0 && !root.btRefreshing
                                    text: root.btEnabled ? "No discoverable devices" : "Bluetooth is off"
                                    font.pixelSize: 11
                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.65)
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }
}
