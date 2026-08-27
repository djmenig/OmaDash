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

  // Clock mode (V2B) uses theme grey (muted) for the countdown text,
  // matching the workspace selector's dimmed numbers.
  readonly property color defaultForeground: Color.foreground
  foreground: defaultForeground

  readonly property bool running: PomodoroEngine.running
  readonly property bool paused: PomodoroEngine.paused
  // Fokus: the indicator's progress is the REMAINING fraction — the arc
  // drains as the session elapses.
  readonly property real remainingFraction: PomodoroEngine.duration > 0
    ? Math.max(0, Math.min(1, PomodoroEngine.remaining / PomodoroEngine.duration))
    : 0

  // Vertical optical adjustment for the ring's center, in real px. The ring is
  // drawn on the slot's geometric center, but the sibling slots (clock,
  // weather) paint centered TEXT, whose ink sits a hair above its em box. To
  // make the ring read level with them, nudge the ring up by a fraction of a
  // pixel. Positive moves it down (invert if the ring ever reads high).
  property real ringCenterDy: -Style.spaceReal(0.75)

  // Countdown while running/paused; the ring reserves its zone via NBSPs.
  // NEVER empty — WidgetButton hides itself when text is empty.
  text: {
    if (root.mode === "clock") return fmt()
    if (root.mode === "ring-clock") return fmt() + nbsp + nbsp
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
      var extent = Math.min(width, height) * 11 / 22
      var stroke = Math.max(1, Math.round(extent / 8))
      var accent = Color.accent
      var track = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
      var cx = width / 2
      var cy = height / 2 + root.ringCenterDy
      var r = extent / 2

      // Ring-clock mode: countdown text rendered by WidgetButton (left), ring drawn on Canvas (right).
      if (root.mode === "ring-clock") {
        // Calculate text width to position ring on the right side.
        // Use the full displayed text (countdown + NBSPs) for accurate positioning.
        var text = fmt() + nbsp + nbsp
        var textWidth = fm.advanceWidth(text)
        var textMargin = Math.round(extent * 0.08)
        var ringX = textWidth + textMargin + r

        // Ring outline (secondary) positioned on the right.
        ctx.lineWidth = stroke
        ctx.strokeStyle = track
        ctx.beginPath()
        ctx.arc(ringX, cy, r, 0, Math.PI * 2)
        ctx.stroke()

        // Remaining fraction arc (accent, subtle).
        if (root.running) {
          ctx.strokeStyle = Color.accent
          ctx.beginPath()
          ctx.arc(ringX, cy, r, -Math.PI / 2, -Math.PI / 2 + root.remainingFraction * Math.PI * 2)
          ctx.stroke()
        } else if (root.paused) {
          var bw = Math.max(2, Math.round(extent * 0.08))
          var bh = Math.round(extent * 0.3)
          var gap = Math.max(2, Math.round(extent * 0.08))
          ctx.fillStyle = Color.accent
          ctx.fillRect(ringX - gap / 2 - bw, cy - bh / 2, bw, bh)
          ctx.fillRect(ringX + gap / 2, cy - bh / 2, bw, bh)
        }
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
          // Play triangle — sized a touch larger than the pause bars so it
          // reads with the same visual weight as the two solid bars.
          var ph = Math.round(extent * 0.36)
          var pw = Math.round(extent * 0.32)
          var px = cx - pw / 3
          ctx.fillStyle = root.foreground
          ctx.beginPath()
          ctx.moveTo(px, cy - ph / 2)
          ctx.lineTo(px, cy + ph / 2)
          ctx.lineTo(px + pw, cy)
          ctx.closePath()
          ctx.fill()
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
          // Play triangle — sized a touch larger than the pause bars so it
          // reads with the same visual weight as the two solid bars.
          var ph = Math.round(extent * 0.36)
          var pw = Math.round(extent * 0.32)
          var px = cx - pw / 3
          ctx.fillStyle = root.foreground
          ctx.beginPath()
          ctx.moveTo(px, cy - ph / 2)
          ctx.lineTo(px, cy + ph / 2)
          ctx.lineTo(px + pw, cy)
          ctx.closePath()
          ctx.fill()
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