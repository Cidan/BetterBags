-- base_spec.lua -- NextControls (next/controls/base.lua): what every BetterBags Next control draws with
-- (next-settings.md §2): a fill from the theme (a texture spec, a palette color, a color, or none) and
-- an edge of four lines round a frame.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" } }) do
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

    -- The render recorder lists every edge drawn in the settings window (render-recorder.md).
    it("is kept in the controls' list of edges, weakly", function()
      assert.is_true(controls.edges[edge])
      assert.are.equal("k", getmetatable(controls.edges).__mode)
    end)

    it("hides for none", function()
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1 })
      controls:PaintEdge(edge, false)
      for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        assert.is_false(edge[side]:IsShown(), side)
      end
    end)

    local SIDES = { "Top", "Bottom", "Left", "Right" }
    local function shown(ring)
      for _, side in ipairs(SIDES) do
        if not ring[side]:IsShown() then return false end
      end
      return true
    end

    -- ElvUI outside its pixel mode draws a black line inside and one outside every edge (General/Toolkit.lua,
    -- SetTemplate; docs/next-elvui-theme.md). An edge's Outlines are rings round its frame, each Offset outside it (inside
    -- for less than 0), Size thick, in its Color at its own Alpha: a strength asked of the edge is the edge's alone.
    it("draws its outlines, rings Offset outside its frame (inside for less than 0), and takes them away", function()
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1, Outlines = {
        { Offset = 1, Color = "Black", Size = 1 },
        { Offset = -1, Color = "Black", Alpha = 0.5, Size = 1 },
      } }, 0.3)
      local rings = edge.outlines.rings
      local outer, inner = rings[1], rings[2]
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -1, 1 }, { outer.Top:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", frame, "TOPRIGHT", 1, 1 }, { outer.Top:GetPoint(2) })
      assert.are.equal(1, outer.Top:GetHeight())
      assert.are.same({ "BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1 }, { outer.Bottom:GetPoint(1) })
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -1, 0 }, { outer.Left:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", frame, "BOTTOMLEFT", -1, 0 }, { outer.Left:GetPoint(2) })
      assert.are.equal(1, outer.Left:GetWidth())
      assert.are.same({ "TOPRIGHT", frame, "TOPRIGHT", 1, 0 }, { outer.Right:GetPoint(1) })
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 1, -1 }, { inner.Top:GetPoint(1) })
      assert.are.same({ "TOPRIGHT", frame, "TOPRIGHT", -1, -1 }, { inner.Top:GetPoint(2) })
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 1, -2 }, { inner.Left:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 2 }, { inner.Left:GetPoint(2) })
      local r, g, b = style:RGBA("Black")
      for _, side in ipairs(SIDES) do
        assert.are.same({ r = r, g = g, b = b, a = 1 }, outer[side]._colorTexture, side .. ": its own alpha")
        assert.are.same({ r = r, g = g, b = b, a = 0.5 }, inner[side]._colorTexture, side)
        assert.are.equal(frame, outer[side]:GetParent(), side .. ": the frame's lines")
      end
      assert.is_true(shown(outer) and shown(inner))
      assert.are.equal(0.3, edge.Top._colorTexture.a, "the edge at its strength")
      -- The render recorder lists every ring with the edges (render-recorder.md).
      assert.is_true(controls.edges[outer])
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1, Outlines = { { Offset = 1, Color = "Black", Size = 1 } } })
      assert.is_true(shown(outer))
      assert.is_false(inner.Top:IsShown(), "a ring the edge no longer has")
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1 })
      assert.is_false(outer.Left:IsShown(), "an edge without outlines")
      controls:PaintEdge(edge, { Color = "Lavender", Size = 1, Outlines = { { Offset = 1, Color = "Black", Size = 1 } } })
      controls:PaintEdge(edge, false)
      assert.is_false(outer.Bottom:IsShown(), "no edge")
    end)

    -- Found in review: on a coarse grid (a small bag at a low UI scale: a screen pixel over 2 units) a ring's offset
    -- rounded to nothing while its line kept its pixel, so all three lines fell on one row. An offset is rounded as a
    -- length: a whole pixel at least, never nothing.
    it("keeps each ring a whole pixel apart from the edge on a coarse grid, and on whole pixels", function()
      local layout = dofile("spec/helpers/layout.lua")
      local pixel = addon:GetModule("NextPixel")
      local undo = layout.UseScreen(1920, 1080, 0.64)
      local parent = CreateFrame("Frame", nil, UIParent)
      parent:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
      parent:SetSize(400, 400)
      parent:SetScale(0.5)
      local box = CreateFrame("Frame", nil, parent)
      local unit = pixel:Unit(box)
      box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 * unit, -10 * unit)
      box:SetSize(40 * unit, 20 * unit)
      local e = controls:CreateEdge(box)
      controls:PaintEdge(e, { Color = "Lavender", Size = 1, Outlines = {
        { Offset = 1, Color = "Black", Size = 1 }, { Offset = -1, Color = "Black", Size = 1 } } })
      local outer, inner = e.outlines.rings[1], e.outlines.rings[2]
      assert.is_true(unit > 2, "a coarse grid: " .. unit)
      local _, _, _, ox, oy = outer.Top:GetPoint(1)
      assert.are.same({ -unit, unit }, { ox, oy }, "a pixel outside")
      local _, _, _, ix, iy = inner.Top:GetPoint(1)
      assert.are.same({ unit, -unit }, { ix, iy }, "a pixel inside")
      assert.are.same({}, layout.PixelCheck(parent))
      undo()
    end)

    -- A part that draws its own edge's lines (the panel's body, faded through a size switch) draws its outlines with them.
    it("places, colors and shows outlines apart, for a part that fades its own edge", function()
      local set = controls:CreateOutlines(frame, "BORDER", 1)
      local made = controls:PlaceOutlines(set, { { Offset = 1, Color = "Black", Size = 1 } })
      assert.are.equal(4, #made)
      assert.is_false(set.rings[1].Top:IsShown(), "placed, not shown")
      controls:ColorOutlines(set, 0.5)
      local r, g, b = style:RGBA("Black")
      assert.are.same({ r = r, g = g, b = b, a = 0.5 }, set.rings[1].Left._colorTexture)
      controls:ShowOutlines(set, true)
      assert.is_true(shown(set.rings[1]))
      assert.are.same({}, controls:PlaceOutlines(set, { { Offset = 2, Color = "Black", Size = 1 } }), "none made again")
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -2, 2 }, { set.rings[1].Top:GetPoint(1) })
      controls:ShowOutlines(set, false)
      assert.is_false(set.rings[1].Right:IsShown())
      controls:PlaceOutlines(set, nil)
      controls:ShowOutlines(set, true)
      assert.is_false(set.rings[1].Top:IsShown(), "no rings to show")
    end)
  end)
end)
