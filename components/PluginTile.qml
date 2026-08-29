import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../components/DashboardRegistry.js" as Registry

// PluginTile: launcher-tile card for a scanned system plugin. Shows the
// plugin's glyph, name and description; clicking summons the real plugin
// via the standard IPC convention (omarchy-shell shell toggle <id>).
// If the plugin is uninstalled after being added, the tile renders a muted
// "not installed" state and stays removable via edit mode.
Item {
  id: root
  property string pluginId: ""        // e.g. "plugin:omarchy.emojis"
  property var bar: null
  property bool hovered: false

  readonly property color fg: (bar && bar.foreground) ? bar.foreground : Color.foreground
  readonly property color accent: (bar && bar.accent) ? bar.accent : Color.accent

  readonly property string manifestId: pluginId.indexOf("plugin:") === 0 ? pluginId.slice("plugin:".length) : pluginId
  readonly property var manifest: {
    var reg = bar && bar.shell && bar.shell.pluginRegistry ? bar.shell.pluginRegistry : null
    if (!reg) return null
    var all = reg.installedPlugins || {}
    return all[manifestId] || null
  }
  readonly property bool installed: !!manifest
  readonly property string name: installed ? (manifest.name || manifestId) : manifestId
  readonly property string description: installed ? (manifest.description || "") : "Not installed"
  readonly property string glyph: installed ? Registry.kindGlyph(manifest.kinds) : "󰅙"

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight

  HoverHandler {
    enabled: true
    onHoveredChanged: root.hovered = hovered
  }

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    Item { Layout.fillHeight: true; Layout.fillWidth: true }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: root.glyph
      color: root.hovered ? root.accent : root.fg
      opacity: root.installed ? 1 : 0.4
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.iconLarge * 1.6
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: root.name
      textFormat: Text.PlainText
      color: root.fg
      opacity: root.installed ? 1 : 0.4
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.heading
      font.weight: Font.Medium
      elide: Text.ElideRight
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      visible: root.description.length > 0
      text: root.description
      textFormat: Text.PlainText
      color: root.fg
      opacity: 0.52
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      elide: Text.ElideRight
    }

    Item { Layout.fillHeight: true; Layout.fillWidth: true }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.installed
    cursorShape: root.installed ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: Util.execDetached("omarchy-shell shell toggle " + Util.shellQuote(root.manifestId))
  }
}
