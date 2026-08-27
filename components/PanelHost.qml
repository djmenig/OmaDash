import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../components/DashboardRegistry.js" as Registry

// PanelHost: embeds a real plugin panel's UI inside a dashboard card.
// Strategy: load the plugin's Panel.qml, hide the bar-widget icon,
// suppress the KeyboardPanel layer-shell surface (kb.open = false),
// make the controller think it's open (so timers/scans run), then
// let the panel render its content directly inside this item.
Item {
  id: root
  property string pluginId: ""
  property var bar: null
  property bool hovered: false

  readonly property color fg: (bar && bar.foreground) ? bar.foreground : Color.foreground
  readonly property color accent: (bar && bar.accent) ? bar.accent : Color.accent

  readonly property string manifestId: pluginId.indexOf("panel:") === 0 ? pluginId.slice("panel:".length) : pluginId
  property var manifest: null
  property bool installed: false

  readonly property string panelEntry: {
    if (!root.installed) return ""
    var ep = root.manifest.entryPoints || {}
    if (ep.panel !== undefined) return ep.panel
    if (ep.barWidget !== undefined && String(ep.barWidget).indexOf("Panel.qml") >= 0)
      return ep.barWidget
    return "Panel.qml"
  }
  readonly property string panelPath: root.installed && root.panelEntry !== ""
    ? "file://" + root.manifest.__sourceDir + "/" + root.panelEntry
    : ""

  property var kbPanel: null
  property bool loadFailed: false
  property bool _contentReady: false

  implicitWidth: root.installed ? Math.max(280, root.kbPanel ? Math.round(root.kbPanel.fittedContentWidth ? root.kbPanel.fittedContentWidth(380) : (root.kbPanel.contentWidth || 320)) : 320) : 280
  implicitHeight: root.installed ? Math.max(280, root.kbPanel ? Math.round(root.kbPanel.fittedContentHeight ? root.kbPanel.fittedContentHeight(root._contentImplicitH) : (root.kbPanel.contentHeight || 380)) : 380) : 160

  // Track the adopted content's implicit height for the sizing binding.
  property real _contentImplicitH: 0

  function findKbPanel(panel) {
    var kids = panel.data
    for (var i = 0; i < kids.length; i++) {
      var c = kids[i]
      if (!c) continue
      if (c.fittedContentWidth !== undefined || c.anchorItem !== undefined || c.toString().indexOf("KeyboardPanel") >= 0) {
        return c
      }
    }
    return null
  }

  function resolveManifest() {
    if (root.manifest) return
    var pid = root.pluginId
    var mid = pid.indexOf("panel:") === 0 ? pid.slice("panel:".length) : pid
    var reg = root.bar && root.bar.shell && root.bar.shell.pluginRegistry ? root.bar.shell.pluginRegistry : null
    if (!reg) { return }
    var all = reg.installedPlugins || {}
    root.manifest = all[mid] || null
    root.installed = !!root.manifest
    if (root.installed) {
      root.loadPanel()
    }
  }

  onBarChanged: root.resolveManifest()
  onPluginIdChanged: root.resolveManifest()

  function loadPanel() {
    if (!root.installed || root.panelPath === "") {
      root.loadFailed = true
      return
    }
  }

  function configureKbPanel(panel) {
    var kb = findKbPanel(panel)
    if (!kb) {
      Qt.callLater(function() { root.configureKbPanel(panel) })
      return
    }
    root.kbPanel = kb

    // Hide the bar widget button (BarIconButton) — it uses anchors.fill:parent
    // and would paint the compact icon over the entire card.
    var kids = panel.data
    for (var i = 0; i < kids.length; i++) {
      var c = kids[i]
      if (c && c.toString().indexOf("BarIconButton") >= 0) {
        c.visible = false
        break
      }
    }

    // Suppress the layer-shell window but keep timers running.
    kb.open = false
    if ("controller" in panel && panel.controller)
      panel.controller.open = true

    if (panel.refresh)
      panel.refresh(true)

    // Adopt content from the KeyboardPanel's contentItem. The content lives
    // in contentHolder.children inside the PanelWindow. We reparent it to
    // hostArea so it renders inside this card. Poll until real content
    // appears (wifi networks load asynchronously).
    // Key insight: the actual UI (Column with wifi list etc.) is nested
    // INSIDE the PanelKeyCatcher, not a sibling. So we dig one level
    // deeper to find the real content to reparent into hostArea.
    function tryAdopt() {
      var content = kb.contentItem
      if (!content) {
        Qt.callLater(tryAdopt)
        return
      }
      var items = content.length !== undefined ? content : [content]
      var toAdopt = []
      for (var i = 0; i < items.length; i++) {
        var item = items[i]
        if (!item) continue
        var name = item.objectName || ""
        var str = item.toString()
        var isKeyCatcher = name === "keyCatcher" || str.indexOf("PanelKeyCatcher") >= 0
        if (isKeyCatcher) {
          // The real content (Column etc.) is INSIDE the PanelKeyCatcher.
          // Dig into its children to find adoptable content.
          var kcKids = item.children || []
          for (var k = 0; k < kcKids.length; k++) {
            var kcChild = kcKids[k]
            if (kcChild && kcChild.toString().indexOf("PanelKeyCatcher") < 0)
              toAdopt.push(kcChild)
          }
        } else {
          toAdopt.push(item)
        }
      }
      if (toAdopt.length === 0) {
        Qt.callLater(tryAdopt)
        return
      }
      if (root._contentReady) return
      for (var i = 0; i < toAdopt.length; i++) {
        var adopted = toAdopt[i]
        if (adopted) {
          adopted.parent = hostArea
          adopted.visible = true
        }
      }
      root._contentReady = true
      if (hostArea.children.length > 0)
        root._contentImplicitH = hostArea.children[0].implicitHeight || 380
    }
    Qt.callLater(tryAdopt)
  }

  Component.onCompleted: root.resolveManifest()

  // Adoption target — the plugin content fills this.
  Item {
    id: hostArea
    anchors.fill: parent
    clip: true
  }

  // Fallback UI — shown if panel fails to load
  ColumnLayout {
    id: fallback
    anchors.fill: parent
    anchors.margins: Style.space(12)
    visible: !root.installed || root.loadFailed
    spacing: Style.space(6)

    Item { Layout.fillHeight: true; Layout.fillWidth: true }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: "?"
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
      elide: Text.ElideRight
    }

    Item { Layout.fillHeight: true; Layout.fillWidth: true }
  }

  // The panel loads here. Visible so the content tree is fully created and
  // laid out (invisible Loaders leave children with zero effective size).
  // Once content is adopted into hostArea, we hide this loader.
  Loader {
    id: panelLoader
    active: root.installed && root.panelPath !== "" && !root.loadFailed
    visible: !root._contentReady
    source: root.panelPath
    onLoaded: {
      if (item) {
        item.bar = root.bar
        item.settings = {}
        if ("manageIpc" in item) item.manageIpc = false
        Qt.callLater(function() { root.configureKbPanel(item) })
      }
    }
  }

  HoverHandler {
    enabled: true
    onHoveredChanged: root.hovered = hovered
  }
}
