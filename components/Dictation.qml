import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root
  property bool flash: false

  property string state: "idle"
  property string icon: ""

  active: state === "recording" || root.flash
  activeText: icon
  inactiveText: "󰍬"
  activeTooltipText: state
  inactiveTooltipText: "Dictate"

  function update(raw) {
    var data = extractData(raw)

    state = String(data.alt || data.class || "idle")
    if (state === "recording") icon = "󰍬"
    else if (state === "transcribing") icon = "󰔟"
    else icon = ""
  }

  Process {
    command: ["bash", "-c", "omarchy-voxtype-status"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
  }

  onPressed: function() {
    root.flash = true
    flashTimer.restart()
    if (!root.bar) return
    root.bar.run("omarchy-voxtype-config")
  }
  Timer { id: flashTimer; interval: 150; onTriggered: root.flash = false }

}
