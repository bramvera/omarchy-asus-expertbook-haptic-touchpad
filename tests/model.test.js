const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const controller = "/usr/local/bin/asus-b9406-hapticctl"

test("parses a valid controller status", () => {
  const result = Model.parseStatus(JSON.stringify({
    schemaVersion: 1,
    ok: true,
    device: "/dev/hidraw11",
    clickForce: 3,
    clickForceName: "firm",
    hapticIntensity: 100,
    readbackAvailable: false,
    applied: false,
    saved: false
  }))
  assert.equal(result.ok, true)
  assert.equal(result.status.clickForce, 3)
  assert.equal(result.status.clickForceName, "Firm")
  assert.equal(result.status.hapticIntensity, 100)
})

test("accepts an unavailable intensity as null", () => {
  const result = Model.parseStatus(JSON.stringify({
    schemaVersion: 1,
    ok: true,
    device: "/dev/hidraw11",
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
    device: "/dev/hidraw11",
    clickForce: 4,
    hapticIntensity: 100
  })).ok, false)
})

test("builds exact argument-array commands", () => {
  assert.deepEqual(Model.statusPlan(controller), {
    ok: true,
    command: [controller, "--status", "--json"]
  })
  assert.deepEqual(Model.applyPlan(controller, 3, 85), {
    ok: true,
    command: [
      "pkexec", controller, "--save", "--click-force", "3",
      "--haptic-intensity", "85", "--json"
    ]
  })
})

test("rejects untrusted paths and invalid settings", () => {
  assert.equal(Model.statusPlan("/tmp/controller").ok, false)
  assert.equal(Model.applyPlan(controller + ";id", 3, 100).ok, false)
  assert.equal(Model.applyPlan(controller, 0, 100).ok, false)
  assert.equal(Model.applyPlan(controller, 3, 101).ok, false)
  assert.equal(Model.applyPlan(controller, 2.5, 50).ok, false)
})
