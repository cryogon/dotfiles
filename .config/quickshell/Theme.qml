// Theme.qml
import Quickshell
import QtQuick
import Quickshell.Io

QtObject {
    id: parent
    property color bgColor: "#1e1e2e"
    property color fgColor: "#cdd6f4"
    property color accentColor: "#89b4fa"

    property FileView walFile: FileView {
    id: pywalFile
    path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
    
    watchChanges: true 

    onLoaded: {
        try {
            let colors = JSON.parse(text());
            parent.bgColor = colors.special.background;
            parent.fgColor = colors.special.foreground;
            parent.accentColor = colors.colors.color4;
            console.log("Pywal: Colors loaded successfully.");
        } catch (e) {
            console.log("Pywal Error: " + e);
        }
    }

    onFileChanged: reload()
}}
