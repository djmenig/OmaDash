// Dashboard plugin registry: id -> descriptor.
// Two card species:
//   - built-in views (calendar/pomodoro/weather/notifications) backed by
//     omadash components
//   - launcher tiles for scanned system plugins, addressed as
//     "plugin:<manifest-id>" — the tile summons the real plugin via IPC
function descriptor(id) {
  if (id && id.indexOf("plugin:") === 0) {
    return {
      id: id,
      label: id.slice("plugin:".length),
      description: "System plugin",
      source: "PluginTile.qml",
      kind: "launcher",
      cols: 1,
      rows: 1
    }
  }
  if (id && id.indexOf("panel:") === 0) {
    return {
      id: id,
      label: id.slice("panel:".length),
      description: "Live plugin panel",
      source: "PanelHost.qml",
      kind: "panel",
      cols: 1,
      rows: 1
    }
  }
  switch (id) {
    case "calendar":
      return { id: "calendar", label: "Calendar", description: "Month calendar with year progress", source: "CalendarView.qml", cols: 2, rows: 2 }
    case "pomodoro":
      return { id: "pomodoro", label: "Pomodoro", description: "Focus countdown timer", source: "PomodoroExpanded.qml", cols: 1, rows: 1 }
    case "weather":
      return { id: "weather", label: "Weather", description: "Current conditions", source: "WeatherExpanded.qml", cols: 1, rows: 1 }
    case "notifications":
      return { id: "notifications", label: "Notifications", description: "Notification history", source: "NotificationsView.qml", cols: 1, rows: 1 }
  }
  return null
}

function allIds() {
  return ["calendar", "pomodoro", "weather", "notifications"]
}

function defaults() {
  return ["pomodoro", "calendar", "weather"]
}

// Nerd-font glyph for a plugin manifest's kinds array.
function kindGlyph(kinds) {
  var k = kinds || []
  if (k.indexOf("menu") >= 0) return ""
  if (k.indexOf("overlay") >= 0) return ""
  if (k.indexOf("panel") >= 0) return "󰀱"
  if (k.indexOf("bar-widget") >= 0) return "󰾔"
  return "󰀻"
}
