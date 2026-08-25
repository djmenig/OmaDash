import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../engine"

// PomodoroOverlay: Fokus-style fullscreen focus overlay, one window per
// screen (all monitors), bound to the shared PomodoroEngine. Shows a giant
// live countdown with Stop / Postpone / Skip / Close. Close hides the
// overlay while the timer keeps running; Stop ends the session.
Item {
  id: root

  function fmt(s) {
    s = Math.max(0, Math.floor(s))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var ss = s % 60
    var p = function (n) { return (n < 10 ? "0" : "") + n }
    return (h > 0 ? h + ":" + p(m) : m) + ":" + p(ss)
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: w

      required property var modelData
      readonly property bool primary: modelData === Quickshell.screens[0]

      screen: modelData
      visible: PomodoroEngine.overlayOpen
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.9)
      exclusionMode: ExclusionMode.Ignore

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "omadash-pomodoro-overlay"
      WlrLayershell.keyboardFocus: visible && primary
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

      // Esc closes the overlay (primary screen holds keyboard focus).
      Item {
        id: keyScope
        anchors.fill: parent
        focus: w.primary
        Keys.onEscapePressed: PomodoroEngine.closeOverlay()
      }

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.space(28)

        // Fokus TimerFace dial: progress ring, countdown digits inside,
        // phase label on the face.
        // NOTE: Layout children are sized from Layout.preferred* — explicit
        // width/height bindings are overridden by the ColumnLayout.
        Item {
          id: dial
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: Math.min(parent.width, parent.height) * 0.7
          Layout.preferredHeight: Layout.preferredWidth

          Canvas {
            id: dialCanvas
            anchors.fill: parent
            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var cx = width / 2
              var cy = height / 2
              var r = width / 2 - Style.space(14)
              var lw = Math.max(6, Math.round(width * 0.03))
              var progress = PomodoroEngine.duration > 0
                ? Math.max(0, Math.min(1, PomodoroEngine.remaining / PomodoroEngine.duration))
                : 0

              ctx.lineWidth = lw
              ctx.strokeStyle = Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
              ctx.beginPath()
              ctx.arc(cx, cy, r, 0, Math.PI * 2)
              ctx.stroke()

              if (progress > 0) {
                ctx.strokeStyle = Color.accent
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + progress * Math.PI * 2)
                ctx.stroke()
              }

              ctx.fillStyle = Color.muted
              ctx.font = "500 " + Math.round(r * 0.16) + "px " + Style.font.menuFamily
              ctx.textAlign = "center"
              var phaseLabel = PomodoroEngine.phase === "focus"
                ? "FOCUS"
                : (PomodoroEngine.duration === PomodoroEngine.longBreakDuration ? "LONG BREAK" : "BREAK")
              ctx.fillText(phaseLabel, cx, cy - r * 0.38)

              ctx.fillStyle = Color.foreground
              ctx.font = "500 " + Math.round(r * 0.52) + "px " + Style.font.menuFamily
              ctx.fillText(root.fmt(PomodoroEngine.remaining), cx, cy + r * 0.18)

              // Session dots — one per focus in the cycle, subtle: filled for
              // completed, hairline outline for remaining.
              var n = PomodoroEngine.longBreakEvery
              var dotSpacing = r * 0.3
              var startX = cx - (n - 1) * dotSpacing / 2
              var dotY = cy + r * 0.52
              for (var d = 0; d < n; d++) {
                ctx.beginPath()
                ctx.arc(startX + d * dotSpacing, dotY, 2.5, 0, Math.PI * 2)
                if (d < PomodoroEngine.completedFocuses) {
                  ctx.fillStyle = Color.accent
                  ctx.fill()
                } else {
                  ctx.lineWidth = 1
                  ctx.strokeStyle = Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.3)
                  ctx.stroke()
                }
              }
            }
            Connections {
              target: PomodoroEngine
              function onRemainingChanged() { dialCanvas.requestPaint() }
              function onDurationChanged() { dialCanvas.requestPaint() }
              function onPhaseChanged() { dialCanvas.requestPaint() }
              function onCompletedFocusesChanged() { dialCanvas.requestPaint() }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: requestPaint()
            Component.onCompleted: requestPaint()
          }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: Style.space(6) }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.space(14)

          Button {
            text: "Stop"
            bordered: true
            foreground: Color.urgent
            onClicked: PomodoroEngine.reset()
          }

          Button {
            text: "Postpone +5"
            bordered: true
            foreground: Color.foreground
            onClicked: PomodoroEngine.postpone()
          }

          Button {
            text: PomodoroEngine.phase === "break" ? "Skip Break" : "Skip"
            bordered: true
            foreground: Color.foreground
            onClicked: PomodoroEngine.skip()
          }

          Button {
            text: "Close"
            bordered: true
            foreground: Color.foreground
            onClicked: PomodoroEngine.closeOverlay()
          }
        }
      }
    }
  }
}
