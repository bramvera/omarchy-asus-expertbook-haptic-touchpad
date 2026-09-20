import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Talks to the controller shipped in this plugin. Everything runs as the
// logged-in user: a udev rule grants the seat access to the touchpad's
// hidraw node, so no privilege is involved.
Item {
  id: root

  readonly property string controller: Model.controllerPath(Qt.resolvedUrl("controller/asus-b9406-hapticctl"))

  property int clickForce: 3
  property int hapticIntensity: 100
  property bool intensityConfigured: false
  property bool available: false
  property string lastError: ""
  property string actionStatus: ""
  readonly property bool busy: statusProcess.running || applyProcess.running || restoreProcess.running

  signal refreshed()

  function refresh() {
    if (busy) return
    statusProcess.running = true
  }

  function apply(force, intensity) {
    if (busy) return
    var plan = Model.applyCommand(controller, force, intensity)
    if (!plan.ok) {
      lastError = plan.error
      return
    }
    lastError = ""
    actionStatus = "Applying"
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

  // Shared by every process: a non-zero exit or bad JSON marks the
  // controller unavailable and surfaces the reason in the panel.
  function accept(exitCode, out, err, fallback) {
    if (exitCode !== 0) {
      available = false
      fail(Model.concise(err || out, fallback))
      return null
    }
    var parsed = Model.parseStatus(out)
    if (!parsed.ok) {
      available = false
      fail(parsed.error)
      return null
    }
    acceptStatus(parsed.status)
    return parsed.status
  }

  Process {
    id: statusProcess
    command: Model.statusCommand(root.controller)
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.accept(exitCode, statusOut.text, statusErr.text, "The touchpad controller is unavailable")
    }
  }

  Process {
    id: restoreProcess
    command: Model.restoreCommand(root.controller)
    stdout: StdioCollector { id: restoreOut; waitForEnd: true }
    stderr: StdioCollector { id: restoreErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.accept(exitCode, restoreOut.text, restoreErr.text, "The touchpad is not set up yet")
    }
  }

  Process {
    id: applyProcess
    stdout: StdioCollector { id: applyOut; waitForEnd: true }
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(exitCode) {
      var status = root.accept(exitCode, applyOut.text, applyErr.text, "The touchpad settings were not applied")
      if (status === null) return
      if (!status.applied || !status.saved) {
        root.fail("The controller did not confirm the saved settings")
        return
      }
      root.actionStatus = "Saved and applied"
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 2600
    onTriggered: root.actionStatus = ""
  }

  // Restoring also reports the current settings, so it doubles as the
  // first status read.
  Component.onCompleted: restoreProcess.running = true
}
