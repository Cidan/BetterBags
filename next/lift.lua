local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextLift lifts a frame to drag it: BetterBags Next's sections (NextDrag, next.md §7) and the settings
-- lists' rows (NextListReorder, next-settings.md §5), so every drag looks and moves the same (CLAUDE.md,
-- "UI Consistency"). A frame picked up leaves its parent for the drag layer (a full-screen frame on
-- UIParent in the TOOLTIP strata that takes no mouse) at exactly the place it was on screen, raised
-- above it, a cover over it taking the release and a shadow under it; it shrinks to the theme's
-- Drag.LiftScale around the point grabbed over Time.Lift and follows the cursor, that point staying
-- under it, until its owner lands it (back to full size where the owner says, over Time.Land) and puts
-- it back. One frame is held at a time. It also flies frames it does not hold (a section docked in a
-- panel, NextDock: into its card, back to its bag, away into the panel), leaving the held frame's shadow
-- and cover alone.
---@class NextLift: AceModule
---@field layer? Frame
---@field shadow? Texture
---@field cover? Frame
---@field held? NextLifted The frame held, from Pick until Put.
---@field detached boolean The held frame left the layer for a while (a dock): no shadow, no cover.
local lift = addon:NewModule('NextLift')

-- How far from a scroll area's top or bottom a drag scrolls it, and how fast at the edge (per second).
lift.SCROLL_EDGE = 40
lift.SCROLL_SPEED = 700
-- How far past a lifted frame's edges its cover reaches: the client starts a drag only once the cursor
-- has moved a little, so the point grabbed can be just outside the frame.
lift.COVER_MARGIN = 20
-- How far above the highest frame in a lifted frame its cover sits, for frames drawn into it while it
-- is lifted.
lift.COVER_ABOVE = 100
-- The highest frame level there is (warcraft.wiki.gg "Frame Strata").
lift.MAX_LEVEL = 10000

lift.detached = false

-- NextLifted is what a drag holds while its frame is lifted, kept by its owner (the owner's drag state).
---@class NextLifted
---@field frame Frame
---@field grabX number From the frame's left to the cursor at pickup.
---@field grabY number From the frame's top down to the cursor at pickup.
---@field scale number
---@field landing boolean It was let go: it no longer follows the cursor.

-- NextDragPoint is where a flight starts from: a top left in UIParent's coordinates, at a scale (a
-- frame leaving a dock, not the cursor).
---@class (exact) NextDragPoint
---@field left number
---@field top number
---@field scale number

-- Cursor returns the cursor's position in UIParent's coordinates.
---@return number x, number y
function lift:Cursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

-- MaxLevel returns the highest frame level in frame and every frame below it.
---@param frame Frame
---@return number
function lift:MaxLevel(frame)
  local level = frame:GetFrameLevel()
  for _, child in ipairs({ frame:GetChildren() }) do
    level = math.max(level, self:MaxLevel(child))
  end
  return level
end

-- ScreenPoint returns a frame's top left in UIParent's coordinates and its scale relative to UIParent,
-- or nil before the client has placed it. The client reports a frame's edges in the frame's own
-- effective scale.
---@param frame Frame
---@return NextDragPoint?
function lift:ScreenPoint(frame)
  local left, top = frame:GetLeft(), frame:GetTop()
  if left == nil or top == nil then
    return nil
  end
  local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return { left = left * scale, top = top * scale, scale = scale }
end

-- Layer makes the drag layer the first time (with the shadow a lifted frame casts and the cover over
-- it) and returns it.
---@return Frame
function lift:Layer()
  if self.layer then
    return self.layer
  end
  local layer = CreateFrame("Frame", "BetterBagsNextDragLayer", UIParent)
  layer:SetAllPoints(UIParent)
  layer:SetFrameStrata("TOOLTIP")
  layer:EnableMouse(false)
  local shadow = layer:CreateTexture(nil, "BACKGROUND")
  shadow:Hide()
  -- The cover lies over a lifted frame and takes the mouse, so the release lands on it and not on
  -- something in the frame: a section's item button's OnReceiveDrag is a left click
  -- (ContainerFrameItemButtonMixin), which picks the item up. It does nothing with it. A drop is found
  -- by position, so it never depends on what is under the cursor.
  local cover = CreateFrame("Frame", nil, layer)
  cover:EnableMouse(true)
  cover:Hide()
  self.layer = layer
  self.shadow = shadow
  self.cover = cover
  self:styleShadow()
  sonataNext:RegisterWidget(self)
  return layer
end

-- raise takes a frame onto the layer, above it. Never lower it: every frame in it moves with it, and one
-- that would go below 0 jumps to the top level (warcraft.wiki.gg "Frame Strata"), where the cover could
-- not be above it.
---@param frame Frame
local function raise(frame)
  frame:SetParent(lift.layer)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(math.max(frame:GetFrameLevel(), lift.layer:GetFrameLevel() + 2))
end

-- IsHolding says whether a frame is lifted.
---@return boolean
function lift:IsHolding()
  return self.held ~= nil
end

-- Pick lifts frame for held (its owner's drag state, which it fills in), unless the client has not
-- placed it yet. onFrame runs every frame until the frame is put back (Put). It returns whether it did.
---@param held NextLifted
---@param frame Frame
---@param onFrame fun(elapsed: number)
---@return boolean
function lift:Pick(held, frame, onFrame)
  local left, top = frame:GetLeft(), frame:GetTop()
  if left == nil or top == nil then
    return false
  end
  self:Layer()
  local x, y = self:Cursor()
  held.frame, held.grabX, held.grabY, held.scale, held.landing = frame, x - left, top - y, 1, false
  self.held, self.detached = held, false
  GameTooltip:Hide()
  raise(frame)
  self:Place(held, x, y)
  local D = style.Theme.Drag
  self:anchorShadow()
  self.shadow:SetAlpha(0)
  local cover = self.cover
  cover:ClearAllPoints()
  cover:SetPoint("TOPLEFT", frame, "TOPLEFT", -self.COVER_MARGIN, self.COVER_MARGIN)
  cover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", self.COVER_MARGIN, -self.COVER_MARGIN)
  cover:SetFrameLevel(math.min(self.MAX_LEVEL, self:MaxLevel(frame) + self.COVER_ABOVE))
  cover:Show()
  tween:Play(held, {
    duration = style.Time.Lift,
    from = 0,
    to = 1,
    ease = style:Ease("Lift"),
    onUpdate = function(t)
      held.scale = 1 - (1 - D.LiftScale) * t
      self.shadow:SetAlpha(self:ShadowAlpha() * t)
      if not held.landing then
        self:Place(held, self:Cursor())
      end
    end,
  })
  self.layer:SetScript("OnUpdate", function(_, elapsed)
    onFrame(elapsed)
  end)
  return true
end

-- Place puts the held frame so that the point grabbed is at x, y, at its scale.
---@param held NextLifted
---@param x number
---@param y number
function lift:Place(held, x, y)
  local frame, s = held.frame, held.scale
  frame:SetScale(s)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x - held.grabX * s) / s, (y + held.grabY * s) / s)
end

-- Land flies a frame from where it is (the cursor's place, or from) to the top left to(left0, top0)
-- returns (UIParent's coordinates, asked every frame: the place may still be moving; left0, top0 is
-- where the flight started) and to the scale it returns third (full size when it returns none), the held
-- frame's shadow fading, then calls onDone, which puts it back (Put).
---@param held NextLifted
---@param to fun(left0: number, top0: number): number, number, number?
---@param onDone fun()
---@param from? NextDragPoint
function lift:Land(held, to, onDone, from)
  local frame = held.frame
  local s0 = from and from.scale or held.scale
  -- Where Place put it: the client reports a scaled frame's edges in its own scale.
  local cx, cy = self:Cursor()
  local left0, top0 = cx - held.grabX * s0, cy + held.grabY * s0
  if from then
    left0, top0 = from.left, from.top
  end
  local shadow0 = self.shadow:GetAlpha()
  tween:Play(held, {
    duration = style.Time.Land,
    from = 0,
    to = 1,
    ease = style:Ease("Land"),
    onUpdate = function(t)
      local left, top, s1 = to(left0, top0)
      local s = s0 + ((s1 or 1) - s0) * t
      local x, y = left0 + (left - left0) * t, top0 + (top - top0) * t
      frame:SetScale(s)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
      if held == self.held then
        self.shadow:SetAlpha(shadow0 * (1 - t))
      end
    end,
    onDone = onDone,
  })
end

-- FlyAway flies a frame from where it is (the cursor's place, or from) into a point (UIParent's
-- coordinates), its grabbed point travelling there, shrinking to the theme's Drag.FlyScale and fading
-- over Time.FlyAway (the held frame's shadow too), then calls onDone (a section moved into a tab, the
-- other bag, a vendor).
---@param held NextLifted
---@param x number
---@param y number
---@param onDone fun()
---@param from? NextDragPoint
function lift:FlyAway(held, x, y, onDone, from)
  local frame = held.frame
  local s0 = from and from.scale or held.scale
  local x0, y0 = self:Cursor()
  if from then
    held.scale = s0
    x0, y0 = from.left + held.grabX * s0, from.top - held.grabY * s0
  end
  local flyScale, shadow = style.Theme.Drag.FlyScale, self:ShadowAlpha()
  tween:Play(held, {
    duration = style.Time.FlyAway,
    from = 0,
    to = 1,
    ease = style:Ease("FlyAway"),
    onUpdate = function(t)
      held.scale = s0 + (flyScale - s0) * t
      frame:SetAlpha(1 - t)
      if held == self.held then
        self.shadow:SetAlpha(shadow * (1 - t))
      end
      self:Place(held, x0 + (x - x0) * t, y0 + (y - y0) * t)
    end,
    onDone = onDone,
  })
end

-- Detach hides the shadow and the cover: the held frame leaves the layer for a while (a dock) and the
-- drag goes on.
function lift:Detach()
  self.detached = true
  self.shadow:Hide()
  self.cover:Hide()
end

-- Raise takes a frame onto the layer where it is on screen (the held frame back from a dock, or a frame
-- it is to fly), and returns where that is (nil before the client placed it), for its flight.
---@param frame Frame
---@return NextDragPoint?
function lift:Raise(frame)
  local from = self:ScreenPoint(frame)
  self:Layer()
  raise(frame)
  if self.held ~= nil and self.held.frame == frame then
    self.detached = false
  end
  if from then
    frame:SetScale(from.scale)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", from.left / from.scale, from.top / from.scale)
  end
  return from
end

-- Put puts a frame back in parent, at full size, one level above parent, with no anchors (its owner
-- places it), and ends its lift (Release).
---@param held NextLifted
---@param parent Frame
function lift:Put(held, parent)
  local frame = held.frame
  self:Release(held)
  frame:SetParent(parent)
  frame:SetScale(1)
  frame:SetAlpha(1)
  frame:SetFrameStrata(parent:GetFrameStrata())
  frame:SetFrameLevel(parent:GetFrameLevel() + 1)
  frame:ClearAllPoints()
end

-- Release ends a frame's lift where the frame is: its flight stops, and, for the held frame, the shadow
-- and the cover hide and the frame callback stops (a section handed to a dock, NextDock).
---@param held NextLifted
function lift:Release(held)
  tween:Stop(held)
  if self.held ~= held then
    return
  end
  self.held = nil
  self.detached = false
  self.shadow:Hide()
  self.cover:Hide()
  self.layer:SetScript("OnUpdate", nil)
end

-- ShadowAlpha is how dark the shadow under a lifted frame gets (the theme's Drag.Shadow), 0 with none.
---@return number
function lift:ShadowAlpha()
  local shadow = style.Theme.Drag.Shadow
  return shadow and shadow.Alpha or 0
end

-- AutoScroll scrolls box while y (UIParent's coordinates) is near the top or bottom of area, faster the
-- closer, never above its top.
---@param area Frame
---@param box WowScrollBox
---@param y number
---@param elapsed number
function lift:AutoScroll(area, box, y, elapsed)
  local top, bottom = area:GetTop(), area:GetBottom()
  if top == nil or bottom == nil then
    return
  end
  local edge = self.SCROLL_EDGE
  local closeness = 0
  if y > top - edge then
    closeness = -math.min(1, (y - (top - edge)) / edge)
  elseif y < bottom + edge then
    closeness = math.min(1, ((bottom + edge) - y) / edge)
  end
  if closeness ~= 0 then
    box:ScrollToOffset(math.max(0, box:GetDerivedScrollOffset() + closeness * self.SCROLL_SPEED * elapsed), true)
  end
end

-- anchorShadow lays the shadow round the held frame (the theme's Drag.Shadow spread), shown while the
-- theme has one.
---@private
function lift:anchorShadow()
  local D = style.Theme.Drag
  local spread = D.Shadow and D.Shadow.Spread or 0
  self.shadow:ClearAllPoints()
  self.shadow:SetPoint("TOPLEFT", self.held.frame, "TOPLEFT", -spread, spread)
  self.shadow:SetPoint("BOTTOMRIGHT", self.held.frame, "BOTTOMRIGHT", spread, -spread)
  self.shadow:SetShown(D.Shadow and true or false)
end

-- styleShadow colors the shadow from the theme (Drag.Shadow), hidden with none.
---@private
function lift:styleShadow()
  local D = style.Theme.Drag
  if D.Shadow then
    style:Paint(self.shadow, { Color = D.Shadow.Color })
  else
    self.shadow:Hide()
  end
end

-- ApplyStyle restyles the shadow for the theme SonataNext applied, laid round the frame held again
-- while it is on the layer.
---@param ctx Context
function lift:ApplyStyle(ctx)
  local _ = ctx
  if self.layer == nil then
    return
  end
  self:styleShadow()
  if self.held ~= nil and not self.detached then
    self:anchorShadow()
  end
end
