import QtQuick

Text {
  font.family: "Jetbrains Mono"
  font.pixelSize: 14
  color: Theme.fgColor
  // cut of the text at the right if it exeeds max width
  elide: Text.ElideRight
  width: Math.min(implicitWidth, 200)
  maximumLineCount: 1
}
