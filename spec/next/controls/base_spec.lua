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

  -- Escape closes the innermost thing open (a menu, then a dialog, then the window: next-settings.md
  -- §2). Blizzard's CloseSpecialWindows hides every shown frame named in UISpecialFrames, walking it
  -- with pairs while it hides them, so the list is changed when something opens and, after a hide,
  -- only on the next frame (a table changed while pairs walks it is undefined behavior).
  describe("Escape, innermost first", function()
    local timers, saved

    local function frame(name)
      local f = CreateFrame("Frame", name)
      f:Show()
      return f
    end

    local function nextFrame()
      local due = timers
      timers = {}
      for _, fn in ipairs(due) do fn() end
    end

    before_each(function()
      timers = {}
      saved = { _G.UISpecialFrames, C_Timer.After }
      _G.UISpecialFrames = { "SomeoneElsesFrame" }
      C_Timer.After = function(_, fn) table.insert(timers, fn) end
      controls.escape = {}
    end)

    after_each(function()
      _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
    end)

    it("names only the innermost frame open, beside every other addon's", function()
      local window, menu = frame("SpecWindow"), frame("SpecMenu")
      controls:PushEscape(window)
      assert.are.same({ "SomeoneElsesFrame", "SpecWindow" }, UISpecialFrames)
      controls:PushEscape(menu)
      assert.are.same({ "SomeoneElsesFrame", "SpecMenu" }, UISpecialFrames)
    end)

    it("gives the frame under it back to Escape a frame after it hides, never while hiding", function()
      local window, menu = frame("SpecWindow"), frame("SpecMenu")
      controls:PushEscape(window)
      controls:PushEscape(menu)
      menu:Hide()
      controls:ReleaseEscape(menu)
      assert.are.same({ "SomeoneElsesFrame", "SpecMenu" }, UISpecialFrames, "unchanged while Escape walks it")
      nextFrame()
      assert.are.same({ "SomeoneElsesFrame", "SpecWindow" }, UISpecialFrames)
      window:Hide()
      controls:ReleaseEscape(window)
      nextFrame()
      assert.are.same({ "SomeoneElsesFrame" }, UISpecialFrames)
    end)

    it("keeps a frame shown again before then", function()
      local window = frame("SpecWindow")
      controls:PushEscape(window)
      window:Hide()
      controls:ReleaseEscape(window)
      window:Show()
      nextFrame()
      assert.are.same({ "SomeoneElsesFrame", "SpecWindow" }, UISpecialFrames)
    end)

    it("does not give Escape back to a frame under it that hid too", function()
      local window, menu = frame("SpecWindow"), frame("SpecMenu")
      controls:PushEscape(window)
      controls:PushEscape(menu)
      window:Hide()
      menu:Hide()
      controls:ReleaseEscape(window)
      controls:ReleaseEscape(menu)
      nextFrame()
      assert.are.same({ "SomeoneElsesFrame" }, UISpecialFrames)
      -- The other way round: the menu released first, the window under it hidden but not yet released.
      controls:PushEscape(window)
      controls:PushEscape(menu)
      window:Hide()
      menu:Hide()
      controls:ReleaseEscape(menu)
      nextFrame()
      assert.are.same({ "SomeoneElsesFrame" }, UISpecialFrames)
    end)

    it("names a frame once when pushed again", function()
      local window = frame("SpecWindow")
      controls:PushEscape(window)
      controls:PushEscape(window)
      assert.are.same({ "SomeoneElsesFrame", "SpecWindow" }, UISpecialFrames)
      assert.are.equal(1, #controls.escape)
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
