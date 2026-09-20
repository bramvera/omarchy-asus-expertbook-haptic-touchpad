// Pure helpers shared by Service.qml and the unit tests. No QML here.

// The controller lives next to the widget. Quickshell resolves it to a
// file:// URL; the process API needs a plain path.
function controllerPath(resolvedUrl) {
  return decodeURIComponent(String(resolvedUrl).replace(/^file:\/\//, ""))
}

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

function statusCommand(controller) {
  return [controller, "--status", "--json"]
}

// Re-send the saved values when the shell starts. The touchpad forgets them
// when powered off. A no-op until the user has saved something.
function restoreCommand(controller) {
  return [controller, "--restore", "--wait", "3", "--json"]
}

function applyCommand(controller, clickForce, hapticIntensity) {
  var force = Number(clickForce)
  var intensity = Number(hapticIntensity)
  if (!validForce(force))
    return { ok: false, error: "Click force must be 1, 2, or 3" }
  if (!validIntensity(intensity))
    return { ok: false, error: "Haptic intensity must be between 0 and 100" }

  return {
    ok: true,
    command: [
      controller, "--save",
      "--click-force", String(force),
      "--haptic-intensity", String(intensity),
      "--json"
    ]
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    applyCommand: applyCommand,
    concise: concise,
    controllerPath: controllerPath,
    forceName: forceName,
    parseStatus: parseStatus,
    restoreCommand: restoreCommand,
    statusCommand: statusCommand
  }
}
