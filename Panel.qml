import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Data.js" as Data

// Lifecycle + data + UI for the Flyby radar popup. Mirrors the standard
// bar-widget popup shape (Panel base -> KeyboardPanel -> PanelKeyCatcher),
// same as the first-party audio/weather panels. Config is read from and
// written back through the host BarWidget (widget.settings / widget.setKey).
Panel {
  id: root
  moduleName: "bert.flyby"
  ipcTarget: "bert.flyby"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var widget: null
  readonly property var barIdentity: hostWidget || root

  // ---- config -----------------------------------------------------------
  readonly property var cfg: (widget && widget.settings) ? widget.settings : ({})
  function val(k, dflt) { return (cfg[k] !== undefined && cfg[k] !== null) ? cfg[k] : dflt }
  function put(k, v) { if (widget && widget.setKey) widget.setKey(k, v) }

  readonly property real originLat: parseFloat(val("latitude", ""))
  readonly property real originLon: parseFloat(val("longitude", ""))
  readonly property bool hasLocation:
      isFinite(originLat) && isFinite(originLon)
      && originLat >= -90 && originLat <= 90
      && originLon >= -180 && originLon <= 180
      && !(originLat === 0 && originLon === 0)

  readonly property int radiusNm: parseInt(val("radiusNm", "25"), 10) || 25
  readonly property real radiusKm: radiusNm * 1.852
  readonly property string provider: val("provider", "adsb.lol")
  readonly property string units: val("units", "km")
  function boolVal(k, dflt) {
    var v = val(k, dflt)
    return v === true || v === "true"
  }
  readonly property bool notifyOverhead:  boolVal("notifyOverhead", false)
  readonly property bool notifyDiscovery: boolVal("notifyDiscovery", true)
  readonly property bool showGround:      boolVal("showGround", false)
  readonly property bool readablePill:    boolVal("readablePill", false)
  readonly property bool altColor:        boolVal("altColor", false)
  readonly property bool routeLookup:     boolVal("routeLookup", true)
  readonly property bool showPhotos:      boolVal("showPhotos", false)
  readonly property bool overheadOnlyLog: boolVal("overheadOnlyLog", false)

  // ---- state ----------------------------------------------------------
  property var aircraft: []
  property var overheadList: []
  property string selectedHex: ""
  property string lastError: ""
  property bool locating: false
  property bool editingLocation: false
  property var _prevOverhead: ({})

  // "scope" | "dex"
  property string view: "scope"
  property string dexSelectedCode: ""
  // Logbook grid filter: "all" | "airliner" | "light" | "rotor" | "milvintage"
  property string dexFilter: "all"
  property bool dexShowAchievements: false
  property bool summaryCopied: false

  // Dex model: { v:1, types:{CODE:{n,first,last,firstCs,photo,...}}, log:[...], achievements:{id:iso} }
  property var dex: ({ v: 1, types: ({}), log: [], achievements: ({}) })
  property bool dexLoaded: false
  // hex codes confirmed present on the previous poll — a type only counts
  // toward the Dex once we've seen the same airframe twice running, so a
  // single garbled type field can't mint a phantom entry.
  property var _prevHexes: ({})
  property int dexDiscoveredCount: 0
  property int dexRareCount: 0
  property int dexExoticCount: 0
  property int dexScore: 0
  property int achievementsUnlocked: 0

  // Today's activity, from the sightings log (local date).
  readonly property var dexToday: {
    var now = new Date()
    var key = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate()
    var seen = 0, codes = ({}), fresh = 0
    var log = (root.dex && root.dex.log) || []
    for (var i = 0; i < log.length; i++) {
      var d = new Date(log[i].t)
      if (d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate() !== key) continue
      seen++
      if (log[i].code) codes[log[i].code] = true
    }
    var types = (root.dex && root.dex.types) || {}
    for (var c in types) {
      var f = new Date(types[c].first)
      if (f.getFullYear() + "-" + f.getMonth() + "-" + f.getDate() === key && Data.typeInfo(c)) fresh++
    }
    return { sightings: seen, types: Object.keys(codes).length, fresh: fresh }
  }

  // Common types still missing from the Logbook — an achievable next target.
  // Deduped by display name (AT72/AT75/AT76 all read "ATR 72").
  readonly property var missingCommons: {
    var out = [], seen = ({}), t = (root.dex && root.dex.types) || {}
    var all = Data.allTypeCodes()
    for (var i = 0; i < all.length && out.length < 7; i++) {
      if (Data.rarity(all[i]) !== "common" || t[all[i]]) continue
      var s = Data.typeShort(all[i])
      if (seen[s]) continue
      seen[s] = true
      out.push(s)
    }
    return out
  }

  // The aircraft the identity card is showing, resolved from selectedHex.
  readonly property var selAc: {
    var h = root.selectedHex
    if (!h) return null
    for (var i = 0; i < root.aircraft.length; i++)
      if (root.aircraft[i].hex === h) return root.aircraft[i]
    return null
  }

  // ---- Phase B enrichment (adsbdb route + owner + photo), click-only.
  // hex -> parsed enrichment object, or "miss". In-memory for the session;
  // route/owner are effectively static so one lookup per airframe is plenty.
  property var _enrichCache: ({})
  property bool enriching: false
  // on-tap photo lookup for a Logbook entry that has none pinned
  property var _dexPhotoTried: ({})
  property string _dexPhotoCode: ""
  property bool _dexPhotoLoading: false
  readonly property var selEnrich: {
    var h = root.selectedHex, c = h ? root._enrichCache[h] : null
    return (c && c !== "miss") ? c : null
  }
  onSelectedHexChanged: {
    root.enriching = false
    if (root.selectedHex && root.routeLookup && !root._enrichCache[root.selectedHex])
      enrichDebounce.restart()
    else
      enrichDebounce.stop()
  }

  function maybeEnrich() {
    var h = root.selectedHex
    if (!h || !root.routeLookup || root._enrichCache[h] || enrichProc.running) return
    var a = root.selAc
    if (!a) return
    var cs = String(a.callsign || "").replace(/[^A-Za-z0-9]/g, "")
    var hex = String(h).replace(/[^A-Fa-f0-9]/g, "")
    if (!hex) return
    // Full URLs built here and passed as args — the script never interpolates
    // them, and every host is fixed. A missing callsign just skips the route.
    var routeUrl = cs ? "https://api.adsbdb.com/v0/callsign/" + cs : "https://api.adsbdb.com/v0/"
    var acUrl = "https://api.adsbdb.com/v0/aircraft/" + hex
    var psUrl = "https://api.planespotters.net/pub/photos/hex/" + hex
    root.enriching = true
    root._enrichHex = h
    enrichProc.command = ["bash", "-c",
      'a=$(timeout 6 curl -sS --max-time 5 -A "$4" -- "$1" | head -c 20000); '
      + 'b=$(timeout 6 curl -sS --max-time 5 -A "$4" -- "$2" | head -c 20000); '
      + 'c=$(timeout 6 curl -sS --max-time 5 -A "$4" -- "$3" | head -c 20000); '
      + 'printf \'{"route":%s,"ac":%s,"ps":%s}\' "${a:-null}" "${b:-null}" "${c:-null}"',
      "flyby", routeUrl, acUrl, psUrl, root.userAgent]
    enrichProc.running = true
  }
  property string _enrichHex: ""

  // Which categories each Logbook filter shows.
  function _filterCats(f) {
    if (f === "airliner")   return { widebody: 1, narrowbody: 1, regional: 1 }
    if (f === "light")      return { piston: 1, turboprop: 1, business: 1 }
    if (f === "rotor")      return { heli: 1 }
    if (f === "milvintage") return { military: 1, vintage: 1 }
    return null   // "all"
  }

  // Type codes for the Logbook grid: filtered, then discovered first
  // (most-seen first), then the rest alphabetically. Recomputes when `dex`
  // or `dexFilter` changes.
  readonly property var dexGridModel: {
    var t = root.dex.types || {}
    var cats = root._filterCats(root.dexFilter)
    var codes = Data.allTypeCodes().filter(function (c) {
      return !cats || cats[Data.category(c)]
    })
    codes.sort(function (a, b) {
      var da = t[a] ? 1 : 0, db = t[b] ? 1 : 0
      if (da !== db) return db - da
      if (da) return (t[b].n || 0) - (t[a].n || 0)
      return a < b ? -1 : 1
    })
    return codes
  }
  readonly property int dexFilterGot: {
    var t = root.dex.types || {}, n = 0
    for (var i = 0; i < root.dexGridModel.length; i++) if (t[root.dexGridModel[i]]) n++
    return n
  }

  readonly property int count: aircraft.length
  readonly property bool overhead: overheadList.length > 0
  readonly property string label: Model.pillText(root.hasLocation, root.aircraft,
                                                 root.overheadList,
                                                 root.readablePill ? Data : null)

  readonly property int dexUniverse: Data.typeUniverseCount()

  readonly property string userAgent: "omarchy-flyby/0.2 (Omarchy plugin; +https://omarchyplugins.com)"

  // ---- lifecycle ----------------------------------------------------
  function open() { root.controller.show(); root.refresh(); Qt.callLater(root.syncLocationFields) }
  function openFromHotkey() { root.open() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // ---- fetch --------------------------------------------------------
  function refresh() {
    if (!root.hasLocation || fetchProc.running) return
    var url = Model.apiUrl(root.provider, root.originLat.toFixed(4),
                           root.originLon.toFixed(4), String(root.radiusNm))
    // url passed as an argument (never interpolated into the script) and
    // guarded with `--` so it can't be read as a curl option; output is
    // time-boxed and byte-capped before it ever reaches the shell.
    fetchProc.command = ["bash", "-c",
      'exec timeout 10 curl -fsS --max-time 9 -A "$1" -- "$2" | head -c "$3"',
      "flyby", root.userAgent, url, "2500000"]
    fetchProc.running = true
  }

  function ingest(rawText) {
    var raw = String(rawText || "").trim()
    if (!raw) { root.lastError = "No response from " + root.provider; retryTimer.restart(); return }
    var list
    try {
      list = Model.parseAircraft(raw)
    } catch (e) {
      root.lastError = "Couldn't read " + root.provider + " data"
      retryTimer.restart()
      return
    }
    list = Model.filterGround(list, root.showGround)
    Model.enrich(list, root.originLat, root.originLon)
    // Keep the list bounded no matter how busy the sky is.
    if (list.length > 60) list = list.slice(0, 60)

    // Attach identity (type name, category, rarity, operator, "unusual" flag)
    // so the radar, list and card can all read it off the aircraft object.
    for (var i = 0; i < list.length; i++) {
      var id = Model.identify(Data, list[i])
      list[i].id = id
      list[i].cat = id.category
      list[i].unusual = id.unusual
    }

    root.lastError = ""
    root.aircraft = list
    var ov = Model.overhead(list)
    root.overheadList = ov
    root.maybeNotify(ov)
    root.updateDex(list)
  }

  // Fold this poll into the Dex. A type is only recorded once the same
  // airframe (hex) has been seen on two consecutive polls — cheap guard
  // against a corrupt `t` field creating a bogus collectible.
  function updateDex(list) {
    if (!root.dexLoaded) return
    var seenNow = ({})
    var d = root.dex
    var types = d.types || (d.types = {})
    var log = d.log || (d.log = [])
    if (!d.achievements) d.achievements = {}
    var nowIso = new Date().toISOString()
    var discovered = []
    var changed = false

    for (var i = 0; i < list.length; i++) {
      var a = list[i]
      if (!a.hex) continue
      seenNow[a.hex] = true
      var confirmed = root._prevHexes[a.hex] === true
      if (!confirmed) continue
      // Overhead-only mode: a type is earned only once it has actually passed
      // within the overhead radius, airborne — not merely somewhere in range.
      if (root.overheadOnlyLog && (a.onGround || !(a.distKm <= Model.OVERHEAD_KM))) continue

      var code = a.id.typeCode
      if (!code) continue
      var known = a.id.known
      var e = types[code]
      if (!e) {
        types[code] = { n: 1, first: nowIso, last: nowIso,
                        firstCs: a.callsign || "", hex: a.hex || "" }
        changed = true
        if (known) discovered.push(code)     // only celebrate real, named types
      } else {
        e.n = (e.n || 0) + 1
        e.last = nowIso
        if (a.hex) e.hex = a.hex              // keep a hex on file for photo lookup
        changed = true
      }

      log.push({
        t: nowIso, code: code, cs: a.callsign || "", reg: a.reg || "",
        hex: a.hex, alt: isFinite(a.altFt) ? Math.round(a.altFt) : null,
        dist: isFinite(a.distKm) ? Math.round(a.distKm * 10) / 10 : null,
        unusual: !!a.unusual
      })
    }
    if (log.length > 500) d.log = log.slice(log.length - 500)

    root._prevHexes = seenNow
    if (changed) {
      // milestones — derive today's sighting count + a pre-dawn flag from the log
      var nowKey = root._dayKey(new Date())
      var todayN = 0, redEye = false
      for (var li = 0; li < d.log.length; li++) {
        var ld = new Date(d.log[li].t)
        if (root._dayKey(ld) === nowKey) todayN++
        if (ld.getHours() < 5) redEye = true
      }
      var newAch = Model.evalAchievements(Data, d, todayN, redEye)
      for (var ai = 0; ai < newAch.length; ai++) {
        d.achievements[newAch[ai].id] = nowIso
        root.announceAchievement(newAch[ai].label)
      }

      root.dex = d                     // reassign so bindings react
      root.recountDex()
      root.persistDex()
    }
    for (var k = 0; k < discovered.length; k++) root.announceDiscovery(discovered[k])
  }

  function _dayKey(dt) { return dt.getFullYear() + "-" + dt.getMonth() + "-" + dt.getDate() }

  function recountDex() {
    var n = 0, rare = 0, exotic = 0, t = root.dex.types || {}
    for (var c in t) {
      var info = Data.typeInfo(c)
      if (!info) continue
      n++
      if (info.r === "rare") rare++
      else if (info.r === "exotic") exotic++
    }
    root.dexDiscoveredCount = n
    root.dexRareCount = rare
    root.dexExoticCount = exotic
    root.dexScore = Model.logbookScore(Data, root.dex)
    root.achievementsUnlocked = Object.keys(root.dex.achievements || {}).length
  }

  function announceAchievement(label) {
    Quickshell.execDetached([
      "omarchy-notification-send", "--app-name", "flyby", "-u", "normal",
      "🏅 " + label, "Flyby logbook · " + root.dexScore + " pts"
    ])
  }

  // Put a share-ready summary of the Logbook on the clipboard. The text always
  // begins with "✈", so it can't be misread by wl-copy as an option.
  function copySummary() {
    var text = Model.logbookSummary(Data, root.dex, root.dexUniverse)
    Quickshell.execDetached(["wl-copy", text])
    root.summaryCopied = true
    summaryResetTimer.restart()
  }

  // Open a photo's source page — only ever a validated planespotters.net URL.
  function openPhotoLink(url) {
    var safe = Model.safePageUrl(url)
    if (safe) Quickshell.execDetached(["xdg-open", safe])
  }

  // Newest hex we've logged for a type (fallback when the type entry predates
  // the `hex` field).
  function _logHexFor(code) {
    var log = (root.dex && root.dex.log) || []
    for (var i = log.length - 1; i >= 0; i--)
      if (log[i].code === code && log[i].hex) return log[i].hex
    return ""
  }

  // Fill in a Logbook entry's photo on demand — when its card is opened and it
  // has none pinned. One lookup per type per session; a genuine "no photo"
  // result is remembered in the file so it isn't retried.
  function maybeDexPhoto() {
    var code = root.dexSelectedCode
    if (!code || !root.showPhotos || !root.routeLookup) return
    var e = root.dex.types ? root.dex.types[code] : null
    if (!e || e.photo || e.photoNone || root._dexPhotoTried[code] || dexPhotoProc.running) return
    var hex = String(e.hex || root._logHexFor(code)).replace(/[^A-Fa-f0-9]/g, "")
    if (!hex) return
    var tried = ({})
    for (var k in root._dexPhotoTried) tried[k] = root._dexPhotoTried[k]
    tried[code] = true
    root._dexPhotoTried = tried
    root._dexPhotoCode = code
    root._dexPhotoLoading = true
    dexPhotoProc.command = ["bash", "-c",
      'b=$(timeout 6 curl -sS --max-time 5 -A "$3" -- "$1" | head -c 20000); '
      + 'c=$(timeout 6 curl -sS --max-time 5 -A "$3" -- "$2" | head -c 20000); '
      + 'printf \'{"ac":%s,"ps":%s}\' "${b:-null}" "${c:-null}"',
      "flyby",
      "https://api.adsbdb.com/v0/aircraft/" + hex,
      "https://api.planespotters.net/pub/photos/hex/" + hex,
      root.userAgent]
    dexPhotoProc.running = true
  }
  onDexSelectedCodeChanged: root.maybeDexPhoto()
  onShowPhotosChanged: if (showPhotos) root.maybeDexPhoto()

  Process {
    id: dexPhotoProc
    stdout: StdioCollector {
      id: dexPhotoOut
      waitForEnd: true
      onStreamFinished: {
        var code = root._dexPhotoCode
        root._dexPhotoLoading = false
        if (!code) return
        var parsed
        try { parsed = Model.parseEnrichment(dexPhotoOut.text) } catch (e) { parsed = null }
        var d = root.dex
        var entry = d.types ? d.types[code] : null
        if (!entry) return
        if (parsed && parsed.photoThumb) {
          entry.photo = parsed.photoThumb
          entry.photoBy = parsed.photoBy || ""
          entry.photoLink = parsed.photoLink || ""
          entry.photoSource = parsed.photoSource || ""
          if (parsed.reg && !entry.photoReg) entry.photoReg = parsed.reg
        } else {
          entry.photoNone = true            // remembered so we don't retry
        }
        root.dex = d
        root.persistDex()
      }
    }
    onExited: function (c) { if (c !== 0) root._dexPhotoLoading = false }
  }

  function announceDiscovery(code) {
    var info = Data.typeInfo(code)
    if (!info) return
    var rar = info.r ? info.r.charAt(0).toUpperCase() + info.r.slice(1) : ""
    if (root.notifyDiscovery) {
      Quickshell.execDetached([
        "omarchy-notification-send", "--app-name", "flyby", "-u", "normal",
        "✦ New in your logbook: " + info.n,
        rar + "  ·  " + root.dexDiscoveredCount + " of " + root.dexUniverse + " types logged"
      ])
    }
  }

  function maybeNotify(ov) {
    var next = ({})
    for (var i = 0; i < ov.length; i++) next[ov[i].hex] = true
    if (root.notifyOverhead) {
      for (var j = 0; j < ov.length; j++) {
        var a = ov[j]
        if (!root._prevOverhead[a.hex]) {
          Quickshell.execDetached([
            "omarchy-notification-send", "--app-name", "flyby", "-u", "normal",
            "✈ " + a.callsign + " overhead",
            Model.fmtAlt(a.altFt, a.onGround) + "  ·  " + a.compass
              + "  ·  " + Model.fmtDist(a.distKm, root.units)
          ])
        }
      }
    }
    root._prevOverhead = next
  }

  // One-shot coarse geolocation from the caller's IP. User-initiated only
  // (the "Locate me" button); result is written straight into the widget
  // settings as latitude/longitude and nothing else is sent.
  function locateMe() {
    if (locateProc.running) return
    root.locating = true
    locateProc.running = true
  }

  // Push the stored coordinates into the manual-entry fields. Called on open,
  // when the editor is revealed, and after a successful "Locate me" so an
  // open editor shows the fetched values (which the user can then fine-tune).
  function syncLocationFields() {
    try {
      latField.text = String(root.val("latitude", ""))
      lonField.text = String(root.val("longitude", ""))
      locErr.shown = false
    } catch (e) { /* fields not built yet — nothing to sync */ }
  }

  // Validate + persist what's typed in the manual-entry fields.
  function saveManualLocation() {
    var la = parseFloat(latField.text)
    var lo = parseFloat(lonField.text)
    if (isFinite(la) && isFinite(lo)
        && la >= -90 && la <= 90 && lo >= -180 && lo <= 180
        && !(la === 0 && lo === 0)) {
      root.put("latitude", la.toFixed(4))
      root.put("longitude", lo.toFixed(4))
      locErr.shown = false
      root.editingLocation = false
      root.aircraft = []
      root.selectedHex = ""
      Qt.callLater(root.refresh)
    } else {
      locErr.shown = true
    }
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.ingest(text)
    }
    onExited: function (code) {
      if (code !== 0 && root.aircraft.length === 0)
        root.lastError = "Couldn't reach " + root.provider
    }
  }

  Process {
    id: locateProc
    command: ["bash", "-c",
      'exec timeout 8 curl -fsS --max-time 6 -A "$1" -- "https://ipapi.co/latlong/" | head -c 64',
      "flyby", root.userAgent]
    stdout: StdioCollector {
      id: locateOut
      waitForEnd: true
      onStreamFinished: {
        root.locating = false
        var parts = String(locateOut.text || "").trim().split(",")
        var la = parseFloat(parts[0]), lo = parseFloat(parts[1])
        if (parts.length === 2 && isFinite(la) && isFinite(lo)
            && la >= -90 && la <= 90 && lo >= -180 && lo <= 180) {
          root.put("latitude", la.toFixed(4))
          root.put("longitude", lo.toFixed(4))
          root.aircraft = []
          Qt.callLater(root.refresh)
          Qt.callLater(root.syncLocationFields)
        } else {
          root.lastError = "Locate failed — enter your coordinates manually below"
          root.editingLocation = true
        }
      }
    }
    onExited: function (code) {
      if (code !== 0) { root.locating = false; root.lastError = "Locate failed (no network?)" }
    }
  }

  // Debounce so cycling the selection with N doesn't fire a burst of lookups.
  Timer { id: enrichDebounce; interval: 350; onTriggered: root.maybeEnrich() }

  Process {
    id: enrichProc
    stdout: StdioCollector {
      id: enrichOut
      waitForEnd: true
      onStreamFinished: {
        var h = root._enrichHex
        root.enriching = false
        if (!h) return
        var parsed
        try { parsed = Model.parseEnrichment(enrichOut.text) } catch (e) { parsed = null }
        var next = ({})
        for (var k in root._enrichCache) next[k] = root._enrichCache[k]
        next[h] = (parsed && (parsed.route || parsed.owner || parsed.acType || parsed.photoThumb))
                  ? parsed : "miss"
        // keep the cache from growing without bound over a long session
        var keys = Object.keys(next)
        if (keys.length > 120) delete next[keys[0]]
        root._enrichCache = next

        // Pin the first photo we ever get for a type onto its Logbook entry,
        // so the Logbook card can show the actual airframe that earned it.
        if (parsed && parsed.photoThumb) {
          var a = null
          for (var j = 0; j < root.aircraft.length; j++)
            if (root.aircraft[j].hex === h) { a = root.aircraft[j]; break }
          var code = a && a.id ? a.id.typeCode : ""
          var d = root.dex
          if (code && d.types && d.types[code] && !d.types[code].photo) {
            d.types[code].photo = parsed.photoThumb
            d.types[code].photoReg = (a.reg || parsed.reg || "")
            d.types[code].photoBy = parsed.photoBy || ""
            d.types[code].photoLink = parsed.photoLink || ""
            d.types[code].photoSource = parsed.photoSource || ""
            root.dex = d
            root.persistDex()
          }
        }
      }
    }
    onExited: function (code) {
      if (code !== 0) root.enriching = false
    }
  }

  Timer { id: retryTimer; interval: 6000; onTriggered: root.refresh() }
  Timer { id: summaryResetTimer; interval: 2000; onTriggered: root.summaryCopied = false }

  Timer {
    id: refreshTimer
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---- Dex persistence ------------------------------------------------
  // One file, ours alone: the logbook of every aircraft type we've seen.
  // Written atomically (temp + rename) and owner-only; read through a
  // wrapper that refuses symlinks / non-regular files and byte-caps the
  // input — same shape as Dropdeck's state file, which passed review.
  readonly property string _stateHome: Quickshell.env("XDG_STATE_HOME")
      || ((Quickshell.env("HOME") || "") + "/.local/state")
  readonly property string dexPath: _stateHome + "/omarchy/flyby-dex.json"
  readonly property int maxDexBytes: 524288

  function applyLoadedDex(text) {
    var parsed = null
    try { parsed = text ? JSON.parse(text) : null } catch (e) { parsed = null }
    if (parsed && typeof parsed === "object") {
      var d = {
        v: 1,
        types: (parsed.types && typeof parsed.types === "object") ? parsed.types : ({}),
        log: Array.isArray(parsed.log) ? parsed.log.slice(-500) : [],
        achievements: (parsed.achievements && typeof parsed.achievements === "object")
                      ? parsed.achievements : ({})
      }
      // Backfill a hex on entries that predate the field, from the log, so an
      // on-tap photo lookup has something to work with right away.
      for (var i = d.log.length - 1; i >= 0; i--) {
        var le = d.log[i]
        if (le.code && le.hex && d.types[le.code] && !d.types[le.code].hex)
          d.types[le.code].hex = le.hex
      }
      root.dex = d
    }
    root.dexLoaded = true
    root.recountDex()
  }

  function persistDex() {
    dexFile.setText(JSON.stringify(root.dex) + "\n")
  }

  function forgetDex() {
    root.dex = { v: 1, types: ({}), log: [], achievements: ({}) }
    root.dexSelectedCode = ""
    root.recountDex()
    root.persistDex()
  }

  function rarityColor(r) {
    if (r === "exotic") return Color.urgent
    if (r === "rare") return Color.accent
    if (r === "uncommon") return Qt.darker(root.fg, 1.15)
    return Qt.darker(root.fg, 1.7)          // common / unclassified
  }
  function shortDate(iso) {
    var d = new Date(iso)
    return isNaN(d.getTime()) ? "?" : Qt.formatDate(d, "d MMM")
  }

  Process {
    id: dexReader
    command: ["bash", "-c",
      'p=$1; n=$2; [ -f "$p" ] && [ ! -L "$p" ] || exit 0; exec timeout 5 head -c "$n" -- "$p"',
      "flyby", root.dexPath, String(root.maxDexBytes)]
    running: true
    stdout: StdioCollector { id: dexOut; waitForEnd: true }
    onExited: function (code) {
      var t = (code === 0) ? String(dexOut.text || "") : ""
      root.applyLoadedDex(t.length >= root.maxDexBytes ? "" : t)
    }
  }

  FileView {
    id: dexFile
    path: root.dexPath
    preload: false
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  onCfgChanged: Qt.callLater(root.refresh)   // range / provider / location edits
  onEditingLocationChanged: if (editingLocation) Qt.callLater(root.syncLocationFields)

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(332))
    contentHeight: panel.fittedContentHeight(col.implicitHeight + Style.space(36))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      // The Logbook grid and a long identity card can outgrow the panel's
      // clamped height, so the whole body scrolls.
      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + Style.space(36)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

      // L toggles Scope / Logbook; N cycles the selection through the
      // in-range contacts nearest-first (then clears).
      Keys.onPressed: function (e) {
        if (e.key === Qt.Key_L) {
          root.view = root.view === "dex" ? "scope" : "dex"
          e.accepted = true
        } else if (e.key === Qt.Key_N && root.view === "scope") {
          var list = root.aircraft
          if (!list.length) { root.selectedHex = ""; e.accepted = true; return }
          var idx = -1
          for (var i = 0; i < list.length; i++)
            if (list[i].hex === root.selectedHex) { idx = i; break }
          root.selectedHex = (idx + 1 < list.length) ? list[idx + 1].hex : ""
          e.accepted = true
        }
      }

      Column {
        id: col
        x: Style.space(18)
        y: Style.space(18)
        width: scroll.width - Style.space(36)
        spacing: Style.space(12)

        // ---- header
        Item {
          width: parent.width
          height: Math.max(titleText.implicitHeight, statusChip.height)

          Text {
            id: titleText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "✈  FLYBY"
            color: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Rectangle {
            id: statusChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipLabel.implicitWidth + Style.space(16)
            height: chipLabel.implicitHeight + Style.space(8)
            radius: Style.cornerRadius
            color: root.overhead ? Style.selectedFillFor(root.fg, Color.accent)
                                 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: !root.hasLocation ? "no location"
                  : root.overhead ? (root.overheadList.length + " overhead")
                  : root.count > 0 ? (root.count + " in range")
                  : "clear skies"
              color: root.overhead ? Color.accent : Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: root.overhead
            }
          }
        }

        // ---- Scope / Logbook view toggle
        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.hasLocation && !root.editingLocation

          Repeater {
            model: [
              { key: "scope", label: "◎  Scope" },
              { key: "dex",   label: "▤  Logbook  " + root.dexDiscoveredCount + " / " + root.dexUniverse }
            ]
            Rectangle {
              required property var modelData
              readonly property bool on: root.view === modelData.key
              width: vtLabel.implicitWidth + Style.space(16)
              height: vtLabel.implicitHeight + Style.space(9)
              radius: Style.cornerRadius
              color: on ? Style.selectedFillFor(root.fg, Color.accent)
                   : vtArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                   : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
              Text {
                id: vtLabel
                anchors.centerIn: parent
                text: modelData.label
                color: parent.on ? Color.accent : Qt.darker(root.fg, 1.35)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: parent.on
                textFormat: Text.PlainText
              }
              MouseArea {
                id: vtArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.view = modelData.key
              }
            }
          }
        }

        // ---- radar
        Radar {
          id: radar
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(268)
          height: Style.space(268)
          visible: root.hasLocation && !root.editingLocation && root.view === "scope"
          aircraft: root.aircraft
          maxKm: root.radiusKm
          units: root.units
          selectedHex: root.selectedHex
          foreground: root.fg
          accent: Color.accent
          altColor: root.altColor
          running: root.opened && root.view === "scope"
          onBlipClicked: function (hex) {
            root.selectedHex = (hex && hex === root.selectedHex) ? "" : hex
          }
        }

        // ---- location editor: shown when no location is set, or when the
        // user taps the "location" chip to fine-tune / re-enter it by hand.
        Column {
          id: locEditor
          width: parent.width
          spacing: Style.space(9)
          visible: !root.hasLocation || root.editingLocation

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.hasLocation
              ? "Enter your latitude and longitude in decimal degrees, or grab an approximate fix from your IP."
              : "Flyby needs to know where you are. Type your coordinates in decimal degrees, or grab an approximate fix from your IP."
            color: Qt.darker(root.fg, 1.4)
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: latField
              width: (parent.width - Style.space(8)) / 2
              placeholderText: "lat  29.4241"
              foreground: root.fg
              onAccepted: root.saveManualLocation()
            }
            TextField {
              id: lonField
              width: (parent.width - Style.space(8)) / 2
              placeholderText: "lon  -98.4936"
              foreground: root.fg
              onAccepted: root.saveManualLocation()
            }
          }

          Text {
            id: locErr
            property bool shown: false
            visible: shown
            width: parent.width
            wrapMode: Text.WordWrap
            text: "That doesn't look like a valid lat/lon. Latitude -90..90, longitude -180..180."
            color: Color.urgent
            font.family: root.ff
            font.pixelSize: Style.font.caption
          }

          Row {
            spacing: Style.space(8)

            Button {
              text: "Save"
              bordered: true
              foreground: root.fg
              onClicked: root.saveManualLocation()
            }
            Button {
              text: root.locating ? "Locating…" : "Locate me (approx)"
              bordered: true
              foreground: root.fg
              enabled: !root.locating
              onClicked: root.locateMe()
            }
            Button {
              visible: root.hasLocation
              text: "Cancel"
              foreground: Qt.darker(root.fg, 1.3)
              onClicked: { root.editingLocation = false; root.syncLocationFields() }
            }
          }
        }

        // ---- divider
        Rectangle {
          width: parent.width
          height: Style.spacing.hairline
          color: root.fg
          opacity: 0.12
          visible: root.hasLocation && !root.editingLocation
        }

        // ---- error line
        Text {
          width: parent.width
          visible: root.hasLocation && !root.editingLocation && root.view === "scope" && root.lastError !== ""
          text: root.lastError
          color: Color.urgent
          font.family: root.ff
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }

        // ---- clear-skies note
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          visible: root.hasLocation && !root.editingLocation && root.view === "scope" && root.lastError === "" && root.count === 0
          text: "Nothing within " + Model.fmtDist(root.radiusKm, root.units) + " right now."
          color: Qt.darker(root.fg, 1.5)
          font.family: root.ff
          font.pixelSize: Style.font.bodySmall
          font.italic: true
        }

        // ---- aircraft list (nearest 8; collapses to 3 while a card is open)
        Column {
          id: acList
          width: parent.width
          spacing: Style.space(2)
          visible: root.hasLocation && !root.editingLocation && root.view === "scope" && root.count > 0

          readonly property int shown: root.selAc ? 3 : 8

          Repeater {
            model: root.aircraft.slice(0, acList.shown)

            Rectangle {
              id: rowRect
              required property var modelData
              required property int index
              width: parent.width
              height: rowCol.implicitHeight + Style.space(10)
              radius: Style.cornerRadius
              readonly property bool isOverhead:
                  !modelData.onGround && modelData.distKm <= Model.OVERHEAD_KM
              readonly property bool selected: modelData.hex === root.selectedHex
              color: selected ? Style.selectedFillFor(root.fg, Color.accent)
                   : rowArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                   : "transparent"

              Rectangle {   // accent spine on overhead / selected
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Style.space(2)
                radius: width
                color: Color.accent
                visible: rowRect.isOverhead || rowRect.selected
              }

              Column {
                id: rowCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Row {
                  width: parent.width
                  Text {
                    width: parent.width - rightMeta.implicitWidth - Style.space(8)
                    elide: Text.ElideRight
                    text: (rowRect.isOverhead ? "▲ " : "") + modelData.callsign
                    color: rowRect.isOverhead ? Color.accent : root.fg
                    font.family: root.ff
                    font.pixelSize: Style.font.body
                    font.bold: rowRect.isOverhead || rowRect.selected
                    textFormat: Text.PlainText
                  }
                  Text {
                    id: rightMeta
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.fmtDist(modelData.distKm, root.units) + "  " + modelData.compass
                    color: Qt.darker(root.fg, 1.3)
                    font.family: root.ff
                    font.pixelSize: Style.font.bodySmall
                    textFormat: Text.PlainText
                  }
                }

                Text {
                  width: parent.width
                  elide: Text.ElideRight
                  text: Model.detailLine(modelData, root.units)
                  color: Qt.darker(root.fg, 1.55)
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  textFormat: Text.PlainText
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedHex =
                    (rowRect.modelData.hex === root.selectedHex) ? "" : rowRect.modelData.hex
              }
            }
          }

          Text {
            visible: root.count > acList.shown
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(4)
            text: "+ " + (root.count - acList.shown) + " more in range"
            color: Qt.darker(root.fg, 1.6)
            font.family: root.ff
            font.pixelSize: Style.font.caption
          }
        }

        // ---- identity card (scope view, when a contact is selected)
        Rectangle {
          width: parent.width
          visible: root.view === "scope" && !root.editingLocation && root.selAc !== null
          radius: Style.cornerRadius
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
          clip: true
          implicitHeight: idCard.implicitHeight + Style.space(20)

          Column {
            id: idCard
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(4)

            readonly property var a: root.selAc || ({})
            readonly property var info: (a.id && a.id.specs) ? a.id.specs : null
            readonly property var dexEntry:
                (a.id && a.id.typeCode && root.dex.types) ? root.dex.types[a.id.typeCode] : null
            readonly property var enr: root.selEnrich
            readonly property var prog: (enr && enr.route)
              ? Model.routeProgress(enr.route, a.lat, a.lon, a.gsKt) : null

            Row {
              width: parent.width
              spacing: Style.space(6)
              Text {
                width: parent.width - rarBadge.width - Style.space(6)
                text: idCard.a.id ? idCard.a.id.typeName : "—"
                color: root.fg
                font.family: root.ff
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
              Rectangle {
                id: rarBadge
                anchors.verticalCenter: parent.verticalCenter
                visible: !!(idCard.a.id && idCard.a.id.known)
                width: visible ? rbl.implicitWidth + Style.space(10) : 0
                height: rbl.implicitHeight + Style.space(4)
                radius: Style.cornerRadius
                readonly property color rc: root.rarityColor(idCard.a.id ? idCard.a.id.rarity : "")
                color: Qt.rgba(rc.r, rc.g, rc.b, 0.18)
                Text {
                  id: rbl
                  anchors.centerIn: parent
                  text: idCard.a.id ? idCard.a.id.rarity : ""
                  color: rarBadge.rc
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  textFormat: Text.PlainText
                }
              }
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: idCard.a.id ? idCard.a.id.operatorDisplay : ""
              color: Qt.darker(root.fg, 1.3)
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Text {
              visible: idCard.a.unusual === true
              width: parent.width
              wrapMode: Text.WordWrap
              text: "⚠  unusual — " + (idCard.a.id ? idCard.a.id.unusualWhy : "")
              color: Color.urgent
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: idCard.info
                ? Model.specSummary(idCard.info)
                : ("No spec sheet for this type yet — logged as " + (idCard.a.type || "unknown") + ".")
              color: Qt.darker(root.fg, 1.5)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: {
                var a = idCard.a, parts = []
                if (a.reg) parts.push("reg " + a.reg)
                if (a.squawk) parts.push("squawk " + a.squawk)
                parts.push(Model.fmtAlt(a.altFt, a.onGround))
                if (typeof a.distKm === "number" && isFinite(a.distKm))
                  parts.push(Model.fmtDist(a.distKm, root.units) + " " + (a.compass || ""))
                return parts.join("  ·  ")
              }
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              visible: text !== ""
              text: idCard.dexEntry
                ? ("✦ in your logbook · seen " + idCard.dexEntry.n + "× · first "
                   + root.shortDate(idCard.dexEntry.first))
                : (idCard.a.id && idCard.a.id.known ? "not in your logbook yet" : "")
              color: idCard.dexEntry ? Color.accent : Qt.darker(root.fg, 1.6)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }

            // ---- Phase B: route / owner / photo, once the lookup returns
            Rectangle {
              width: parent.width
              height: Style.spacing.hairline
              color: root.fg
              opacity: 0.12
              visible: root.routeLookup && (root.enriching || idCard.enr !== null)
            }

            Text {
              visible: root.enriching && idCard.enr === null
              text: "looking up route…"
              color: Qt.darker(root.fg, 1.6)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.italic: true
              textFormat: Text.PlainText
            }

            // route: SFO → EWR + place names
            Text {
              visible: !!(idCard.enr && idCard.enr.route)
              width: parent.width
              wrapMode: Text.WordWrap
              text: idCard.enr && idCard.enr.route
                ? (idCard.enr.route.oIata + "  →  " + idCard.enr.route.dIata
                   + "   " + idCard.enr.route.oName + " → " + idCard.enr.route.dName)
                : ""
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.bodySmall
              textFormat: Text.PlainText
            }

            // progress bar + phase / ETA (only when the aircraft is plausibly
            // on this route — see routeProgress `reliable`)
            Column {
              visible: idCard.prog !== null && idCard.prog.reliable
              width: parent.width
              spacing: Style.space(3)
              Rectangle {
                width: parent.width
                height: Style.space(5)
                radius: height / 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
                Rectangle {
                  height: parent.height
                  radius: height / 2
                  color: Color.accent
                  width: Math.max(height, parent.width * (idCard.prog ? idCard.prog.frac : 0))
                }
              }
              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                  if (!idCard.prog) return ""
                  var pct = Math.round(idCard.prog.frac * 100)
                  var eta = Model.fmtEta(idCard.prog.etaMin)
                  var lbl = idCard.prog.phase === "departed" ? "just departed"
                          : idCard.prog.phase === "arriving" ? "arriving"
                          : pct + "% of the way"
                  return lbl + (eta ? "  ·  " + eta + " to landing" : "")
                }
                color: Qt.darker(root.fg, 1.4)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }
            }

            // registered owner (great for GA — whose plane is that)
            Text {
              visible: !!(idCard.enr && idCard.enr.owner)
              width: parent.width
              text: idCard.enr ? ("operated by " + idCard.enr.owner
                   + (idCard.enr.ownerCountry ? " · " + idCard.enr.ownerCountry : "")) : ""
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            // photo of the airframe — opt-in (loads a remote image), and only
            // ever from a host-checked airport-data.com / plnspttrs.net URL.
            Text {
              visible: !root.showPhotos && !!(idCard.enr && idCard.enr.photoThumb)
              width: parent.width
              text: "＋ show airframe photo"
              color: Color.accent
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.put("showPhotos", true)
              }
            }
            Text {
              visible: root.showPhotos && flybyPhoto.status === Image.Loading
              text: "loading photo…"
              color: Qt.darker(root.fg, 1.6)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.italic: true
              textFormat: Text.PlainText
            }
            Image {
              id: flybyPhoto
              visible: root.showPhotos && status === Image.Ready
              width: parent.width
              fillMode: Image.PreserveAspectFit
              sourceSize.width: Math.round(parent.width)
              asynchronous: true
              cache: true
              source: (root.showPhotos && idCard.enr && idCard.enr.photoThumb)
                      ? idCard.enr.photoThumb : ""
            }
            Text {
              visible: root.showPhotos && flybyPhoto.status === Image.Ready
              width: parent.width
              wrapMode: Text.WordWrap
              readonly property bool hasLink: !!(idCard.enr && idCard.enr.photoLink)
              text: (idCard.enr && idCard.enr.photoBy ? "photo © " + idCard.enr.photoBy + "  ·  " : "photo · ")
                  + (idCard.enr && idCard.enr.photoSource ? idCard.enr.photoSource : "")
                  + (hasLink ? "  ·  tap to open" : "  ·  tap to hide")
              color: Qt.darker(root.fg, 1.9)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.hasLink ? root.openPhotoLink(idCard.enr.photoLink)
                                          : root.put("showPhotos", false)
              }
            }
          }
        }

        // ---- Logbook (Dex) view
        Column {
          width: parent.width
          spacing: Style.space(9)
          visible: root.view === "dex" && !root.editingLocation

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.dexDiscoveredCount + " / " + root.dexUniverse + " types  ·  score "
                + root.dexScore
                + (root.dexRareCount > 0 ? "  ·  " + root.dexRareCount + " rare" : "")
                + (root.dexExoticCount > 0 ? "  ·  " + root.dexExoticCount + " exotic" : "")
            color: Qt.darker(root.fg, 1.2)
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }

          Rectangle {
            width: parent.width
            height: Style.space(6)
            radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
            Rectangle {
              height: parent.height
              radius: height / 2
              color: Color.accent
              width: Math.max(height, parent.width * (root.dexUniverse > 0
                     ? root.dexDiscoveredCount / root.dexUniverse : 0))
            }
          }

          Text {
            visible: root.dexToday.sightings > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "today — " + root.dexToday.types + " types · " + root.dexToday.sightings
                + " seen" + (root.dexToday.fresh > 0 ? " · " + root.dexToday.fresh + " new" : "")
            color: Qt.darker(root.fg, 1.45)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          Text {
            visible: root.dexDiscoveredCount === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Nothing logged yet. Leave Flyby running — every aircraft type that "
                + "crosses your range gets added here, and a new one raises a note."
            color: Qt.darker(root.fg, 1.5)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.italic: true
          }

          // ---- achievements (collapsible)
          Column {
            width: parent.width
            spacing: Style.space(5)
            visible: root.dexDiscoveredCount > 0

            Text {
              width: parent.width
              text: "🏅 achievements  " + root.achievementsUnlocked + " / " + Model.achievementTotal()
                  + (root.dexShowAchievements ? "  ▾" : "  ▸")
              color: Qt.darker(root.fg, 1.3)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dexShowAchievements = !root.dexShowAchievements
              }
            }

            Flow {
              width: parent.width
              spacing: Style.space(5)
              visible: root.dexShowAchievements
              Repeater {
                model: Model.achievementList()
                Rectangle {
                  required property var modelData
                  readonly property bool got: !!(root.dex.achievements
                                                 && root.dex.achievements[modelData.id])
                  width: achL.implicitWidth + Style.space(12)
                  height: achL.implicitHeight + Style.space(6)
                  radius: Style.cornerRadius
                  color: got ? Style.selectedFillFor(root.fg, Color.accent)
                             : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                  Text {
                    id: achL
                    anchors.centerIn: parent
                    text: (parent.got ? "🏅 " : "🔒 ") + modelData.label
                    color: parent.got ? Color.accent : Qt.darker(root.fg, 1.9)
                    font.family: root.ff
                    font.pixelSize: Style.font.caption
                    textFormat: Text.PlainText
                  }
                }
              }
            }
          }

          // ---- still-to-find nudge
          Text {
            visible: root.dexDiscoveredCount > 0 && root.missingCommons.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "still to find (common): " + root.missingCommons.join("  ·  ")
            color: Qt.darker(root.fg, 1.6)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }
          Text {
            visible: root.dexDiscoveredCount > 0 && root.missingCommons.length === 0
            width: parent.width
            text: "every common type logged 🎉"
            color: Color.accent
            font.family: root.ff
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          // ---- grid filter chips
          Flow {
            width: parent.width
            spacing: Style.space(5)
            visible: root.dexDiscoveredCount > 0
            Repeater {
              model: [
                { k: "all",        l: "all" },
                { k: "airliner",   l: "airliners" },
                { k: "light",      l: "GA / biz" },
                { k: "rotor",      l: "rotor" },
                { k: "milvintage", l: "mil / vintage" }
              ]
              Rectangle {
                required property var modelData
                readonly property bool on: root.dexFilter === modelData.k
                width: fl.implicitWidth + Style.space(14)
                height: fl.implicitHeight + Style.space(7)
                radius: Style.cornerRadius
                color: on ? Style.selectedFillFor(root.fg, Color.accent)
                     : flArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                     : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                Text {
                  id: fl
                  anchors.centerIn: parent
                  text: modelData.l
                  color: parent.on ? Color.accent : Qt.darker(root.fg, 1.4)
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: parent.on
                  textFormat: Text.PlainText
                }
                MouseArea {
                  id: flArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.dexFilter = modelData.k; root.dexSelectedCode = "" }
                }
              }
            }
          }
          Text {
            visible: root.dexDiscoveredCount > 0 && root.dexFilter !== "all"
            width: parent.width
            text: root.dexFilterGot + " / " + root.dexGridModel.length + " in this group"
            color: Qt.darker(root.fg, 1.7)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          // spec card for a tapped Logbook entry
          Rectangle {
            width: parent.width
            visible: root.dexSelectedCode !== "" && Data.typeInfo(root.dexSelectedCode) !== null
            onVisibleChanged: if (visible) root.maybeDexPhoto()
            radius: Style.cornerRadius
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            clip: true
            implicitHeight: dexCard.implicitHeight + Style.space(20)
            Column {
              id: dexCard
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(12)
              spacing: Style.space(3)
              readonly property var info: Data.typeInfo(root.dexSelectedCode)
              readonly property var e: root.dex.types ? root.dex.types[root.dexSelectedCode] : null
              // photo pinned from an airframe of this type we've looked up,
              // re-checked against the host allowlist on the way out of the file
              readonly property string photo: Model.safePhotoUrl(e ? e.photo : "")
              // is a photo lookup even possible for this entry?
              readonly property bool canLookup:
                  !!(e && !e.photoNone && (e.hex || root._logHexFor(root.dexSelectedCode)))
              readonly property bool looking:
                  root._dexPhotoLoading && root._dexPhotoCode === root.dexSelectedCode
              Text {
                width: parent.width
                text: dexCard.info ? dexCard.info.n : ""
                color: root.fg
                font.bold: true
                font.family: root.ff
                font.pixelSize: Style.font.subtitle
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: dexCard.info ? Model.specSummary(dexCard.info) : ""
                color: Qt.darker(root.fg, 1.5)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }
              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: dexCard.e !== null && dexCard.e !== undefined
                text: dexCard.e
                  ? ("✦ seen " + dexCard.e.n + "× · first " + root.shortDate(dexCard.e.first)
                     + " · last " + root.shortDate(dexCard.e.last))
                  : ""
                color: Color.accent
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }

              // airframe photo — same opt-in as the identity card. Tapping a
              // Logbook entry looks one up on the spot if none is pinned yet.
              Text {
                visible: !root.showPhotos && (dexCard.photo !== "" || dexCard.canLookup)
                width: parent.width
                text: "＋ show airframe photo"
                color: Color.accent
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.put("showPhotos", true)
                }
              }
              Text {
                visible: root.showPhotos && dexCard.photo === ""
                        && (dexCard.looking || dexPhoto.status === Image.Loading)
                text: "looking up a photo…"
                color: Qt.darker(root.fg, 1.6)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.italic: true
                textFormat: Text.PlainText
              }
              Text {
                visible: root.showPhotos && dexCard.photo === "" && !dexCard.looking
                        && !!(dexCard.e && dexCard.e.photoNone)
                width: parent.width
                text: "no photo on file for this airframe"
                color: Qt.darker(root.fg, 1.8)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.italic: true
                textFormat: Text.PlainText
              }
              Image {
                id: dexPhoto
                visible: root.showPhotos && status === Image.Ready
                width: parent.width
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.round(parent.width)
                asynchronous: true
                cache: true
                source: root.showPhotos ? dexCard.photo : ""
              }
              Text {
                visible: root.showPhotos && dexPhoto.status === Image.Ready
                width: parent.width
                wrapMode: Text.WordWrap
                readonly property bool hasLink: Model.safePageUrl(dexCard.e ? dexCard.e.photoLink : "") !== ""
                text: (dexCard.e && dexCard.e.photoReg ? dexCard.e.photoReg + "  ·  " : "")
                      + (dexCard.e && dexCard.e.photoBy ? "© " + dexCard.e.photoBy + "  ·  " : "")
                      + (dexCard.e && dexCard.e.photoSource ? dexCard.e.photoSource : "photo")
                      + (hasLink ? "  ·  tap to open" : "  ·  tap to hide")
                color: Qt.darker(root.fg, 1.9)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: parent.hasLink ? root.openPhotoLink(dexCard.e.photoLink)
                                            : root.put("showPhotos", false)
                }
              }
            }
          }

          // the grid — discovered first, then a capped run of blanks to fill
          Flow {
            width: parent.width
            spacing: Style.space(5)

            Repeater {
              model: root.dexGridModel.slice(0, root.dexFilterGot + 24)
              Rectangle {
                required property var modelData
                readonly property var info: Data.typeInfo(modelData)
                readonly property var e: root.dex.types ? root.dex.types[modelData] : null
                readonly property bool got: e !== null && e !== undefined
                width: cellRow.implicitWidth + Style.space(14)
                height: cellRow.implicitHeight + Style.space(8)
                radius: Style.cornerRadius
                color: root.dexSelectedCode === modelData
                       ? Style.selectedFillFor(root.fg, Color.accent)
                     : (cellArea.containsMouse && got)
                       ? Style.hoverFillFor(root.fg, Color.accent)
                     : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, got ? 0.07 : 0.03)
                Row {
                  id: cellRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.parent.got
                    width: Style.space(4)
                    height: Style.space(4)
                    radius: width / 2
                    color: root.rarityColor(parent.parent.info ? parent.parent.info.r : "")
                  }
                  Text {
                    text: parent.parent.got
                          ? (parent.parent.info ? parent.parent.info.s : modelData)
                          : "???"
                    color: parent.parent.got ? root.fg : Qt.darker(root.fg, 2.2)
                    font.family: root.ff
                    font.pixelSize: Style.font.caption
                    font.bold: parent.parent.got
                    textFormat: Text.PlainText
                  }
                  Text {
                    visible: parent.parent.got && parent.parent.e && parent.parent.e.n > 1
                    text: "×" + (parent.parent.e ? parent.parent.e.n : "")
                    color: Qt.darker(root.fg, 1.5)
                    font.family: root.ff
                    font.pixelSize: Style.font.caption
                  }
                }
                MouseArea {
                  id: cellArea
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: parent.got
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.dexSelectedCode =
                      (root.dexSelectedCode === parent.modelData) ? "" : parent.modelData
                }
              }
            }
          }

          Text {
            visible: root.dexGridModel.length > root.dexFilterGot + 24
            width: parent.width
            text: "＋ " + (root.dexGridModel.length - root.dexFilterGot - 24)
                + " more types out there to spot"
            color: Qt.darker(root.fg, 1.7)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          Row {
            visible: root.dexDiscoveredCount > 0
            width: parent.width
            spacing: Style.space(8)
            topPadding: Style.space(2)

            Rectangle {
              width: csLabel.implicitWidth + Style.space(16)
              height: csLabel.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: root.summaryCopied ? Style.selectedFillFor(root.fg, Color.accent)
                   : csArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                   : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
              Text {
                id: csLabel
                anchors.centerIn: parent
                text: root.summaryCopied ? "copied ✓" : "📋 copy summary"
                color: root.summaryCopied ? Color.accent : Qt.darker(root.fg, 1.3)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }
              MouseArea {
                id: csArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copySummary()
              }
            }

            Rectangle {
              width: clLabel.implicitWidth + Style.space(16)
              height: clLabel.implicitHeight + Style.space(8)
              radius: Style.cornerRadius
              color: clArea.containsMouse ? Style.hoverFillFor(root.fg, Color.urgent)
                                          : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
              Text {
                id: clLabel
                anchors.centerIn: parent
                text: "clear logbook"
                color: Qt.darker(root.fg, 1.7)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }
              MouseArea {
                id: clArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.forgetDex()
              }
            }
          }
        }

        // ---- footer: location + range chips + units + bell + ground + provider
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.hasLocation && !root.editingLocation

          // location chip — tap to re-enter / fine-tune coordinates by hand
          Rectangle {
            width: locChipLabel.implicitWidth + Style.space(14)
            height: locChipLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: locChipArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                                             : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: locChipLabel
              anchors.centerIn: parent
              // Coarse (2 dp, ~1 km) on purpose — this is a "tap to edit" label,
              // not a readout, and it keeps a screenshot from pinning your house.
              text: "📍 " + (isFinite(root.originLat) ? root.originLat.toFixed(2) : "?")
                  + ", " + (isFinite(root.originLon) ? root.originLon.toFixed(2) : "?")
              color: Qt.darker(root.fg, 1.3)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
            MouseArea {
              id: locChipArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.editingLocation = true; root.syncLocationFields() }
            }
          }

          Repeater {
            model: ["5", "10", "25", "50", "100"]
            Rectangle {
              required property var modelData
              readonly property bool on: String(root.radiusNm) === modelData
              width: chLabel.implicitWidth + Style.space(14)
              height: chLabel.implicitHeight + Style.space(7)
              radius: Style.cornerRadius
              color: on ? Style.selectedFillFor(root.fg, Color.accent)
                   : chArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                   : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
              Text {
                id: chLabel
                anchors.centerIn: parent
                text: modelData + "nm"
                color: parent.on ? Color.accent : Qt.darker(root.fg, 1.4)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: parent.on
              }
              MouseArea {
                id: chArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.put("radiusNm", modelData)
              }
            }
          }

          // units cycle
          Rectangle {
            width: uLabel.implicitWidth + Style.space(14)
            height: uLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: uArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                                       : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: uLabel
              anchors.centerIn: parent
              text: root.units
              color: Qt.darker(root.fg, 1.3)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              id: uArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("units", root.units === "km" ? "mi"
                                          : root.units === "mi" ? "nm" : "km")
            }
          }

          // overhead-notify toggle
          Rectangle {
            width: bLabel.implicitWidth + Style.space(14)
            height: bLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: root.notifyOverhead ? Style.selectedFillFor(root.fg, Color.accent)
                 : bArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: bLabel
              anchors.centerIn: parent
              text: root.notifyOverhead ? "🔔 on" : "🔕 off"
              color: root.notifyOverhead ? Color.accent : Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              id: bArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("notifyOverhead", !root.notifyOverhead)
            }
          }

          // ground-traffic toggle
          Rectangle {
            width: gLabel.implicitWidth + Style.space(14)
            height: gLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: root.showGround ? Style.selectedFillFor(root.fg, Color.accent)
                 : gArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: gLabel
              anchors.centerIn: parent
              text: root.showGround ? "🛬 ground" : "✈ air only"
              color: root.showGround ? Color.accent : Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              id: gArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("showGround", !root.showGround)
            }
          }

          // provider cycle
          Rectangle {
            width: pLabel.implicitWidth + Style.space(14)
            height: pLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: pArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                                       : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: pLabel
              anchors.centerIn: parent
              text: root.provider
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              id: pArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("provider", root.provider === "adsb.lol" ? "adsb.fi" : "adsb.lol")
            }
          }

          // altitude-colour toggle
          Rectangle {
            width: acLabel.implicitWidth + Style.space(14)
            height: acLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: root.altColor ? Style.selectedFillFor(root.fg, Color.accent)
                 : acArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: acLabel
              anchors.centerIn: parent
              text: root.altColor ? "◐ alt colour" : "○ flat colour"
              color: root.altColor ? Color.accent : Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
            MouseArea {
              id: acArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("altColor", !root.altColor)
            }
          }

          // readable-pill toggle
          Rectangle {
            width: rpLabel.implicitWidth + Style.space(14)
            height: rpLabel.implicitHeight + Style.space(7)
            radius: Style.cornerRadius
            color: root.readablePill ? Style.selectedFillFor(root.fg, Color.accent)
                 : rpArea.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
                 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            Text {
              id: rpLabel
              anchors.centerIn: parent
              text: root.readablePill ? "pill: type" : "pill: callsign"
              color: root.readablePill ? Color.accent : Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
            MouseArea {
              id: rpArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.put("readablePill", !root.readablePill)
            }
          }
        }
      }
      }
    }
  }
}
