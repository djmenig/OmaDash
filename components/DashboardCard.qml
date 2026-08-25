import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../components/DashboardRegistry.js" as Registry

// DashboardCard: a single tiled plugin "card".
// Sizing: natural size derives from the plugin content (Loader adopts the
// loaded item's implicit size); the tiler's flex packer assigns final
// x/y/width/height imperatively.
// Layout: the content fills the card; edit-mode controls (remove button +
// grip handle) overlay the top-right corner. Header/content are ANCHORED
// (not a ColumnLayout) so nothing can push the plugin content around.
// Edit mode: grip handle (top-right) for drag-reorder, remove button next
// to it, accent border on hover.
Item {
  id: root
  property string cardId: ""
  property var bar: null
  property bool editMode: false
  property bool dragActive: false
  property bool hovered: false
  // NOTE: must NOT be named `index` — that would shadow the Repeater's
  // injected context `index` and every card would read positions[0].
  property int cardIndex: 0
  signal removeRequested()
  signal dragStarted(int index)
  signal dragUpdated()
  signal dragEnded()

  readonly property var desc: Registry.descriptor(root.cardId)
  readonly property color fg: (bar && bar.foreground) ? bar.foreground : Color.foreground
  readonly property color accent: (bar && bar.accent) ? bar.accent : Color.accent
  readonly property real cardPad: Style.space(10)
  // Panel-host cards keep their natural width — the packer does not stretch
  // them (panels are designed around their own preferred content width).
  readonly property bool fixedWidth: !!root.desc && root.desc.kind === "panel"

  // Natural content size — the flex packer's input.
  implicitWidth: contentLoader.implicitWidth + 2 * cardPad
  implicitHeight: contentLoader.implicitHeight + 2 * cardPad

  // Animated reposition while tiling. Suppressed for the dragged card:
  // MouseArea drag writes x/y directly every frame, and animating those
  // writes makes the card rubber-band behind the cursor.
  Behavior on x {
    enabled: root.editMode && !root.dragActive
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }
  Behavior on y {
    enabled: root.editMode && !root.dragActive
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }

  // Hover only matters in edit mode (border highlight + remove button).
  HoverHandler {
    enabled: root.editMode
    onHoveredChanged: root.hovered = hovered
  }

  BorderSurface {
    id: cardSurface
    anchors.fill: parent
    radius: Style.cornerRadius
    // Background stays at normal fill; only the border reacts (edit mode).
    color: Style.controlFill(false, false, root.fg, root.accent)
    borderSpec: root.editMode && root.hovered
      ? Border.controlSpec("hover-cursor", root.fg, root.accent)
      : Border.controlSpec("normal", root.fg, root.accent)

    // Content fills the card; edit-mode controls float above it.
    Loader {
      id: contentLoader
      anchors.fill: parent
      anchors.margins: root.cardPad
      source: root.desc ? root.desc.source : ""
      onLoaded: {
        if ("bar" in item) item.bar = root.bar
        if ("pluginId" in item) item.pluginId = root.cardId
      }
    }
  }

  // Remove button — sits right next to the grip handle. Always visible in
  // edit mode so the whole handle cluster (− ⋮⋮) reads as one affordance.
  // Remove button — sits right next to the grip handle. Always visible in
  // edit mode so the whole handle cluster (− ⋮⋮) reads as one affordance.
  // Opaque chip + border keeps OmaDash chrome distinguishable from busy
  // plugin content underneath; the icon still tints urgent on hover via its
  // internal foreground binding.
  PanelActionButton {
    id: removeButton
    visible: root.editMode
    color: Color.popups.background
    bordered: true
    anchors.top: parent.top
    anchors.right: grip.left
    anchors.topMargin: Style.space(3)
    anchors.rightMargin: Style.space(2)
    iconText: "−"
    foreground: Color.foreground
    hoverColor: Color.urgent
    tooltipText: "Remove"
    onClicked: root.removeRequested()
  }

  // Grip (drag handle) — top-right corner, edit mode only, on an opaque
  // chip matching the remove button.
  Item {
    id: grip
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Style.space(3)
    anchors.rightMargin: Style.space(2)
    width: removeButton.width
    height: removeButton.height
    visible: root.editMode
    opacity: root.editMode ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 100 } }

    BorderSurface {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.controlSpec("normal", root.fg, root.accent)
    }

    Text {
      anchors.centerIn: parent
      text: "⋮⋮"
      // Same hover tint the system-shortcut buttons use (theme accent).
      // Icon-sized glyph matches the remove button's icon.
      color: ma.containsMouse ? Color.accent : Color.foreground
      Behavior on color { ColorAnimation { duration: 60 } }
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      anchors.margins: -Style.space(6)
      enabled: root.editMode
      hoverEnabled: true
      drag.target: root
      drag.axis: Drag.XAndYAxis
      cursorShape: ma.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      onPressed: root.dragStarted(root.cardIndex)
      onPositionChanged: if (pressed) root.dragUpdated()
      onReleased: root.dragEnded()
      onCanceled: root.dragEnded()
    }
  }
}
