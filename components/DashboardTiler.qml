import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../engine"
import "../components/DashboardRegistry.js" as Registry

// DashboardTiler: row-aware flex tiler for the expanded dashboard, styled
// after Hyprland's placement model:
//   - each plugin carries a persisted `row` number; the packer starts a new
//     visual row whenever the row number changes (and on overflow), so the
//     user — not the width — decides where rows break
//   - within a row, cards wrap on overflow and stretch to fill (equal grow),
//     row height = tallest natural height
//   - dragging a card shows a ghost at the split point: left half of a card
//     = land before it (its row), right half = after it, above the grid =
//     top of the first row, below the grid = a brand-new row
Item {
  id: root
  property var bar: null
  property bool editMode: false
  Layout.fillWidth: true
  property real gap: Style.space(12)

  // Content-driven horizontal sizing for the WIDEST row (not the sum of all
  // cards): the popup widens to fit the biggest row's demand, +space(32) for
  // the popup's side margins (mirrored by Panel's _hInset) and +gap headroom
  // so rounding never flips the packer's strict comparison.
  implicitWidth: {
    var list = DashboardConfig.activePlugins
    var rowSums = ({})
    var rowCounts = ({})
    for (var i = 0; i < list.length; i++) {
      var r = rowOf(list[i])
      var c = rep.itemAt(i)
      var w = c && c.implicitWidth > 0 ? Math.max(minCardW, c.implicitWidth) : fallbackW
      rowSums[r] = (rowSums[r] || 0) + w
      rowCounts[r] = (rowCounts[r] || 0) + 1
    }
    var maxDemand = 0
    for (var key in rowSums) {
      var demand = rowSums[key] + (rowCounts[key] - 1) * gap
      maxDemand = Math.max(maxDemand, demand)
    }
    return maxDemand > 0 ? maxDemand + Style.space(32) + gap : fallbackW
  }

  property var positions: []        // slot rects by plugin index (stable layout)
  property var ghostRect: null      // drop-slot rect while dragging
  property real contentHeight: 0
  implicitHeight: contentHeight

  property int draggingIndex: -1
  property int targetIndex: -1
  property int targetRow: -1

  readonly property real minCardW: Style.space(240)
  readonly property real fallbackW: Style.space(280)
  readonly property real fallbackH: Style.space(180)

  function rowOf(e) {
    return e && typeof e.row === "number" ? e.row : 0
  }

  // Natural size of a plugin's card, from the live delegate. `fixed` marks
  // species that must not stretch (panel hosts keep their natural width).
  function naturalOf(id) {
    for (var j = 0; j < rep.count; j++) {
      var c = rep.itemAt(j)
      if (c && c.cardId === id) {
        return {
          w: c.implicitWidth > 0 ? Math.max(minCardW, c.implicitWidth) : fallbackW,
          h: c.implicitHeight > 0 ? c.implicitHeight : fallbackH,
          fixed: c.fixedWidth === true
        }
      }
    }
    return { w: fallbackW, h: fallbackH, fixed: false }
  }

  // Row-aware flex packer. With dragEntry set, that card is simulated at
  // insertAt with insertRow; its rect comes back as `ghost`, everyone else
  // as `slots`. A new visual row starts on a row-number change or overflow.
  function packList(list, dragEntry, insertAt, insertRow) {
    var W = Math.max(minCardW * 2, root.width > 0 ? root.width : 800)
    var items = []
    for (var i = 0; i < list.length; i++) {
      if (dragEntry !== null && i === insertAt) {
        var dg = naturalOf(dragEntry.id)
        items.push({ src: -1, w: dg.w, h: dg.h, row: insertRow, fixed: dg.fixed })
      }
      var n = naturalOf(list[i].id)
      items.push({ src: i, w: n.w, h: n.h, row: rowOf(list[i]), fixed: n.fixed })
    }
    if (dragEntry !== null && insertAt >= list.length) {
      var dg2 = naturalOf(dragEntry.id)
      items.push({ src: -1, w: dg2.w, h: dg2.h, row: insertRow, fixed: dg2.fixed })
    }

    // Row grouping: row-number change or overflow breaks the row.
    var rows = []
    var cur = []
    var curRow = -1
    var curW = 0
    for (i = 0; i < items.length; i++) {
      var it = items[i]
      var breaks = cur.length > 0 && (it.row !== curRow || curW + it.w + (cur.length ? gap : 0) > W + 0.5)
      if (breaks) { rows.push(cur); cur = []; curW = 0 }
      if (cur.length === 0) curRow = it.row
      cur.push(it)
      curW += (cur.length > 1 ? gap : 0) + it.w
    }
    if (cur.length) rows.push(cur)

    // Row layout: stretch-to-fill among growable cards (equal grow);
    // fixed-width species (panel hosts) keep their natural width.
    var slots = []
    for (i = 0; i < list.length; i++) slots.push(null)
    var ghost = null
    var y = 0
    for (var r = 0; r < rows.length; r++) {
      var row = rows[r]
      var nat = 0
      var rowH = 0
      var growCount = 0
      for (var j = 0; j < row.length; j++) {
        nat += row[j].w
        rowH = Math.max(rowH, row[j].h)
        if (!row[j].fixed) growCount++
      }
      nat += gap * (row.length - 1)
      var extra = growCount > 0 ? Math.max(0, (W - nat) / growCount) : 0
      var x = 0
      for (j = 0; j < row.length; j++) {
        var w = row[j].fixed ? Math.min(W, row[j].w) : Math.min(W, row[j].w + extra)
        var rect = { x: x, y: y, w: w, h: rowH }
        if (row[j].src === -1) ghost = rect
        else slots[row[j].src] = rect
        x += w + gap
      }
      y += rowH + gap
    }
    return { slots: slots, ghost: ghost, contentH: rows.length ? (y - gap) : 0 }
  }

  function recompute() {
    var out = packList(DashboardConfig.activePlugins, null, -1, 0)
    root.positions = out.slots
    root.ghostRect = null
    root.contentHeight = out.contentH
    applyPositions(out.slots)
  }

  function whatIf(insertAt, insertRow) {
    var list = DashboardConfig.activePlugins
    var draggedEntry = (root.draggingIndex >= 0 && list[root.draggingIndex]) ? list[root.draggingIndex] : null
    if (!draggedEntry) return
    var out = packList(list, draggedEntry, insertAt, insertRow)
    root.ghostRect = out.ghost
    root.contentHeight = Math.max(root.contentHeight, out.contentH)
    applyPositions(out.slots)
  }

  // Imperative positioning — no x/y bindings on cards (MouseArea drag writes
  // x/y directly, which would destroy bindings). The dragged card is skipped
  // so the cursor keeps it.
  function applyPositions(slots) {
    for (var i = 0; i < rep.count; i++) {
      var c = rep.itemAt(i)
      if (!c || i === root.draggingIndex) continue
      var s = slots[i]
      if (!s) continue
      c.x = s.x
      c.y = s.y
      c.width = s.w
      c.height = s.h
    }
  }

  // Drop target: Hyprland-style split over the stable (pre-drag) layout.
  // Over card i: left half → before it (its row), right half → after it
  // (its row). Above the grid → top of the first row. Below the grid →
  // append into a brand-new row. Right of the last card → append to its row.
  // Sets targetIndex/targetRow; returns true when the target changed.
  function updateTarget(px, py) {
    var list = DashboardConfig.activePlugins
    var idx = -1
    var row = 0
    var firstIdx = -1
    var first = null
    var lastIdx = -1
    var last = null

    for (var i = 0; i < root.positions.length; i++) {
      if (i === root.draggingIndex) continue
      var s = root.positions[i]
      if (!s) continue
      if (!first) { firstIdx = i; first = s }
      lastIdx = i
      last = s
      if (px >= s.x && px <= s.x + s.w && py >= s.y && py <= s.y + s.h) {
        idx = (px <= s.x + s.w / 2) ? i : i + 1
        row = rowOf(list[i])
        break
      }
    }

    if (idx < 0) {
      if (!first) {
        idx = 0
        row = 0
      } else if (py < first.y) {
        idx = firstIdx
        row = rowOf(list[firstIdx])
      } else if (last && py > last.y + last.h) {
        var maxRow = 0
        for (var j = 0; j < list.length; j++) maxRow = Math.max(maxRow, rowOf(list[j]))
        idx = list.length
        row = maxRow + 1
      } else {
        idx = list.length
        row = rowOf(list[lastIdx])
      }
    }

    var changed = idx !== root.targetIndex || row !== root.targetRow
    root.targetIndex = idx
    root.targetRow = row
    return changed
  }

  onWidthChanged: if (root.width > 0) recompute()
  onVisibleChanged: if (visible && root.width > 0) recompute()
  Component.onCompleted: Qt.callLater(function() { if (root.width > 0) recompute() })

  Connections {
    target: DashboardConfig
    function onActivePluginsChanged() { Qt.callLater(root.recompute) }
  }

  Repeater {
    id: rep
    model: DashboardConfig.activePlugins
    DashboardCard {
      cardId: modelData.id
      bar: root.bar
      editMode: root.editMode
      cardIndex: index
      dragActive: root.draggingIndex === cardIndex
      onRemoveRequested: DashboardConfig.removePlugin(cardId)
      onDragStarted: {
        root.draggingIndex = cardIndex
        root.targetIndex = cardIndex
        root.targetRow = root.rowOf(DashboardConfig.activePlugins[cardIndex])
        root.whatIf(root.targetIndex, root.targetRow)
      }
      onDragUpdated: {
        var card = rep.itemAt(cardIndex)
        if (!card) return
        if (root.updateTarget(card.x + card.width / 2, card.y + card.height / 2))
          root.whatIf(root.targetIndex, root.targetRow)
      }
      onDragEnded: {
        var src = root.draggingIndex
        var tgt = root.targetIndex
        var trow = root.targetRow
        root.draggingIndex = -1
        root.targetIndex = -1
        root.targetRow = -1
        root.ghostRect = null
        var list = DashboardConfig.activePlugins
        if (src < 0 || src >= list.length || tgt < 0) { root.recompute(); return }

        var curRow = root.rowOf(list[src])
        // No-op: dropped back into the same slot (index and row unchanged).
        if ((tgt === src || tgt === src + 1) && trow === curRow) { root.recompute(); return }

        // Remove the dragged entry, re-insert at the (adjusted) split index.
        var item = list[src]
        var next = []
        for (var i = 0; i < list.length; i++) {
          if (i !== src) next.push(list[i])
        }
        var insertAt = tgt > src ? tgt - 1 : tgt
        insertAt = Math.max(0, Math.min(next.length, insertAt))
        var entry = {}
        for (var k in item) entry[k] = item[k]
        entry.row = trow
        next.splice(insertAt, 0, entry)
        DashboardConfig.activePlugins = next  // persists + recompute
      }
      // Trigger tiler recompute when card implicit size changes (e.g. panel content loads)
      onImplicitWidthChanged: root.recompute()
      onImplicitHeightChanged: root.recompute()
    }
  }

  // Ghost outlining the drop slot during drag.
  Item {
    id: ghost
    x: root.ghostRect ? root.ghostRect.x : 0
    y: root.ghostRect ? root.ghostRect.y : 0
    width: root.ghostRect ? root.ghostRect.w : 0
    height: root.ghostRect ? root.ghostRect.h : 0
    visible: root.draggingIndex >= 0 && root.ghostRect !== null
    opacity: root.draggingIndex >= 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    BorderSurface {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Util.alpha(Color.accent, 0.08)
      borderSpec: Border.controlSpec("hover-cursor", Color.foreground, Color.accent)
    }
  }

  onEditModeChanged: if (!editMode) addDialog.open = false

  // Bottom clearance for the add-picker overlay: it must sit above the
  // edit-switch/FAB row (injected by ExpandedPanel).
  property real dialogBottomGap: Style.space(48)

  function toggleAddDialog() {
    addDialog.open = !addDialog.open
  }
}
