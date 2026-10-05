import QtQuick
import qs.Commons

// Draws a hotkey such as "CTRL + SPACE" as a row of keycaps.
Row {
  id: root

  property string combo: ""
  property color foreground: Color.foreground
  property int pixelSize: Style.font.caption
  // Caps are darker than the panel so the foreground text stays readable.
  property color background: Color.background
  readonly property color faceColor: Qt.darker(background, 1.3)
  readonly property color edgeColor: Qt.darker(background, 1.9)

  readonly property var tokens: String(combo || "").split(/\s*\+\s*/).filter(function(token) {
    return token !== ""
  })

  spacing: Style.space(5)

  function capLabel(token) {
    var lower = token.toLowerCase()
    return lower.length > 1 ? lower.charAt(0).toUpperCase() + lower.slice(1) : token.toUpperCase()
  }

  Repeater {
    model: root.tokens

    Row {
      id: entry

      required property int index
      required property string modelData

      spacing: root.spacing

      Text {
        visible: entry.index > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "+"
        color: Qt.alpha(root.foreground, 0.55)
        font.family: Style.font.family
        font.pixelSize: root.pixelSize
      }

      Item {
        width: label.implicitWidth + Style.space(14)
        height: label.implicitHeight + Style.space(12)

        // Darker lower edge gives the cap its depth.
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: Style.space(2)
          radius: Style.space(5)
          color: root.edgeColor
        }

        Rectangle {
          anchors.fill: parent
          anchors.bottomMargin: Style.space(2)
          radius: Style.space(5)
          color: root.faceColor
          border.width: 1
          border.color: Qt.alpha(root.foreground, 0.3)

          Text {
            id: label

            anchors.centerIn: parent
            text: root.capLabel(entry.modelData)
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: root.pixelSize
            font.bold: true
          }
        }
      }
    }
  }
}
