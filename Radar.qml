import QtQuick
import qs.Commons

// The scope. A phosphor-green-style radar sweep (recoloured to the theme
// accent) with range rings, cardinal ticks, and a blip per aircraft placed
// by bearing + distance. Blips flare as the sweep passes them and fade like
// real radar persistence. Click a blip to select it.
Item {
  id: root

  // Enriched + sorted aircraft from Model.enrich(), each also carrying the
  // identity fields Panel adds during ingest:
  // { hex, callsign, bearing, distKm, trackDeg, onGround, altFt, cat, unusual }.
  property var aircraft: []
  property real maxKm: 46.3            // range ring maximum (25 nm default)
  property string units: "km"
  property string selectedHex: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color urgent: Color.urgent
  // Colour blips by altitude (warm low -> cool high) instead of flat accent.
  property bool altColor: false
  // Animate only while the popup is open — a Canvas ticking at 30fps behind a
  // closed panel is wasted work.
  property bool running: true

  signal blipClicked(string hex)

  implicitWidth: 260
  implicitHeight: 260

  readonly property real _sweepStep: 3.6        // degrees per frame (~ 3s / rev at 30fps)
  property real _sweepDeg: 0
  // hex -> ms timestamp the sweep last painted that blip.
  property var _lit: ({})

  function _kmLabel(km) {
    var v = km
    if (units === "mi") v = km * 0.621371
    else if (units === "nm") v = km * 0.539957
    return (v < 10 ? v.toFixed(1) : String(Math.round(v)))
  }

  // Relative glyph size per category (1.0 = a regional jet).
  function _catScale(cat) {
    switch (cat) {
      case "widebody":   return 1.55
      case "military":   return 1.35
      case "narrowbody": return 1.15
      case "vintage":    return 1.05
      case "heli":       return 1.0
      case "regional":   return 1.0
      case "business":   return 0.9
      case "turboprop":  return 0.92
      case "piston":     return 0.7
      default:           return 0.85
    }
  }

  // Altitude -> hue: ~2 kft amber, ~18 kft green, ~38 kft blue.
  function _altHue(ft) {
    if (typeof ft !== "number" || !isFinite(ft)) return 150
    var t = Math.max(0, Math.min(1, ft / 40000))
    return 40 + t * 170        // 40 (amber) -> 210 (blue)
  }

  // A dart pointing "up" (nose at -y), drawn in the caller's transformed
  // frame. Props get a rounder body, helis a rotor cross, vintage a ring.
  function _glyph(ctx, cat, k) {
    if (cat === "heli") {
      ctx.lineWidth = 1.1
      ctx.beginPath()
      ctx.moveTo(-3.4 * k, 0); ctx.lineTo(3.4 * k, 0)
      ctx.moveTo(0, -3.4 * k); ctx.lineTo(0, 3.4 * k)
      ctx.stroke()
      ctx.beginPath(); ctx.arc(0, 0, 1.3 * k, 0, Math.PI * 2); ctx.fill()
      return
    }
    if (cat === "piston" || cat === "turboprop") {
      ctx.beginPath(); ctx.arc(0, 0, 2.4 * k, 0, Math.PI * 2); ctx.fill()
      return
    }
    if (cat === "vintage") {
      ctx.lineWidth = 1.2
      ctx.beginPath(); ctx.arc(0, 0, 2.6 * k, 0, Math.PI * 2); ctx.stroke()
      return
    }
    // jet dart (narrowbody / widebody / regional / business / military)
    ctx.beginPath()
    ctx.moveTo(0, -3.6 * k)
    ctx.lineTo(2.6 * k, 2.6 * k)
    ctx.lineTo(0, 1.4 * k)
    ctx.lineTo(-2.6 * k, 2.6 * k)
    ctx.closePath()
    ctx.fill()
    if (cat === "military") {          // little tailplane to set them apart
      ctx.beginPath()
      ctx.moveTo(-1.6 * k, 2.9 * k)
      ctx.lineTo(1.6 * k, 2.9 * k)
      ctx.lineTo(0, 4.1 * k)
      ctx.closePath()
      ctx.fill()
    }
  }

  Timer {
    interval: 33
    repeat: true
    running: root.running
    onTriggered: {
      var prev = root._sweepDeg
      var cur = (prev + root._sweepStep) % 360
      var wrapped = cur < prev
      var now = Date.now()
      var lit = root._lit
      var list = root.aircraft || []
      for (var i = 0; i < list.length; i++) {
        var ba = ((list[i].bearing % 360) + 360) % 360
        var crossed = wrapped ? (ba > prev || ba <= cur) : (ba > prev && ba <= cur)
        if (crossed) lit[list[i].hex] = now
      }
      root._lit = lit
      root._sweepDeg = cur
      canvas.requestPaint()
    }
  }

  onAircraftChanged: canvas.requestPaint()
  onSelectedHexChanged: canvas.requestPaint()
  onRunningChanged: if (running) canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent

    function pol(cx, cy, r, deg) {
      var a = (deg - 90) * Math.PI / 180        // 0deg = north = up, clockwise
      return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) }
    }

    onPaint: {
      var ctx = getContext("2d")
      var W = width, H = height
      ctx.clearRect(0, 0, W, H)

      var cx = W / 2, cy = H / 2
      var R = Math.min(W, H) / 2 - 18
      if (R <= 0) return

      var fg = root.foreground
      var ac = root.accent

      // ---- scope face
      ctx.beginPath()
      ctx.arc(cx, cy, R, 0, Math.PI * 2)
      ctx.fillStyle = Qt.rgba(ac.r, ac.g, ac.b, 0.05)
      ctx.fill()

      // ---- range rings + labels
      ctx.lineWidth = 1
      var rings = [1 / 3, 2 / 3, 1]
      for (var k = 0; k < rings.length; k++) {
        var rr = R * rings[k]
        ctx.beginPath()
        ctx.arc(cx, cy, rr, 0, Math.PI * 2)
        ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.14)
        ctx.stroke()
        // Label the inner rings only, on the downward vertical, so nothing
        // collides with the "N" tick up top. The outer ring == the range chip.
        if (k < rings.length - 1) {
          ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.35)
          ctx.font = "9px sans-serif"
          ctx.textAlign = "left"
          ctx.textBaseline = "middle"
          ctx.fillText(root._kmLabel(root.maxKm * rings[k]) + root.units, cx + 4, cy + rr)
        }
      }

      // ---- crosshair
      ctx.beginPath()
      ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy)
      ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R)
      ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.08)
      ctx.stroke()

      // ---- cardinal letters
      var card = [["N", 0], ["E", 90], ["S", 180], ["W", 270]]
      ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.45)
      ctx.font = "bold 10px sans-serif"
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      for (var c = 0; c < card.length; c++) {
        var p = pol(cx, cy, R + 9, card[c][1])
        ctx.fillText(card[c][0], p.x, p.y)
      }

      // ---- sweep: faint trailing wedge + bright leading edge
      var lead = root._sweepDeg
      var span = 44
      for (var s = 0; s < span; s += 4) {
        var a0 = (lead - s - 90) * Math.PI / 180
        var a1 = (lead - s - 4 - 90) * Math.PI / 180
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.arc(cx, cy, R, a1, a0)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(ac.r, ac.g, ac.b, 0.10 * (1 - s / span))
        ctx.fill()
      }
      var le = pol(cx, cy, R, lead)
      ctx.beginPath()
      ctx.moveTo(cx, cy); ctx.lineTo(le.x, le.y)
      ctx.strokeStyle = Qt.rgba(ac.r, ac.g, ac.b, 0.55)
      ctx.lineWidth = 1.5
      ctx.stroke()

      // ---- blips
      var list = root.aircraft || []
      var now = Date.now()
      for (var i = 0; i < list.length; i++) {
        var a = list[i]
        var frac = Math.min(1, (a.distKm || 0) / root.maxKm)
        var bp = pol(cx, cy, R * frac, a.bearing || 0)

        var age = now - (root._lit[a.hex] || 0)
        var glow = age > 2600 ? 0.30 : (1 - 0.70 * (age / 2600))
        var sel = a.hex && a.hex === root.selectedHex
        var alpha = a.onGround ? 0.4 * Math.max(glow, 0.5)
                              : Math.max(glow, sel ? 0.95 : 0.32)
        var hasTrack = typeof a.trackDeg === "number" && isFinite(a.trackDeg)

        // fill colour: unusual -> urgent, altColor -> hue by altitude,
        // on-ground -> dim foreground, else theme accent.
        var col
        if (a.onGround)      col = Qt.rgba(fg.r, fg.g, fg.b, alpha)
        else if (a.unusual)  col = Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, Math.max(alpha, 0.6))
        else if (root.altColor) col = Qt.hsla(root._altHue(a.altFt) / 360, 0.6, 0.62, alpha)
        else                 col = Qt.rgba(ac.r, ac.g, ac.b, alpha)

        var k = root._catScale(a.cat) * (sel ? 1.25 : 1.0)

        ctx.save()
        ctx.translate(bp.x, bp.y)
        if (hasTrack) ctx.rotate(a.trackDeg * Math.PI / 180)
        ctx.fillStyle = col
        ctx.strokeStyle = col
        root._glyph(ctx, a.cat || "unknown", k)
        ctx.restore()

        if (sel) {
          ctx.beginPath()
          ctx.arc(bp.x, bp.y, 9, 0, Math.PI * 2)
          ctx.strokeStyle = Qt.rgba(ac.r, ac.g, ac.b, 0.9)
          ctx.lineWidth = 1
          ctx.stroke()
          ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.95)
          ctx.font = "bold 10px sans-serif"
          ctx.textAlign = "center"
          ctx.textBaseline = "bottom"
          ctx.fillText(a.callsign || "", bp.x, bp.y - 12)
        }
      }

      // ---- you
      ctx.save()
      ctx.translate(cx, cy)
      ctx.rotate(Math.PI / 4)
      ctx.fillStyle = fg
      ctx.fillRect(-2.5, -2.5, 5, 5)
      ctx.restore()
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: function (m) {
      var cx = width / 2, cy = height / 2
      var R = Math.min(width, height) / 2 - 18
      if (R <= 0) return
      var list = root.aircraft || []
      var bestHex = "", bestD = 16       // px pick radius
      for (var i = 0; i < list.length; i++) {
        var a = list[i]
        var frac = Math.min(1, (a.distKm || 0) / root.maxKm)
        var ang = ((a.bearing || 0) - 90) * Math.PI / 180
        var bx = cx + R * frac * Math.cos(ang)
        var by = cy + R * frac * Math.sin(ang)
        var d = Math.sqrt((m.x - bx) * (m.x - bx) + (m.y - by) * (m.y - by))
        if (d < bestD) { bestD = d; bestHex = a.hex }
      }
      root.blipClicked(bestHex)         // "" clears the selection
    }
  }
}
