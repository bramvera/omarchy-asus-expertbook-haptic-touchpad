function forceName(value) {
  var names = { 1: "Light", 2: "Medium", 3: "Firm" }
  return names[Number(value)] || "Unknown"
}

function concise(value, fallback) {
  var text = String(value || "").replace(/\s+/g, " ").trim() || fallback
  return text.length > 180 ? text.substring(0, 177) + "…" : text
}

function validControllerPath(value) {
  return typeof value === "string" && value === "/usr/local/bin/asus-b9406-hapticctl"
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
  if (!Number.isInteger(force) || force < 1 || force > 3)
    return { ok: false, error: "The controller returned an invalid click force" }

  var intensity = payload.hapticIntensity
  if (intensity !== null) {
    intensity = Number(intensity)
    if (!Number.isInteger(intensity) || intensity < 0 || intensity > 100)
      return { ok: false, error: "The controller returned an invalid haptic intensity" }
  }

  if (typeof payload.device !== "string" || payload.device.length === 0)
    return { ok: false, error: "The controller did not identify the touchpad" }

  return {
    ok: true,
    status: {
      device: payload.device,
      clickForce: force,
      clickForceName: forceName(force),
      hapticIntensity: intensity,
      readbackAvailable: payload.readbackAvailable === true,
      applied: payload.applied === true,
      saved: payload.saved === true
    }
  }
}

function statusPlan(controllerPath) {
  if (!validControllerPath(controllerPath))
    return { ok: false, error: "The touchpad controller path is not trusted" }
  return { ok: true, command: [controllerPath, "--status", "--json"] }
}

function applyPlan(controllerPath, clickForce, hapticIntensity) {
  var force = Number(clickForce)
  var intensity = Number(hapticIntensity)
  if (!validControllerPath(controllerPath))
    return { ok: false, error: "The touchpad controller path is not trusted" }
  if (!Number.isInteger(force) || force < 1 || force > 3)
    return { ok: false, error: "Click force must be 1, 2, or 3" }
  if (!Number.isInteger(intensity) || intensity < 0 || intensity > 100)
    return { ok: false, error: "Haptic intensity must be between 0 and 100" }

  return {
    ok: true,
    command: [
      "pkexec",
      controllerPath,
      "--save",
      "--click-force", String(force),
      "--haptic-intensity", String(intensity),
      "--json"
    ]
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    applyPlan: applyPlan,
    concise: concise,
    forceName: forceName,
    parseStatus: parseStatus,
    statusPlan: statusPlan
  }
}
