import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../engine"

// Expanded Pomodoro: a minimal, in-memory 25:00 countdown timer.
// Bound to the shared PomodoroEngine singleton (one instance across the bar).
// Transparent container — the KeyboardPanel popup provides the card surface.
Item {
  id: root
  property var bar: null
  readonly property color fg: bar ? bar.foreground : Color.foreground

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight

  function fmt(s) {
    var m = Math.floor(s / 60)
    var ss = s % 60
    return (m < 10 ? "0" : "") + m + ":" + (ss < 10 ? "0" : "") + ss
  }

  ColumnLayout {
    id: col
    anchors.fill: parent
    spacing: Style.space(8)

    Text {
      text: "Pomodoro"
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      color: Color.muted
    }

    // Fokus TimerFace dial (matches the fullscreen overlay): progress ring
    // with the countdown digits and phase label inside.
    // NOTE: Layout children are sized from Layout.preferred* — explicit
    // width/height bindings are overridden by the ColumnLayout.
    Item {
      id: dial
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: Math.min(col.width - Style.space(8), Style.space(200))
      Layout.preferredHeight: Layout.preferredWidth

      Canvas {
        id: dialCanvas
        anchors.fill: parent
        onVisibleChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var cx = width / 2
          var cy = height / 2
          var r = width / 2 - Style.space(8)
          var lw = Math.max(5, Math.round(width * 0.045))
          var progress = PomodoroEngine.duration > 0
            ? Math.max(0, Math.min(1, PomodoroEngine.remaining / PomodoroEngine.duration))
            : 0

          ctx.lineWidth = lw
          ctx.strokeStyle = Util.alpha(root.fg, 0.14)
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
          ctx.font = "500 " + Math.round(r * 0.18) + "px " + Style.font.menuFamily
          ctx.textAlign = "center"
          ctx.fillText(PomodoroEngine.phase === "break" ? "BREAK" : "FOCUS", cx, cy - r * 0.38)

          ctx.fillStyle = root.fg
          ctx.font = "500 " + Math.round(r * 0.5) + "px " + Style.font.menuFamily
          ctx.fillText(fmt(PomodoroEngine.remaining), cx, cy + r * 0.18)
        }
        Connections {
          target: PomodoroEngine
          function onRemainingChanged() { dialCanvas.requestPaint() }
          function onDurationChanged() { dialCanvas.requestPaint() }
          function onPhaseChanged() { dialCanvas.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
      }
    }

    RowLayout {
      spacing: Style.space(6)

      Button {
        text: PomodoroEngine.running ? "Pause" : "Start"
        bordered: true
        foreground: root.fg
        onClicked: PomodoroEngine.toggle()
      }

      Button {
        text: "Reset"
        bordered: true
        foreground: root.fg
        onClicked: PomodoroEngine.reset()
      }

      Button {
        text: "+5 min"
        bordered: true
        foreground: root.fg
        tooltipText: "Postpone"
        onClicked: PomodoroEngine.postpone()
      }

      Button {
        text: "Skip"
        bordered: true
        foreground: root.fg
        tooltipText: "End session"
        onClicked: PomodoroEngine.skip()
      }
    }
  }
}
