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
import "modules/controllers"

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

    property alias wifiEnabled: wifiController.wifiEnabled
    property alias wifiCurrentSsid: wifiController.wifiCurrentSsid
    property alias wifiIfname: wifiController.wifiIfname
    property alias wifiSignal: wifiController.wifiSignal
    property alias wifiNetworks: wifiController.wifiNetworks
    property alias wifiRefreshing: wifiController.wifiRefreshing
    property alias wifiConnecting: wifiController.wifiConnecting
    property alias wifiPasswordSsid: wifiController.wifiPasswordSsid
    property alias wifiStatusText: wifiController.wifiStatusText

    property alias btEnabled: bluetoothController.btEnabled
    property alias btConnected: bluetoothController.btConnected
    property alias btRefreshing: bluetoothController.btRefreshing
    property alias btScanning: bluetoothController.btScanning
    property alias btBusy: bluetoothController.btBusy
    property alias btPairedDevices: bluetoothController.btPairedDevices
    property alias btAvailableDevices: bluetoothController.btAvailableDevices
    property alias btStatusText: bluetoothController.btStatusText

    property alias wifiSnapshotProc: wifiController.wifiSnapshotProc
    property alias wifiNetworksProc: wifiController.wifiNetworksProc
    property alias wifiToggleProc: wifiController.wifiToggleProc
    property alias wifiConnectProc: wifiController.wifiConnectProc
    property alias wifiDisconnectProc: wifiController.wifiDisconnectProc

    property alias btStatusProc: bluetoothController.btStatusProc
    property alias btPairedProc: bluetoothController.btPairedProc
    property alias btDevicesProc: bluetoothController.btDevicesProc
    property alias btPowerProc: bluetoothController.btPowerProc
    property alias btScanProc: bluetoothController.btScanProc
    property alias btActionProc: bluetoothController.btActionProc

    Theme {id: theme}

    WifiController {
        id: wifiController
    }

    BluetoothController {
        id: bluetoothController
    }

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
        wifiController.refreshWifi(rescan)
    }

    function refreshBluetooth() {
        bluetoothController.refreshBluetooth()
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
                                        : Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.18)

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
                                color: Qt.rgba(theme.bgColor.r, theme.bgColor.g, theme.bgColor.b, 0.78)

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
                                color: Qt.rgba(theme.bgColor.r, theme.bgColor.g, theme.bgColor.b, 0.72)
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
                                        color: wifiNetMouse.containsMouse
                                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.16)
                                            : "transparent"

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
                                        : Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.18)

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
                                color: Qt.rgba(theme.bgColor.r, theme.bgColor.g, theme.bgColor.b, 0.72)
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    model: root.btPairedDevices

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 46
                                        radius: 8
                                        color: btPairedMouse.containsMouse
                                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.16)
                                            : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            CryoText {
                                                text: modelData.connected ? "󰂱" : "󰂲"
                                                color: modelData.connected ? theme.accentColor : theme.fgColor
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                CryoText {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: modelData.connected ? theme.accentColor : theme.fgColor
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }

                                                CryoText {
                                                    visible: modelData.battery >= 0
                                                    text: "Battery " + modelData.battery + "%"
                                                    font.pixelSize: 10
                                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.68)
                                                }
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
                                color: Qt.rgba(theme.bgColor.r, theme.bgColor.g, theme.bgColor.b, 0.72)
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4
                                    model: root.btAvailableDevices

                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 46
                                        radius: 8
                                        color: btAvailMouse.containsMouse
                                            ? Qt.rgba(theme.accentColor.r, theme.accentColor.g, theme.accentColor.b, 0.16)
                                            : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            CryoText {
                                                text: "󰂲"
                                                color: theme.fgColor
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0

                                                CryoText {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: theme.fgColor
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }

                                                CryoText {
                                                    visible: modelData.battery >= 0
                                                    text: "Battery " + modelData.battery + "%"
                                                    font.pixelSize: 10
                                                    color: Qt.rgba(theme.fgColor.r, theme.fgColor.g, theme.fgColor.b, 0.68)
                                                }
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
