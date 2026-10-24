-- pixelaudit_spec.lua -- PixelAudit (debug/pixelaudit.lua): the pixel check BetterBags Next is held to
-- (next-pixel-perfect.md), run in game from the /bbdb debug window and by the specs (spec/helpers/layout.lua's
-- PixelCheck calls it). It reads only what the client gives an addon: where a region is (GetScaledRect),
-- its anchors, its regions and children, whether it shows.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local layout = dofile("spec/helpers/layout.lua")

local audit = addon:GetModule("PixelAudit")

describe("PixelAudit", function()
  local undo, unit, window

  before_each(function()
    -- The reporter's window at 65%: a unit is 1.153 pixels.
    undo = layout.UseScreen(3396, 1362, 0.65)
    unit = (768 / 1362) / 0.65
    window = CreateFrame("Frame", nil, UIParent)
    window:SetSize(100 * unit, 50 * unit)
    window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10 * unit, -20 * unit)
  end)

  after_each(function()
    undo()
  end)

  describe("the check", function()
    -- In game the client says where a region is; the check never works it out from anchors itself.
    it("judges a region where the client puts it (GetScaledRect), whatever its anchors say", function()
      local tex = window:CreateTexture()
      tex:SetPoint("TOPLEFT", window, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      local factor = 768 / 1362
      function tex:GetScaledRect() return 20 * factor, 30 * factor, 4 * factor, factor end
      assert.are.same({}, audit:Check(window), "on whole pixels where the client put it")
      function tex:GetScaledRect() return 20.5 * factor, 30 * factor, 4 * factor, factor end
      assert.are.same({ "window.tex: left 20.500, right 24.500" },
        audit:Check(window, { owners = { window = { tex = tex } } }))
    end)

    it("judges a font string by its anchor points, from where the client puts its text", function()
      local text = window:CreateFontString()
      text:SetFontObject(GameFontNormal)
      text:SetText("odd")
      text:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
      local factor = 768 / 1362
      -- Its right edge is the text's measure, between pixels: not judged.
      function text:GetScaledRect() return 7 * factor, 40 * factor, 19.37 * factor, 12 * factor end
      assert.are.same({}, audit:Check(window))
      function text:GetScaledRect() return 7.25 * factor, 40 * factor, 19.37 * factor, 12 * factor end
      assert.are.equal(1, #audit:Check(window))
    end)

    -- warcraft.wiki.gg ScriptRegion:GetRect (and GetScaledRect): "Not allowed on restricted frames".
    it("skips a region the client will not measure, still judging what is in it", function()
      window:SetClipsChildren(true)
      function window:GetScaledRect() error("restricted frame") end
      local tex = window:CreateTexture()
      tex:SetPoint("TOPLEFT", window, "TOPLEFT", 0.3, 0)
      tex:SetSize(4 * unit, unit)
      local problems = audit:Check(window)
      assert.are.equal(1, #problems, "the texture, not the frame")
    end)

    it("skips a region the client has not placed", function()
      window:SetClipsChildren(true)
      function window:GetScaledRect() end
      assert.are.same({}, audit:Check(window))
    end)

    -- What a message names a part by when no owner table reaches it: the field of its parent it is kept in
    -- (a template's parentKey, a button's state art), else where it is in the tree.
    it("names a part by the field its parent keeps it in, else by its place in the tree", function()
      local button = CreateFrame("Button", nil, window)
      button:SetPoint("TOPLEFT", window, "TOPLEFT", 0.4, 0)
      button:SetSize(10 * unit, 10 * unit)
      button.Glow = button:CreateTexture()
      button.Glow:SetAllPoints(button)
      local loose = button:CreateTexture()
      loose:SetAllPoints(button)
      local problems = audit:Check(window)
      table.sort(problems)
      assert.are.equal(2, #problems)
      assert.is_truthy(problems[1]:find("^Texture >1>Glow: "), problems[1])
      assert.is_truthy(problems[2]:find("^Texture >1>t2: "), problems[2])
    end)
  end)
end)
