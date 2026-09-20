const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const CONTROLLER = "/home/me/.config/omarchy/plugins/io.github.bramvera.haptic-touchpad/controller/asus-b9406-hapticctl"

test("resolves the controller next to the widget", () => {
  assert.equal(Model.controllerPath("file://" + CONTROLLER), CONTROLLER)
  assert.equal(
    Model.controllerPath("file:///home/a%20b/plugins/x/controller/asus-b9406-hapticctl"),
    "/home/a b/plugins/x/controller/asus-b9406-hapticctl"
  )
})

test("parses a valid controller status", () => {
  const result = Model.parseStatus(JSON.stringify({
    schemaVersion: 1,
    ok: true,
    device: "/dev/hidraw11",
    clickForce: 3,
    hapticIntensity: 100,
    applied: false,
    saved: false
  }))
  assert.equal(result.ok, true)
  assert.equal(result.status.clickForce, 3)
  assert.equal(result.status.hapticIntensity, 100)
  assert.equal(Model.forceName(result.status.clickForce), "Firm")
})

test("accepts an unset intensity as null", () => {
  const result = Model.parseStatus(JSON.stringify({
    schemaVersion: 1,
    ok: true,
    clickForce: 2,
    hapticIntensity: null
  }))
  assert.equal(result.ok, true)
  assert.equal(result.status.hapticIntensity, null)
})

test("rejects malformed and out-of-range status", () => {
  assert.equal(Model.parseStatus("nope").ok, false)
  assert.equal(Model.parseStatus(JSON.stringify({ schemaVersion: 2, ok: true })).ok, false)
  assert.equal(Model.parseStatus(JSON.stringify({
    schemaVersion: 1,
    ok: true,
    clickForce: 4,
    hapticIntensity: 100
  })).ok, false)
})

test("builds argument-array commands with no privilege wrapper", () => {
  assert.deepEqual(Model.statusCommand(CONTROLLER), [CONTROLLER, "--status", "--json"])
  assert.deepEqual(Model.restoreCommand(CONTROLLER), [CONTROLLER, "--restore", "--wait", "3", "--json"])
  assert.deepEqual(Model.applyCommand(CONTROLLER, 3, 85), {
    ok: true,
    command: [
      CONTROLLER, "--save",
      "--click-force", "3",
      "--haptic-intensity", "85",
      "--json"
    ]
  })
  for (const command of [Model.statusCommand(CONTROLLER), Model.restoreCommand(CONTROLLER), Model.applyCommand(CONTROLLER, 1, 0).command])
    assert.ok(!command.some(arg => /^(sudo|pkexec)$/.test(arg)), "no privilege wrapper in " + command.join(" "))
})

test("rejects invalid settings", () => {
  assert.equal(Model.applyCommand(CONTROLLER, 0, 100).ok, false)
  assert.equal(Model.applyCommand(CONTROLLER, 3, 101).ok, false)
  assert.equal(Model.applyCommand(CONTROLLER, 2.5, 50).ok, false)
})
