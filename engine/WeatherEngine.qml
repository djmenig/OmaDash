pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/caps.js" as Caps
import "../components/weatherIcons.js" as WeatherIcons

// Shared weather engine: one fetch chain for every bar instance and the
// expanded dashboard, across all monitors (same pattern as PomodoroEngine).
// Location chain: the shared stock Omarchy location file
// (~/.local/state/omarchy/settings/weather.json) when configured, else an
// IP-geolocation fallback (ip-api.com). Forecast: Open-Meteo (no API key —
// wttr.in proved flaky). Fetches use argv-array curl with size/time caps
// (no shell interpolation).
QtObject {
  id: engine

  // ---- state ---------------------------------------------------------------
  property var location: null          // { latitude, longitude }
  property string placeLabel: ""
  property var current: null           // { temp, feels, label, code, wind, humidity }
  property var daily: []               // [{ day, glyph, label, max, min }]
  property var hourly: []              // [{ label, glyph, temp, wind, precip }]
  property string sunrise: ""
  property string sunset: ""
  property string errorText: ""
  readonly property bool loaded: !!current
  // Display unit — driven by the compact mode selection (shared so the
  // expanded card follows). Engine storage stays metric (°C).
  property bool celsius: true

  // Convert a stored °C value to the selected display unit.
  function dispTemp(c) {
    return celsius ? Math.round(Number(c) || 0) : Math.round((Number(c) || 0) * 9 / 5 + 32)
  }

  // Wind: km/h (metric) or mph (imperial).
  readonly property string windUnit: celsius ? "km/h" : "mph"

  function dispWind(kmh) {
    return celsius ? Math.round(Number(kmh) || 0) : Math.round((Number(kmh) || 0) * 0.621371)
  }

  // Open-Meteo uses WMO weather codes.
  function wmoLabel(code) {
    code = Math.round(Number(code) || 0)
    if (code === 0) return "Clear sky"
    if (code === 1) return "Mostly clear"
    if (code <= 2) return "Partly cloudy"
    if (code === 3) return "Overcast"
    if (code <= 48) return "Fog"
    if (code <= 57) return "Drizzle"
    if (code <= 67) return "Rain"
    if (code <= 77) return "Snow"
    if (code <= 82) return "Rain showers"
    if (code <= 86) return "Snow showers"
    return "Thunderstorm"
  }

  function wmoGlyph(code) {
    code = Math.round(Number(code) || 0)
    if (code === 0) return "󰖙"
    if (code === 1) return "󰖨"
    if (code <= 2) return "󰼰"
    if (code === 3) return "󰖐"
    if (code <= 48) return "󰖑"
    if (code <= 57) return "󰖗"
    if (code <= 67) return "󰖖"
    if (code <= 77) return "󰖘"
    if (code <= 82) return "󰖗"
    if (code <= 86) return "󰖘"
    return "󰼸"
  }

  // WMO code → wttr code → nerd-font glyph. Ported verbatim from the
  // built-in weather plugin's Model.js (iconForOpenMeteoCode).
  function glyphForOpenMeteoCode(code, night) {
    var c = parseInt(String(code || "0"), 10)
    if (c === 0) return WeatherIcons.iconForCode(113, night)
    if (c === 1 || c === 2) return WeatherIcons.iconForCode(116, night)
    if (c === 3) return WeatherIcons.iconForCode(119, night)
    if (c === 45 || c === 48) return WeatherIcons.iconForCode(143, night)
    if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return WeatherIcons.iconForCode(266, night)
    if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return WeatherIcons.iconForCode(308, night)
    if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return WeatherIcons.iconForCode(338, night)
    if (c === 95 || c === 96 || c === 99) return WeatherIcons.iconForCode(389, night)
    return WeatherIcons.iconForCode(119, night)
  }

  // Format a "YYYY-MM-DD" date string as a local weekday. `new Date(iso)`
  // parses the bare date as UTC midnight, which lands on the PREVIOUS day
  // in west-of-UTC timezones (the strip read today/+1/+2 instead of
  // +1/+2/+3). Build the date from its components instead so the label
  // matches the date Open-Meteo returned.
  function dayLabel(iso) {
    var parts = String(iso || "").split("-")
    if (parts.length < 3) return ""
    var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
    return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "ddd")
  }

  // ---- location + fetch chain ----------------------------------------------
  function start() {
    engine.errorText = ""
    engine.locationFile.reload()
  }

  function setLocation(lat, lon, label) {
    engine.location = { latitude: Number(lat), longitude: Number(lon) }
    if (label !== undefined && label !== null && String(label).length) engine.placeLabel = String(label)
    engine.fetchForecast()
  }

  function fetchForecast() {
    if (!location) return
    var u = "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + location.latitude + "&longitude=" + location.longitude
      + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day"
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
      + "&hourly=temperature_2m,weather_code,wind_speed_10m,precipitation_probability"
      + "&timezone=auto&forecast_days=4"
    // NOTE: rebuild the command per fetch — a static command would drop the
    // query (the original "unavailable" bug).
    meteoProc.command = ["curl", "-sL", "--max-time", "8", "--max-filesize", String(Caps.CURL_FORECAST), u]
    meteoProc.acc = ""
    meteoProc.running = true
    meteoDeadline.restart()
  }

  // IP geolocation fallback (no configured location). Retries both providers
  // with backoff until one succeeds or attempts run out — a shell restart can
  // race the network/DNS coming up, and the previous code stopped the retry
  // timer in onExited, so a single transient geo failure stuck on the error
  // until the next 5-minute refresh. NOTE: ip-api's free tier is HTTP-only
  // (returns {} on https), so the odd/even split keeps it HTTP and ipwho.is
  // HTTPS.
  property int geoAttempts: 0
  property Timer geoRetryTimer: Timer {
    interval: 10000
    repeat: false
    onTriggered: engine.ipFallback()
  }

  function ipFallback() {
    if (engine.geoAttempts >= 4) {
      engine.errorText = "Could not detect location"
      return
    }
    // First odd attempt: ip-api; alternate to ipwho.is (both expose the same
    // lat/lon/city fields). Ping-pong so one dead provider can't block the other.
    var url = (engine.geoAttempts % 2 === 1)
      ? "https://ipwho.is/"
      : "http://ip-api.com/json/?fields=lat,lon,city"
    engine.geoAttempts++
    geoProc.command = ["curl", "-sL", "--max-time", "6", "--max-filesize", String(Caps.CURL_GEOLOCATION), url]
    geoProc.acc = ""
    geoProc.running = true
    geoDeadline.restart()
    geoRetryTimer.restart()
  }

  property FileView locationFile: FileView {
    id: locationFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    watchChanges: false
    printErrors: false
    // NOTE: FileView.text is a METHOD.
    onLoaded: {
      // Reject nothing-but-bounded data: only parse a small, regular file.
      if (text().length > Caps.MAX_LOCATION_JSON) { engine.ipFallback(); return }
      try {
        var d = JSON.parse(text())
        var lat = parseFloat(d.latitude !== undefined ? d.latitude : d.lat)
        var lon = parseFloat(d.longitude !== undefined ? d.longitude : d.lon)
        if (!isNaN(lat) && !isNaN(lon)) {
          engine.setLocation(lat, lon, d.name || d.city)
          return
        }
      } catch (e) { }
      engine.ipFallback()
    }
    onLoadFailed: engine.ipFallback()
  }

  property Process geoProc: Process {
    id: geoProc
    command: ["curl", "-sL", "--max-time", "6", "--max-filesize", String(Caps.CURL_GEOLOCATION), "http://ip-api.com/json/?fields=lat,lon,city"]
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { geoProc.acc = Caps.appendCapped(geoProc.acc, line, Caps.MAX_GEOLOCATION) } }
    onExited: {
      geoDeadline.stop()
      try {
        var d = JSON.parse(geoProc.acc)
        if (d.success === false) throw "provider failed"
        var lat = d.lat !== undefined ? d.lat : d.latitude
        var lon = d.lon !== undefined ? d.lon : d.longitude
        if (isNaN(parseFloat(lat)) || isNaN(parseFloat(lon))) throw "no coords"
        // Success: stop the retry timer and clear the transient error so a
        // recovered provider doesn't keep showing a stale "no location".
        geoRetryTimer.stop()
        engine.geoAttempts = 0
        engine.errorText = ""
        engine.setLocation(lat, lon, d.city)
      } catch (e) {
        // Transient failure — back off, then try the other provider.
        geoRetryTimer.restart()
      }
      geoProc.acc = ""
    }
  }

  // Hard deadline: if the geo fetch never exits on its own, SIGTERM it so a
  // hung provider can't leave the retry chain wedged.
  property Timer geoDeadline: Timer {
    interval: 7000
    repeat: false
    onTriggered: { if (geoProc.running) geoProc.running = false }
  }

  property Process meteoProc: Process {
    id: meteoProc
    command: ["curl", "-sL", "--max-time", "8", "--max-filesize", String(Caps.CURL_FORECAST), "https://api.open-meteo.com/v1/forecast"]
    property string acc: ""
    stdout: SplitParser { onRead: function (line) { meteoProc.acc = Caps.appendCapped(meteoProc.acc, line, Caps.MAX_RESPONSE) } }
    onExited: {
      meteoDeadline.stop()
      try {
        var d = JSON.parse(meteoProc.acc)
        var cu = d.current
        if (!cu) throw "no current"
        var isDay = cu.is_day === 1 || cu.is_day === true
        engine.current = {
          temp: Math.round(cu.temperature_2m),
          feels: Math.round(cu.apparent_temperature),
          label: engine.wmoLabel(cu.weather_code),
          glyph: engine.glyphForOpenMeteoCode(cu.weather_code, !isDay),
          code: cu.weather_code,
          wind: Math.round(cu.wind_speed_10m),
          humidity: Math.round(cu.relative_humidity_2m),
          isDay: isDay
        }
        var days = []
        var dl = d.daily || {}
        // Strip = the 3 days AHEAD of today (tomorrow-first), per spec.
        // Ensure we get exactly 3 days starting from tomorrow by comparing dates.
        // Take the 3 days AHEAD of today (tomorrow-first). Index-based skip
        // of entry 0 (today) is timezone-independent — comparing against the
        // machine's local "today" wrongly skipped a day whenever the forecast
        // location's timezone differed from the machine's.
        var times = dl.time || []
        for (var i = 1; i < times.length && days.length < 3; i++) {
          days.push({
            day: engine.dayLabel(times[i]),
            glyph: engine.glyphForOpenMeteoCode(dl.weather_code[i], false),
            precip: dl.precipitation_probability_max !== undefined ? dl.precipitation_probability_max[i] : null,
            label: engine.wmoLabel(dl.weather_code[i]),
            max: Math.round(dl.temperature_2m_max[i]),
            min: Math.round(dl.temperature_2m_min[i])
          })
        }
        engine.daily = days

        // Sunrise / sunset (today's) for the expanded card.
        var sr = (dl.sunrise && dl.sunrise.length) ? new Date(dl.sunrise[0]) : null
        var ss = (dl.sunset && dl.sunset.length) ? new Date(dl.sunset[0]) : null
        engine.sunrise = sr && !isNaN(sr.getTime()) ? Qt.formatDateTime(sr, "h:mm AP") : ""
        engine.sunset = ss && !isNaN(ss.getTime()) ? Qt.formatDateTime(ss, "h:mm AP") : ""

        // Hourly detail (next ~24h from now) for the point-graph strip.
        var hl = d.hourly || {}
        var hourly = []
        if (hl.time && hl.time.length) {
          var now = Date.now()
          var hcount = 0
          for (var h = 0; h < hl.time.length && hcount < 24; h++) {
            var hd = new Date(hl.time[h])
            if (isNaN(hd.getTime())) continue
            if (hd.getTime() < now - 30 * 60 * 1000) continue
            hourly.push({
              h: Qt.formatDateTime(hd, "h AP").split(" ")[0],
              ap: Qt.formatDateTime(hd, "AP"),
              glyph: engine.glyphForOpenMeteoCode(hl.weather_code[h], false),
              temp: engine.dispTemp(hl.temperature_2m[h]),
              wind: engine.dispWind(hl.wind_speed_10m ? hl.wind_speed_10m[h] : 0),
              precip: hl.precipitation_probability ? hl.precipitation_probability[h] : null
            })
            hcount++
          }
        }
        engine.hourly = hourly
        engine.errorText = ""
      } catch (e) {
        // Refresh failure keeps the last reading visible (built-in behavior).
        engine.errorText = "Weather unavailable"
      }
      meteoProc.acc = ""
    }
  }

  // Hard deadline: if the forecast fetch never exits on its own, SIGTERM it so
  // a hung network can't leave the weather wedged until the next refresh.
  property Timer meteoDeadline: Timer {
    interval: 10000
    repeat: false
    onTriggered: { if (meteoProc.running) meteoProc.running = false }
  }

  property Timer refreshTimer: Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    onTriggered: engine.location ? engine.fetchForecast() : engine.start()
  }

  Component.onCompleted: start()
}
