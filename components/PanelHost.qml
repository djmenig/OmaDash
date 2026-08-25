import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../components/DashboardRegistry.js" as Registry

// PanelHost: a corkboard container that embeds a real plugin panel's UI.
// Loads the plugin's Panel.qml (its layer window stays unmapped — open is
// false, so no surface is ever created), then re-parents the genuine
// content Item out of the panel's card into this host. Ids and bindings are
// lexical to the plugin component, so the content keeps working unchanged:
// same services, same logic, the literal UI from the bar icon click.
//
// The panel is also led to believe it is open (controller.open = true while
// the window binding is broken) — panels gate peak monitors, scans and
// refresh timers on `opened`, and the adopted content still binds to panel
// state.
Item {
  id: root
  property string pluginId: ""        // e.g. "panel:omarchy.network"
  property var bar: null
  property bool hovered: false

  readonly property color fg: (bar && bar.foreground) ? bar.foreground : Color.foreground
  readonly property color accent: (bar && bar.accent) ? bar.accent : Color.accent

  readonly property string manifestId: pluginId.indexOf("panel:") === 0 ? pluginId.slice("panel:".length) : pluginId
  readonly property var manifest: {
    var reg = bar && bar.shell && bar.shell.pluginRegistry ? bar.shell.pluginRegistry : null
    if (!reg) return null
    var all = reg.installedPlugins || {}
    return all[manifestId] || null
  }
  readonly property bool installed: !!manifest

  // Resolve the panel QML. Most panels/* plugins declare no `panel` entry
  // point — they use the bar-widget convention where Panel.qml IS the
  // popup host (declared as barWidget, or present by convention).
  readonly property string panelEntry: {
    if (!installed) return ""
    var ep = manifest.entryPoints || {}
    if (ep.panel !== undefined) return ep.panel
    if (ep.barWidget !== undefined && String(ep.barWidget).indexOf("Panel.qml") >= 0)
      return ep.barWidget
    return "Panel.qml"
  }
  readonly property string panelPath: installed && panelEntry !== ""
    ? "file://" + manifest.__sourceDir + "/" + panelEntry
    : ""

  // Natural size from the loaded panel's own KeyboardPanel preferences,
  // clamped to corkboard-sensible bounds. The packer treats panel cards as
  // fixed-width (no stretch).
  readonly property int panelPreferredW: kbPanel ? Math.max(280, Math.min(380, Math.round(kbPanel.contentWidth))) : 320
  readonly property int panelPreferredH: kbPanel ? Math.max(280, Math.min(560, Math.round(kbPanel.contentHeight))) : 380
  property var kbPanel: null
  property bool adoptFailed: false

  implicitWidth: installed ? panelPreferredW : 280
  implicitHeight: installed ? panelPreferredH : 160

  function adoptContent() {
    var panel = panelLoader.item
    if (!panel) { root.adoptFailed = true; return }
    panel.bar = root.bar
    panel.settings = {}
    if ("manageIpc" in panel) panel.manageIpc = false

    // Panel root → KeyboardPanel. The KeyboardPanel is a PanelWindow — a
    // window object, not an Item — so it never appears in Item.children;
    // it lives in the QML `data` property (all child objects). Identify it
    // by its unique fittedContentWidth method, with property/type-name
    // fallbacks for robustness.
    var kb = null
    var kids = panel.data
    for (var i = 0; i < kids.length; i++) {
      var c = kids[i]
      if (!c) continue
      if (c.fittedContentWidth !== undefined || c.anchorItem !== undefined || c.toString().indexOf("KeyboardPanel") >= 0) {
        kb = c
        break
      }
    }
    if (!kb) { root.adoptFailed = true; return }
    root.kbPanel = kb

    // The KeyboardPanel's default property aliases contentHolder.children —
    // reading `contentItem` yields the panel's declared content directly
    // (e.g. audio: PanelKeyCatcher + the ScrollView UI). No need to dig
    // through the card's BorderSurface internals.
    var content = kb.contentItem
    if (!content || content.length === 0) { root.adoptFailed = true; return }

    // Copy first — re-parenting mutates the live children list.
    var toAdopt = []
    for (i = 0; i < content.length; i++) toAdopt.push(content[i])
    for (i = 0; i < toAdopt.length; i++) {
      var adopted = toAdopt[i]
      adopted.parent = hostArea
      adopted.anchors.fill = hostArea
      adopted.visible = true
    }

    // Keep the window unmapped forever, but let the panel believe it is
    // open — panels gate peak monitors, scans and refresh timers on
    // `opened`, and the adopted content still binds to panel state.
    // Break kb's `open: root.opened` binding FIRST so flipping the
    // controller can never map the surface or trigger popout coordination.
    kb.open = false
    if ("controller" in panel && panel.controller)
      panel.controller.open = true
  }

  ColumnLayout {
    id: fallback
    anchors.fill: parent
    anchors.margins: Style.space(12)
    visible: !root.installed || root.adoptFailed
    spacing: Style.space(6)

    Item { Layout.fillHeight: true; Layout.fillWidth: true }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "󰅙"
      color: root.fg
      opacity: 0.4
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.iconLarge * 1.4
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: root.manifestId
      color: root.fg
      opacity: 0.5
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: root.installed ? "Panel could not be embedded" : "Not installed"
      color: root.fg
      opacity: 0.4
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }

    Item { Layout.fillHeight: true; Layout.fillWidth: true }
  }

  // The panel lives here, invisible; its content is adopted out of it.
  Loader {
    id: panelLoader
    active: root.installed && root.panelPath !== "" && !root.adoptFailed
    visible: false
    source: root.panelPath
    onLoaded: Qt.callLater(root.adoptContent)
  }

  // Adoption target — the plugin content fills this.
  Item {
    id: hostArea
    anchors.fill: parent
  }

  HoverHandler {
    enabled: true
    onHoveredChanged: root.hovered = hovered
  }
}
