import QtQuick
import qs.Commons
import qs.Ui

// Bar pill for the Flyby radar. Left click opens the scope popup; middle
// click forces a refresh. The pill shows the count of aircraft in range, or
// the closest callsign (with a pulsing dot) when something is overhead.
BarWidget {
  id: root
  moduleName: "bert.flyby"

  function injectPanel() {
    var t = panelLoader.item
    if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("settings" in t) t.settings = root.settings
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
    if ("widget" in t) t.widget = root
  }

  // Persist one changed key into shell.json, same mechanism the first-party
  // bar widgets use for their settings.
  function setKey(key, value) {
    var entry = { id: root.moduleName }
    var s = root.settings || {}
    for (var k in s) if (k !== "id") entry[k] = s[k]
    entry[key] = value
    root.settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }
  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  readonly property bool overhead: panelLoader.item ? panelLoader.item.overhead === true : false
  readonly property int contactCount: panelLoader.item ? (panelLoader.item.count || 0) : 0
  readonly property bool hasLocation: panelLoader.item ? panelLoader.item.hasLocation === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.label : "✈"
    horizontalMargin: 8.75
    active: root.overhead
    dimmed: !root.hasLocation
    tooltipText: !root.hasLocation ? "Flyby — set your location"
               : root.overhead ? "Flyby — aircraft passing over you"
               : root.contactCount + " aircraft in range"

    onPressed: function (b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Rectangle {
      visible: root.overhead
      width: Style.space(6)
      height: Style.space(6)
      radius: width / 2
      color: Color.accent
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.space(4)
      anchors.rightMargin: Style.space(3)

      SequentialAnimation on opacity {
        running: root.overhead
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
      }
    }
  }
}
