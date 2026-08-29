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
      textFormat: Text.PlainText
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
          textFormat: Text.PlainText
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

    // ---- Hourly detail: horizontal point graph at the bottom. ----------
    // Five stacked rows per hour: time (H + AM/PM), sky glyph, temperature,
    // a temperature point graph, and a rain drop + chance %. The whole strip
    // scrolls horizontally.
    ColumnLayout {
      id: hours
      visible: WeatherEngine.hourly.length > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: Style.space(150)
      spacing: Style.space(4)

      Text {
        text: "HOURLY"
        color: root.fgDim
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }

      // Fixed width of one hour column; the graph band height.
      property real hourW: Style.space(46)
      property real graphH: Style.space(34)
      property real rowGap: Style.space(3)

      // Measure the degree symbol so the number alone can be visually centered
      // (a trailing "°" shifts the digit left of the column axis if the whole
      // string is centered).
      FontMetrics {
        id: degFm
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }

      Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: hourStrip.width
        contentHeight: hourStrip.height
        interactive: contentWidth > width

        // Map the vertical mouse wheel to horizontal panning so the strip is
        // scrollable with the wheel as well as by dragging.
        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function (event) {
            if (event.angleDelta.y === 0) return
            var step = 40
            var target = flick.contentX + (event.angleDelta.y < 0 ? step : -step)
            target = Math.max(0, Math.min(target, Math.max(0, flick.contentWidth - flick.width)))
            flick.contentX = target
          }
        }

        Item {
          id: hourStrip
          width: WeatherEngine.hourly.length * hours.hourW
          height: hourCol.implicitHeight

          Column {
            id: hourCol
            width: parent.width
            spacing: hours.rowGap

            Row {
              id: timeRow
              width: parent.width
              Repeater {
                model: WeatherEngine.hourly
                // Hour figure + tightly-spaced meridiem (\u2009 thin space),
                // centered in the slot.
                Text {
                  width: hours.hourW
                  text: modelData.h + "\u2009" + modelData.ap
                  horizontalAlignment: Text.AlignHCenter
                  color: root.fgDim
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Row {
              id: glyphRow
              width: parent.width
              Repeater {
                model: WeatherEngine.hourly
                Text {
                  required property var modelData
                  width: hours.hourW
                  text: modelData.glyph
                  horizontalAlignment: Text.AlignHCenter
                  color: root.fg
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                }
              }
            }

            Row {
              id: tempRow
              width: parent.width
              Repeater {
                model: WeatherEngine.hourly
                Item {
                  required property var modelData
                  width: hours.hourW
                  implicitHeight: tempValue.implicitHeight

                  // Center the numeric value on the column axis (matching the
                  // graph dot) and let the degree symbol hang off its right, so
                  // the whole reading reads "72°" yet the digits sit on-center.
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: degFm.advanceWidth("°") / 2
                    Text {
                      id: tempValue
                      text: modelData.temp
                      color: root.fg
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.body
                    }
                    Text {
                      text: "°"
                      color: root.fg
                      font.family: Style.font.menuFamily
                      font.pixelSize: Style.font.body
                    }
                  }
                }
              }
            }

            // Temperature point graph: dots joined by a line, one per hour.
            Item {
              width: parent.width
              height: hours.graphH

              Canvas {
                id: graph
                anchors.fill: parent
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.clearRect(0, 0, width, height)
                  var list = WeatherEngine.hourly
                  if (!list || list.length < 1) return
                  var pad = 4
                  var top = pad
                  var bottom = height - pad
                  var span = bottom - top
                  var any = false
                  var x0 = 0, y0 = 0
                  for (var i = 0; i < list.length; i++) {
                    var v = Number(list[i].temp)
                    if (isNaN(v)) continue
                    var x = hours.hourW * i + hours.hourW / 2
                    var y = bottom - span * 0.5   // default mid
                    // Normalize temp into the band (loose min/max around data).
                    if (!any) {
                      var mn = v, mx = v
                      for (var k = 0; k < list.length; k++) {
                        var vk = Number(list[k].temp)
                        if (isNaN(vk)) continue
                        mn = Math.min(mn, vk); mx = Math.max(mx, vk)
                      }
                      if (mx === mn) { mx = mn + 1; mn = mn - 1 }
                      // band-top = max temp, band-bottom = min temp
                    }
                    y = top + (mx - v) / (mx - mn) * span
                    if (any) {
                      ctx.strokeStyle = root.fgDim
                      ctx.lineWidth = 1
                      ctx.globalAlpha = 0.4
                      ctx.beginPath()
                      ctx.moveTo(x0, y0)
                      ctx.lineTo(x, y)
                      ctx.stroke()
                      ctx.globalAlpha = 1
                    }
                    ctx.fillStyle = root.fg
                    ctx.beginPath()
                    ctx.arc(x, y, 2, 0, Math.PI * 2)
                    ctx.fill()
                    x0 = x; y0 = y; any = true
                  }
                }
                Connections {
                  target: WeatherEngine
                  function onHourlyChanged() { graph.requestPaint() }
                }
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
              }
            }

            // Rain: drop glyph + chance (blank when no chance reported).
            Row {
              id: rainRow
              width: parent.width
              Repeater {
                model: WeatherEngine.hourly
                Text {
                  required property var modelData
                  width: hours.hourW
                  text: (modelData.precip !== null && modelData.precip !== undefined)
                    ? "󰖗 " + modelData.precip + "%"
                    : ""
                  horizontalAlignment: Text.AlignHCenter
                  color: root.fgDim
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }

      // Subtle scroll indicator so overflow is discoverable without being
      // visually heavy; hidden when there's nothing to scroll. Draggable.
      Item {
        id: scrub
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(3)
        visible: flick.contentWidth > flick.width

        function thumbW() { return width * flick.visibleArea.widthRatio }
        function thumbMaxX() { return width - thumbW() }
        function contentForThumbX(tx) {
          var maxC = Math.max(0, flick.contentWidth - flick.width)
          if (thumbMaxX() <= 0) return 0
          return maxC * (tx / thumbMaxX())
        }

        Rectangle {
          id: scrubThumb
          width: scrub.thumbW()
          height: parent.height
          radius: height / 2
          color: Util.alpha(root.fg, 0.3)
        }

        MouseArea {
          id: scrubThumbDrag
          anchors.fill: parent
          property real handleX: 0
          property real grabOffset: 0

          function clampToThumb(xp) {
            var min = 0
            var max = scrub.thumbMaxX()
            return Math.max(min, Math.min(xp, max))
          }

          onPressed: function (mouse) {
            // If the press lands on the thumb, keep the grab offset so it
            // doesn't jump; otherwise snap the thumb to the pointer.
            var thumbLeft = scrubThumb.x
            var thumbRight = thumbLeft + scrubThumb.width
            if (mouse.x >= thumbLeft && mouse.x <= thumbRight) {
              grabOffset = mouse.x - thumbLeft
            } else {
              grabOffset = thumbW() / 2
              scrubThumbDrag.handleX = clampToThumb(mouse.x - grabOffset)
              flick.contentX = scrub.contentForThumbX(scrubThumbDrag.handleX)
            }
          }
          onPositionChanged: function (mouse) {
            scrubThumbDrag.handleX = clampToThumb(mouse.x - grabOffset)
            flick.contentX = scrub.contentForThumbX(scrubThumbDrag.handleX)
          }
        }

        // Keep the thumb in sync when the flick is scrolled by other means
        // (wheel, drag on the strip) — the visual x follows the live position.
        Binding {
          target: scrubThumb
          property: "x"
          value: scrubThumbDrag.pressed ? scrubThumbDrag.handleX : scrub.width * flick.visibleArea.xPosition
          restoreMode: Binding.RestoreBinding
        }
      }
    }
  }
}
