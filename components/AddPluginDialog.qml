import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../engine"
import "./DashboardRegistry.js" as Registry

// AddPluginDialog: in-dashboard overlay for choosing what to pin to the
// corkboard. Deliberately NOT a PopupCard — a window here would join the
// bar's popout coordination and close the dashboard on open. Instead it
// floats over the grid (z-boosted by the tiler), toggled from the FAB,
// dismissed by clicking anywhere outside its box.
// Sections of control-token rows (same family as the search results):
//   - Dashboard views: omadash's own live components
//   - Live panels: scanned panel-kind plugins, embedded via PanelHost
//   - Plugins: everything else summonable, as launcher tiles
// Passive services with nothing to summon and omadash itself are excluded.
Item {
  id: root
  property bool open: false
  property var bar: null
  // Space to keep clear at the bottom (the FAB row, injected by the tiler).
  property real bottomGap: Style.space(72)

  visible: opacity > 0
  opacity: open ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  function glyphForKinds(kinds) {
    return Registry.kindGlyph(kinds)
  }

  function viewGlyph(id) {
    switch (id) {
      case "calendar": return ""
      case "pomodoro": return "󰄉"
      case "weather": return ""
      case "notifications": return "󰂚"
    }
    return "󰀻"
  }

  readonly property var viewRows: {
    var out = []
    var ids = Registry.allIds()
    for (var i = 0; i < ids.length; i++) {
      var d = Registry.descriptor(ids[i])
      if (d) out.push({ id: d.id, label: d.label, description: d.description || "", glyph: root.viewGlyph(d.id) })
    }
    return out
  }

  readonly property var activeIdSet: {
    var set = {}
    var list = DashboardConfig.activePlugins
    for (var i = 0; i < list.length; i++) set[list[i].id] = true
    return set
  }

  // Scan of installed plugins from the shell's PluginRegistry, classified
  // by species: panel-kind → live PanelHost cards; the rest → launcher
  // tiles. Passive services and omadash itself are excluded.
  readonly property var panelRows: {
    var rows = root.scanAll()
    var out = []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].isPanel) out.push(rows[i])
    }
    return out
  }

  readonly property var scannedRows: {
    var rows = root.scanAll()
    var out = []
    for (var i = 0; i < rows.length; i++) {
      if (!rows[i].isPanel) out.push(rows[i])
    }
    return out
  }

  function scanAll() {
    var reg = bar && bar.shell && bar.shell.pluginRegistry ? bar.shell.pluginRegistry : null
    var out = []
    if (!reg) return out
    var excluded = {
      "omadash": true,
      "omarchy.background": true,
      "omarchy.polkit": true,
      "omarchy.lock": true,
      "omarchy.bar": true
    }
    var all = reg.installedPlugins || {}
    for (var id in all) {
      if (excluded[id]) continue
      var m = all[id]
      var kinds = m.kinds || []
      // Panel species: explicit `panel` kind, or the plugin lives in the
      // first-party panels/ tree — those ship Panel.qml as their popup UI
      // even when the manifest only declares bar-widget (network, weather…).
      var srcDir = String(m.__sourceDir || "")
      var isPanel = kinds.indexOf("panel") >= 0 || srcDir.indexOf("/plugins/panels/") >= 0
      out.push({
        id: (isPanel ? "panel:" : "plugin:") + id,
        label: m.name || id,
        description: m.description || "",
        glyph: root.glyphForKinds(kinds),
        isPanel: isPanel
      })
    }
    out.sort(function (a, b) { return a.label.localeCompare(b.label) })
    return out
  }

  component SectionLabel: Text {
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    color: Color.muted
    opacity: 0.8
  }

  component AddRow: Item {
    id: row
    required property var modelData

    readonly property bool added: !!root.activeIdSet[row.modelData.id]
    readonly property bool hovered: ma.containsMouse

    width: contentCol.width
    height: added ? 0 : Style.space(52)
    visible: !added
    clip: true

    BorderSurface {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: row.hovered ? Style.hoverFillFor(Color.foreground, Color.accent) : "transparent"
      borderSpec: row.hovered
        ? Border.controlSpec("hover-cursor", Color.foreground, Color.accent)
        : Border.none()
    }

    Text {
      text: row.modelData.glyph || "󰀻"
      color: Color.foreground
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.iconLarge
      width: Style.space(36)
      horizontalAlignment: Text.AlignHCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8) + Style.space(36) + Style.space(6)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: row.modelData.label
        color: Color.foreground
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: row.modelData.description.length > 0
        text: row.modelData.description
        color: Color.foreground
        opacity: 0.52
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }

    Text {
      text: "＋"
      color: Color.foreground
      opacity: row.hovered ? 0.9 : 0.3
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        DashboardConfig.addPlugin(row.modelData.id)
        root.open = false
      }
    }
  }

  // Click-outside dismissal (covers the whole tiler; the box sits above it).
  MouseArea {
    anchors.fill: parent
    enabled: root.open
    onClicked: root.open = false
  }

  BorderSurface {
    id: box
    visible: root.open
    width: Style.space(430)
    height: Math.min(contentCol.implicitHeight + Style.space(16), Style.space(430))
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.bottomGap
    anchors.horizontalCenter: parent.horizontalCenter
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: Style.space(8)
      contentWidth: width
      contentHeight: contentCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: contentCol
        width: flick.width
        spacing: Style.space(4)

        Text {
          Layout.leftMargin: Style.space(8)
          text: "Add plugin"
          color: Color.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.Medium
        }

        SectionLabel {
          Layout.leftMargin: Style.space(8)
          Layout.topMargin: Style.space(6)
          text: "DASHBOARD VIEWS"
        }

        Repeater {
          model: root.viewRows
          delegate: AddRow {}
        }

        SectionLabel {
          Layout.leftMargin: Style.space(8)
          Layout.topMargin: Style.space(10)
          text: "LIVE PANELS"
          visible: root.panelRows.length > 0
        }

        Repeater {
          model: root.panelRows
          delegate: AddRow {}
        }

        SectionLabel {
          Layout.leftMargin: Style.space(8)
          Layout.topMargin: Style.space(10)
          text: "PLUGINS"
          visible: root.scannedRows.length > 0
        }

        Repeater {
          model: root.scannedRows
          delegate: AddRow {}
        }

        Text {
          Layout.leftMargin: Style.space(8)
          Layout.topMargin: Style.space(10)
          visible: root.scannedRows.length === 0 && root.panelRows.length === 0
          text: "No additional plugins found."
          color: Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
