import QtQuick
import QtQuick.Layouts
import qs.Commons

// Compact top bar: Pomodoro (left) | Clock (middle) | Weather (right).
// Every slot emits clicked(); the parent wires them all to open OmaDash.
// `bar` is forwarded from BarWidget so the built-in button components can
// pick up the bar's font/foreground and tooltips.
Item {
  id: root
  signal requestToggle()
  property var bar: null
  readonly property real clockLabelWidth: clockSlot.labelWidth

  implicitHeight: 28
  implicitWidth: layout.implicitWidth

  RowLayout {
    id: layout
    anchors.horizontalCenter: parent.horizontalCenter
    height: parent.height
    spacing: Style.space(8)

    // Balancing spacers: Slot A and Slot C are auto-sized (and differ in
    // width), while Slot B (clock) is the fixed center anchor. The wider side
    // gets an empty spacer so both wings (spacer + A  vs  C + spacer) are
    // equal, keeping the widget's center on Slot B.
    Item {
      id: leftSpacer
      Layout.fillHeight: true
      Layout.preferredWidth: Math.max(0, wx.implicitWidth - pomo.implicitWidth)
    }

    PomodoroCompact {
      id: pomo
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.requestToggle()
    }

    ClockCompact {
      id: clockSlot
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.requestToggle()
    }

    WeatherCompact {
      id: wx
      Layout.fillHeight: true
      Layout.alignment: Qt.AlignVCenter
      onClicked: root.requestToggle()
    }

    Item {
      id: rightSpacer
      Layout.fillHeight: true
      Layout.preferredWidth: Math.max(0, pomo.implicitWidth - wx.implicitWidth)
    }
  }
}
