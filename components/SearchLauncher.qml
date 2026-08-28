import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../components/LauncherModel.js" as LauncherModel
import "../components/caps.js" as Caps

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

  // Placeholder font sizing for the search field — kept on root so the
  // TextField can access via root.placeholderFontPx / root.fitPlaceholderFont().
  property int placeholderFontPx: Style.font.heading
  function fitPlaceholderFont() {
    var avail = field.width - Style.space(24)
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
    if (root.placeholderFontPx !== chosen) root.placeholderFontPx = chosen
  }

  // Load both menu sources at startup via hardened reads
  Component.onCompleted: {
    loadDefaultMenu()
    loadUserMenu()
  }

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

  // Hardened reads: the menu JSONC files are loaded through an external
  // command that verifies the file is a regular file (not a symlink), owned
  // by the invoking user or root, and within a byte cap BEFORE emitting
  // content — a FileView can't establish any of that and would load the
  // whole file into memory first regardless.
  property Process defaultMenuFile: Process {
    id: defaultMenuFile
    running: false
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { defaultMenuFile.acc = Caps.appendCapped(defaultMenuFile.acc, line + "\n", Caps.MAX_MENU_JSON) } }
    onExited: function(exitCode) {
      defaultMenuDeadline.stop()
      root._parseDefaultMenu(exitCode === 0 ? defaultMenuFile.acc : "")
    }
  }

  property Timer defaultMenuDeadline: Timer {
    interval: 2000
    repeat: false
    onTriggered: { if (defaultMenuFile.running) defaultMenuFile.running = false }
  }

  function loadDefaultMenu() {
    defaultMenuFile.acc = ""
    defaultMenuFile.command = Caps.safeReadCommand(root.defaultMenuPath, Caps.MAX_MENU_JSON)
    if (!defaultMenuFile.running) { defaultMenuFile.running = true; defaultMenuDeadline.restart() }
  }

  function _parseDefaultMenu(raw) {
    root.defaultMenuItems = LauncherModel.parseMenuJsonc(raw)
    root.rebuildMenuIndex()
  }

  property Process userMenuFile: Process {
    id: userMenuFile
    running: false
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { userMenuFile.acc = Caps.appendCapped(userMenuFile.acc, line + "\n", Caps.MAX_MENU_JSON) } }
    onExited: function(exitCode) {
      userMenuDeadline.stop()
      root._parseUserMenu(exitCode === 0 ? userMenuFile.acc : "")
    }
  }

  property Timer userMenuDeadline: Timer {
    interval: 2000
    repeat: false
    onTriggered: { if (userMenuFile.running) userMenuFile.running = false }
  }

function loadUserMenu() {
    userMenuFile.acc = ""
    userMenuFile.command = Caps.safeReadCommand(root.userMenuPath, Caps.MAX_MENU_JSON)
    if (!userMenuFile.running) { userMenuFile.running = true; userMenuDeadline.restart() }
  }

  function _parseUserMenu(raw) {
    root.userMenuItems = LauncherModel.parseMenuJsonc(raw)
    root.rebuildMenuIndex()
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
      font.pixelSize: root.placeholderFontPx
      onTextChanged: queryTimer.restart()
      onAccepted: root.activate(root.cursorActive ? root.selectedIndex : 0)
      onWidthChanged: Qt.callLater(root.fitPlaceholderFont)
      Component.onCompleted: root.fitPlaceholderFont()
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
      // Bounded retention: never keep more than MAX_FILE_ROWS rows, whatever
      // the search returns.
      onRead: function (line) { if (fileProc.acc.length < Caps.MAX_FILE_ROWS) fileProc.acc.push(String(line).trim()) }
    }
    onExited: {
      fileDeadline.stop()
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
  // Hard deadline: a deep recursive search can be slow; SIGTERM it if it
  // hasn't finished, so a large home dir can't stall the executor.
  property Timer fileDeadline: Timer {
    interval: 3000
    repeat: false
    onTriggered: { if (fileProc.running) fileProc.running = false }
  }
  function runFiles(q) {
    fileProc.query = q
    fileProc.acc = []
    fileProc.command = ["bash", "-lc", "fd -t f -H --exclude .git -d 6 " + Util.shellQuote(q) + " " + Util.shellQuote(Quickshell.env("HOME"))]
    fileProc.running = true
    fileDeadline.restart()
  }

  // ---- Calculator (python3, sandboxed eval) --------------------------------
  Process {
    id: calcProc
    running: false
    property string query: ""
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { calcProc.acc = Caps.appendCapped(calcProc.acc, line, Caps.MAX_CALC) } }
    onExited: {
      calcDeadline.stop()
      var v = calcProc.acc.trim()
      if (v.length) {
        root.setProvider("calc", [{ provider: "calc", kind: "calc", label: v, detail: calcProc.query, payload: v, glyph: "", section: "top", fixedScore: -1 }])
      }
      calcProc.acc = ""
    }
  }
  property Timer calcDeadline: Timer {
    interval: 2000
    repeat: false
    onTriggered: { if (calcProc.running) calcProc.running = false }
  }
  function runCalc(q) {
    var code = "import math,sys; safe={k:getattr(math,k) for k in dir(math) if not k.startswith('_')}; safe.update({'abs':abs,'pow':pow,'round':round,'min':min,'max':max}); print(eval(sys.argv[1],{'__builtins__':{}},safe))"
    calcProc.query = q
    calcProc.acc = ""
    calcProc.command = ["python3", "-c", code, q]
    calcProc.running = true
    calcDeadline.restart()
  }

  // ---- Definitions (Wiktionary) --------------------------------------------
  // Source: Wiktionary via the MediaWiki parse API. The previous source
  // (dictionaryapi.dev) is a free hobbyist server that frequently hangs for
  // seconds and drops requests — measured ~25% timeouts — which is why lookups
  // were slow and often came back empty. Wiktionary runs on Wikipedia's
  // infrastructure: reliable, keyless, and never hangs. Repeat lookups are
  // served from a session cache (instant, no re-fetch), and every result is
  // guarded against the user having typed a different word in the meantime, so
  // a stale in-flight response can't overwrite the current query.
  property var defCache: ({})
  property var activeDefine: ""   // the word the in-flight fetch is for
  Process {
    id: defProc
    running: false
    property string acc: ""
    property string queryWord: ""
    stdout: SplitParser { onRead: function (line) { defProc.acc = Caps.appendCapped(defProc.acc, line + "\n", Caps.MAX_DEFINITION) } }
    onExited: {
      defDeadline.stop()
      root.parseDefine(defProc.acc, defProc.queryWord)
      defProc.acc = ""
    }
  }
  property Timer defDeadline: Timer {
    interval: 10000
    repeat: false
    onTriggered: { if (defProc.running) defProc.running = false }
  }
  function runDefine(q) {
    var word = String(q).trim().toLowerCase()
    if (!word) { root.setProvider("define", []); return }
    // Cached? Serve instantly and skip the network entirely.
    if (root.defCache[word]) {
      root.setProvider("define", root.defCache[word])
      return
    }
    // Show the fetch is in progress immediately (local, instant) so the user
    // isn't left guessing whether a word is missing or still loading.
    root.setProvider("define", [{ provider: "define", kind: "define", label: "Looking up \u201C" + word + "\u201D\u2026", detail: "", payload: "", glyph: "", section: "top", fixedScore: -1 }])
    root.activeDefine = word
    defProc.queryWord = word
    defProc.acc = ""
    // Remember the headword so parseDefine can name it in the detail line.

    var url = "https://en.wiktionary.org/w/api.php?action=parse&page=" + encodeURIComponent(word)
      + "&prop=wikitext&format=json&formatversion=2"
    defProc.command = ["curl", "-s", "--max-time", "8", "--max-filesize", String(Caps.CURL_DEFINITION), url]
    defProc.running = true
    defDeadline.restart()
  }
  function parseDefine(raw, word) {
    // Stale response — the user moved to a different word while we were out.
    if (word !== root.activeDefine) return
    var rows = root.parseWiktionary(raw, word)
    // Remember it so a later lookup of the same word is immediate.
    if (word) root.defCache[word] = rows
    root.setProvider("define", rows)
  }

  // ---- Wiktionary wikitext → clean definition rows -------------------------
  readonly property var defPosSet: ({ noun: 1, verb: 1, adjective: 1, adverb: 1, interjection: 1,
    preposition: 1, pronoun: 1, conjunction: 1, determiner: 1, particle: 1, numeral: 1,
    article: 1, contraction: 1, "prepositional phrase": 1, "proper noun": 1, suffix: 1 })

  // Strip balanced {{...}} templates and [[...]] links. Templates with no
  // display value (q/w/senseid/lb anchors, inflection markers) are dropped;
  // others keep their last pipe-arg as the visible text ({{l|en|word}} → word).
  function stripWikitext(s) {
    var out = ""
    var i = 0
    var n = s.length
    while (i < n) {
      var ch = s[i]
      if (ch === "{" && s[i + 1] === "{") {
        var depth = 0, j = i
        for (; j < n; j++) {
          if (s[j] === "{" && s[j + 1] === "{") { depth++; j++ }
          else if (s[j] === "}" && s[j + 1] === "}") { depth--; j++; if (depth === 0) break }
        }
        var inner = s.slice(i + 2, j - 1)
        var parts = inner.split("|")
        var nm = String(parts[0]).trim().toLowerCase()
        if (nm === "q" || nm === "w" || nm === "lb" || nm === "senseid" || nm === "anchor"
            || nm === "infl of" || nm === "inflection of") {
          // anchor / label / inflection — no visible text
        } else {
          for (var k = parts.length - 1; k >= 0; k--) {
            var a = String(parts[k]).trim()
            if (!a) continue
            if (parts.length > 1 && k === 0) continue   // template name
            out += a
            break
          }
        }
        i = j + 1
        continue
      }
      if (ch === "[" && s[i + 1] === "[") {
        var end = s.indexOf("]]", i)
        var link = (end === -1 ? s.slice(i + 2) : s.slice(i + 2, end)).split("|")
        out += String(link[link.length - 1]).trim()
        i = (end === -1) ? n : end + 2
        continue
      }
      out += ch
      i++
    }
    return out
  }

  function cleanWikidef(raw) {
    var s = String(raw).trim()
    s = s.replace(/^#+/, "").trim()          // # / ## / ### bullets
    s = s.replace(/^[:*]+/, "").trim()       // lead-in markers
    s = root.stripWikitext(s)
    s = s.replace(/'''''/g, "").replace(/'''/g, "").replace(/''/g, "")
    s = s.replace(/\s+/g, " ").trim()
    return s
  }

  // Filter out inflection/derivation meta-rows ("ed-form of determine", "past
  // participle of ...") that aren't real definitions.
  function isWikidefInflection(def) {
    return /^(ed-form|e-form|past participle|present participle|simple past|simple presence|preterite|gerund|imperative|infinitive|subjunctive|participle)\b.*\bof\b/i.test(def)
  }

  // Extract up to one clean definition per part of speech from the English
  // section of the wikitext, capped at three rows.
  function parseWiktionary(raw, head) {
    var rows = []
    try {
      var data = JSON.parse(raw)
      if (!data || !data.parse || typeof data.parse.wikitext !== "string") return rows
      var lines = data.parse.wikitext.split("\n")
      var start = -1
      for (var i = 0; i < lines.length; i++) {
        if (String(lines[i]).trim() === "==English==") { start = i; break }
      }
      var eng = start >= 0 ? lines.slice(start + 1) : lines
      var curPos = ""
      var seenPos = {}
      var got = []
      for (var li = 0; li < eng.length && got.length < 3; li++) {
        var text = String(eng[li]).trim()
        if (/^==[^=].*==$/.test(text)) break            // left the English section
        var h = /^={3,6}([A-Za-z][A-Za-z ]*)={3,6}$/.exec(text)
        if (h) {
          curPos = root.defPosSet[String(h[1]).trim().toLowerCase()] ? String(h[1]).trim() : ""
          continue
        }
        if (curPos && /^#{1,3} /.test(text)) {
          var def = root.cleanWikidef(text)
          if (def && def.length > 3 && !root.isWikidefInflection(def)) {
            if (!seenPos[curPos]) {
              seenPos[curPos] = true
              got.push({ pos: curPos, def: def })
            }
          }
          curPos = ""
        }
      }
      for (var g = 0; g < got.length; g++) {
        rows.push({
          provider: "define", kind: "define",
          label: got[g].def,
          detail: "Definition of \u201C" + head + "\u201D" + "  ·  " + got[g].pos,
          payload: got[g].def, glyph: "", section: "top", fixedScore: -1
        })
      }
    } catch (e) { }
    return rows
  }

  // ---- Hyprland windows ------------------------------------------------------
  Process {
    id: winProc
    running: false
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { winProc.acc = Caps.appendCapped(winProc.acc, line, Caps.MAX_WINDOWS) } }
    onExited: {
      winDeadline.stop()
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
  property Timer winDeadline: Timer {
    interval: 1500
    repeat: false
    onTriggered: { if (winProc.running) winProc.running = false }
  }
  function runWindows(q) {
    winProc.acc = ""
    winProc.command = ["hyprctl", "clients", "-j"]
    winProc.running = true
    winDeadline.restart()
  }
}
