const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

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

test("builds argument-array commands", () => {
  assert.deepEqual(Model.statusCommand(), [Model.CONTROLLER, "--status", "--json"])
  assert.deepEqual(Model.applyCommand(3, 85), {
    ok: true,
    command: [
      "pkexec", Model.CONTROLLER, "--save",
      "--click-force", "3",
      "--haptic-intensity", "85",
      "--json"
    ]
  })
})

test("rejects invalid settings", () => {
  assert.equal(Model.applyCommand(0, 100).ok, false)
  assert.equal(Model.applyCommand(3, 101).ok, false)
  assert.equal(Model.applyCommand(2.5, 50).ok, false)
})
