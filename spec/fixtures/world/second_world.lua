-- spec/world_spec.lua runs this file after first_world.lua, in a busted of their own: it starts from a world of its
-- own, and the first file's world is collected.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local left = debug.getregistry().BetterBagsWorldSpec

describe("the spec file after it", function()
  it("runs after first_world.lua", function()
    assert.is_table(left)
  end)

  it("gets an addon of its own, without the first file's stub module", function()
    assert.are_not.equal(left.addon, addon)
    assert.is_nil(addon:GetModule("WorldSpecStub", true))
  end)

  it("gets mocked APIs of its own", function()
    assert.is_nil(C_Container.BetterBagsWorldSpec)
  end)

  it("lets the first file's world be collected", function()
    collectgarbage("collect")
    collectgarbage("collect")
    assert.is_nil(left.addon)
    assert.is_nil(left.frame)
  end)
end)
