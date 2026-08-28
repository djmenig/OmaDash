import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "components"
import "engine"

// Expanded dashboard host. Extends the qs.Ui Panel base (which owns the
// open/close lifecycle + popout coordination) and renders the content in a
// bar-anchored KeyboardPanel. manageIpc: false — BarWidget owns the IPC.
Panel {
  id: root
  moduleName: "djmenig.omadash"
  manageIpc: false

  // Injected by BarWidget.injectPanel().
  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property int screenH: Quickshell.screens.length ? Quickshell.screens[0].height : 1080
  property int screenW: Quickshell.screens.length ? Quickshell.screens[0].width : 1920

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher

    // Auto-sized to content; capped at ~98% of the screen on each axis.
    // fittedContentHeight already adds the card's vertical inset
    // (padding + borders) via verticalContentInset; the horizontal inset
    // has no stock counterpart, so compensate it here — otherwise the
    // content's width demand is truncated by the card's own padding and
    // the tiler can never fit one row.
    readonly property real _hInset:
      2 * (panel.padding + Math.max(Border.left(panel.borderSpec), 0) + Math.max(Border.right(panel.borderSpec), 0))

    contentWidth: panel.fittedContentWidth(Math.min(content.implicitWidth + 32 + _hInset, root.screenW * 0.98))
    contentHeight: panel.fittedContentHeight(Math.min(content.implicitHeight + 32, root.screenH * 0.98))

    PanelKeyCatcher { id: keyCatcher }

    ExpandedPanel {
      id: content
      anchors.fill: parent
      bar: root.bar
      screenH: root.screenH
      screenW: root.screenW
    }
  }

  // Track open/close so edit mode auto-exits when the last dashboard
  // closes (DashboardConfig counts instances across monitors), hand
  // keyboard focus to the search field like the launcher does, and
  // refresh the weather so the expanded card is current whenever viewed.
  onOpenedChanged: {
    if (opened) {
      DashboardConfig.panelOpened()
      WeatherEngine.fetchForecast()
      Qt.callLater(content.focusSearch)
    } else {
      DashboardConfig.panelClosed()
    }
  }

  Connections {
    target: content
    function onCloseRequested() { root.close() }
  }
}
