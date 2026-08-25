# OmaDash

A malleable HUD/dashboard plugin for [Omarchy](https://omarchy.org). A compact
bar pill (Pomodoro · clock · weather) that expands into a full dashboard:
quick actions, a launcher-style search, system shortcuts, and a corkboard of
pinnable plugin cards.

![OmaDash](preview.png)

## Features

- **Compact bar pill** — Pomodoro timer, clock, and weather at a glance
- **Expanded dashboard** — opens from the bar; autosizes to content
- **Launcher-style search** — apps, files, calculator, definitions, unit
  conversion, web keywords (`gg:` `dd:` `wiki:` `gh:`), and Hyprland window
  switching, all scored and merged in one list
- **Corkboard** — pin any installed Omarchy plugin:
  - *Live panels* — the plugin's real UI (network, audio, bluetooth, power,
    …) embedded in a card
  - *Launcher tiles* — one-click summons for overlay/menu plugins
- **Edit mode** — drag cards between rows with animated push (Hyprland-style
  half-split drop targets), remove, and re-add from a scanned plugin list
- **Live data** — weather via Open-Meteo (no API key, shared Omarchy
  location), Pomodoro focus timer with postpone/skip

## Install

```sh
omarchy plugin add https://github.com/djmenig/omadash.git --enable
omarchy restart shell
```

Move the pill to the center of the bar if it landed elsewhere:

```sh
omarchy bar move omadash --section center
```

## Usage

- **Left-click the pill** — open/close the dashboard
- **Edit switch** (bottom-right) — enter edit mode: drag cards (left/right
  half of a card decides the drop side), remove, or add via the **+** button
- **Search** — type to search; ↑/↓ navigate, Enter activates, Esc clears
- **Right-click** support and per-card removal persist across restarts
  (layout is saved to `~/.config/omarchy/omadash/dashboard.json`)

## Requirements

- Omarchy (Quickshell-based shell)
- Network access for weather (Open-Meteo / wttr.in) — everything else works
  offline

## License

MIT — see [LICENSE](LICENSE).
