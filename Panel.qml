pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.bramvera.haptic-touchpad"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property int draftClickForce: 3
  property int draftIntensity: 100

  readonly property int clickForce: controller.clickForce
  readonly property int hapticIntensity: controller.hapticIntensity
  readonly property bool intensityConfigured: controller.intensityConfigured
  readonly property bool available: controller.available
  readonly property bool busy: controller.busy
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool dirty: !intensityConfigured
    || draftClickForce !== clickForce
    || draftIntensity !== hapticIntensity

  function syncDrafts() {
    draftClickForce = controller.clickForce
    draftIntensity = controller.hapticIntensity
  }

  function open() {
    controller.refresh()
    root.controller.show()
  }

  function close() { root.controller.hide() }
  function toggle() { opened ? close() : open() }
  function refresh() { controller.refresh() }
  function apply() {
    if (!controller.busy) controller.apply(draftClickForce, draftIntensity)
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  Service {
    id: controller
    onRefreshed: root.syncDrafts()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.apply()
      onTextKey: function(text) {
        if (text === "1" || text === "2" || text === "3") root.draftClickForce = Number(text)
        else if (text === "r" || text === "R") root.refresh()
        else if (text === "+" || text === "=") root.draftIntensity = Math.min(100, root.draftIntensity + 5)
        else if (text === "-") root.draftIntensity = Math.max(0, root.draftIntensity - 5)
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: "Haptic Touchpad"
          meta: controller.available
            ? "PIXART 093A:4F05 · " + controller.device
            : "PIXART 093A:4F05"
          detail: controller.busy ? "Working" : (controller.available ? "Ready" : "Unavailable")
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "TP"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }
          trailingControl: Component {
            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !controller.busy
              onClicked: root.refresh()
            }
          }
        }

        PanelSeparator { width: parent.width }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader { text: "CLICK FORCE" }

          Text {
            width: parent.width
            text: "Higher force reduces accidental clicks. This setting changes the pressure threshold that triggers the haptic click."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ButtonGroup {
            options: [
              { value: "1", label: "Light" },
              { value: "2", label: "Medium" },
              { value: "3", label: "Firm" }
            ]
            value: String(root.draftClickForce)
            foreground: root.foreground
            fontFamily: root.fontFamily
            focusable: true
            onChanged: function(value) { root.draftClickForce = Number(value) }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          RowLayout {
            width: parent.width

            PanelSectionHeader {
              Layout.fillWidth: true
              text: "HAPTIC INTENSITY"
            }

            Text {
              text: root.draftIntensity + "%"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 100
            step: 5
            integer: true
            tickCount: 5
            value: root.draftIntensity
            onMoved: function(value) { root.draftIntensity = Math.round(value / 5) * 5 }
            onReleased: function(value) { root.draftIntensity = Math.round(value / 5) * 5 }
          }

          Text {
            width: parent.width
            visible: controller.available && !controller.intensityConfigured
            text: "No intensity is saved yet. Applying will save the selected value and use it at startup."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Text {
          width: parent.width
          visible: controller.lastError !== "" || controller.actionStatus !== ""
          text: controller.lastError !== "" ? controller.lastError : controller.actionStatus
          color: controller.lastError !== "" ? (bar ? bar.urgent : Color.urgent) : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Button {
          width: parent.width
          text: controller.busy ? "Applying…" : (root.dirty ? "Apply settings" : "Settings applied")
          iconText: root.dirty ? "󰄬" : ""
          bordered: true
          selected: root.dirty
          focusable: true
          enabled: controller.available && !controller.busy && root.dirty
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.apply()
        }

        Text {
          width: parent.width
          text: "Apply asks for administrator approval, saves the settings for startup, and sends them to the touchpad. Firmware readback is unavailable, so confirmed values come from the saved configuration."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
