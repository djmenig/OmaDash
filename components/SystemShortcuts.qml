import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SystemShortcuts: power actions + an OmaDash settings shortcut, shown in the
// expanded dashboard's top header (right column). Icon-only — no text labels;
// each button surfaces its action via a hover tooltip. Destructive actions
// (reboot/shutdown/logout) tint their hover with the theme's urgent color.
// Borderless PanelActionButtons (no surrounding box).
Item {
  id: root
  property var bar: null
  readonly property color fg: bar ? bar.foreground : Color.foreground

  readonly property string omadashDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/djmenig.omadash"

  signal settingsRequested()
  // Emitted before any action that takes over the screen so the host can
  // close the dashboard first (screensaver/lock/logout/reboot/shutdown).
  signal sessionActionRequested()
  // Emitted after the screensaver launch so the host can hide the bar.
  signal screensaverStarted()

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  // Poll for the screensaver window; when it is gone, restore the bar.
  property bool ssSeen: false
  property int ssPolls: 0
  property Timer ssPoll: Timer {
    interval: 2000
    repeat: false
    onTriggered: ssProbe.running = true
  }
  property Process ssProbe: Process {
    command: ["bash", "-c", "echo none"]
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { ssProbe.acc += line } }
    onExited: {
      var state = ssProbe.acc.trim()
      ssProbe.acc = ""
      // Startup self-heal result: "stale" = flag with no screensaver → clear.
      if (state === "stale") {
        Util.execDetached("rm -f $HOME/.local/state/omarchy/toggles/bar-off")
        return
      }
      var present = state === "yes"
      if (present) {
        root.ssSeen = true
        if (root.ssPolls < 120) root.ssPoll.restart()
        else { Util.execDetached("rm -f $HOME/.local/state/omarchy/toggles/bar-off") }
      } else if (root.ssSeen || root.ssPolls > 2) {
        Util.execDetached("rm -f $HOME/.local/state/omarchy/toggles/bar-off")
        root.ssSeen = false
        root.ssPolls = 0
      } else {
        root.ssPoll.restart()
      }
    }
  }
  onScreensaverStarted: {
    ssSeen = false
    ssPolls = 0
    ssPoll.restart()
  }

  // Startup self-heal: a shell restart orphans the bar-off flag (the poll
  // dies with the old instance), leaving the bar hidden forever. If the
  // flag exists at startup and no screensaver window is present, clear it.
  Component.onCompleted: {
    ssProbe.command = ["bash", "-c",
      "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && { hyprctl clients -j 2>/dev/null | grep -q org.omarchy.screensaver && echo hidden || echo stale; } || echo none"]
    ssProbe.running = true
  }

  RowLayout {
    id: row
    // Centered in the span between the search field's right edge and the
    // panel's right edge (the host anchors this item across that gap).
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(8)

    PanelActionButton {
      iconText: "\u{F013}"
      tooltipText: "OmaDash Settings"
      foreground: root.fg
      hoverColor: Color.accent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: root.settingsRequested()
    }

    PanelActionButton {
      iconText: ""
      tooltipText: "Lock"
      foreground: root.fg
      hoverColor: Color.accent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: {
        root.sessionActionRequested()
        Util.execDetached("omarchy system lock")
      }
    }

    PanelActionButton {
      iconText: "󰜉"
      tooltipText: "Reboot"
      foreground: root.fg
      hoverColor: Color.urgent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: {
        root.sessionActionRequested()
        Util.execDetached("omarchy system reboot")
      }
    }

    PanelActionButton {
      iconText: "󰐥"
      tooltipText: "Shutdown"
      foreground: root.fg
      hoverColor: Color.urgent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: {
        root.sessionActionRequested()
        Util.execDetached("omarchy system shutdown")
      }
    }

    PanelActionButton {
      iconText: "󰍃"
      tooltipText: "Logout"
      foreground: root.fg
      hoverColor: Color.urgent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: {
        root.sessionActionRequested()
        Util.execDetached("hyprctl dispatch exit")
      }
    }

    PanelActionButton {
      iconText: "󱄄"
      tooltipText: "Screensaver"
      foreground: root.fg
      hoverColor: Color.accent
      color: "transparent"
      fontSize: 15
      size: 26
      onClicked: {
        root.sessionActionRequested()
        // Hide the bar while the screensaver runs — the screensaver is a
        // plain window, so the layer-shell bar would paint on top of it.
        // The bar watches the stock bar-off flag; the poll restores it when
        // the screensaver window is gone.
        Util.execDetached("mkdir -p $HOME/.local/state/omarchy/toggles && touch $HOME/.local/state/omarchy/toggles/bar-off")
        Util.execDetached("omarchy-launch-screensaver force")
        root.screensaverStarted()
      }
    }
  }
}

