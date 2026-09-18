import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.bramvera.haptic-touchpad"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property int clickForce: panelLoader.item ? panelLoader.item.clickForce : 3
  readonly property int hapticIntensity: panelLoader.item ? panelLoader.item.hapticIntensity : 100
  readonly property bool intensityConfigured: panelLoader.item ? panelLoader.item.intensityConfigured : false
  readonly property bool available: panelLoader.item ? panelLoader.item.available : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

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

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.broadcast("refresh") }
    function status(): string {
      return JSON.stringify({
        available: root.available,
        clickForce: root.clickForce,
        hapticIntensity: root.intensityConfigured ? root.hapticIntensity : null
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.available ? "TP " + root.clickForce : "TP ?"
    active: root.opened
    tooltipText: root.available
      ? "Haptic Touchpad · " + (["", "Light", "Medium", "Firm"][root.clickForce])
        + " · " + (root.intensityConfigured ? root.hapticIntensity + "%" : "intensity unchanged")
      : "Haptic Touchpad · controller unavailable"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }
}
