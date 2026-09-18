import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  readonly property string controllerPath: "/usr/local/bin/asus-b9406-hapticctl"
  property int clickForce: 3
  property int hapticIntensity: 100
  property bool intensityConfigured: false
  property string device: ""
  property bool readbackAvailable: false
  property bool available: false
  property bool refreshing: false
  property string lastError: ""
  property string actionStatus: ""
  readonly property bool busy: statusProcess.running || applyProcess.running

  property string _statusOutput: ""
  property string _statusError: ""
  property string _applyOutput: ""
  property string _applyError: ""

  signal refreshed()

  function refresh() {
    if (busy) return false
    var plan = Model.statusPlan(controllerPath)
    if (!plan.ok) {
      lastError = plan.error
      return false
    }
    _statusOutput = ""
    _statusError = ""
    refreshing = true
    statusProcess.command = plan.command
    statusProcess.running = true
    return true
  }

  function apply(clickForce, hapticIntensity) {
    if (busy) return false
    var plan = Model.applyPlan(controllerPath, clickForce, hapticIntensity)
    if (!plan.ok) {
      lastError = plan.error
      return false
    }
    _applyOutput = ""
    _applyError = ""
    lastError = ""
    actionStatus = "Waiting for administrator approval"
    applyProcess.command = plan.command
    applyProcess.running = true
    return true
  }

  function acceptStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed.ok) {
      lastError = parsed.error
      available = false
      return false
    }
    clickForce = parsed.status.clickForce
    if (parsed.status.hapticIntensity !== null) {
      hapticIntensity = parsed.status.hapticIntensity
      intensityConfigured = true
    } else {
      intensityConfigured = false
    }
    device = parsed.status.device
    readbackAvailable = parsed.status.readbackAvailable
    available = true
    lastError = ""
    refreshed()
    return true
  }

  Process {
    id: statusProcess
    command: []
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
      onStreamFinished: root._statusOutput = text
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
      onStreamFinished: root._statusError = text
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      if (exitCode !== 0) {
        root.available = false
        root.lastError = Model.concise(stderr || stdout, "The touchpad controller is unavailable")
        return
      }
      root.acceptStatus(stdout)
    }
  }

  Process {
    id: applyProcess
    command: []
    stdout: StdioCollector {
      id: applyStdout
      waitForEnd: true
      onStreamFinished: root._applyOutput = text
    }
    stderr: StdioCollector {
      id: applyStderr
      waitForEnd: true
      onStreamFinished: root._applyError = text
    }
    onExited: function(exitCode) {
      var stdout = String(applyStdout.text || root._applyOutput || "")
      var stderr = String(applyStderr.text || root._applyError || "")
      if (exitCode !== 0) {
        root.actionStatus = ""
        root.lastError = Model.concise(stderr || stdout, "The touchpad settings were not applied")
        return
      }
      var parsed = Model.parseStatus(stdout)
      if (!parsed.ok || !parsed.status.applied || !parsed.status.saved) {
        root.actionStatus = ""
        root.lastError = parsed.ok ? "The controller did not confirm the saved settings" : parsed.error
        return
      }
      root.clickForce = parsed.status.clickForce
      root.hapticIntensity = parsed.status.hapticIntensity
      root.intensityConfigured = parsed.status.hapticIntensity !== null
      root.device = parsed.status.device
      root.readbackAvailable = parsed.status.readbackAvailable
      root.available = true
      root.lastError = ""
      root.actionStatus = "Saved and applied"
      root.refreshed()
      statusTimer.restart()
    }
  }

  Timer {
    id: statusTimer
    interval: 2600
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Component.onCompleted: refresh()
}
