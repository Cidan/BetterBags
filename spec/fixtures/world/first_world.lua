-- spec/world_spec.lua runs this file and second_world.lua, in that order, in a busted of their own. This one leaves
-- behind what a spec file can leave in its world; second_world.lua checks that none of it reaches it.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local frame = CreateFrame("Frame", nil, UIParent)

describe("a spec file", function()
  it("leaves a stub module, a frame and a mark on a mocked API behind", function()
    StubBetterBagsModule("WorldSpecStub")
    C_Container.BetterBagsWorldSpec = true
    -- The registry is in no world, so it carries these to second_world.lua; weak, so it does not keep them alive itself.
    debug.getregistry().BetterBagsWorldSpec = setmetatable({ addon = addon, frame = frame }, { __mode = "v" })
    assert.is_table(addon:GetModule("WorldSpecStub"))
  end)
end)
