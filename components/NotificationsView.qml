import QtQuick
import QtQuick.Controls
import qs.Commons

// NotificationsView: placeholder ListView, themed to popup surface.
Item {
  id: root
  implicitWidth: 200
  implicitHeight: 140

  Rectangle {
    anchors.fill: parent
    radius: 6
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: 1

    ListView {
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: Style.space(4)
      clip: true
      model: ListModel {
        ListElement { title: "Notification 1"; body: "Placeholder message" }
        ListElement { title: "Notification 2"; body: "Placeholder message" }
        ListElement { title: "Notification 3"; body: "Placeholder message" }
      }
      delegate: Column {
        width: ListView.view.width
        spacing: 2
        Text { text: model.title; font.pixelSize: 12; font.family: Style.font.family; color: Color.popups.text; font.bold: true }
        Text { text: model.body; font.pixelSize: 11; font.family: Style.font.family; color: Color.muted }
      }
    }
  }
}
