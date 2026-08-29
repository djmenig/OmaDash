import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// SearchResults: launcher-style result rows rendered in the dashboard's
// control-token family so the overlay reads as an extension of the search
// field: popups surface + normal control border on the box, control hover
// fill + hover-cursor border on the cursor row, foreground text throughout.
// Rows keep the launcher geometry: 50/58px, 36px icon column, heading/Medium
// labels, dimmed detail while filtering, "›" trail on menu/link rows, and a
// hairline divider before the "more" section.
Item {
  id: root
  property var bar: null
  property var results: []
  property int selectedIndex: 0
  property bool cursorActive: false
  signal activated(int index)
  signal selectionChanged(int index)

  readonly property color fg: (bar && bar.foreground) ? bar.foreground : Color.foreground
  readonly property color accent: (bar && bar.accent) ? bar.accent : Color.accent

  implicitWidth: Style.space(560)
  implicitHeight: Math.min(list.contentHeight + Style.space(12), Style.space(356))

  BorderSurface {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.controlSpec("normal", root.fg, root.accent)
  }

  ListView {
    id: list
    anchors.fill: parent
    anchors.margins: Style.space(6)
    clip: true
    spacing: Style.spacing.xs
    boundsBehavior: Flickable.StopAtBounds
    model: root.results
    section.property: "section"
    section.criteria: ViewSection.FullString

    section.delegate: Item {
      required property string section

      width: ListView.view.width
      height: section === "more" ? Style.space(17) : 0
      visible: section === "more"

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(4)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        height: Style.spacing.hairline
        color: Util.alpha(root.fg, 0.2)
      }
    }

    delegate: BorderSurface {
      id: row
      required property int index
      required property var modelData

      readonly property bool hasCursor: root.cursorActive && row.index === root.selectedIndex
      readonly property bool hasGlyph: !!row.modelData.glyph && row.modelData.glyph.length > 0
      readonly property bool hasAppIcon: !!row.modelData.appIcon && row.modelData.appIcon.length > 0
      readonly property bool hasIcon: row.hasGlyph || row.hasAppIcon
      readonly property bool showDetail: !!row.modelData.detail

      width: ListView.view.width
      height: row.showDetail
        ? Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
        : Math.max(Style.space(50), Style.font.body + Style.spacing.rowPaddingX * 2)
      radius: Style.cornerRadius
      color: row.hasCursor ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
      borderSpec: row.hasCursor
        ? Border.controlSpec("hover-cursor", root.fg, root.accent)
        : Border.none()

      Text {
        visible: row.hasGlyph
        text: row.modelData.glyph || ""
        color: root.fg
        font.family: row.modelData.iconFont && row.modelData.iconFont.length > 0 ? row.modelData.iconFont : Style.font.menuFamily
        font.pixelSize: Style.font.iconLarge
        width: Style.space(36)
        horizontalAlignment: Text.AlignHCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      Image {
        visible: row.hasAppIcon
        width: Style.font.iconLarge
        height: Style.font.iconLarge
        fillMode: Image.PreserveAspectFit
        // Decode at physical pixels so PNG icons stay sharp on HiDPI.
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        source: row.modelData.appIcon || ""
        asynchronous: true
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8) + (Style.space(36) - width) / 2
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        anchors.left: parent.left
        anchors.leftMargin: row.hasIcon ? Style.space(8) + Style.space(36) + Style.space(6) : Style.space(18)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(24)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: row.modelData.label
          textFormat: Text.PlainText
          color: root.fg
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.Medium
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: row.modelData.detail || ""
          textFormat: Text.PlainText
          visible: row.showDetail
          color: root.fg
          opacity: 0.52
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      Text {
        visible: row.modelData.kind === "menu" || row.modelData.kind === "link"
        text: "›"
        color: root.fg
        opacity: 0.36
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.heading
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: {
          if (!row.hasCursor) root.selectionChanged(row.index)
        }
        onClicked: root.activated(row.index)
      }
    }
  }

  function reveal(i) {
    if (i >= 0 && i < list.count) list.positionViewAtIndex(i, ListView.Contain)
  }
}
