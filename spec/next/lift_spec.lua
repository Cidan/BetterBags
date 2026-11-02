-- lift_spec.lua -- NextLift (next/lift.lua): lifting a frame to drag it, as BetterBags Next's sections
-- are (next.md §7) and the settings lists' rows (next-settings.md §5). Shared so every drag looks and
-- moves the same (CLAUDE.md, "UI Consistency"): the frame leaves its parent for the drag layer where it
-- was on screen, a cover over it and a shadow under it, shrinks around the point grabbed, follows the
-- cursor, and lands where its owner says, back at full size.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextLift", "next/lift.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local lift = addon:GetModule("NextLift")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local context = addon:GetModule("Context")

describe("NextLift", function()
  local parent, frame, held, frames

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  before_each(function()
    UseNextTheme(nil)
    tween:Init()
    parent = CreateFrame("Frame", nil, UIParent)
    parent:SetFrameStrata("HIGH")
    parent:SetFrameLevel(20)
    frame = CreateFrame("Button", nil, parent)
    frame:_SetRect(100, 500, 200, 40)
    CreateFrame("Frame", nil, frame):SetFrameLevel(60)
    _G._cursorX, _G._cursorY = 120, 530
    frames = {}
    held = {}
    GameTooltip:Show()
  end)

  after_each(function()
    if lift:IsHolding() then
      lift:Put(lift.held, parent)
    end
    _G._cursorX, _G._cursorY = 0, 0
    UseNextTheme(nil)
  end)

  local function pick()
    return lift:Pick(held, frame, function(elapsed) table.insert(frames, elapsed) end)
  end

  describe("picking up", function()
    it("takes the frame onto the drag layer where it was on screen, above everything", function()
      assert.is_true(pick())
      assert.are.equal(lift.layer, frame:GetParent())
      assert.are.equal("TOOLTIP", lift.layer:GetFrameStrata())
      assert.are.equal("TOOLTIP", frame:GetFrameStrata())
      assert.is_true(frame:GetFrameLevel() >= lift.layer:GetFrameLevel() + 2)
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 540 }, { frame:GetPoint(1) })
      assert.are.same({ 20, 10, 1 }, { held.grabX, held.grabY, held.scale })
      assert.are.equal(frame, held.frame)
      assert.is_false(held.landing)
      assert.is_false(GameTooltip:IsShown())
      assert.is_true(lift:IsHolding())
      assert.is_false(lift.layer:IsMouseEnabled(), "the layer takes no mouse")
    end)

    -- A frame shares its parent's strata unless it set its own (warcraft.wiki.gg "Frame Strata").
    it("raises a frame that set its own strata too", function()
      frame:SetFrameStrata("LOW")
      pick()
      assert.are.equal("TOOLTIP", frame:GetFrameStrata())
    end)

    it("never lowers a frame already above the layer", function()
      frame:SetFrameLevel(500)
      pick()
      assert.are.equal(500, frame:GetFrameLevel())
    end)

    it("picks nothing up that the client has not placed yet", function()
      frame._rect = nil
      assert.is_false(pick())
      assert.are.equal(parent, frame:GetParent())
      assert.is_false(lift:IsHolding())
    end)

    -- The release goes to the mouse-enabled frame under the cursor (next.md §7): the cover takes it,
    -- so nothing in the lifted frame is clicked by it.
    it("covers the frame past its edges, above everything in it", function()
      pick()
      local cover = lift.cover
      assert.is_true(cover:IsShown())
      assert.is_true(cover:IsMouseEnabled())
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -lift.COVER_MARGIN, lift.COVER_MARGIN }, { cover:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", frame, "BOTTOMRIGHT", lift.COVER_MARGIN, -lift.COVER_MARGIN },
        { cover:GetPoint(2) })
      assert.is_true(cover:GetFrameLevel() > lift:MaxLevel(frame))
    end)

    it("shrinks to the theme's lift scale around the point grabbed, its shadow coming up", function()
      local D = style.Theme.Drag
      pick()
      assert.are.equal(0, lift.shadow:GetAlpha())
      assert.is_true(lift.shadow:IsShown())
      _G._cursorX, _G._cursorY = 300, 200
      finishTweens()
      local s = frame:GetScale()
      assert.are.equal(D.LiftScale, s)
      assert.are.equal(D.LiftScale, held.scale)
      assert.are.equal(D.Shadow.Alpha, lift.shadow:GetAlpha())
      local _, _, _, ox, oy = frame:GetPoint(1)
      assert.is_true(math.abs((ox * s + 20 * s) - 300) < 1e-6, "the grabbed point's x")
      assert.is_true(math.abs((oy * s - 10 * s) - 200) < 1e-6, "the grabbed point's y")
      local spread = D.Shadow.Spread
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -spread, spread }, { lift.shadow:GetPoint(1) })
    end)

    it("follows its theme: the lift scale, the shadow's color, darkness and spread, or none", function()
      UseNextTheme({ Drag = { LiftScale = 0.8, Shadow = { Color = "Gold", Alpha = 0.5, Spread = 4 } } })
      lift:ApplyStyle(context:New("spec"))
      pick()
      finishTweens()
      assert.are.equal(0.8, held.scale)
      assert.are.equal(0.5, lift.shadow:GetAlpha())
      local c = lift.shadow._colorTexture
      assert.are.same({ 1, 0.84, 0.5, 1 }, { c.r, c.g, c.b, c.a })
      assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -4, 4 }, { lift.shadow:GetPoint(1) })
      UseNextTheme({ Drag = { Shadow = false } })
      lift:ApplyStyle(context:New("spec"))
      assert.is_false(lift.shadow:IsShown(), "restyled while lifted")
      UseNextTheme(nil)
      lift:ApplyStyle(context:New("spec"))
      assert.is_true(lift.shadow:IsShown())
      assert.are.same(style.Color.Black, { lift.shadow._colorTexture.r, lift.shadow._colorTexture.g,
        lift.shadow._colorTexture.b, lift.shadow._colorTexture.a })
    end)

    it("runs its holder's frame every frame until it is put back", function()
      pick()
      lift.layer:GetScript("OnUpdate")(lift.layer, 0.016)
      assert.are.same({ 0.016 }, frames)
      lift:Put(held, parent)
      assert.is_nil(lift.layer:GetScript("OnUpdate"))
    end)

    it("stops following the cursor while it lands", function()
      pick()
      held.landing = true
      _G._cursorX, _G._cursorY = 300, 200
      finishTweens()
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 540 }, { frame:GetPoint(1) }, "where it was")
    end)
  end)

  describe("landing and putting back", function()
    it("flies to where its owner says, aiming every frame, back to full size, then calls back", function()
      pick()
      finishTweens()
      local targetY, done = 400, 0
      lift:Land(held, function() return 50, targetY end, function() done = done + 1 end)
      assert.are.equal(0, done)
      tween:Step(style.Time.Land / 2)
      targetY = 380
      tween:Step(style.Time.Land)
      assert.are.equal(1, done)
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 50, 380 }, { frame:GetPoint(1) })
      assert.are.equal(1, frame:GetScale())
      assert.are.equal(0, lift.shadow:GetAlpha())
    end)

    it("starts a landing from a point instead of the cursor", function()
      pick()
      finishTweens()
      local first
      lift:Land(held, function(left0, top0)
        first = first or { left0, top0 }
        return left0, top0
      end, function() end, { left = 10, top = 20, scale = 0.5 })
      assert.are.same({ 10, 20 }, first)
    end)

    it("lands where it started when its owner has no place for it", function()
      pick()
      lift:Land(held, function(left0, top0) return left0, top0 end, function() end)
      finishTweens()
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 540 }, { frame:GetPoint(1) })
    end)

    it("puts the frame back in a parent at full size, unanchored, its shadow and cover gone", function()
      frame:SetFrameLevel(500)
      pick()
      finishTweens()
      frame:SetAlpha(0.3)
      lift:Put(held, parent)
      assert.are.equal(parent, frame:GetParent())
      assert.are.same({ 1, 1 }, { frame:GetScale(), frame:GetAlpha() })
      assert.are.equal("HIGH", frame:GetFrameStrata())
      assert.are.equal(21, frame:GetFrameLevel())
      assert.are.equal(0, frame:GetNumPoints())
      assert.is_false(lift.shadow:IsShown())
      assert.is_false(lift.cover:IsShown())
      assert.is_false(lift:IsHolding())
    end)

    -- A section waiting in a dock (next.md §7) leaves the layer while the drag goes on.
    it("detaches for a dock, keeping its shadow hidden through a theme, and raises it again", function()
      pick()
      lift:Detach()
      assert.is_false(lift.shadow:IsShown())
      assert.is_false(lift.cover:IsShown())
      lift:ApplyStyle(context:New("spec"))
      assert.is_false(lift.shadow:IsShown())
      local dock = CreateFrame("Frame", nil, UIParent)
      frame:SetParent(dock)
      frame:_SetRect(300, 300, 200, 40)
      local from = lift:Raise(frame)
      assert.are.same({ left = 300, top = 340, scale = 1 }, from)
      assert.are.equal(lift.layer, frame:GetParent())
      assert.are.equal("TOOLTIP", frame:GetFrameStrata())
      lift:ApplyStyle(context:New("spec"))
      assert.is_true(lift.shadow:IsShown(), "lifted again")
    end)
  end)

  -- A docked section (NextDock) flies into its card, back to its bag or away into the vendor, while the
  -- lift may hold another frame the player drags.
  describe("flying a frame it does not hold", function()
    local other, flying

    before_each(function()
      other = CreateFrame("Frame", nil, parent)
      other:_SetRect(400, 400, 100, 30)
      flying = { frame = other, grabX = 0, grabY = 0, scale = 1, landing = true }
      pick()
      finishTweens()
    end)

    it("lands it to the scale its owner says, the held frame's shadow left alone", function()
      local shadow = lift.shadow:GetAlpha()
      lift:Raise(other)
      lift:Land(flying, function() return 10, 20, 0.5 end, function() end, { left = 400, top = 430, scale = 1 })
      finishTweens()
      assert.are.equal(0.5, other:GetScale())
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 20, 40 }, { other:GetPoint(1) })
      assert.are.equal(shadow, lift.shadow:GetAlpha())
      assert.is_true(lift.shadow:IsShown())
    end)

    it("flies it away into a point, shrinking to the theme's fly scale and fading", function()
      local done = 0
      local shadow = lift.shadow:GetAlpha()
      lift:Raise(other)
      lift:FlyAway(flying, 600, 300, function() done = done + 1 end, { left = 400, top = 430, scale = 1 })
      tween:Step(0.0001)
      local _, _, _, sx, sy = other:GetPoint(1)
      local s0 = other:GetScale()
      assert.is_true(math.abs(sx * s0 - 400) < 1 and math.abs(sy * s0 - 430) < 1, "from where it was")
      finishTweens()
      assert.are.equal(shadow, lift.shadow:GetAlpha(), "the held frame's shadow left alone")
      assert.are.equal(1, done)
      assert.is_true(math.abs(style.Theme.Drag.FlyScale - other:GetScale()) < 1e-9)
      assert.are.equal(0, other:GetAlpha())
      local s = other:GetScale()
      local _, _, _, ox, oy = other:GetPoint(1)
      assert.is_true(math.abs(ox * s - 600) < 1e-6 and math.abs(oy * s - 300) < 1e-6)
      assert.is_true(lift.shadow:IsShown(), "the held frame's shadow stays")
    end)

    it("puts it back without ending the hold", function()
      lift:Raise(other)
      lift:Put(flying, parent)
      assert.are.equal(parent, other:GetParent())
      assert.is_true(lift:IsHolding())
      assert.is_true(lift.shadow:IsShown())
      assert.is_true(lift.cover:IsShown())
      assert.is_function(lift.layer:GetScript("OnUpdate"))
    end)

    it("raises it without taking the held frame off the layer's shadow", function()
      lift:Detach()
      lift:Raise(other)
      lift:ApplyStyle(context:New("spec"))
      assert.is_false(lift.shadow:IsShown(), "the held frame is still detached")
    end)
  end)

  it("flies the held frame away from the cursor, its shadow fading", function()
    pick()
    finishTweens()
    local done = 0
    lift:FlyAway(held, 600, 300, function() done = done + 1 end)
    finishTweens()
    assert.are.equal(1, done)
    assert.are.equal(0, lift.shadow:GetAlpha())
    local s = frame:GetScale()
    local _, _, _, ox, oy = frame:GetPoint(1)
    assert.is_true(math.abs((ox * s + 20 * s) - 600) < 1e-6, "the grabbed point at the target")
    assert.is_true(math.abs((oy * s - 10 * s) - 300) < 1e-6)
  end)

  it("ends a hold without moving the frame", function()
    pick()
    finishTweens()
    local point = { frame:GetPoint(1) }
    lift:Release(held)
    assert.is_false(lift:IsHolding())
    assert.is_false(lift.shadow:IsShown())
    assert.is_false(lift.cover:IsShown())
    assert.is_nil(lift.layer:GetScript("OnUpdate"))
    assert.are.same(point, { frame:GetPoint(1) })
    assert.are.equal(lift.layer, frame:GetParent())
  end)

  -- BetterBags Next's small panels have a Bag Scale (docs/next-appearance-size.md): a frame in one is
  -- drawn at that scale, and everything on screen is read in UIParent's units.
  it("scrolls no further than the end it is told, never pulling back from past it", function()
    local box = CreateFrame("Frame", nil, parent)
    local offset = 0
    box.GetDerivedScrollOffset = function() return offset end
    box.GetDerivedScrollRange = function() return 500 end
    box.ScrollToOffset = function(_, to) offset = to end
    local area = CreateFrame("Frame", nil, parent)
    area:_SetRect(0, 100, 100, 400)
    for _ = 1, 400 do
      lift:AutoScroll(area, box, 101, 0.1, 80)
    end
    assert.are.equal(420, offset)
    offset = 450
    lift:AutoScroll(area, box, 101, 0.1, 80)
    assert.are.equal(450, offset, "past it already, it stays")
    lift:AutoScroll(area, box, 499, 0.1, 80)
    assert.is_true(offset < 450, "and scrolls back up when asked")
  end)

  describe("a frame in a scaled panel", function()
    before_each(function()
      parent:SetScale(0.5)
      -- In its own units: on screen 50 to 150 across, its top at 270.
      _G._cursorX, _G._cursorY = 60, 265
    end)

    it("says where it is and how big on screen", function()
      assert.are.equal(0.5, lift:ScaleOf(frame))
      assert.are.same({ 100, 260 }, { lift:Center(frame) })
      assert.are.same({ left = 50, top = 270, scale = 0.5 }, lift:ScreenPoint(frame))
      frame._rect = nil
      assert.is_nil(lift:Center(frame))
    end)

    it("lifts it at its size on screen, the point grabbed under the cursor", function()
      assert.is_true(pick())
      assert.are.same({ 20, 10, 0.5 }, { held.grabX, held.grabY, held.scale })
      assert.are.equal(0.5, frame:GetScale())
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 540 }, { frame:GetPoint(1) })
      finishTweens()
      local s = style.Theme.Drag.LiftScale * 0.5
      assert.is_true(math.abs(held.scale - s) < 1e-9, "shrinks from its size on screen")
      local _, _, _, ox, oy = frame:GetPoint(1)
      assert.is_true(math.abs((ox * s + 20 * s) - 60) < 1e-6, "the grabbed point's x")
      assert.is_true(math.abs((oy * s - 10 * s) - 265) < 1e-6, "the grabbed point's y")
    end)

    it("lands back at its size on screen, or at the scale its owner says", function()
      pick()
      finishTweens()
      lift:Land(held, function() return 50, 270 end, function() end)
      finishTweens()
      assert.are.equal(0.5, frame:GetScale())
      assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 540 }, { frame:GetPoint(1) })
      lift:Release(held)
      held = {}
      pick()
      lift:Land(held, function() return 50, 270, 1.5 end, function() end)
      finishTweens()
      assert.are.equal(1.5, frame:GetScale())
    end)

    it("flies away shrinking from its size on screen", function()
      pick()
      finishTweens()
      lift:FlyAway(held, 600, 300, function() end)
      finishTweens()
      assert.is_true(math.abs(style.Theme.Drag.FlyScale * 0.5 - frame:GetScale()) < 1e-9)
    end)

    it("scrolls an area by where it is on screen", function()
      local area = CreateFrame("Frame", nil, parent)
      -- On screen: its top at 250, its bottom at 50.
      area:_SetRect(0, 100, 300, 400)
      local box = CreateFrame("Frame", nil, area, "WowScrollBox")
      box._scrollRange, box._scrollPercentage = 1000, 0.5
      box.ScrollToOffset = function(self, offset) self._scrolledTo = offset end
      lift:AutoScroll(area, box, 250 - lift.SCROLL_EDGE / 2, 0.1)
      assert.are.equal(500 - 0.5 * lift.SCROLL_SPEED * 0.1, box._scrolledTo, "up, halfway into the edge")
      lift:AutoScroll(area, box, 50, 0.1)
      assert.are.equal(500 + lift.SCROLL_SPEED * 0.1, box._scrolledTo, "down, at the bottom")
      box._scrolledTo = nil
      lift:AutoScroll(area, box, 150, 0.1)
      assert.is_nil(box._scrolledTo, "in the middle on screen")
    end)
  end)

  describe("scrolling near the edges", function()
    local area, box

    before_each(function()
      area = CreateFrame("Frame", nil, UIParent)
      area:_SetRect(0, 100, 300, 400)
      box = CreateFrame("Frame", nil, area, "WowScrollBox")
      box._scrollRange, box._scrollPercentage = 1000, 0.5
      box.ScrollToOffset = function(self, offset) self._scrolledTo = offset end
    end)

    it("scrolls toward the edge the cursor is near, faster the closer", function()
      lift:AutoScroll(area, box, 500 - lift.SCROLL_EDGE / 2, 0.1)
      assert.are.equal(500 - 0.5 * lift.SCROLL_SPEED * 0.1, box._scrolledTo, "up, halfway into the edge")
      lift:AutoScroll(area, box, 100, 0.1)
      assert.are.equal(500 + lift.SCROLL_SPEED * 0.1, box._scrolledTo, "down, at the bottom")
    end)

    it("does not scroll away from the edges, past the top, or before the client placed it", function()
      lift:AutoScroll(area, box, 300, 0.1)
      assert.is_nil(box._scrolledTo)
      box._scrollPercentage = 0
      lift:AutoScroll(area, box, 500, 0.1)
      assert.are.equal(0, box._scrolledTo)
      box._scrolledTo = nil
      area._rect = nil
      lift:AutoScroll(area, box, 500, 0.1)
      assert.is_nil(box._scrolledTo)
    end)
  end)
end)
