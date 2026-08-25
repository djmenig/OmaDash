// CompactFormats.js: format-cycling logic for OmaDash's compact widgets.
// Clock ring ported from the built-in clock's Model.js
// (plugins/panels/clock/Model.js) so cycling matches 1:1.

var CLOCK_FORMATS = [
  "dddd HH:mm",
  "dddd h:mm AP",
  "HH:mm",
  "h:mm AP",
  "ddd d MMM HH:mm",
  "ddd d MMM h:mm AP",
  "d MMMM 'W'ww yyyy",
  "yyyy-MM-dd HH:mm"
]

// The presets in a fixed order, plus the current format when it is something
// else — the ring must not reshuffle around the current value, or cycling
// would bounce between two entries instead of walking.
function clockRing(current) {
  var ring = []
  var candidates = CLOCK_FORMATS.concat([current])
  for (var i = 0; i < candidates.length; i++) {
    var f = String(candidates[i] === undefined || candidates[i] === null ? "" : candidates[i])
    if (f === "" || ring.indexOf(f) !== -1) continue
    ring.push(f)
  }
  return ring.length > 0 ? ring : ["HH:mm"]
}

// Next entry after `current`. An unknown current starts the walk at the top.
function nextInRing(ring, current) {
  if (!ring || ring.length === 0) return ""
  var index = ring.indexOf(String(current === undefined || current === null ? "" : current))
  return ring[(index + 1) % ring.length]
}

// Pomodoro compact indicator styles, in cycling order (Fokus template):
// frame (circular outline + inner pie), ring (bare thin ring), pie (outline
// + filled wedge). The countdown sits beside the indicator.
// Pomodoro compact modes, in cycling order:
//   ring         — the ring indicator alone (play/pause/running states)
//   ring-clock   — the ring with the countdown centered inside it
//   clock        — the bare countdown text (gentle blink when paused)
var POMODORO_MODES = ["ring", "ring-clock", "clock"]

function nextPomodoroMode(current) {
  var index = POMODORO_MODES.indexOf(String(current || "ring"))
  return POMODORO_MODES[(index + 1) % POMODORO_MODES.length]
}

// Weather compact display modes, in cycling order. "icon" carries no
// temperature, so the unit variants collapse into one unit-agnostic mode.
// c = Celsius (native), f = Fahrenheit (converted at render).
var WEATHER_MODES = ["full-c", "icon", "temp-c", "full-f", "temp-f"]

function nextWeatherMode(current) {
  var index = WEATHER_MODES.indexOf(String(current || "full-c"))
  return WEATHER_MODES[(index + 1) % WEATHER_MODES.length]
}

// ---- ISO week (ported from the built-in clock's Model.js) -----------------
// Qt has no ISO-week specifier, so the built-in substitutes the 'ww' token
// before formatting; the compact clock mirrors that pipeline.

function _pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

var _MS_PER_DAY = 24 * 60 * 60 * 1000

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / _MS_PER_DAY + 1) / 7)
}

function isoWeekLiteral(year, month, day) {
  return _pad2(isoWeek(year, month, day))
}

// The built-in's exact pre-format step: substitute the 'ww' token (the
// quoted 'W' around it renders literally).
function applyIsoWeek(format, date) {
  return String(format || "").replace(
    /ww/g,
    isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())
  )
}
