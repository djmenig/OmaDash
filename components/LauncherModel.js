// LauncherModel.js: pure-JS engine for the dashboard's launcher-style search.
// Ports the scoring/filter core of the Omarchy menu (plugins/menu/MenuModel.js)
// and adds KRunner-style extras: a dependency-free unit converter and web
// search keywords. No UI — everything here returns plain objects.

// ---------------------------------------------------------------------------
// Omarchy menu JSONC parsing (ported from MenuModel.js)
// ---------------------------------------------------------------------------

function stripJsonc(raw) {
  return String(raw || "")
    .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
    .replace(/,(\s*[}\]])/g, "$1")
}

function normalizeAliases(value) {
  if (Array.isArray(value)) return value.filter(function (v) { return v })
  if (typeof value === "string" && value) return [value]
  return []
}

function normalizeItem(id, raw) {
  var value = raw || {}
  var aliases = normalizeAliases(value.aliases)
  var parent = value.parent
  if (parent === undefined)
    parent = id.indexOf(".") >= 0 ? id.split(".").slice(0, -1).join(".") : "root"
  if (id === "root") parent = ""

  var kind = value.action ? "action" : (value.target ? "link" : "menu")

  return {
    id: id,
    parent: parent,
    kind: kind,
    icon: value.icon || "",
    iconFont: value.iconFont || "",
    label: value.label || id,
    title: value.title || "",
    target: value.target || "",
    description: value.description || "",
    action: value.action || "",
    aliases: aliases
  }
}

function parseMenuJsonc(raw) {
  var stripped = stripJsonc(raw)
  if (!stripped.trim()) return []

  var parsed
  try {
    parsed = JSON.parse(stripped)
  } catch (e) {
    return []
  }
  if (typeof parsed !== "object" || parsed === null) return []

  var source = (parsed.items && typeof parsed.items === "object" && !Array.isArray(parsed.items))
    ? parsed.items
    : parsed
  var out = []
  for (var id in source) {
    var entry = source[id]
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue
    out.push(normalizeItem(id, entry))
  }
  return out
}

// Merge default + user menu trees: user entries override by id, order follows
// first appearance.
function mergeMenuSources(defaultItems, userItems) {
  var byId = {}
  var order = []
  var sources = [defaultItems || [], userItems || []]

  for (var s = 0; s < sources.length; s++) {
    var src = sources[s]
    for (var i = 0; i < src.length; i++) {
      var e = src[i]
      if (!e || !e.id) continue
      if (!byId[e.id]) {
        byId[e.id] = {}
        for (var k in e) byId[e.id][k] = e[k]
        order.push(e.id)
      } else {
        var m = byId[e.id]
        for (var k2 in e) m[k2] = e[k2]
      }
    }
  }

  var out = []
  for (var j = 0; j < order.length; j++) out.push(byId[order[j]])
  return out
}

// ---------------------------------------------------------------------------
// Search scoring (ported tiers from MenuModel.js, flattened)
// ---------------------------------------------------------------------------

function searchableToken(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "")
}

function leafIdFor(id) {
  var s = String(id || "")
  return s.indexOf(".") >= 0 ? s.slice(s.lastIndexOf(".") + 1) : s
}

function nameSearchText(entry) {
  if (!entry) return ""
  var aliases = []
  var values = Array.isArray(entry.aliases) ? entry.aliases : []
  for (var i = 0; i < values.length; i++) aliases.push(searchableToken(values[i]))
  return [String(entry.label || ""), searchableToken(leafIdFor(entry.id)), aliases.join(" ")].join(" ").toLowerCase()
}

function termInSearchWords(term, text) {
  var words = String(text || "").toLowerCase().split(/\s+/)
  for (var i = 0; i < words.length; i++) {
    if (words[i] === term) return true
  }
  return false
}

function descriptionTextMatches(query, text) {
  var terms = String(query || "").toLowerCase().trim().split(/\s+/)
  for (var i = 0; i < terms.length; i++) {
    if (terms[i] && !termInSearchWords(terms[i], text)) return false
  }
  return true
}

// Multi-term match: every term must hit the name (label/id/aliases) or be a
// whole word in the description.
function matchesQuery(entry, query) {
  if (!entry) return false
  var nameText = nameSearchText(entry)
  var descriptionText = String(entry.description || "").toLowerCase()
  var terms = String(query || "").toLowerCase().trim().split(/\s+/)

  for (var i = 0; i < terms.length; i++) {
    if (!terms[i]) continue
    if (nameText.indexOf(terms[i]) >= 0) continue
    if (termInSearchWords(terms[i], descriptionText)) continue
    return false
  }

  return true
}

// Tiered score (lower = better), mirroring the launcher:
// exact label 0 < starts-with 10 < contains 30 < name/aliases 40 < description 60.
// Menus/links rank slightly above apps on ties, like the launcher.
function searchScore(row, query) {
  var needle = String(query || "").toLowerCase().trim()
  var label = String(row.label || "").toLowerCase()
  var nameText = nameSearchText(row)
  var descriptionText = String(row.description || "").toLowerCase()
  var score = 80

  if (needle && label === needle) score = 0
  else if (needle && label.indexOf(needle) === 0) score = 10
  else if (needle && label.indexOf(needle) >= 0) score = 30
  else if (needle && nameText.indexOf(needle) >= 0) score = 40
  else if (needle && descriptionTextMatches(needle, descriptionText)) score = 60

  if (row.kind === "menu" || row.kind === "link") score -= 2
  if (row.kind === "app") score -= 5

  return score
}

// ---------------------------------------------------------------------------
// Unit conversion (hand-rolled, no external dependencies)
// ---------------------------------------------------------------------------

var _unitGroups = [
  // length (base m)
  { units: { mm: 0.001, cm: 0.01, m: 1, km: 1000, in: 0.0254, inch: 0.0254, inches: 0.0254, ft: 0.3048, foot: 0.3048, feet: 0.3048, yd: 0.9144, yard: 0.9144, yards: 0.9144, mi: 1609.344, mile: 1609.344, miles: 1609.344, nmi: 1852 } },
  // mass (base kg)
  { units: { mg: 0.000001, g: 0.001, kg: 1, t: 1000, tonne: 1000, tonnes: 1000, oz: 0.028349523125, ozs: 0.028349523125, lb: 0.45359237, lbs: 0.45359237, pound: 0.45359237, pounds: 0.45359237, st: 6.35029318, stone: 6.35029318 } },
  // time (base s)
  { units: { ms: 0.001, s: 1, sec: 1, secs: 1, min: 60, mins: 60, h: 3600, hr: 3600, hrs: 3600, hour: 3600, hours: 3600, day: 86400, days: 86400, week: 604800, weeks: 604800 } },
  // volume (base l)
  { units: { ml: 0.001, cl: 0.01, l: 1, liter: 1, liters: 1, litre: 1, litres: 1, m3: 1000, gal: 3.785411784, gallon: 3.785411784, gallons: 3.785411784, qt: 0.946352946, pt: 0.473176473, cup: 0.2365882365, cups: 0.2365882365, floz: 0.0295735295625 } },
  // data (base B; decimal + binary)
  { units: { bit: 0.125, b: 1, byte: 1, bytes: 1, kb: 1000, mb: 1000000, gb: 1000000000, tb: 1000000000000, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 } }
]

var _tempUnits = {
  c: "c", "°c": "c", celcius: "c", celsius: "c", centigrade: "c",
  f: "f", "°f": "f", fahrenheit: "f",
  k: "k", kelvin: "k"
}

function _fmt(value) {
  var r = Math.round(value * 1000000) / 1000000
  return String(r)
}

function _toCelsius(v, unit) {
  if (unit === "f") return (v - 32) * 5 / 9
  if (unit === "k") return v - 273.15
  return v
}

function _fromCelsius(v, unit) {
  if (unit === "f") return v * 9 / 5 + 32
  if (unit === "k") return v + 273.15
  return v
}

// Parses "10 km in miles", "5kg to lb", "10km->mi", "72f in c".
// Returns { label, result } or null.
function parseUnit(q) {
  var m = String(q || "").trim().match(/^([+-]?\d*\.?\d+)\s*([a-zA-Z°µ]+)\s*(?:in|to|->|→|as)\s*([a-zA-Z°µ]+)$/)
  if (!m) return null

  var v = parseFloat(m[1])
  var from = m[2].toLowerCase()
  var to = m[3].toLowerCase()
  if (!isFinite(v)) return null

  // Temperature (affine).
  if (_tempUnits[from] && _tempUnits[to]) {
    var c = _toCelsius(v, _tempUnits[from])
    var t = _fromCelsius(c, _tempUnits[to])
    var res = _fmt(t) + " " + m[3]
    return { label: q + " = " + res, result: res }
  }

  // Linear groups.
  for (var g = 0; g < _unitGroups.length; g++) {
    var units = _unitGroups[g].units
    if (units[from] !== undefined && units[to] !== undefined) {
      var r = v * units[from] / units[to]
      var res2 = _fmt(r) + " " + m[3]
      return { label: q + " = " + res2, result: res2 }
    }
  }

  return null
}

// ---------------------------------------------------------------------------
// Web search keywords (KRunner-style): "gg: query", "wiki: …", …
// ---------------------------------------------------------------------------

var _webKeywords = {
  gg: { name: "Google", url: "https://www.google.com/search?q=" },
  dd: { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
  wiki: { name: "Wikipedia", url: "https://en.wikipedia.org/w/index.php?search=" },
  gh: { name: "GitHub", url: "https://github.com/search?q=" }
}

// Returns { label, detail, url } or null.
function parseWeb(q) {
  var s = String(q || "")
  var i = s.indexOf(":")
  if (i < 1) return null
  var key = s.slice(0, i).toLowerCase()
  var w = _webKeywords[key]
  if (!w) return null
  var query = s.slice(i + 1).trim()
  if (!query) return null
  return {
    label: "Search " + w.name + " for \"" + query + "\"",
    detail: "Web search",
    url: w.url + encodeURIComponent(query)
  }
}
