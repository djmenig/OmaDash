import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "components"

// OmaDash bar-widget entry point. Owns the compact slot (CollapsedBar) and
// loads the expanded dashboard (Panel.qml) internally. All lifecycle is
// forwarded to the loaded panel — mirrors the omarchy.clock contract.
BarWidget {
  id: root
  moduleName: "djmenig.omadash"

  // Size the bar slot from the compact widget (the bar sizes slots from
  // implicitWidth/Height; without this the slot is 0x0 and invisible).
  implicitWidth: collapsedBar.implicitWidth
  implicitHeight: collapsedBar.implicitHeight

  // Open-panel indicator (matches built-in clock/weather): the bar paints a
  // dot under the widget when its dashboard is open. Span the whole OmaDash
  // widget (all three slots), not just the clock label.
  readonly property real openPanelIndicatorWidth: Math.max(collapsedBar.implicitWidth, Style.space(40))
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // ---- Lifecycle forwarded to the loaded Panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function summon() { open() }
  function hide() { close() }
  function refresh() { if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // Push the host context into the panel once it loads (and whenever the bar
  // re-injects bar/settings, which happens on layout/theme changes).
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = collapsedBar
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  CollapsedBar {
    id: collapsedBar
    anchors.fill: parent
    bar: root.bar
    onRequestToggle: root.togglePanel()
  }

  // Exposed so the open-panel indicator can line up under the clock slot.
  readonly property var clockSlot: collapsedBar.clockSlot

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}
