import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "../components/caps.js" as Caps

BarIndicator {
  id: root
  property bool flash: false

  property int reminderCount: 0
  property string tooltip: ""

  active: reminderCount > 0 || root.flash
  activeText: "󰢌"
  inactiveText: "󰢌"
  activeTooltipText: tooltip
  inactiveTooltipText: tooltip

  function refresh() {
    if (!jsonProc.running) { jsonProc.running = true; jsonDeadline.restart() }
  }

  function openReminderFlow() {
    Quickshell.execDetached(["omarchy-reminder", "-i"])
  }

  function update(raw) {
    // Bounded retention: a malformed or huge reminder JSON must not make us
    // retain/parse unbounded input. Cap before extractData, which only needs
    // a small {count, tooltip} object.
    raw = String(raw || "").slice(0, Caps.MAX_REMINDER)
    var data = extractData(raw)
    reminderCount = Number(data.count || 0)
    tooltip = String(data.tooltip || "")
  }

  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: jsonProc
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
    onExited: function(exitCode) {
      jsonDeadline.stop()
      if (exitCode !== 0) {
        root.reminderCount = 0
        root.tooltip = ""
      }
    }
  }

  // Hard deadline: if the reminder query never exits, SIGTERM it so the
  // indicator can't stay wedged "loading".
  property Timer jsonDeadline: Timer {
    interval: 5000
    repeat: false
    onTriggered: { if (jsonProc.running) jsonProc.running = false }
  }

  onPressed: function() {
    root.flash = true
    flashTimer.restart()
    if (root.reminderCount > 0) Quickshell.execDetached(["omarchy-reminder", "show"])
    else root.openReminderFlow()
  }
  Timer { id: flashTimer; interval: 150; onTriggered: root.flash = false }

}
