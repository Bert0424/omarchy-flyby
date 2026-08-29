// Pure parsing + geo math for the Flyby radar. No QML imports here so it
// can be unit-tested with plain node:
//   node -e 'const M=require("./Model.js"); console.log(M.compass(45))'
//
// Normalised aircraft shape produced by parseAircraft() + enrich():
//   { hex, callsign, reg, type, desc,
//     altFt, onGround, gsKt, trackDeg, vrFpm, squawk,
//     lat, lon,                       // raw position
//     distKm, bearing, compass }      // added by enrich(), relative to you

var COMPASS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
               "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

// Horizontal distance (km) under which an airborne aircraft counts as "overhead".
var OVERHEAD_KM = 3.0

function toRad(d) { return d * Math.PI / 180 }
function toDeg(r) { return r * 180 / Math.PI }

// Trim, drop anything a Text element could read as markup or that wrecks
// layout, collapse whitespace, clamp length. Every string that comes off the
// wire goes through here before it reaches QML.
function cleanStr(s, max) {
  var t = String(s === undefined || s === null ? "" : s)
  t = t.replace(/[\x00-\x1f\x7f]/g, " ").replace(/[<>]/g, "").replace(/\s+/g, " ").trim()
  var cap = max || 40
  return t.length > cap ? t.slice(0, cap) : t
}

function haversineKm(lat1, lon1, lat2, lon2) {
  var R = 6371.0088
  var dlat = toRad(lat2 - lat1)
  var dlon = toRad(lon2 - lon1)
  var a = Math.sin(dlat / 2) * Math.sin(dlat / 2)
        + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dlon / 2) * Math.sin(dlon / 2)
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)))
}

// Initial great-circle bearing from point 1 to point 2, degrees clockwise from north.
function bearingDeg(lat1, lon1, lat2, lon2) {
  var dLon = toRad(lon2 - lon1)
  var y = Math.sin(dLon) * Math.cos(toRad(lat2))
  var x = Math.cos(toRad(lat1)) * Math.sin(toRad(lat2))
        - Math.sin(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(dLon)
  return (toDeg(Math.atan2(y, x)) + 360) % 360
}

function compass(bearing) {
  return COMPASS[Math.round(((bearing % 360) + 360) % 360 / 22.5) % 16]
}

function isNum(v) { return typeof v === "number" && isFinite(v) }
function num(v) { var n = Number(v); return isFinite(n) ? n : NaN }

// Accepts the readsb / re-api JSON shared by adsb.lol, adsb.fi and
// airplanes.live: a top-level `ac` (or `aircraft`) array of raw contacts.
function parseAircraft(rawText) {
  var data = JSON.parse(String(rawText || "{}"))
  var arr = data.ac || data.aircraft || []
  if (!Array.isArray(arr)) return []
  var out = []
  for (var i = 0; i < arr.length; i++) {
    var a = arr[i] || {}
    var lat = num(a.lat)
    var lon = num(a.lon)
    if (!isNum(lat) || !isNum(lon)) continue          // no position fix — skip

    var altRaw = a.alt_baro !== undefined ? a.alt_baro : a.alt_geom
    var onGround = altRaw === "ground"
    var altFt = onGround ? 0 : num(altRaw)

    var track = isNum(num(a.track)) ? num(a.track)
              : isNum(num(a.mag_heading)) ? num(a.mag_heading)
              : isNum(num(a.true_heading)) ? num(a.true_heading) : NaN

    var vr = isNum(num(a.baro_rate)) ? num(a.baro_rate)
           : isNum(num(a.geom_rate)) ? num(a.geom_rate) : NaN

    // ADS-B callsign fields arrive padded, and an un-set one comes through as
    // "@@@@@@@@" or all-symbols — fall back to registration, then hex.
    var rawCs = cleanStr(a.flight || "", 12).toUpperCase()
    if (!/[A-Z0-9]/.test(rawCs) || /^@+$/.test(rawCs)) rawCs = ""
    var callsign = rawCs || cleanStr(a.r || "", 12).toUpperCase()
                         || cleanStr(a.hex || "", 8).toUpperCase()

    out.push({
      hex: cleanStr(a.hex || a.icao || "", 8).toLowerCase(),
      callsign: callsign || "(no callsign)",
      reg: cleanStr(a.r || "", 12),
      type: cleanStr(a.t || "", 8),
      desc: cleanStr(a.desc || a.ownOp || "", 40),
      altFt: altFt,
      onGround: onGround,
      gsKt: num(a.gs),
      trackDeg: track,
      vrFpm: vr,
      squawk: cleanStr(a.squawk || "", 6),
      lat: lat,
      lon: lon
    })
  }
  return out
}

// Adds distance / bearing / compass relative to (originLat, originLon) and
// returns the list sorted nearest-first.
function enrich(list, originLat, originLon) {
  for (var i = 0; i < list.length; i++) {
    var a = list[i]
    a.distKm = haversineKm(originLat, originLon, a.lat, a.lon)
    a.bearing = bearingDeg(originLat, originLon, a.lat, a.lon)
    a.compass = compass(a.bearing)
  }
  list.sort(function (x, y) { return x.distKm - y.distKm })
  return list
}

// Drop ground contacts (parked/taxiing aircraft, tower, service vehicles)
// unless the user explicitly wants them — this widget is about flyovers.
function filterGround(list, showGround) {
  if (showGround) return list
  return list.filter(function (a) { return !a.onGround })
}

// Airborne contacts within OVERHEAD_KM, nearest first.
function overhead(list) {
  var out = []
  for (var i = 0; i < list.length; i++) {
    var a = list[i]
    if (!a.onGround && isNum(a.distKm) && a.distKm <= OVERHEAD_KM) out.push(a)
  }
  return out
}

function kmToUnit(km, unit) {
  if (unit === "mi") return km * 0.621371
  if (unit === "nm") return km * 0.539957
  return km
}

function fmtDist(km, unit) {
  if (!isNum(km)) return "—"
  var v = kmToUnit(km, unit)
  return (v < 10 ? v.toFixed(1) : String(Math.round(v))) + " " + (unit || "km")
}

function fmtAlt(ft, onGround) {
  if (onGround) return "on ground"
  if (!isNum(ft)) return "alt —"
  var r = Math.round(ft / 25) * 25
  return r.toLocaleString ? r.toLocaleString("en-US") + " ft"
       : String(r).replace(/\B(?=(\d{3})+(?!\d))/g, ",") + " ft"
}

// ↑ climbing, ↓ descending, · level, "" unknown.
function trend(vrFpm) {
  if (!isNum(vrFpm)) return ""
  if (vrFpm > 200) return "↑"
  if (vrFpm < -200) return "↓"
  return "·"
}

function fmtSpeed(gsKt) {
  return isNum(gsKt) ? Math.round(gsKt) + " kt" : ""
}

// Dim one-liner under the callsign: type · alt trend · speed · heading.
function detailLine(a, unit) {
  var parts = []
  if (a.type) parts.push(a.type)
  else if (a.reg) parts.push(a.reg)
  var alt = fmtAlt(a.altFt, a.onGround)
  var t = trend(a.vrFpm)
  parts.push(t && t !== "·" ? alt + " " + t : alt)
  var spd = fmtSpeed(a.gsKt)
  if (spd) parts.push(spd)
  if (isNum(a.trackDeg)) parts.push("→ " + compass(a.trackDeg))
  return parts.join("  ·  ")
}

// api URL for a provider. lat/lon already validated numeric by the caller;
// radiusNm is one of the fixed manifest enum strings.
function apiUrl(provider, lat, lon, radiusNm) {
  var r = String(parseInt(radiusNm, 10) || 25)
  var la = String(lat)
  var lo = String(lon)
  if (provider === "adsb.fi")
    return "https://opendata.adsb.fi/api/v2/lat/" + la + "/lon/" + lo + "/dist/" + r
  return "https://api.adsb.lol/v2/point/" + la + "/" + lo + "/" + r   // default
}

// Bar pill text. hasLocation false => prompt; overhead => closest callsign;
// else the count within range.
function pillText(hasLocation, aircraft, overheadList) {
  if (!hasLocation) return "✈ set location"
  if (overheadList && overheadList.length) return "✈ " + overheadList[0].callsign
  var n = aircraft ? aircraft.length : 0
  return n > 0 ? "✈ " + n : "✈"
}

if (typeof module !== "undefined") {
  module.exports = {
    OVERHEAD_KM: OVERHEAD_KM,
    cleanStr: cleanStr,
    filterGround: filterGround,
    haversineKm: haversineKm,
    bearingDeg: bearingDeg,
    compass: compass,
    parseAircraft: parseAircraft,
    enrich: enrich,
    overhead: overhead,
    kmToUnit: kmToUnit,
    fmtDist: fmtDist,
    fmtAlt: fmtAlt,
    trend: trend,
    detailLine: detailLine,
    apiUrl: apiUrl,
    pillText: pillText
  }
}
