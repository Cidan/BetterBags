-- scrollbox_spec.lua -- The Scrollbox drawable (render/scrollbox.lua): a WowScrollBox with a
-- MinimalScrollBar that renders one child, hands it the width left of the bar, and reports
-- the viewport it takes: the child's height capped at a maximum (content-sized windows) or a
-- fixed height (window-sized windows). Blizzard's bar shows itself only when the child does
-- not fit (SetHideIfUnscrollable).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")

local render = addon:GetModule("Render")
local drawable = addon:GetModule("Drawable")
local scrollbox = addon:GetModule("Scrollbox")

-- child builds a drawable of a fixed natural size that records the width it was given.
local function child(width, height, log)
  local c = drawable:Create({})
  c.frame = CreateFrame("Frame")
  c.given = {}
  function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
  function c:Render(parentResult)
    table.insert(self.given, parentResult and parentResult.Width or false)
    if log then table.insert(log, "child:render") end
    return { Width = (parentResult and parentResult.Width) or width, Height = height }
  end
  return c
end

-- root wraps the scroll box with a fixed constraint, like a window would.
local function root(sb, constraint)
  local r = drawable:Create({})
  r.frame = CreateFrame("Frame")
  function r:GetRenderPlan()
    return { Plan = { { step = render.PRE }, { step = render.DEP, target = sb }, { step = render.SELF } } }
  end
  function r:PreRender() return constraint end
  function r:Render(_, _, results) return results.Results[sb] end
  return r
end

describe("Scrollbox", function()
  before_each(function()
    render:Init()
  end)

  it("builds a scroll box, a minimal scroll bar and a scroll child Blizzard owns", function()
    local parent = CreateFrame("Frame")
    local sb = scrollbox:Create(parent, "BetterBagsTestScroll")

    assert.are.equal(parent, sb.frame:GetParent())
    assert.is_truthy(sb.scrollBox._template:find("WowScrollBox"))
    assert.is_truthy(sb.scrollBar._template:find("MinimalScrollBar"))
    assert.are.equal(sb.scrollBox:GetScrollTarget(), sb.scrollChild:GetParent())
    local point, relativeTo = sb.scrollChild:GetPoint(1)
    assert.are.same({ "TOPLEFT", sb.scrollBox:GetScrollTarget() }, { point, relativeTo })
    point = sb.scrollChild:GetPoint(2)
    assert.are.equal("TOPRIGHT", point)
    assert.are.equal(sb.scrollBar, sb.scrollBox._scrollBar)
    assert.is_true(sb.scrollBar._hideIfUnscrollable)
  end)

  it("parents its child to the scroll child, hidden until it renders", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local c = child(100, 50)
    sb:SetChild(c)
    assert.are.equal(sb.scrollChild, c.frame:GetParent())
    assert.are.equal(c, sb:GetChild())
    assert.are.equal(sb, c.renderParent)
    assert.is_false(c.frame:IsShown())
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    assert.is_true(c.frame:IsShown())
  end)

  it("detaches and hides the child it replaces", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local first = child(100, 50)
    sb:SetChild(first)
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    local second = child(100, 60)

    sb:SetChild(second)

    assert.is_false(first.frame:IsShown())
    assert.is_nil(first.renderParent)
    assert.are.equal(sb, second.renderParent)
  end)

  it("gives the child its natural width when the window sizes to its content", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local c = child(300, 200)
    sb:SetChild(c)

    local result = render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})

    assert.are.same({ false }, c.given)
    assert.are.equal(300 + sb:GetBarWidth(), result.Width)
    assert.are.equal(200, result.Height)
    assert.are.equal(200, sb.scrollChild:GetHeight())
    assert.is_false(result.Scrollable)
  end)

  it("renders as a root with no constraints at its natural size", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 200))
    local result = render:NewRenderChain(sb, {})
    assert.are.equal(300 + sb:GetBarWidth(), result.Width)
    assert.are.equal(200, result.Height)
  end)

  it("caps the viewport at the maximum height and reports that it scrolls", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 900))

    local result = render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})

    assert.are.equal(500, result.Height)
    assert.are.equal(900, sb.scrollChild:GetHeight())
    assert.is_true(result.Scrollable)
  end)

  it("never shows or hides the bar itself", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 900))
    sb.scrollBar:Hide()
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    assert.is_false(sb.scrollBar:IsShown())
    sb.scrollBar:Show()
    sb:SetChild(child(300, 10))
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    assert.is_true(sb.scrollBar:IsShown())
  end)

  it("tells the controller cursor to skip the bar when nothing scrolls", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 900))
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    assert.is_false(sb.scrollBar:GetAttribute("nodeignore"))
    sb:SetChild(child(300, 100))
    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
    assert.is_true(sb.scrollBar:GetAttribute("nodeignore"))
  end)

  it("does not scroll for a child less than half a pixel taller than the viewport", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 480.4))
    local result = render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
    assert.is_false(result.Scrollable)
    sb:SetChild(child(300, 480.6))
    result = render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
    assert.is_true(result.Scrollable)
  end)

  it("gives the child the width left of the bar when the window has a set size", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local c = child(300, 200)
    sb:SetChild(c)

    local result = render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})

    assert.are.same({ 640 - sb:GetBarWidth() }, c.given)
    assert.are.equal(640, result.Width)
    assert.are.equal(480, result.Height)
    assert.is_false(result.Scrollable)
  end)

  it("prefers a set height over a maximum", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 200))
    local result = render:NewRenderChain(root(sb, { Width = 640, Height = 480, MaxHeight = 100 }), {})
    assert.are.equal(480, result.Height)
  end)

  it("never hands the child a negative width", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local c = child(300, 200)
    sb:SetChild(c)
    render:NewRenderChain(root(sb, { Width = 5, Height = 480 }), {})
    assert.are.same({ 0 }, c.given)
  end)

  it("updates the scroll box after sizing the scroll child", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(300, 200))
    local heightAtUpdate
    local originalUpdate = sb.scrollBox.FullUpdate
    sb.scrollBox.FullUpdate = function(box, immediately)
      heightAtUpdate = sb.scrollChild:GetHeight()
      originalUpdate(box, immediately)
    end

    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})

    assert.are.equal(200, heightAtUpdate)
    assert.is_true(sb.scrollBox._lastFullUpdateImmediate)
  end)

  it("keeps the scroll child at least one pixel tall", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    sb:SetChild(child(0, 0))

    render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})

    assert.are.equal(1, sb.scrollChild:GetHeight())
  end)

  -- A bag's scroll box keeps the bar's room on both sides at all times, so its content is
  -- centered and never moves when the bar appears; the bar itself shows only while the player
  -- scrolls with the mouse wheel or points at it (window.md, centering).
  describe("for a bag (Symmetric, AutoHideBar)", function()
    local function bagScroll()
      local sb = scrollbox:Create(CreateFrame("Frame"), nil, { Symmetric = true, AutoHideBar = true })
      sb.frame:SetSize(400, 300)
      sb.frame._rect = { left = 100, bottom = 100 }
      return sb
    end

    it("keeps the bar's room on both sides: the child is inset by it and gets the width less both", function()
      local sb = bagScroll()
      local c = child(300, 200)
      sb:SetChild(c)
      assert.are.equal(28, sb:GetGutterWidth())
      assert.are.same({ "TOPLEFT", sb.scrollChild, "TOPLEFT", 14, 0 }, { c.frame:GetPoint(1) })
      local result = render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
      assert.are.same({ 640 - 28 }, c.given)
      assert.are.equal(640, result.Width)
      local natural = render:NewRenderChain(root(sb, { MaxHeight = 500 }), {})
      assert.are.equal(300 + 28, natural.Width)
    end)

    -- A window snapping to its content: the child's narrowest width comes up with the box's
    -- room, and the width to lay out for goes down without it.
    it("passes the child's fit width up and a layout width down, each with the room on both sides", function()
      local sb = bagScroll()
      local c = child(300, 200)
      local seen
      function c:Render(parentResult)
        seen = parentResult
        return { Width = parentResult.Width, Height = 200, FitWidth = 410 }
      end
      sb:SetChild(c)
      local result = render:NewRenderChain(root(sb, { Width = 640, Height = 480, LayoutWidth = 600 }), {})
      assert.are.equal(612, seen.Width)
      assert.are.equal(572, seen.LayoutWidth)
      assert.are.equal(438, result.FitWidth)
      render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
      assert.is_nil(seen.LayoutWidth)
    end)

    it("keeps the child where it is whether or not it scrolls", function()
      local sb = bagScroll()
      local tall, short = child(300, 900), child(300, 100)
      sb:SetChild(tall)
      render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
      sb:SetChild(short)
      render:NewRenderChain(root(sb, { Width = 640, Height = 480 }), {})
      assert.are.same({ 612 }, tall.given)
      assert.are.same({ 612 }, short.given)
      assert.are.same({ "TOPLEFT", sb.scrollChild, "TOPLEFT", 14, 0 }, { short.frame:GetPoint(1) })
    end)

    it("keeps the bar's room on the right only for other scroll boxes", function()
      local sb = scrollbox:Create(CreateFrame("Frame"))
      local c = child(300, 200)
      sb:SetChild(c)
      assert.are.equal(14, sb:GetGutterWidth())
      assert.are.same({ "TOPLEFT", sb.scrollChild, "TOPLEFT", 0, 0 }, { c.frame:GetPoint(1) })
      assert.is_nil(sb.barDriver)
      assert.are.equal(1, sb.scrollBar:GetAlpha())
    end)

    describe("the bar", function()
      local savedCursor
      before_each(function()
        savedCursor = { _G._cursorX, _G._cursorY }
      end)
      after_each(function()
        _G._cursorX, _G._cursorY = savedCursor[1], savedCursor[2]
      end)

      local function tick(sb, seconds)
        local update = sb.barDriver:GetScript("OnUpdate")
        local steps = math.floor(seconds / 0.05 + 0.5)
        for _ = 1, steps do update(sb.barDriver, 0.05) end
      end

      local function pointAt(x, y)
        _G._cursorX, _G._cursorY = x, y
      end

      it("starts hidden", function()
        local sb = bagScroll()
        assert.are.equal(0, sb.scrollBar:GetAlpha())
        assert.are.equal(sb.scrollBar, sb.barDriver:GetParent())
      end)

      it("shows while the pointer is in the bar's room on the right, then fades a second after it leaves", function()
        local sb = bagScroll()
        pointAt(494, 250)
        tick(sb, 0.2)
        assert.are.equal(1, sb.scrollBar:GetAlpha())
        tick(sb, 3)
        assert.are.equal(1, sb.scrollBar:GetAlpha())
        pointAt(300, 250)
        tick(sb, 0.9)
        assert.are.equal(1, sb.scrollBar:GetAlpha())
        tick(sb, 0.5)
        assert.are.equal(0, sb.scrollBar:GetAlpha())
      end)

      it("stays hidden while the pointer is over the content", function()
        local sb = bagScroll()
        pointAt(300, 250)
        tick(sb, 2)
        assert.are.equal(0, sb.scrollBar:GetAlpha())
        pointAt(480, 250)
        tick(sb, 1)
        assert.are.equal(0, sb.scrollBar:GetAlpha())
      end)

      it("shows when the mouse wheel scrolls, then fades", function()
        local sb = bagScroll()
        pointAt(300, 250)
        sb.scrollBox:GetScript("OnMouseWheel")(sb.scrollBox, -1)
        tick(sb, 0.2)
        assert.are.equal(1, sb.scrollBar:GetAlpha())
        tick(sb, 1.4)
        assert.are.equal(0, sb.scrollBar:GetAlpha())
      end)

      it("fades in and out over a moment, not at once", function()
        local sb = bagScroll()
        pointAt(494, 250)
        tick(sb, 0.05)
        local alpha = sb.scrollBar:GetAlpha()
        assert.is_true(alpha > 0 and alpha < 1, tostring(alpha))
      end)

      it("starts hidden again each time it reappears", function()
        local sb = bagScroll()
        pointAt(494, 250)
        tick(sb, 0.2)
        assert.are.equal(1, sb.scrollBar:GetAlpha())
        -- Blizzard hides the bar when nothing scrolls (SetHideIfUnscrollable) and shows it again
        -- when something does; the spec frame mock does not fire OnShow.
        sb.barDriver:GetScript("OnShow")(sb.barDriver)
        assert.are.equal(0, sb.scrollBar:GetAlpha())
      end)
    end)
  end)

  it("errors when rendered without a child", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    assert.has_error(function() render:NewRenderChain(root(sb, { MaxHeight = 500 }), {}) end)
  end)

  it("errors when its child returns no result", function()
    local sb = scrollbox:Create(CreateFrame("Frame"))
    local c = drawable:Create({})
    c.frame = CreateFrame("Frame")
    function c:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
    function c:Render() return nil end
    sb:SetChild(c)
    assert.has_error(function() render:NewRenderChain(root(sb, { MaxHeight = 500 }), {}) end)
  end)
end)
