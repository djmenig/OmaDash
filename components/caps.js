// Shared byte/item retention caps for data produced by external commands and
// network fetches. Every SplitParser / StdioCollector accumulator and every
// persistent-JSON FileView parse in OmaDash is bounded here so that a remote
// or local producer can never make QML retain or parse unbounded input.
.pragma library

// Producer-side curl caps (--max-filesize) — a timeout alone does not bound
// how much a server can stream before QML retains it.
var CURL_GEOLOCATION = 8192        // lat/lon/city — a tiny JSON object
var CURL_FORECAST = 262144         // 256 KB — hourly + 4-day forecast
var CURL_DEFINITION = 262144       // 256 KB — one Wiktionary page's wikitext

// Retention caps applied in onRead before a response is appended to QML state.
var MAX_RESPONSE = 262144          // 256 KB — generic remote-response retention
var MAX_GEOLOCATION = 8192         // 8 KB — geo fallback response retention
var MAX_DEFINITION = 262144        // 256 KB — Wiktionary wikitext retention
var MAX_CALC = 256                 // arithmetic result is a single short number
var MAX_WINDOWS = 1048576          // 1 MB — hyprctl clients -j window table
var MAX_SSPROBE = 256              // screensaver state probe is a single token
var MAX_REMINDER = 65536           // reminder JSON object

// Item caps for list-shaped accumulators / parsed collections.
var MAX_FILE_ROWS = 8              // fd file-search rows retained (display caps at 6)

// Persistent-JSON read caps (reject/ignore larger or non-regular files).
var MAX_DASHBOARD_JSON = 1048576   // 1 MB — active dashboard layout
var MAX_SETTINGS_JSON = 65536      // 64 KB — compact-widget preferences
var MAX_LOCATION_JSON = 65536      // 64 KB — shared Omarchy weather location file
var MAX_WEATHER_STATE = 262144     // shared Omarchy weather.json (if parsed)

// Append `line` to the string `acc` but never let `acc` exceed `max` bytes.
function appendCapped(acc, line, max) {
  acc = String(acc || "")
  line = String(line || "")
  var room = max - acc.length
  if (room <= 0) return acc
  return acc + (line.length <= room ? line : line.slice(0, room))
}
