import QtQuick
import qs.Commons
import qs.Ui
import "../engine"
import "./CompactFormats.js" as Formats

// Compact Clock: mirrors the built-in clock's WidgetButton (same font,
// foreground, padding). Its width is FIXED to the widest string the current
// format can produce, so the slot never resizes as the time ticks and the
// compact widget can center on this slot. Left-click opens OmaDash;
// right-click cycles the format through the built-in clock's full ring
// (persisted in omadash settings).
WidgetButton {
  id: root
  signal clicked()

  // Adjustable clock format, persisted across restarts.
  property string format: DashboardConfig.settings.clockFormat || "h:mm AP"

  // Ticked by the Timer; the text BINDS to this so a format switch renders
  // instantly (an imperative text assignment here would break the binding
  // and leave stale/raw formatting until the next tick).
  property date now: new Date()

  // The built-in formats with Qt.formatDateTime (NOT formatTime — date
  // tokens render as literal junk in formatTime) after substituting the
  // 'ww' ISO-week token, which Qt has no specifier for.
  function displayFormat(date) {
    return Formats.applyIsoWeek(root.format, date)
  }

  text: Qt.formatDateTime(root.now, root.displayFormat(root.now))
  horizontalMargin: 8.75
  verticalPadding: 8.75

  FontMetrics {
    id: fm
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  // Widest time string the format can render (monospace font, so the only
  // variance is digit count). Sampling a few representative times and taking
  // the max keeps the width stable per-format. Same substitution pipeline
  // as the live text.
  function widestWidth() {
    var samples = [
      new Date(2000, 0, 12, 12, 59, 59),
      new Date(2000, 0, 12, 23, 59, 59),
      new Date(2000, 0, 12, 9,  0,  0),
      new Date(2000, 0, 12, 10, 0,  0)
    ]
    var w = 0
    for (var i = 0; i < samples.length; i++)
      w = Math.max(w, fm.boundingRect(Qt.formatDateTime(samples[i], root.displayFormat(samples[i]))).width)
    return w
  }

  fixedWidth: widestWidth() + horizontalMargin * 2

  onPressed: function(b) {
    if (b === Qt.LeftButton) {
      root.clicked()
    } else if (b === Qt.RightButton) {
      root.format = Formats.nextInRing(Formats.clockRing(root.format), root.format)
      DashboardConfig.setSetting("clockFormat", root.format)
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }
}
