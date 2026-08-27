import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../components/LauncherModel.js" as LauncherModel

// SearchLauncher: the dashboard's search field (top header, center).
// A replica of the Omarchy launcher's search: unified scored results from
// multiple providers — apps (shared AppLibrary), the Omarchy menu tree
// (omarchy-menu.jsonc), files (fd), calculator, definitions, unit conversion,
// web keywords, and Hyprland window switching.
// Keyboard: ↓/↑/PageUp/PageDown move the cursor (appears on first ↓),
// Enter activates, Esc clears the query then closes the dashboard.
Item {
  id: root
  property var bar: null
  readonly property color fg: bar ? bar.foreground : Color.foreground

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight

  signal closeRequested()

  property var providerResults: ({})
  property var results: []
  property int selectedIndex: 0
  property bool cursorActive: false
  readonly property bool hasResults: results.length > 0

  function appLibrary() {
    var b = root.bar
    if (b && b.shell && b.shell.appLibrary) return b.shell.appLibrary
    return null
  }

  function focusSearch() {
    field.forceActiveFocus()
  }

  // ---- Omarchy menu tree (same sources as the launcher) -------------------
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  property var defaultMenuItems: []
  property var userMenuItems: []
  property var menuItems: []

  function rebuildMenuIndex() {
    var merged = LauncherModel.mergeMenuSources(root.defaultMenuItems, root.userMenuItems)
    var byId = {}
    for (var i = 0; i < merged.length; i++) byId[merged[i].id] = merged[i]
    for (i = 0; i < merged.length; i++) {
      var m = merged[i]
      var p = byId[m.parent]
      m.parentLabel = (p && p.id !== "root") ? p.label : ""
    }
    root.menuItems = merged
  }

  property FileView defaultMenuFile: FileView {
    path: root.defaultMenuPath
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.defaultMenuItems = LauncherModel.parseMenuJsonc(text)
      root.rebuildMenuIndex()
    }
    onLoadFailed: {
      root.defaultMenuItems = []
      root.rebuildMenuIndex()
    }
    Component.onCompleted: reload()
  }

  property FileView userMenuFile: FileView {
    path: root.userMenuPath
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.userMenuItems = LauncherModel.parseMenuJsonc(text)
      root.rebuildMenuIndex()
    }
    onLoadFailed: {
      root.userMenuItems = []
      root.rebuildMenuIndex()
    }
    Component.onCompleted: reload()
  }

  // ---- UI -----------------------------------------------------------------
  ColumnLayout {
    id: col
    anchors.fill: parent
    spacing: Style.space(4)

    TextField {
      id: field
      property string fullPlaceholder: "Search... Launch... Define... Calculate..."
      Layout.fillWidth: true
      Layout.minimumWidth: Style.space(240)
      placeholderText: fullPlaceholder
      foreground: root.fg
      font.family: Style.font.menuFamily
      // Shrink the font when the full placeholder overflows the field width,
      // keeping the whole hint visible instead of clipping it.
      font.pixelSize: placeholderFontPx
      onTextChanged: queryTimer.restart()
      onAccepted: root.activate(root.cursorActive ? root.selectedIndex : 0)
      onWidthChanged: Qt.callLater(fitPlaceholderFont)
      Component.onCompleted: fitPlaceholderFont()
      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
          if (field.text.length) {
            field.text = ""
            root.providerResults = {}
            root.results = []
          } else {
            root.closeRequested()
          }
          event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.moveSelection(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.moveSelection(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.moveSelection(6)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.moveSelection(-6)
          event.accepted = true
        }
      }
    }

    FontMetrics {
      id: placeholderMetrics
      font.family: field.font.family
    }

    property int placeholderFontPx: Style.font.heading
    function fitPlaceholderFont() {
      var avail = field.width - Style.space(24)   // leave room for field padding
      if (avail <= 0) return
      var chosen = Style.font.heading
      var candidates = [Style.font.heading, Style.font.bodySmall]
      for (var i = 0; i < candidates.length; i++) {
        placeholderMetrics.font.pixelSize = candidates[i]
        if (placeholderMetrics.advanceWidth(field.fullPlaceholder) <= avail) {
          chosen = candidates[i]
          break
        }
      }
      if (placeholderFontPx !== chosen) placeholderFontPx = chosen
    }
  }

  // Results float OVER the dashboard (never resize the popup). z: 1 inside
  // this item + header z-boost in ExpandedPanel keep them above the grid.
  SearchResults {
    id: resultsView
    z: 1
    visible: root.hasResults
    width: Style.space(560)
    anchors.top: col.bottom
    anchors.topMargin: Style.space(4)
    anchors.horizontalCenter: parent.horizontalCenter
    bar: root.bar
    results: root.results
    selectedIndex: root.selectedIndex
    cursorActive: root.cursorActive
    onActivated: function (index) { root.activate(index) }
    onSelectionChanged: function (index) {
      root.selectedIndex = index
      root.cursorActive = true
    }
  }

  // The KeyboardPanel hands keyboard focus to its key catcher right after
  // opening; retry shortly after so the search field reliably wins.
  Timer {
    id: focusTimer
    interval: 150
    repeat: false
    onTriggered: if (root.visible) field.forceActiveFocus()
  }
  onVisibleChanged: if (visible) focusTimer.restart()

  Timer {
    id: queryTimer
    interval: 160
    onTriggered: runQuery(field.text)
  }

  function moveSelection(delta) {
    if (!root.results.length) return
    var next = root.cursorActive ? root.selectedIndex + delta : (delta > 0 ? 0 : root.results.length - 1)
    next = Math.max(0, Math.min(root.results.length - 1, next))
    root.selectedIndex = next
    root.cursorActive = true
    resultsView.reveal(next)
  }

  function setProvider(name, rows) {
    var pr = root.providerResults
    pr[name] = rows
    root.providerResults = pr
    rebuildResults()
  }

  function rebuildResults() {
    var all = []
    for (var key in root.providerResults) {
      var arr = root.providerResults[key] || []
      for (var i = 0; i < arr.length; i++) all.push(arr[i])
    }
    var q = field.text
    for (i = 0; i < all.length; i++) {
      all[i].score = (all[i].fixedScore !== undefined) ? all[i].fixedScore : LauncherModel.searchScore(all[i], q)
    }
    all.sort(function (a, b) {
      if (a.score !== b.score) return a.score - b.score
      return String(a.label).localeCompare(String(b.label))
    })
    root.results = all.slice(0, 24)
    root.selectedIndex = 0
    root.cursorActive = false
    resultsView.reveal(0)
  }

  function isMath(q) { return /^[0-9+\-*/%^().\s]+$/.test(q) && /[0-9]/.test(q) }
  function isWord(q) { return /^[a-zA-Z]+$/.test(q) }

  function runQuery(q) {
    q = String(q || "").trim()
    root.providerResults = {}
    root.results = []
    root.cursorActive = false
    root.selectedIndex = 0
    if (q.length === 0) return

    var pr = {}
    var direct = []

    var unit = LauncherModel.parseUnit(q)
    if (unit) direct.push({ provider: "unit", kind: "unit", label: unit.label, detail: "Unit conversion", payload: unit.result, glyph: "", section: "top", fixedScore: -1 })

    var web = LauncherModel.parseWeb(q)
    if (web) direct.push({ provider: "web", kind: "web", label: web.label, detail: web.detail, payload: web.url, glyph: "", section: "more", fixedScore: -1 })

    if (isMath(q)) runCalc(q)
    pr.direct = direct
    pr.apps = runApps(q)
    pr.menus = runMenus(q)
    root.providerResults = pr
    rebuildResults()

    runFiles(q)
    runWindows(q)
    if (isWord(q)) runDefine(q)
  }

  // ---- Apps (shared AppLibrary, like the launcher) ------------------------
  function runApps(q) {
    var al = appLibrary()
    if (!al) return []
    var rows = al.sortedEntries(q) || []
    var out = []
    for (var i = 0; i < rows.length && out.length < 8; i++) {
      var e = rows[i] && rows[i].entry !== undefined ? rows[i].entry : rows[i]
      var id = String(e.id || "")
      if (!id) continue
      var sub = al.entrySubtext(e)
      var aliases = sub ? [sub] : []
      try {
        if (e.keywords && typeof e.keywords.join === "function") aliases = aliases.concat(e.keywords)
      } catch (err) { }
      out.push({
        provider: "app", kind: "app",
        label: al.entryName(e), detail: sub || "",
        appIcon: al.iconSource(String(e.icon || "")),
        payload: id, glyph: "",
        aliases: aliases, section: "top"
      })
    }
    return out
  }

  // ---- Omarchy menu tree ---------------------------------------------------
  function runMenus(q) {
    var out = []
    var items = root.menuItems
    for (var i = 0; i < items.length && out.length < 24; i++) {
      var m = items[i]
      if (!m || m.id === "root") continue
      if (!LauncherModel.matchesQuery(m, q)) continue
      out.push({
        provider: "menu", kind: m.kind,
        label: m.label,
        detail: m.description || m.parentLabel || "",
        payload: m.kind === "action" ? m.action : (m.kind === "link" ? m.target : m.id),
        glyph: m.icon || "", iconFont: m.iconFont || "",
        aliases: m.aliases || [], description: m.description || "",
        section: "top"
      })
    }
    return out
  }

  // ---- Activation ----------------------------------------------------------
  function activate(i) {
    var r = root.results[i]
    if (!r) return
    var p = r.provider
    // Window-launching activations close the dashboard so the system can
    // focus the action; clipboard results keep it open.
    var closes = p === "app" || p === "menu" || p === "file" || p === "web" || p === "window"
    if (p === "app") {
      var al = appLibrary()
      if (al) al.launch(r.payload, r.label)
    } else if (p === "menu") {
      if (r.kind === "action") {
        Util.execDetached(r.payload)
      } else {
        // menu/link rows summon the real Omarchy launcher at that submenu.
        Util.execDetached("omarchy-shell shell summon omarchy.menu " + Util.shellQuote(JSON.stringify({ menu: r.payload })))
      }
    } else if (p === "file" || p === "web") {
      Util.execDetached("xdg-open " + Util.shellQuote(r.payload))
    } else if (p === "window") {
      Util.execDetached("hyprctl dispatch focuswindow address:" + r.payload)
    } else {
      // calc/define/unit → copy to clipboard
      Util.execDetached("printf '%s' " + Util.shellQuote(r.payload) + " | wl-copy 2>/dev/null || true")
    }
    if (closes) root.closeRequested()
    field.text = ""
    root.providerResults = {}
    root.results = []
    root.cursorActive = false
  }

  // ---- Files (fd) ----------------------------------------------------------
  Process {
    id: fileProc
    running: false
    property string query: ""
    property var acc: []
    stdout: SplitParser {
      onRead: function (line) { fileProc.acc.push(String(line).trim()) }
    }
    onExited: {
      var out = []
      var lim = Math.min(fileProc.acc.length, 6)
      for (var i = 0; i < lim; i++) {
        var p = fileProc.acc[i]
        if (!p) continue
        var parts = String(p).split("/")
        out.push({ provider: "file", kind: "file", label: parts[parts.length - 1], detail: p, payload: p, glyph: "", section: "more" })
      }
      fileProc.acc = []
      root.setProvider("files", out)
    }
  }
  function runFiles(q) {
    fileProc.query = q
    fileProc.acc = []
    fileProc.command = ["bash", "-lc", "fd -t f -H --exclude .git -d 6 " + Util.shellQuote(q) + " " + Util.shellQuote(Quickshell.env("HOME"))]
    fileProc.running = true
  }

  // ---- Calculator (python3, sandboxed eval) --------------------------------
  Process {
    id: calcProc
    running: false
    property string query: ""
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { calcProc.acc += line } }
    onExited: {
      var v = calcProc.acc.trim()
      if (v.length) {
        root.setProvider("calc", [{ provider: "calc", kind: "calc", label: v, detail: calcProc.query, payload: v, glyph: "", section: "top", fixedScore: -1 }])
      }
      calcProc.acc = ""
    }
  }
  function runCalc(q) {
    var code = "import math,sys; safe={k:getattr(math,k) for k in dir(math) if not k.startswith('_')}; safe.update({'abs':abs,'pow':pow,'round':round,'min':min,'max':max}); print(eval(sys.argv[1],{'__builtins__':{}},safe))"
    calcProc.query = q
    calcProc.acc = ""
    calcProc.command = ["python3", "-c", code, q]
    calcProc.running = true
  }

  // ---- Definitions (dictionaryapi.dev) --------------------------------------
  Process {
    id: defProc
    running: false
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { defProc.acc += line + "\n" } }
    onExited: {
      root.parseDefine(defProc.acc)
      defProc.acc = ""
    }
  }
  function runDefine(q) {
    // Show the fetch is in progress immediately (local, instant) so the user
    // isn't left guessing whether a word is missing or still loading.
    root.setProvider("define", [{ provider: "define", kind: "define", label: "Looking up \u201C" + q + "\u201D\u2026", detail: "", payload: "", glyph: "", section: "top", fixedScore: -1 }])
    defProc.acc = ""
    var url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + encodeURIComponent(q.toLowerCase())
    defProc.command = ["bash", "-lc", "curl -s --max-time 5 " + Util.shellQuote(url)]
    defProc.running = true
  }
  function parseDefine(raw) {
    try {
      var data = JSON.parse(raw)
      if (Array.isArray(data) && data[0] && data[0].meanings) {
        var m = data[0].meanings[0]
        var def = m.definitions && m.definitions[0] ? m.definitions[0].definition : ""
        if (def) {
          root.setProvider("define", [{ provider: "define", kind: "define", label: def, detail: "Definition of \"" + data[0].word + "\"", payload: def, glyph: "", section: "top", fixedScore: -1 }])
        } else {
          // No usable definition — drop the "Looking up…" row.
          root.setProvider("define", [])
        }
      } else {
        root.setProvider("define", [])
      }
    } catch (e) {
      root.setProvider("define", [])
    }
  }

  // ---- Hyprland windows ------------------------------------------------------
  Process {
    id: winProc
    running: false
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { winProc.acc += line } }
    onExited: {
      var out = []
      try {
        var clients = JSON.parse(winProc.acc)
        var q = String(field.text || "").trim().toLowerCase()
        for (var i = 0; i < clients.length && out.length < 5; i++) {
          var c = clients[i]
          var title = String(c.title || "")
          var cls = String(c.class || "")
          if (!title && !cls) continue
          if (q && title.toLowerCase().indexOf(q) < 0 && cls.toLowerCase().indexOf(q) < 0) continue
          out.push({
            provider: "window", kind: "window",
            label: title || cls,
            detail: cls + "  ·  workspace " + (c.workspace && c.workspace.id !== undefined ? c.workspace.id : "?"),
            payload: String(c.address || ""),
            glyph: "", section: "more"
          })
        }
      } catch (e) { }
      winProc.acc = ""
      root.setProvider("windows", out)
    }
  }
  function runWindows(q) {
    winProc.acc = ""
    winProc.command = ["hyprctl", "clients", "-j"]
    winProc.running = true
  }
}
