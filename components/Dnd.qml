import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂚"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  onPressed: function() {
    if (root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }

  // Invert BarIndicator's default opacity for DND: "on" (silencing) is dimmed,
  // "off" (allow notifications) is full. Deferred via Timer so it applies AFTER
  // syncIndicatorOpacity() (which otherwise re-dims the off state, since base
  // handlers run after the derived instance's on the same signals).
  Timer {
    id: opacityFix
    interval: 1
    onTriggered: root.opacity = root.active ? 0.45 : 1
  }
  Component.onCompleted: opacityFix.restart()
  onActiveChanged: opacityFix.restart()
  onEffectiveActiveChanged: opacityFix.restart()
}
