import QtQuick
import qs.Commons
import qs.Ui
import "../engine"
import "./CompactFormats.js" as Formats

// Compact Pomodoro: Fokus-style ring indicator with three modes, cycled by
// right-click (persisted):
//   ring         — the ring alone: ready (empty track + play glyph),
//                  paused (track + pause bars), running (accent sweep arc
//                  drains with the remaining fraction, nothing inside)
//   ring-clock   — the ring with the countdown centered inside it (colon
//                  on the ring's center); same states
//   clock        — the bare countdown text (gentle blink when paused)
// Left-click starts/pauses focus; starting opens the fullscreen overlay on
// break (Fokus behavior).
WidgetButton {
  id: root
  signal clicked()

  property string mode: DashboardConfig.settings.pomodoroMode || "ring"

  readonly property bool running: PomodoroEngine.running
  readonly property bool paused: PomodoroEngine.paused
  // Fokus: the indicator's progress is the REMAINING fraction — the arc
  // drains as the session elapses.
  readonly property real remainingFraction: PomodoroEngine.duration > 0
    ? Math.max(0, Math.min(1, PomodoroEngine.remaining / PomodoroEngine.duration))
    : 0

  // Countdown while running/paused; the ring reserves its zone via NBSPs.
  // NEVER empty — WidgetButton hides itself when text is empty.
  text: {
    if (root.mode === "clock") return fmt()
    if (root.mode === "ring-clock" && (root.running || root.paused)) return fmt()
    return nbsp + nbsp + nbsp + nbsp
  }

  readonly property string nbsp: "\u00A0"

  function fmt() {
    var s = Math.max(0, PomodoroEngine.remaining)
    var m = Math.floor(s / 60)
    var ss = s % 60
    return m + ":" + (ss < 10 ? "0" : "") + ss
  }

  // Gentle paused blink (clock mode only): slow, low-amplitude —
  // communicates "held, not dead" without strobing.
  SequentialAnimation {
    running: root.paused && root.mode === "clock" && root.visible
    loops: Animation.Infinite
    alwaysRunToEnd: true

    NumberAnimation {
      target: root
      property: "opacity"
      to: 0.45
      duration: 600
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: root
      property: "opacity"
      to: 1
      duration: 600
      easing.type: Easing.InOutSine
    }
  }

  FontMetrics {
    id: fm
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
  }

  Canvas {
    id: indicator
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      if (root.mode === "clock")
        return   // the WidgetButton label IS the countdown; blink handled above

// Fokus proportions, per the user's tuning: diameter ~2px smaller
      // than the slot-derived extent, ring stroke ~1px thicker.
      var extent = Math.min(width, height) * 15 / 22
      var stroke = Math.max(1, Math.round(extent / 8))
      var accent = Color.accent
      var track = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
      var cx = width / 2
      var cy = height / 2
      var r = extent / 2
      var accent = Color.accent
      var track = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
      var cx = width / 2
      var cy = height / 2
      var r = extent / 2

      // Ring outline.
      ctx.lineWidth = stroke
      ctx.strokeStyle = track
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2)
      ctx.stroke()

      // Ring-clock mode: the ring with countdown centered inside.
      if (root.mode === "ring-clock") {
        // Ring outline.
        ctx.lineWidth = stroke
        ctx.strokeStyle = track
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.stroke()

        if (root.running) {
          ctx.strokeStyle = accent
          ctx.beginPath()
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + root.remainingFraction * Math.PI * 2)
          ctx.stroke()
        } else if (root.paused) {
          var bw = Math.max(2, Math.round(extent * 0.08))
          var bh = Math.round(extent * 0.3)
          var gap = Math.max(2, Math.round(extent * 0.08))
          ctx.fillStyle = root.foreground
          ctx.fillRect(cx - gap / 2 - bw, cy - bh / 2, bw, bh)
          ctx.fillRect(cx + gap / 2, cy - bh / 2, bw, bh)
        }
        // Countdown text centered inside the ring (WidgetButton label handles text)
        return
      }

      // Ring mode
      if (root.mode === "ring") {
        ctx.lineWidth = stroke
        ctx.strokeStyle = track
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.stroke()

        if (root.running) {
          if (root.remainingFraction > 0) {
            ctx.strokeStyle = accent
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + root.remainingFraction * Math.PI * 2)
            ctx.stroke()
          }
        } else if (root.paused) {
          var bw = Math.max(2, Math.round(extent * 0.08))
          var bh = Math.round(extent * 0.3)
          var gap = Math.max(2, Math.round(extent * 0.08))
          ctx.fillStyle = root.foreground
          ctx.fillRect(cx - gap / 2 - bw, cy - bh / 2, bw, bh)
          ctx.fillRect(cx + gap / 2, cy - bh / 2, bw, bh)
        } else {
          ctx.fillStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
          ctx.font = Math.round(extent * 0.32) + "px " + root.fontFamily
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText("\u25B6", cx, cy + 1)
        }
        return
      }

      // Pie (wedge) mode
      if (root.mode === "pie") {
        ctx.lineWidth = stroke
        ctx.strokeStyle = track
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.stroke()

        if (root.running) {
          ctx.fillStyle = accent
          ctx.beginPath()
          ctx.moveTo(cx, cy)
          ctx.arc(cx, cy, Math.max(1, r - stroke - 1), -Math.PI / 2, -Math.PI / 2 + root.remainingFraction * Math.PI * 2)
          ctx.closePath()
          ctx.fill()
        } else if (root.paused) {
          var bw = Math.max(2, Math.round(extent * 0.08))
          var bh = Math.round(extent * 0.3)
          var gap = Math.max(2, Math.round(extent * 0.08))
          ctx.fillStyle = root.foreground
          ctx.fillRect(cx - gap / 2 - bw, cy - bh / 2, bw, bh)
          ctx.fillRect(cx + gap / 2, cy - bh / 2, bw, bh)
        } else {
          ctx.fillStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
          ctx.font = Math.round(extent * 0.32) + "px " + root.fontFamily
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText("\u25B6", cx, cy + 1)
        }
        return
      }

      // Clock mode (bare countdown text)
      if (root.mode === "clock") {
        return
      }
    }
    Connections {
      target: PomodoroEngine
      function onRemainingChanged() { indicator.requestPaint() }
      function onDurationChanged() { indicator.requestPaint() }
      function onPhaseChanged() { indicator.requestPaint() }
    }
    Connections {
      target: root
      function onModeChanged() { indicator.requestPaint() }
      function onRunningChanged() { indicator.requestPaint() }
      function onPausedChanged() { indicator.requestPaint() }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }

  onPressed: function(b) {
    if (b === Qt.LeftButton) {
      PomodoroEngine.toggle()   // start (+ overlay on break) or pause
    } else if (b === Qt.RightButton) {
      root.mode = Formats.nextPomodoroMode(root.mode)
      DashboardConfig.setSetting("pomodoroMode", root.mode)
    }
  }
}