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
import Quickshell.Networking

ShellRoot {
    id: root

    property string time
    property string gpuTemp
    property string cpuTemp
    property string cpuUsage
    property string gpuUsage
    property string ramUsage

    Theme {id: theme}

    readonly property var activePlayer: {
        for (let i = 0; i < Mpris.players.values.length; i++) {
            if (Mpris.players.values[i].playbackState === MprisPlaybackState.Playing) {
                return Mpris.players.values[i]
            }
        }
        return Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    }

    readonly property var wifiDevice: {
      // for (let i = 0; i < Networking.devices)
      return null 
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
        command: ["bash", "-c", "cat /sys/class/hwmon/hwmon2/temp1_input | awk '{printf \"%.0f\", $1 / 1000}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpuTemp = this.text
            }
        }
    }

    Process {
        id: cpuTempProc
        command: ["bash", "-c", "cat /sys/class/hwmon/hwmon3/temp1_input | awk '{printf \"%.0f\", $1 / 1000}'"]
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
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            dateProc.running = true
            gpuTempProc.running = true
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

                        CryoText {
                            text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "󰝚 " : "󰏤"
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
                    implicitWidth: tempSection.width + 30
                    radius: 15
                    color: theme.bgColor

                    CryoText {
                        id: tempSection
                        anchors.centerIn: parent
                        text: " " + root.cpuTemp + "°C " + "󰢮 " + root.gpuTemp + "°C"
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

                      CryoText {
                        text: "  " + root.cpuUsage + "%"   
                      }

                      CryoText {
                        text: "󰢮  " + root.gpuUsage + "%"
                      }

                      CryoText {
                        text: "  " + root.ramUsage + "%"
                      }
                  }
                }
                
                Rectangle {
                  id: essentialSection
                  implicitHeight: 35
                  implicitWidth: 100
                  radius: 15
                  color: theme.bgColor
                  Row {
                  anchors.centerIn: parent
                  spacing: 6
                  Row {
                    spacing: 3
                    CryoText {
                      text: {
                        if (!Networking.wifiEnabled) {
                            return "󰖪" 
                        }
                        
                        let connection = Networking.primaryConnection
                        if (!connection || !connection.wireless) {
                            return "󰤯" // No connection
                        }
                        
                        let strength = connection.wireless.strength
                        if (strength >= 80) return "󰤨" // Excellent
                        if (strength >= 60) return "󰤥" // Good
                        if (strength >= 40) return "󰤢" // Fair
                        if (strength >= 20) return "󰤟" // Weak
                        return "󰤯" // Very weak
                      }

                      MouseArea {
                        anchors.fill: parent
                        onClicked: (mouse) => {
                          if (mouse.button === Qt.LeftButton){
                             networkManagerDmenuProcess.running = true
                          }
                        } 
                      }
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
        
                      if (defaultSink?.audio){
                        vol =  (vol).toFixed(0)
                      }
                      return icon + vol + "%"
                    }
                    
                    MouseArea {
                      anchors.fill: parent
                      onWheel: (wheel) => {
                        let delta  = wheel.angleDelta.y / 120 // normalise scroll delta
                        let volumeChange = delta * 0.05 // 5% per scroll step
                        let currentVol = getCurrentVolume()

                        let newVolume = currentVol + volumeChange
                        setVolume(newVolume)
                      }

                      onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                         pavucontrolProcess.running = true 
                        }
                      }
                    }
                  }}
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
                            delegate: Item {
                                width: 22
                                height: 22

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
}
