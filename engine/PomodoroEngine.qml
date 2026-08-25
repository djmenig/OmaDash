pragma Singleton
import QtQuick
import qs.Commons

// Single, shared Pomodoro timer engine. Registered as a QML singleton so every
// bar instance (and the expanded dashboard) references the SAME instance — like
// the volume widget sharing one backing store across the bar. In-memory: resets
// on shell restart.
//
// Fokus-style phase model, proper pomodoro technique: focus → short break →
// focus → … → LONG break every `longBreakEvery` completed focuses (15:00).
// The fullscreen overlay opens ONLY during breaks; skipping a break closes it
// and starts the next focus. Postpone extends the current phase. A chime
// sounds when a phase's timer ends.
QtObject {
  id: engine
  property string phase: "focus"        // "focus" | "break"
  property int focusDuration: 25 * 60
  property int shortBreakDuration: 5 * 60
  property int longBreakDuration: 15 * 60
  property int longBreakEvery: 4
  // Completed focuses within the current cycle (0 .. longBreakEvery-1).
  property int completedFocuses: 0
  // Total for the CURRENT phase — drives the compact ring and expanded bar.
  property int duration: focusDuration
  property int remaining: duration
  property bool running: false
  // True when a started session was paused (vs never started) — lets the
  // compact indicator distinguish ready / paused / running.
  property bool paused: false
  // Fullscreen overlay visibility. Only ever true during a break.
  property bool overlayOpen: false

  // End-of-phase chime (fires on focus end and break end).
  function chime() {
    Util.execDetached("paplay /usr/share/sounds/freedesktop/stereo/bell.oga")
  }

  function toggle() {
    if (running) {
      running = false
      paused = true
    } else {
      if (remaining <= 0) advance()
      running = true
      paused = false
    }
  }

  function reset() {
    phase = "focus"
    duration = focusDuration
    remaining = focusDuration
    completedFocuses = 0
    running = false
    paused = false
    overlayOpen = false
  }

  // Advance to the next phase. focus → break (short, or long every 4th
  // focus — overlay opens); break → focus (overlay closes, next session
  // starts immediately). Chimes when the ended phase's timer runs out.
  function advance() {
    chime()
    if (phase === "focus") {
      engine.completedFocuses++
      var long = completedFocuses % longBreakEvery === 0
      phase = "break"
      duration = long ? longBreakDuration : shortBreakDuration
      remaining = duration
      running = true
      overlayOpen = true
    } else {
      phase = "focus"
      duration = focusDuration
      remaining = focusDuration
      running = true
      overlayOpen = false
    }
  }

  // Skip = advance to the next phase. Skipping a break closes the overlay
  // and starts focus.
  function skip() {
    advance()
  }

  // Extend the current phase by five minutes.
  function postpone() {
    remaining += 5 * 60
  }

  // Hide the fullscreen overlay; the current phase keeps running.
  function closeOverlay() {
    overlayOpen = false
  }

  function tick() {
    if (remaining > 0) {
      remaining -= 1
      if (remaining <= 0) advance()
    }
  }

  // Timer is a typed property (not a default child) so the file parses cleanly.
  property Timer tickTimer: Timer {
    interval: 1000
    running: engine.running
    repeat: true
    onTriggered: engine.tick()
  }
}
