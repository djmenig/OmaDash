import QtQuick
import qs.Commons
import qs.Ui

// Calendar: full replica of the built-in clock widget's calendar — hero date,
// year + memento-mori life rails, a fixed six-row ISO week-number grid with
// today outlined, and prev/next month stepping. Preferences (week start,
// birth year, life expectancy) are kept in-memory for the session rather than
// written back to shell.json. The date math is inlined (rather than a script
// import) so the panel loads from a user plugin directory.
Flickable {
  id: root
  implicitWidth: Style.space(460)
  implicitHeight: calendarColumn.implicitHeight
  contentWidth: calendarColumn.width
  contentHeight: calendarColumn.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  interactive: contentHeight > height || contentWidth > width

  property var bar: null

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var weekdayNames: ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

  property date today: new Date()
  readonly property string todayKey: keyForDate(today)

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  readonly property real yearDone: yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  property int birthYearValue: 0
  property int lifeExpectancyValue: 90

  readonly property int birthYear: parseBirthYear(birthYearValue, today.getFullYear())
  readonly property int age: ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: parseLifeExpectancy(lifeExpectancyValue)
  readonly property real lifeDone: lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: lifeProgressPercent(age, lifeExpectancy)

  property bool editingLife: false

  property int weekStart: normalizedWeekStart(null, Qt.locale().firstDayOfWeek)
  readonly property string nextWeekStartLabel: Qt.locale().dayName(toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: weekdayOrder(weekStart)
  readonly property var weeks: monthGrid(viewYear, viewMonth, weekStart, todayKey)

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: {
      var next = new Date()
      if (keyForDate(next) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = next
      if (followToday) root.goToToday()
    }
  }

  function pad2(value) {
    var n = Number(value)
    return (n < 10 ? "0" : "") + n
  }

  function dateKey(year, month, day) {
    return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
  }

  function keyForDate(date) {
    return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
  }

  function coerceWeekStart(value) {
    if (value === undefined || value === null) return null
    if (typeof value === "number")
      return isFinite(value) ? ((Math.round(value) % 7) + 7) % 7 : null
    var text = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
    if (text === "") return null
    for (var i = 0; i < weekdayNames.length; i++)
      if (weekdayNames[i] === text || weekdayNames[i].substr(0, 3) === text) return i
    var parsed = parseInt(text, 10)
    return isFinite(parsed) ? ((parsed % 7) + 7) % 7 : null
  }

  function normalizedWeekStart(value, fallback) {
    var configured = coerceWeekStart(value)
    if (configured !== null) return configured
    var fallbackStart = coerceWeekStart(fallback)
    return fallbackStart === null ? 1 : fallbackStart
  }

  function toggledWeekStart(index) {
    return normalizedWeekStart(index, 1) === 1 ? 0 : 1
  }

  function weekdayOrder(weekStart) {
    var start = normalizedWeekStart(weekStart, 1)
    var out = []
    for (var i = 0; i < 7; i++) out.push((start + i) % 7)
    return out
  }

  function isoWeek(year, month, day) {
    var date = new Date(Date.UTC(year, month, day))
    var weekday = date.getUTCDay() || 7
    date.setUTCDate(date.getUTCDate() + 4 - weekday)
    var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
    return Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
  }

  function dayOfYear(year, month, day) {
    return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / 86400000) + 1
  }

  function daysInYear(year) {
    return dayOfYear(year, 11, 31)
  }

  function yearProgress(year, month, day) {
    var total = daysInYear(year)
    if (total <= 0) return 0
    return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total))
  }

  function yearProgressPercent(year, month, day) {
    return Math.round(yearProgress(year, month, day) * 100)
  }

  function parseBirthYear(value, currentYear) {
    var now = Math.round(Number(currentYear))
    if (!isFinite(now)) return 0
    var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
    if (!/^\d{4}$/.test(text)) return 0
    var year = parseInt(text, 10)
    if (!isFinite(year) || year > now || year < now - 120) return 0
    return year
  }

  function ageFromBirthYear(birthYear, currentYear) {
    var born = parseBirthYear(birthYear, currentYear)
    if (born <= 0) return 0
    return Math.round(Number(currentYear)) - born
  }

  function parseAge(value) {
    var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
    if (!/^\d+$/.test(text)) return 0
    var years = parseInt(text, 10)
    if (!isFinite(years) || years <= 0 || years > 120) return 0
    return years
  }

  function parseLifeExpectancy(value) {
    var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
    if (!/^\d+$/.test(text)) return 90
    var years = parseInt(text, 10)
    if (!isFinite(years) || years <= 0 || years > 150) return 90
    return years
  }

  function lifeProgress(age, expectancy) {
    var years = parseAge(age)
    var span = parseLifeExpectancy(expectancy)
    if (years <= 0 || span <= 0) return 0
    return Math.max(0, Math.min(1, years / span))
  }

  function lifeProgressPercent(age, expectancy) {
    return Math.round(lifeProgress(age, expectancy) * 100)
  }

  function monthGrid(year, month, weekStart, todayKey) {
    var start = normalizedWeekStart(weekStart, 1)
    var leading = (new Date(year, month, 1).getDay() - start + 7) % 7
    var cursor = new Date(year, month, 1 - leading)
    var today = String(todayKey || "")
    var weeks = []
    for (var w = 0; w < 6; w++) {
      var days = []
      var thursday = null
      for (var d = 0; d < 7; d++) {
        var cellYear = cursor.getFullYear()
        var cellMonth = cursor.getMonth()
        var cellDay = cursor.getDate()
        var weekday = cursor.getDay()
        var key = dateKey(cellYear, cellMonth, cellDay)
        if (weekday === 4) thursday = { year: cellYear, month: cellMonth, day: cellDay }
        days.push({
          key: key,
          year: cellYear,
          month: cellMonth,
          day: cellDay,
          weekday: weekday,
          inMonth: cellMonth === month && cellYear === year,
          weekend: weekday === 0 || weekday === 6,
          today: key === today
        })
        cursor.setDate(cursor.getDate() + 1)
      }
      var anchor = thursday || days[0]
      weeks.push({ week: isoWeek(anchor.year, anchor.month, anchor.day), days: days })
    }
    return weeks
  }

  function stepMonth(year, month, delta) {
    var target = new Date(year, Number(month) + Number(delta), 1)
    return { year: target.getFullYear(), month: target.getMonth() }
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
  }

  function moveMonth(delta) {
    var next = stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  function toggleWeekStart() {
    root.weekStart = toggledWeekStart(root.weekStart)
  }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
  }

  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  function clearLife() {
    if (root.birthYear <= 0) return
    root.birthYearValue = 0
  }

  function commitLife() {
    var born = parseBirthYear(bornField.text, today.getFullYear())
    var span = parseLifeExpectancy(expectancyField.text)
    root.birthYearValue = born
    root.lifeExpectancyValue = span
    cancelEditingLife()
  }

  function weekdayLabel(weekday) {
    return String(Qt.locale().dayName(weekday, Locale.ShortFormat)).replace(/\.$/, "").toUpperCase()
  }

  Column {
    id: calendarColumn
    width: Math.max(root.width, gridColumn.width)
    spacing: Style.space(8)

    Item {
      width: parent.width
      height: heroRow.height

      Row {
        id: heroRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(22)

        Text {
          anchors.baseline: heroDate.baseline
          text: "󰃭"
          color: heroMouse.containsMouse
            ? Style.hoverStateColor(root.contentForeground, Color.accent)
            : root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: 48
        }

        Text {
          id: heroDate
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatDate(root.today, "MMMM d")
          color: heroMouse.containsMouse
            ? Style.hoverStateColor(root.contentForeground, Color.accent)
            : root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: 52
          font.bold: true
        }
      }

      MouseArea {
        id: heroMouse
        x: heroRow.x
        y: heroRow.y
        width: heroRow.width
        height: heroRow.height
        enabled: !root.viewingCurrentMonth
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.goToToday()

        PanelToolTip {
          visible: heroMouse.containsMouse
          text: "Back to today"
          fontFamily: root.contentFontFamily
        }
      }
    }

    Item {
      width: parent.width
      height: yearBlock.y + yearBlock.height

      Item {
        id: yearBlock
        y: Style.space(6)
        anchors.horizontalCenter: parent.horizontalCenter
        width: gridColumn.width
        height: Math.max(yearLabel.implicitHeight, Style.space(10))

        TapHandler {
          enabled: !root.editingLife
          onDoubleTapped: root.startEditingLife()
        }

        Row {
          visible: root.editingLife
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BORN"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
          }

          TextField {
            id: bornField
            width: Style.space(70)
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: "year"
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            inputMethodHints: Qt.ImhDigitsOnly

            Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Style.space(6)
            text: "LIVE TO"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1
          }

          TextField {
            id: expectancyField
            width: Style.space(60)
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: "90"
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            inputMethodHints: Qt.ImhDigitsOnly

            Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
          }
        }

        Text {
          id: yearLabel
          visible: !root.editingLife
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.today.getFullYear()
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        Text {
          id: yearPercent
          visible: !root.editingLife
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.yearDonePercent + "%"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Rectangle {
          id: yearTrack
          visible: !root.editingLife
          anchors.left: yearLabel.right
          anchors.right: yearPercent.left
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(6)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Rectangle {
            width: Math.round(parent.width * root.yearDone)
            height: parent.height
            radius: parent.radius
            color: Style.selectedStateColor(root.contentForeground, Color.accent)

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          }
        }
      }
    }

    Item {
      visible: root.birthYear > 0
      width: parent.width
      height: visible ? lifeBlock.height : 0

      Item {
        id: lifeBlock
        anchors.horizontalCenter: parent.horizontalCenter
        width: gridColumn.width
        height: Math.max(lifeLabel.implicitHeight, Style.space(10))

        Text {
          id: lifeLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "LIFE"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
        }

        Text {
          id: lifePercent
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.lifeDonePercent + "%"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Rectangle {
          anchors.left: lifeLabel.right
          anchors.right: lifePercent.left
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(6)
          radius: Style.cornerRadius > 0 ? height / 2 : 0
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

          Rectangle {
            width: Math.round(parent.width * root.lifeDone)
            height: parent.height
            radius: parent.radius
            color: Style.selectedStateColor(root.contentForeground, Color.accent)

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          }
        }

        TapHandler {
          onDoubleTapped: root.clearLife()
        }

        MouseArea {
          id: lifeMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton

          PanelToolTip {
            visible: lifeMouse.containsMouse
            text: "Memento Mori"
            fontFamily: root.contentFontFamily
          }
        }
      }
    }

    Item {
      width: parent.width
      height: gridColumn.y + gridColumn.height

      WheelHandler {
        onWheel: function(event) {
          if (event.angleDelta.y === 0) return
          root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
        }
      }

      Column {
        id: gridColumn
        y: Style.space(18)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(3)

        Row {
          id: headerRow
          spacing: root.cellSpacing

          Rectangle {
            width: root.weekColumnWidth
            height: Style.space(16)
            radius: Style.cornerRadius
            color: weekStartMouse.containsMouse
              ? Style.hoverFillFor(root.contentForeground, Color.accent)
              : "transparent"

            Text {
              anchors.centerIn: parent
              text: "W"
              color: weekStartMouse.containsMouse
                ? Style.hoverStateColor(root.contentForeground, Color.accent)
                : Qt.darker(root.contentForeground, 1.9)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            MouseArea {
              id: weekStartMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleWeekStart()
            }

            PanelToolTip {
              visible: weekStartMouse.containsMouse
              text: "Start weeks on " + root.nextWeekStartLabel
              fontFamily: root.contentFontFamily
            }
          }

          Item {
            width: root.gutterWidth
            height: Style.space(16)
          }

          Repeater {
            model: root.weekdays

            Text {
              required property var modelData
              width: root.cellWidth
              height: Style.space(16)
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: root.weekdayLabel(modelData)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }
          }
        }

        Repeater {
          model: root.weeks

          Row {
            required property var modelData
            spacing: root.cellSpacing

            Text {
              width: root.weekColumnWidth
              height: root.cellHeight
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: modelData.week
              color: Qt.darker(root.contentForeground, 1.9)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Item {
              width: root.gutterWidth
              height: root.cellHeight
            }

            Repeater {
              model: modelData.days

              Rectangle {
                required property var modelData

                width: root.cellWidth
                height: root.cellHeight
                radius: Style.cornerRadius
                color: "transparent"
                border.width: modelData.today ? Style.spacing.hairline : 0
                border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                Text {
                  anchors.centerIn: parent
                  text: modelData.day
                  color: modelData.inMonth
                    ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                    : Qt.darker(root.contentForeground, 2.2)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: modelData.today
                }
              }
            }
          }
        }
      }

      Rectangle {
        x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
        y: gridColumn.y + headerRow.height + gridColumn.spacing
        width: Style.spacing.hairline
        height: gridColumn.height - headerRow.height - gridColumn.spacing
        color: root.contentForeground
        opacity: 0.1
      }
    }

    Item {
      width: parent.width
      height: monthNav.height

      Item {
        id: monthNav
        anchors.horizontalCenter: parent.horizontalCenter
        width: gridColumn.width
        height: monthLabel.implicitHeight + Style.space(10)

        Text {
          id: monthLabel
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(130)
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.letterSpacing: 1
        }

        PanelActionButton {
          anchors.left: parent.left
          anchors.leftMargin: -Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅁"
          tooltipText: "Previous month"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.moveMonth(-1)
        }

        PanelActionButton {
          anchors.right: parent.right
          anchors.rightMargin: -Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅂"
          tooltipText: "Next month"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.moveMonth(1)
        }
      }
    }
  }
}
