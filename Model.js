// Pure helpers shared by Service.qml and the unit tests. No QML here.

var CONTROLLER = "/usr/local/bin/asus-b9406-hapticctl"

function forceName(value) {
  var names = { 1: "Light", 2: "Medium", 3: "Firm" }
  return names[Number(value)] || "Unknown"
}

// Collapse process output to one short line for the panel status text.
function concise(value, fallback) {
  var text = String(value || "").replace(/\s+/g, " ").trim() || fallback
  return text.length > 180 ? text.substring(0, 177) + "…" : text
}

function validForce(value) {
  return Number.isInteger(value) && value >= 1 && value <= 3
}

function validIntensity(value) {
  return Number.isInteger(value) && value >= 0 && value <= 100
}

function parseStatus(raw) {
  var payload
  try {
    payload = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "The controller returned invalid JSON" }
  }

  if (!payload || payload.schemaVersion !== 1 || payload.ok !== true)
    return { ok: false, error: "The controller returned an unsupported status response" }

  var force = Number(payload.clickForce)
  if (!validForce(force))
    return { ok: false, error: "The controller returned an invalid click force" }

  var intensity = payload.hapticIntensity
  if (intensity !== null) {
    intensity = Number(intensity)
    if (!validIntensity(intensity))
      return { ok: false, error: "The controller returned an invalid haptic intensity" }
  }

  return {
    ok: true,
    status: {
      clickForce: force,
      hapticIntensity: intensity,
      applied: payload.applied === true,
      saved: payload.saved === true
    }
  }
}

function statusCommand() {
  return [CONTROLLER, "--status", "--json"]
}

function applyCommand(clickForce, hapticIntensity) {
  var force = Number(clickForce)
  var intensity = Number(hapticIntensity)
  if (!validForce(force))
    return { ok: false, error: "Click force must be 1, 2, or 3" }
  if (!validIntensity(intensity))
    return { ok: false, error: "Haptic intensity must be between 0 and 100" }

  return {
    ok: true,
    command: [
      "pkexec", CONTROLLER, "--save",
      "--click-force", String(force),
      "--haptic-intensity", String(intensity),
      "--json"
    ]
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    CONTROLLER: CONTROLLER,
    applyCommand: applyCommand,
    concise: concise,
    forceName: forceName,
    parseStatus: parseStatus,
    statusCommand: statusCommand
  }
}
