import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../engine"

// Expanded Weather: pure UI bound to the shared WeatherEngine singleton.
// Monochrome by design — only the theme foreground in two shades (full for
// values, dimmed for labels) with hairline dividers for separation, matching
// the built-in weather popup's restrained look.
Item {
  id: root
  property var bar: null
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color fgDim: Qt.darker(root.fg, 1.5)

  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight

  // Hairline divider between sections.
  component Divider: Rectangle {
    color: root.fg
    opacity: 0.12
    height: Style.spacing.hairline
    Layout.fillWidth: true
  }

  ColumnLayout {
    id: col
    anchors.fill: parent
    spacing: Style.space(12)

    // Loading / error states.
    Text {
      visible: !WeatherEngine.loaded
      text: WeatherEngine.errorText.length ? WeatherEngine.errorText : "Loading forecast…"
      color: root.fgDim
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      Layout.fillWidth: true
    }

    // ---- Hero: condition glyph + temperature (own row) ------------------
    RowLayout {
      visible: WeatherEngine.loaded
      Layout.fillWidth: true
      spacing: Style.space(10)

      Text {
        text: WeatherEngine.current.glyph
        color: root.fg
        font.family: Style.font.menuFamily
        font.pixelSize: 48
      }

      RowLayout {
        spacing: Style.space(2)

        Text {
          text: WeatherEngine.dispTemp(WeatherEngine.current.temp)
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
          color: root.fgDim
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.title
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: Style.space(6)
        }
      }
    }

    // ---- Location + stats (own row) ------------------------------------
    ColumnLayout {
      visible: WeatherEngine.loaded
      Layout.fillWidth: true
      spacing: Style.space(8)

      RowLayout {
        spacing: Style.space(6)
        Layout.alignment: Qt.AlignVCenter

        Text {
          visible: WeatherEngine.location !== null
          text: "\uf041"
          color: root.fgDim
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          verticalAlignment: Text.AlignVCenter
          Layout.alignment: Qt.AlignVCenter
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + WeatherEngine.location.latitude + "&mlon=" + WeatherEngine.location.longitude + "&zoom=12")
          }
        }

        Text {
          text: WeatherEngine.placeLabel.toUpperCase()
          color: root.fgDim
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          font.letterSpacing: 1
          verticalAlignment: Text.AlignVCenter
          Layout.alignment: Qt.AlignVCenter
        }
      }

      RowLayout {
        spacing: Style.space(20)

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
            text: WeatherEngine.dispTemp(WeatherEngine.current.feels) + "°"
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
            text: WeatherEngine.dispWind(WeatherEngine.current.wind) + " " + WeatherEngine.windUnit
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
            text: WeatherEngine.current.humidity + "%"
            color: root.fg
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.title
          }
        }
      }

      Text {
        text: WeatherEngine.current.label
        color: root.fg
        opacity: 0.8
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }
    }

    // ---- Sunrise / sunset on a single line -----------------------------
    RowLayout {
      visible: WeatherEngine.loaded && WeatherEngine.sunrise !== ""
      spacing: Style.space(18)

      RowLayout {
        spacing: Style.space(6)
        Text {
          text: "SUNRISE"
          color: root.fgDim
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }
        Text {
          text: WeatherEngine.sunrise
          color: root.fg
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }
      }

      RowLayout {
        spacing: Style.space(6)
        Text {
          text: "SUNSET"
          color: root.fgDim
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }
        Text {
          text: WeatherEngine.sunset
          color: root.fg
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }
      }
    }

    Divider { visible: WeatherEngine.daily.length > 0 }

    // ---- 3-day strip: the 3 days AHEAD of today (tomorrow-first). -------
    RowLayout {
      visible: WeatherEngine.daily.length > 0
      Layout.fillWidth: true
      spacing: Style.space(20)

      Repeater {
        model: WeatherEngine.daily

        ColumnLayout {
          required property var modelData
          spacing: Style.space(3)

          Text {
            text: modelData.day
            color: root.fgDim
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
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: modelData.precip !== null && modelData.precip !== undefined
            text: modelData.precip + "% rain"
            color: root.fgDim
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }
    }

    Divider { visible: WeatherEngine.hourly.length > 0 }

    // ---- Hourly detail: scrollable list at the bottom. -----------------
    ColumnLayout {
      visible: WeatherEngine.hourly.length > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: Style.space(120)
      spacing: Style.space(4)

      Text {
        text: "HOURLY"
        color: root.fgDim
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: hourlyCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: hourlyCol
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: WeatherEngine.hourly

            RowLayout {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: modelData.label
                color: root.fgDim
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                Layout.preferredWidth: Style.space(52)
                Layout.alignment: Qt.AlignLeft
              }

              Text {
                text: modelData.glyph
                color: root.fg
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
              }

              Text {
                text: modelData.temp + "°"
                color: root.fg
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                Layout.preferredWidth: Style.space(36)
              }

              Text {
                text: modelData.wind + " " + WeatherEngine.windUnit
                color: root.fgDim
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                Layout.fillWidth: true
              }

              Text {
                visible: modelData.precip !== null && modelData.precip !== undefined
                text: modelData.precip + "%"
                color: root.fgDim
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }
      }
    }
  }
}
