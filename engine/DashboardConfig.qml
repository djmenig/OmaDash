pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../components/DashboardRegistry.js" as Registry

// Persisted layout of the expanded dashboard's bottom tile grid.
// Stores an ordered list of active plugin ids (with their grid spans) in
// ~/.config/omarchy/omadash/config/dashboard.json. The tiler reads
// `activePlugins`; the add dialog reads `availableIds()`.
QtObject {
  id: root

  // Config lives OUTSIDE the plugin directory — writing inside
  // plugins/djmenig.omadash/ trips the shell's plugin watcher ("Local plugin
  // changed, reloading") which tears down and reloads the whole plugin,
  // closing the open dashboard on every persist.
  readonly property string configDir: Quickshell.env("HOME") + "/.config/omarchy/omadash"
  readonly property string configPath: configDir + "/dashboard.json"
  property var activePlugins: []
  // Persisted compact-widget preferences (clockFormat, pomodoroMode, …).
  property var settings: ({})
  readonly property string settingsPath: configDir + "/settings.json"
  property bool editMode: false
  // Number of currently-open dashboard instances (one per monitor). Edit
  // mode auto-exits when the count returns to zero.
  property int openPanels: 0

  // Ensure the config directory exists (FileView does not mkdir -p).
  Component.onCompleted: Util.execDetached("mkdir -p " + Util.shellQuote(root.configDir))

  function panelOpened() {
    root.openPanels++
  }

  function panelClosed() {
    root.openPanels = Math.max(0, root.openPanels - 1)
    if (root.openPanels === 0 && root.editMode) root.setEditMode(false)
  }

  function _defaultList() {
    var out = []
    var ids = Registry.defaults()
    for (var i = 0; i < ids.length; i++) {
      var d = Registry.descriptor(ids[i])
      if (d) out.push({ id: d.id, cols: d.cols, rows: d.rows, row: 0 })
    }
    return out
  }

  function _parse(raw) {
    var arr = []
    try {
      var data = JSON.parse(String(raw || "[]"))
      if (Array.isArray(data)) {
        for (var i = 0; i < data.length; i++) {
          var rawId = String(data[i].id || "")
          var d = Registry.descriptor(rawId)
          // Species ids (plugin:/panel:) are self-describing — never let a
          // descriptor anomaly drop a pinned card on load.
          if (!d && (rawId.indexOf("plugin:") === 0 || rawId.indexOf("panel:") === 0))
            d = { id: rawId, cols: 1, rows: 1 }
          // `row` is the tiler's manual row break (Hyprland-style placement);
          // absent in older configs, which parse as row 0.
          if (d) arr.push({ id: d.id, cols: d.cols, rows: d.rows, row: typeof data[i].row === "number" ? data[i].row : 0 })
        }
      }
    } catch (e) {}
    if (arr.length === 0) arr = _defaultList()
    root.activePlugins = arr
  }

  function availableIds() {
    var active = {}
    for (var i = 0; i < root.activePlugins.length; i++) active[root.activePlugins[i].id] = true
    var out = []
    var all = Registry.allIds()
    for (var j = 0; j < all.length; j++) if (!active[all[j]]) out.push(all[j])
    return out
  }

  function setEditMode(mode) {
    if (root.editMode === mode) return
    root.editMode = mode
  }

  function _stripSpecies(id) {
    var s = String(id || "")
    if (s.indexOf("plugin:") === 0) return s.slice("plugin:".length)
    if (s.indexOf("panel:") === 0) return s.slice("panel:".length)
    return s
  }

  // One-time migration: as community plugins that shipped a Panel.qml entry
  // (e.g. the notification center) gained live in-card embedding, any that
  // were previously pinned as `plugin:` launcher tiles should become `panel:`
  // cards so their content renders instead of just their metadata.
  function reconcilePanels(registry) {
    if (!registry) return
    var all = registry.installedPlugins || {}
    var changed = false
    var next = []
    for (var i = 0; i < root.activePlugins.length; i++) {
      var e = root.activePlugins[i]
      var rawId = String(e.id || "")
      if (rawId.indexOf("plugin:") === 0) {
        var mid = rawId.slice("plugin:".length)
        var m = all[mid]
        if (m && Registry.isPanelManifest(m)) {
          var migrated = { cols: e.cols, rows: e.rows, row: e.row }
          migrated.id = "panel:" + mid
          next.push(migrated)
          changed = true
          continue
        }
      }
      next.push(e)
    }
    if (changed) {
      root.activePlugins = next
      _persist()
    }
  }

  function addPlugin(id) {
    var d = Registry.descriptor(id)
    if (!d) return
    // Normalize for comparison: strip "plugin:" or "panel:" prefix
    var normId = _stripSpecies(id)
    for (var i = 0; i < root.activePlugins.length; i++) {
      var existing = root.activePlugins[i].id
      var existingNorm = _stripSpecies(existing)
      if (existingNorm === normId) return
    }
    // Join the last row; the popup widens to fit until the screen cap.
    var maxRow = 0
    for (i = 0; i < root.activePlugins.length; i++) maxRow = Math.max(maxRow, rowOf(root.activePlugins[i]))
    // Store the original descriptor id (with prefix for system plugins)
    root.activePlugins = root.activePlugins.concat([{ id: d.id, cols: d.cols, rows: d.rows, row: maxRow }])
    _persist()
  }

  function rowOf(e) {
    return e && typeof e.row === "number" ? e.row : 0
  }

  function removePlugin(id) {
    var next = []
    for (var i = 0; i < root.activePlugins.length; i++) if (root.activePlugins[i].id !== id) next.push(root.activePlugins[i])
    root.activePlugins = next
    _persist()
  }

  // Synchronous write via FileView (the shell's own config-write idiom) —
  // the previous execDetached+shell approach raced the async config reads,
  // which could consume a half-written file, fail JSON.parse, and reset
  // the layout to defaults.
  property FileView writer: FileView {
    path: root.configPath
    printErrors: false
  }

  function _persist() {
    writer.setText(JSON.stringify(root.activePlugins, null, 2) + "\n")
  }

  // ---- compact-widget settings (clock format, pomodoro mode, …) ----------
  property FileView settingsReader: FileView {
    path: root.settingsPath
    watchChanges: false
    printErrors: false
    // NOTE: FileView.text is a METHOD.
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        root.settings = Util.isPlainObject(parsed) ? parsed : {}
      } catch (e) {
        root.settings = {}
      }
    }
    onLoadFailed: root.settings = {}
    Component.onCompleted: reload()
  }

  property FileView settingsWriter: FileView {
    path: root.settingsPath
    printErrors: false
  }

  function setSetting(key, value) {
    var next = {}
    for (var k in root.settings) next[k] = root.settings[k]
    next[key] = value
    root.settings = next
    settingsWriter.setText(JSON.stringify(next, null, 2) + "\n")
  }

  property FileView reader: FileView {
    path: root.configPath
    watchChanges: false
    printErrors: false
    // NOTE: FileView.text is a METHOD — `text` alone passes the function
    // reference and JSON.parse always fails.
    onLoaded: root._parse(text())
    onLoadFailed: root._parse("[]")
    Component.onCompleted: reload()
  }
}
