pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.bramvera.haptic-touchpad"
  ipcTarget: moduleName
  // manageIpc: false so this panel owns the single IpcHandler for its target
  // and can add refresh/status on top of the standard open/close methods.
  manageIpc: false

  // Values the user is editing. They only reach the controller on Apply.
  property int draftClickForce: 3
  property int draftIntensity: 100

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool dirty: !touchpad.intensityConfigured
    || draftClickForce !== touchpad.clickForce
    || draftIntensity !== touchpad.hapticIntensity

  function syncDrafts() {
    draftClickForce = touchpad.clickForce
    draftIntensity = touchpad.hapticIntensity
  }

  function apply() {
    if (touchpad.available && dirty) touchpad.apply(draftClickForce, draftIntensity)
  }

  function stepForce(delta) {
    draftClickForce = Math.max(1, Math.min(3, draftClickForce + delta))
  }

  function stepIntensity(delta) {
    draftIntensity = Math.max(0, Math.min(100, draftIntensity + delta))
  }

  onOpenedChanged: if (opened) touchpad.refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: touchpad
    onRefreshed: root.syncDrafts()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { touchpad.refresh(); return "ok" }
    function status(): string {
      return JSON.stringify({
        available: touchpad.available,
        clickForce: touchpad.clickForce,
        hapticIntensity: touchpad.intensityConfigured ? touchpad.hapticIntensity : null
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰝁"
    active: root.opened
    tooltipText: touchpad.available
      ? "Haptic touchpad · " + Model.forceName(touchpad.clickForce)
        + (touchpad.intensityConfigured ? " · " + touchpad.hapticIntensity + "%" : "")
      : "Haptic touchpad · not set up"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) touchpad.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.apply()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.stepForce(dx)
        else if (dy !== 0) root.stepIntensity(-dy * 5)
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: "Haptic Touchpad"
          meta: touchpad.available ? "Click force and feedback strength" : "Touchpad access not set up"
          detail: touchpad.busy ? "Working" : (touchpad.available ? "Ready" : "Unavailable")
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰝁"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !touchpad.busy
              onClicked: touchpad.refresh()
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "CLICK FORCE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Caption { text: "How hard you press before the touchpad clicks. Firm helps avoid accidental clicks." }

          ButtonGroup {
            options: [
              { value: "1", label: "Light" },
              { value: "2", label: "Medium" },
              { value: "3", label: "Firm" }
            ]
            value: String(root.draftClickForce)
            foreground: root.foreground
            fontFamily: root.fontFamily
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
              foreground: root.foreground
              fontFamily: root.fontFamily
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

          Caption {
            visible: touchpad.available && !touchpad.intensityConfigured
            text: "No intensity saved yet. Apply saves both settings and restores them when the shell starts."
          }
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: touchpad.lastError !== "" ? touchpad.lastError : touchpad.actionStatus
          color: touchpad.lastError !== "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Button {
          width: parent.width
          text: touchpad.busy ? "Applying…" : (root.dirty ? "Apply settings" : "Settings applied")
          iconText: root.dirty ? "󰄬" : ""
          bordered: true
          selected: root.dirty
          focusable: true
          enabled: touchpad.available && !touchpad.busy && root.dirty
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.apply()
        }

        Caption { text: "Settings are saved and restored when the shell starts." }
      }
    }
  }

  component Caption: Text {
    width: parent.width
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
