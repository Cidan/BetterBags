-- base_spec.lua -- NextControls (next/controls/base.lua): what every BetterBags Next control draws with
-- (next-settings.md §2): a fill from the theme (a texture spec, a palette color, a color, or none) and
-- an edge of four lines round a frame.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextControls", "next/controls/base.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local controls = addon:GetModule("NextControls")
local style = addon:GetModule("NextStyle")

describe("NextControls", function()
  teardown(function()
    UseNextTheme(nil)
  end)

  describe("a fill", function()
    local texture

    before_each(function()
      texture = CreateFrame("Frame"):CreateTexture()
    end)

    it("paints a texture spec's color at its alpha", function()
      controls:Paint(texture, { Color = "Gold", Alpha = 0.5 })
      local r, g, b = style:RGBA("Gold")
      assert.are.same({ r = r, g = g, b = b, a = 0.5 }, texture._colorTexture)
      assert.is_true(texture:IsShown())
    end)

    it("paints a palette color or a color given outright, at its own alpha or the one asked for", function()
      controls:Paint(texture, "Lavender")
      local r, g, b, a = style:RGBA("Lavender")
      assert.are.same({ r = r, g = g, b = b, a = a }, texture._colorTexture)
      controls:Paint(texture, { 0.1, 0.2, 0.3, 0.4 })
      assert.are.same({ r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, texture._colorTexture)
      controls:Paint(texture, { Color = "Gold", Alpha = 0.5 }, 0.25)
      assert.are.equal(0.25, texture._colorTexture.a)
    end)

    it("draws a theme's texture tinted by its color", function()
      controls:Paint(texture, { Texture = "Glow", Color = "Gold", Alpha = 0.3 })
      assert.are.equal(style.Theme.Textures.Glow, texture:GetTexture())
      local r, g, b = style:RGBA("Gold")
      assert.are.same({ r, g, b, 0.3 }, { texture:GetVertexColor() })
    end)

    it("hides the texture for none, and shows it again for a fill", function()
      controls:Paint(texture, false)
      assert.is_false(texture:IsShown())
      controls:Paint(texture, nil)
      assert.is_false(texture:IsShown())
      controls:Paint(texture, { Color = "Gold" })
      assert.is_true(texture:IsShown())
    end)
  end)

  describe("an edge", function()
    local frame, edge

    before_each(function()
      frame = CreateFrame("Frame")
      frame:SetSize(100, 40)
      edge = controls:CreateEdge(frame)
    end)

    it("is four lines inside the frame's border, Size thick, in its color and alpha", function()
      controls:PaintEdge(edge, { Color = "Lavender", Alpha = 0.3, Size = 2 })
      local r, g, b = style:RGBA("Lavender")
      for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local t = edge[side]
        assert.are.same({ r = r, g = g, b = b, a = 0.3 }, t._colorTexture, side)
        assert.is_true(t:IsShown(), side)
      end
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 0, 0 }, { edge.Top:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", frame, "TOPRIGHT", 0, 0 }, { edge.Top:GetPoint(2) })
      assert.are.equal(2, edge.Top:GetHeight())
      assert.are.same({ "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0 }, { edge.Bottom:GetPoint(1) })
      assert.are.equal(2, edge.Bottom:GetHeight())
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 0, -2 }, { edge.Left:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2 }, { edge.Left:GetPoint(2) })
      assert.are.equal(2, edge.Left:GetWidth())
      assert.are.same({ "TOPRIGHT", frame, "TOPRIGHT", 0, -2 }, { edge.Right:GetPoint(1) })
      assert.are.equal(2, edge.Right:GetWidth())
    end)

    it("takes a strength in place of its alpha (an edge stronger under the pointer)", function()
      controls:PaintEdge(edge, { Color = "Lavender", Alpha = 0.3, Size = 1 }, 0.9)
      assert.are.equal(0.9, edge.Left._colorTexture.a)
    end)

    it("hides for none", function()
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1 })
      controls:PaintEdge(edge, false)
      for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        assert.is_false(edge[side]:IsShown(), side)
      end
    end)
  end)
end)
