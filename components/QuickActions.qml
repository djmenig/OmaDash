import QtQuick
import qs.Commons
import qs.Ui
import "./"

// Quick Actions: a 1-to-1 replica of Omarchy's built-in Indicators plugin
// (Dictation, Screen Recording, Reminder, Night Light, DND, Stay Awake),
// placed in the expanded dashboard's top header (left column). The six
// indicator QML files are copied verbatim from the shell and behave exactly
// as in the bar — active glyphs render at full opacity, inactive at a dimmed
// opacity (indicatorHost.revealInactiveIndicators), so the row is always
// visible with an obvious active/inactive state.
//
// The indicators are given a thin `barProxy` instead of the real bar: it
// forwards `shell` (for firstPartyServiceFor) and `run` (for toggles) but
// omits the bar's click-target machinery, so the popup's indicators never
// register as bar click-targets (which would cause stray bar highlight
// side-effects). Hover labels are driven by a single Popup-scoped
// `PanelToolTip` (indicatorTip) wired through the proxy's showTooltip/
// hideTooltip, so each icon shows its existing tooltipText on hover.
Item {
  id: root
  property var bar: null

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  // Thin `bar` stand-in: forwards `shell` (firstPartyServiceFor) and `run`
  // (toggles) but omits the real bar's click-target/tooltip machinery so the
  // popup's indicators never register as bar click-targets. It also exposes
  // the `bar.*` sizing/style properties BarIndicator/WidgetButton read via
  // `bar ? bar.x : default` — WITHOUT these, the truthy-but-empty proxy makes
  // those ternaries pick `undefined` and the indicators collapse to 0 height.
  QtObject {
    id: barProxy
    property var shell: root.bar ? root.bar.shell : null
    property bool vertical: false
    property real barSize: Style.bar.sizeHorizontal
    property color barForeground: Color.foreground
    property string fontFamily: Style.font.family
    property color urgent: Color.urgent
    property bool foregroundAnimationEnabled: true
    function run(cmd) { if (root.bar) root.bar.run(cmd) }
    function showTooltip(target, text) {
      indicatorTip.text = text
      indicatorTip.parent = target
      indicatorTip.visible = true
    }
    function hideTooltip(target) {
      indicatorTip.visible = false
    }
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
  }

  QtObject {
    id: indicatorHost
    property bool revealInactiveIndicators: true
    signal refreshRequested()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: indicatorHost.refreshRequested()
  }

  PanelToolTip {
    id: indicatorTip
    visible: false
  }

  Row {
    id: row
    // Centered in the slot: visually balanced between the panel's left
    // edge and the search field beside it.
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(8)

    Dictation { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
    ScreenRecording { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
    Reminder { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
    NightLight { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
    Dnd { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
    StayAwake { bar: barProxy; indicatorHost: indicatorHost; fontSize: 15; fixedWidth: 26 }
  }
}

