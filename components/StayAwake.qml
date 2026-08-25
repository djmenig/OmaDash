import QtQuick
import qs.Ui

BarIndicator {
  id: root
  property bool flash: false

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("omarchy.idle")

  active: (idleService ? idleService.stayAwake : false) || root.flash
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Allow Idle Lock & Screensaver"
  inactiveTooltipText: "Stay Awake"

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(!root.idleService.stayAwake)
  }

  onPressed: function() {
    root.flash = true
    flashTimer.restart()
    root.toggle()
  }
  Timer { id: flashTimer; interval: 150; onTriggered: root.flash = false }

}
