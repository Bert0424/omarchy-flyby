import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

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
  readonly property bool notifyOverhead: val("notifyOverhead", false) === true
                                      || val("notifyOverhead", false) === "true"
  readonly property bool showGround: val("showGround", false) === true
                                  || val("showGround", false) === "true"

  // ---- state ----------------------------------------------------------
  property var aircraft: []
  property var overheadList: []
  property string selectedHex: ""
  property string lastError: ""
  property bool locating: false
  property bool editingLocation: false
  property var _prevOverhead: ({})

  readonly property int count: aircraft.length
  readonly property bool overhead: overheadList.length > 0
  readonly property string label: Model.pillText(root.hasLocation, root.aircraft, root.overheadList)

  readonly property string userAgent: "omarchy-flyby/0.1 (Omarchy plugin; +https://omarchyplugins.com)"

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
    root.lastError = ""
    root.aircraft = list
    var ov = Model.overhead(list)
    root.overheadList = ov
    root.maybeNotify(ov)
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

  Timer { id: retryTimer; interval: 6000; onTriggered: root.refresh() }

  Timer {
    id: refreshTimer
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
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

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(18)
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

        // ---- radar
        Radar {
          id: radar
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(268)
          height: Style.space(268)
          visible: root.hasLocation && !root.editingLocation
          aircraft: root.aircraft
          maxKm: root.radiusKm
          units: root.units
          selectedHex: root.selectedHex
          foreground: root.fg
          accent: Color.accent
          running: root.opened
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
          visible: root.hasLocation && !root.editingLocation && root.lastError !== ""
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
          visible: root.hasLocation && !root.editingLocation && root.lastError === "" && root.count === 0
          text: "Nothing within " + Model.fmtDist(root.radiusKm, root.units) + " right now."
          color: Qt.darker(root.fg, 1.5)
          font.family: root.ff
          font.pixelSize: Style.font.bodySmall
          font.italic: true
        }

        // ---- aircraft list (nearest 8)
        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: root.hasLocation && !root.editingLocation && root.count > 0

          Repeater {
            model: root.aircraft.slice(0, 8)

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
            visible: root.count > 8
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(4)
            text: "+ " + (root.count - 8) + " more in range"
            color: Qt.darker(root.fg, 1.6)
            font.family: root.ff
            font.pixelSize: Style.font.caption
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
        }
      }
    }
  }
}
