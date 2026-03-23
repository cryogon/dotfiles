import QtQuick

Text {
  property color fallbackColor: "#cdd6f4"
  property var themeRef: {
    let p = parent
    while (p) {
      if (p.themeObj && p.themeObj.fgColor !== undefined) return p.themeObj
      p = p.parent
    }
    return null
  }

  font.family: "Jetbrains Mono"
  font.pixelSize: 14
  color: themeRef ? themeRef.fgColor : fallbackColor
  // cut of the text at the right if it exeeds max width
  elide: Text.ElideRight
  width: Math.min(implicitWidth, 200)
  maximumLineCount: 1
}
