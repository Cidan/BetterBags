-- style_spec.lua -- NextStyle (next/style.lua): BetterBagsNext's timings. 0.24 seconds is the time
-- for everything that moves in answer to the player (next.md §5); the panel's slides in and out
-- keep their own.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

ResetModuleStub("NextStyle", "next/style.lua")
LoadBetterBagsModule("next/style.lua")

local style = addon:GetModule("NextStyle")

describe("NextStyle timings", function()
  it("moves everything that answers the player in 0.24 seconds", function()
    local t = style.Time
    assert.are.equal(0.24, t.Interaction)
    for _, name in ipairs({ "Glide", "Land", "FlyAway" }) do
      assert.are.equal(t.Interaction, t[name], name)
    end
  end)

  it("keeps the panel's slides, feedback and fades at their own times", function()
    local t = style.Time
    assert.are.same({ 0.45, 0.24, 0.32, 0.12, 0.15, 0.6, 0.44 },
      { t.Open, t.Close, t.Cascade, t.Lift, t.Hover, t.Pulse, t.Wash })
  end)
end)

teardown(function()
  ResetModuleStub("NextStyle")
end)
