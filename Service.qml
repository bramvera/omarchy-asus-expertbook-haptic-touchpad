import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Talks to the root-owned controller binary. Reading status needs no
// privilege; applying goes through pkexec so Polkit asks the user first.
Item {
  id: root

  property int clickForce: 3
  property int hapticIntensity: 100
  property bool intensityConfigured: false
  property bool available: false
  property string lastError: ""
  property string actionStatus: ""
  readonly property bool busy: statusProcess.running || applyProcess.running

  signal refreshed()

  function refresh() {
    if (busy) return
    statusProcess.running = true
  }

  function apply(force, intensity) {
    if (busy) return
    var plan = Model.applyCommand(force, intensity)
    if (!plan.ok) {
      lastError = plan.error
      return
    }
    lastError = ""
    actionStatus = "Waiting for administrator approval"
    applyProcess.command = plan.command
    applyProcess.running = true
  }

  function fail(message) {
    actionStatus = ""
    lastError = message
  }

  function acceptStatus(status) {
    clickForce = status.clickForce
    intensityConfigured = status.hapticIntensity !== null
    if (intensityConfigured) hapticIntensity = status.hapticIntensity
    available = true
    lastError = ""
    refreshed()
  }

  Process {
    id: statusProcess
    command: Model.statusCommand()
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.available = false
        root.fail(Model.concise(statusErr.text || statusOut.text, "The touchpad controller is unavailable"))
        return
      }
      var parsed = Model.parseStatus(statusOut.text)
      if (!parsed.ok) {
        root.available = false
        root.fail(parsed.error)
        return
      }
      root.acceptStatus(parsed.status)
    }
  }

  Process {
    id: applyProcess
    stdout: StdioCollector { id: applyOut; waitForEnd: true }
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.fail(Model.concise(applyErr.text || applyOut.text, "The touchpad settings were not applied"))
        return
      }
      var parsed = Model.parseStatus(applyOut.text)
      if (!parsed.ok) {
        root.fail(parsed.error)
        return
      }
      if (!parsed.status.applied || !parsed.status.saved) {
        root.fail("The controller did not confirm the saved settings")
        return
      }
      root.acceptStatus(parsed.status)
      root.actionStatus = "Saved and applied"
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 2600
    onTriggered: root.actionStatus = ""
  }

  Component.onCompleted: refresh()
}
