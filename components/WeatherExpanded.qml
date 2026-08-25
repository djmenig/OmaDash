import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../engine"

// Expanded Weather: pure UI bound to the shared WeatherEngine singleton.
// Layout mirrors the built-in weather popup: hero row (large condition
// glyph + oversized bold temperature on the left, uppercase location and
// FEELS/WIND/HUMID stat columns on the right) over a 3-day forecast strip
// (tomorrow-first, with rain chance). Theme-dependent throughout.
Item {
  id: root
  property var bar: null
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color fgDim: Qt.darker(root.fg, 1.5)

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight

  // ---- UI -------------------------------------------------------------------
  ColumnLayout {
    id: col
    anchors.fill: parent
    spacing: Style.space(14)

    Text {
      text: "\uf3c5 " + WeatherEngine.placeLabel.toUpperCase()
      color: root.fgDim
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      font.letterSpacing: 1
    }

    // Loading / error states.
    Text {
      visible: !WeatherEngine.loaded
      text: WeatherEngine.errorText.length ? WeatherEngine.errorText : "Loading forecast…"
      color: Color.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      Layout.fillWidth: true
    }

    // ---- Hero row: big glyph + temp on the left; location and stats
    // stacked on the right (built-in popup structure).
    RowLayout {
      visible: WeatherEngine.loaded
      Layout.fillWidth: true
      spacing: Style.space(16)

      RowLayout {
        spacing: Style.space(10)

        Text {
          text: WeatherEngine.loaded ? WeatherEngine.current.glyph : ""
          color: root.fg
          font.family: Style.font.menuFamily
          font.pixelSize: 56
        }

        RowLayout {
          spacing: 0

          Text {
            text: WeatherEngine.loaded ? WeatherEngine.dispTemp(WeatherEngine.current.temp) + (WeatherEngine.celsius ? "°C" : "°F") : ""
            color: root.fg
            font.family: Style.font.menuFamily
            font.pixelSize: 44
            font.bold: true

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: WeatherEngine.celsius = !WeatherEngine.celsius
            }
          }

          Text {
            text: WeatherEngine.celsius ? "°C" : "°F"
            color: root.fg
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.display
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Style.space(10)
          }
        }
      }

      Item { Layout.fillWidth: true }

      ColumnLayout {
        spacing: Style.space(12)

        RowLayout {
          spacing: Style.space(6)

          Text {
            text: WeatherEngine.placeLabel.toUpperCase()
            color: root.fgDim
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            font.letterSpacing: 1
          }

          MouseArea {
            visible: WeatherEngine.location !== null
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + WeatherEngine.location.latitude + "&mlon=" + WeatherEngine.location.longitude + "&zoom=12")
            Text {
              text: "\uf041"
              color: root.fgDim
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        RowLayout {
          spacing: Style.space(28)

          ColumnLayout {
            spacing: Style.space(5)

            Text {
              text: "FEELS"
              color: root.fgDim
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Text {
              text: WeatherEngine.loaded ? WeatherEngine.dispTemp(WeatherEngine.current.feels) + "°" : ""
              color: root.fg
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
            }
          }

          ColumnLayout {
            spacing: Style.space(5)

            Text {
              text: "WIND"
              color: root.fgDim
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Text {
              text: WeatherEngine.loaded ? WeatherEngine.dispWind(WeatherEngine.current.wind) + " " + WeatherEngine.windUnit : ""
              color: root.fg
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
            }
          }

          ColumnLayout {
            spacing: Style.space(5)

            Text {
              text: "HUMID"
              color: root.fgDim
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              font.letterSpacing: 1
            }

            Text {
              text: WeatherEngine.loaded ? WeatherEngine.current.humidity + "%" : ""
              color: root.fg
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
            }
          }
        }
      }
    }

    Text {
      visible: WeatherEngine.loaded
      text: WeatherEngine.loaded ? WeatherEngine.current.label : ""
      color: root.fg
      opacity: 0.75
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      Layout.fillWidth: true
    }

    // ---- 3-day strip: the 3 days AHEAD of today (tomorrow-first), with
    // rain chance.
    RowLayout {
      visible: WeatherEngine.daily.length > 0
      spacing: Style.space(28)

      Repeater {
        model: WeatherEngine.daily

        ColumnLayout {
          required property var modelData
          spacing: Style.space(3)

          Text {
            text: modelData.day
            color: Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            text: modelData.glyph
            color: root.fg
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.iconLarge
          }

          Text {
            text: WeatherEngine.dispTemp(modelData.max) + "° / " + WeatherEngine.dispTemp(modelData.min) + "°"
            color: root.fg
            opacity: 0.8
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: modelData.precip !== null && modelData.precip !== undefined
            text: modelData.precip !== null && modelData.precip !== undefined ? modelData.precip + "% rain" : ""
            color: Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }

    Item { Layout.fillHeight: true; Layout.fillWidth: true }
  }
}