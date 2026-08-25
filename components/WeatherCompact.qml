import QtQuick
import qs.Commons
import qs.Ui
import "../engine"
import "./CompactFormats.js" as Formats

// Compact Weather: mirrors the built-in weather pill (icon glyph +
// temperature) using the shared WeatherEngine's live reading. Right-click
// cycles five display modes (persisted): full °C, icon (unit-agnostic),
// temp °C, full °F, temp °F. Left-click opens OmaDash. Refresh failures
// keep the last reading visible.
WidgetButton {
  id: root
  signal clicked()

  property string mode: DashboardConfig.settings.weatherMode || "full-c"

  readonly property bool loaded: WeatherEngine.loaded
  readonly property string glyph: root.loaded ? WeatherEngine.current.glyph : "󰖐"

  // The compact mode selects the shared display unit (icon preserves the
  // current unit — the glyph carries no temperature).
  onModeChanged: {
    if (root.mode === "full-f" || root.mode === "temp-f") WeatherEngine.celsius = false
    else if (root.mode === "full-c" || root.mode === "temp-c") WeatherEngine.celsius = true
  }
  Component.onCompleted: {
    if (root.mode === "full-f" || root.mode === "temp-f") WeatherEngine.celsius = false
  }

  text: {
    if (!root.loaded) return "…"
    var t = WeatherEngine.dispTemp(WeatherEngine.current.temp) + "°"
    if (root.mode === "full-c" || root.mode === "full-f") return glyph + " " + t
    if (root.mode === "temp-c" || root.mode === "temp-f") return t
    return glyph
  }

  horizontalMargin: 8.75
  verticalPadding: 8.75

  onPressed: function(b) {
    if (b === Qt.LeftButton) {
      root.clicked()
    } else if (b === Qt.RightButton) {
      root.mode = Formats.nextWeatherMode(root.mode)
      DashboardConfig.setSetting("weatherMode", root.mode)
    }
  }
}
