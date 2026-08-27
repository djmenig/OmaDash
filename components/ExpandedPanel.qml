import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../engine"

// ExpandedPanel: the dashboard content shown in the bar-anchored popup.
// Two sections:
//   TOP    — header row: Quick Actions | Search/Launcher | System Shortcuts | Edit Button
//   BOTTOM — malleable tile grid (pomodoro left, calendar center 2x2, weather right)
// Uses ColumnLayout/RowLayout for real implicit content sizes.
Flickable {
  id: root
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  interactive: contentHeight > height
  contentWidth: width
  contentHeight: layout.y + layout.height + Style.space(64)

  property int screenH: 1080
  property int screenW: 1920
  property var bar: null
  property real columnPadding: Style.space(16)
  property bool editMode: false

  // Emitted when the search wants to close the whole dashboard (second Esc).
  signal closeRequested()

  // OmaDash Settings overlay state — placeholder for a future settings UI.
  property bool settingsOpen: false

  readonly property string omadashDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/omadash"

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.y + layout.height + Style.space(64)

  function focusSearch() {
    searchLauncher.focusSearch()
  }

  function toggleEditMode() {
    editMode = !editMode
    DashboardConfig.setEditMode(editMode)
  }

  // Migrate older `plugin:` dashboard entries to `panel:` when the plugin now
  // supports live in-card embedding (one-time, after the registry is ready).
  function reconcilePanelsOnce() {
    var reg = root.bar && root.bar.shell && root.bar.shell.pluginRegistry
    DashboardConfig.reconcilePanels(reg ? reg : null)
  }
  onBarChanged: Qt.callLater(reconcilePanelsOnce)
  Component.onCompleted: Qt.callLater(reconcilePanelsOnce)

  // Add plugin dialog — top-level so it sits above header (search results).
  AddPluginDialog {
    id: addDialog
    anchors.fill: parent
    z: 10
    bar: root.bar
    bottomGap: Style.space(72)
  }

  ColumnLayout {
    id: layout
    x: Style.space(32)
    y: Style.space(16)
    width: root.width - Style.space(64)
    spacing: Style.space(16)

    // ---- TOP: header row — anchored thirds so the search is EXACTLY
    // centered: QuickActions fills [left … search.left], SystemShortcuts
    // fills [search.right … right], each centering its content in its span.
    // z: 1 — the search results float over the grid, so this subtree must
    // paint (and hit-test) above the tiler below.
    Item {
      id: header
      Layout.fillWidth: true
      z: 1
      implicitHeight: Math.max(searchLauncher.implicitHeight, quickActions.implicitHeight, systemShortcuts.implicitHeight)
      height: implicitHeight

      QuickActions {
        id: quickActions
        anchors.left: parent.left
        anchors.right: searchLauncher.left
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
      }

      SearchLauncher {
        id: searchLauncher
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width * 0.42, Style.space(560))
        bar: root.bar
        onCloseRequested: root.closeRequested()
      }

      SystemShortcuts {
        id: systemShortcuts
        anchors.left: searchLauncher.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
        onSettingsRequested: root.settingsOpen = true
        onSessionActionRequested: root.closeRequested()
        // The bar hide/restore for the screensaver is handled inside
        // SystemShortcuts via the stock bar-off flag (Bar watches the file).
      }
    }

    // ---- divider between header and malleable area (matches TextField normal border)
    BorderSurface {
      Layout.fillWidth: true
      height: 1
      color: "transparent"
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)
    }

    // ---- BOTTOM: editable snapping tile grid
    DashboardTiler {
      id: tiler
      Layout.fillWidth: true
      Layout.topMargin: root.columnPadding
      bar: root.bar
      editMode: root.editMode
      // The add-picker overlay clears the edit-switch/FAB row below.
      dialogBottomGap: editSwitchRow.height + Style.space(12)
    }
  }

  // ---- Pomodoro focus overlay (Fokus-style, all screens).
  PomodoroOverlay { }

  Connections {
    target: DashboardConfig
    // NOTE: property change signals carry NO arguments — read the value
    // from the singleton instead (a `mode` parameter is always undefined).
    function onEditModeChanged() {
      root.editMode = DashboardConfig.editMode
    }
  }

  // ---- OmaDash Settings overlay — placeholder for a future settings UI.
  // Same in-dashboard pattern as the add-plugin picker: scrim + centered
  // box, dismissed by clicking outside. Dies with the dashboard.
  Item {
    id: settingsOverlay
    anchors.fill: parent
    z: 6
    visible: opacity > 0
    opacity: root.settingsOpen ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      enabled: root.settingsOpen
      onClicked: root.settingsOpen = false
    }

    BorderSurface {
      id: settingsBox
      width: Style.space(340)
      height: settingsCol.implicitHeight + Style.space(20)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: settingsCol
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(10)

        Text {
          Layout.fillWidth: true
          text: "OmaDash Settings"
          color: Color.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.Medium
        }

        Text {
          Layout.fillWidth: true
          text: "Coming Soon!"
          color: Color.foreground
          opacity: 0.75
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Text {
          Layout.fillWidth: true
          text: "Open config folder"
          color: Color.accent
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          opacity: configLink.containsMouse ? 1 : 0.7

          MouseArea {
            id: configLink
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Util.execDetached("omarchy launch editor " + root.omadashDir)
          }
        }
      }
    }
  }

  // ---- Edit mode switch — bottom-center, with the add-plugin button
  // anchored to its right (square, matching the switch height, vertically
  // centered). The row sits centered in the band between the grid's bottom
  // edge and the card's bottom border (the constant +32 slack).
  RowLayout {
    id: editSwitchRow
    anchors.horizontalCenter: parent.horizontalCenter
    // Centered in the doubled bottom band (64px slack below the grid).
    y: layout.y + layout.height + Style.space(32) - height / 2
    spacing: Style.space(16)

    Text {
      text: "Edit"
      color: Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }

    ToggleSwitch {
      checked: root.editMode
      onToggled: root.toggleEditMode()
    }

    PanelActionButton {
      id: fab
      visible: tiler.editMode && tiler.contentHeight > 0 && tiler.draggingIndex < 0
      size: editSwitchRow.height
      color: Color.popups.background
      bordered: true
      iconText: "+"
      foreground: Color.foreground
      hoverColor: Color.accent
      tooltipText: "Add plugin"
      onClicked: addDialog.open = !addDialog.open
    }
  }
}