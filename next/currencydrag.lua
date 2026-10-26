local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Currencies: AceModule
local currencies = addon:GetModule('Currencies')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

---@class NextSparkles: AceModule
local sparkles = addon:GetModule('NextSparkles')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextCurrencyDrag drags one tracked currency or item on its own (.claude/rules/currency.md §5a): picked up with Shift
-- from the backpack's strip or the tracker (asked: "shift click -> drag them off the tracker individually (this means
-- shift click -> drag doesn't move the bar, or create the popout)"), as an action is pulled off a locked action bar.
-- It is lifted alone (NextLift: the sections' lift and shadow), the entries round it closing up. Over the strip or the
-- tracker (each a view of the same tracked list), a room opens where it would land, and letting go puts it there (the
-- tracked order, Currencies:Move); anywhere else, letting go stops tracking it, in a puff of sparkles.
---@class NextCurrencyDrag: AceModule
---@field containers NextCurrencyContainer[] The strip and the tracker.
---@field held? NextCurrencyEntryDrag
---@field hint? FontString What letting go does, under the entry held.
---@field burst? NextSparkleEmitter The puff, on the drag layer.
local drag = addon:NewModule('NextCurrencyDrag')

-- NextCurrencyContainer is what shows the tracked list and takes an entry dragged on its own: the strip, the tracker.
---@class NextCurrencyContainer
---@field frame Frame
---@field IsOver fun(self: any, x: number, y: number): boolean The cursor (UIParent's coordinates) is over it.
---@field IndexAt fun(self: any, x: number, y: number): number How many of its entries the room goes after.
---@field RoomPoint fun(self: any): number?, number?, number? The room's top left (UIParent's coordinates), its scale.
---@field Keys fun(self: any): string[] What it shows, in order, the entry held left out.
---@field Relayout fun(self: any, ctx: Context)

-- NextCurrencyEntryDrag is the entry held: NextLift fills in where it was grabbed and its scale.
---@class NextCurrencyEntryDrag: NextLifted
---@field key string
---@field kind NextCurrencyKind
---@field id number
---@field source NextCurrencyContainer What it was picked up from, whose entry it is.
---@field over? NextCurrencyContainer Where it would land.
---@field index? number Its room among over's entries.
---@field released? number Frames the left button was found up.

drag.containers = {}

-- Register adds a container (the strip, the tracker, as each is made).
---@param container NextCurrencyContainer
function drag:Register(container)
  table.insert(self.containers, container)
end

-- Local turns a point (UIParent's coordinates) into a container frame's own: from its top left, down, in its units;
-- nothing before the client placed it. It also returns where the frame is (NextLift:ScreenPoint).
---@param frame Frame
---@param x number
---@param y number
---@return number? x, number? y, NextDragPoint? at
function drag:Local(frame, x, y)
  local at = lift:ScreenPoint(frame)
  if at == nil then
    return nil, nil, nil
  end
  return (x - at.left) / at.scale, (at.top - y) / at.scale, at
end

-- Near says whether a point in a container frame's own coordinates (Local) is on it or within an icon of it.
---@param frame Frame
---@param x? number
---@param y? number
---@return boolean
function drag:Near(frame, x, y)
  if x == nil or y == nil then
    return false
  end
  local m = style.Theme.Currency.Icon
  return x >= -m and x <= frame:GetWidth() + m and y >= -m and y <= frame:GetHeight() + m
end

-- Count is how many of centers (along a container's axis, its own coordinates) are before at: where its room goes.
---@param centers number[]
---@param at number
---@return number
function drag.Count(centers, at)
  local n = 0
  for _, c in ipairs(centers) do
    if c < at then
      n = n + 1
    end
  end
  return n
end

-- HeldKey is the key of the entry held, or nothing.
---@return string?
function drag:HeldKey()
  return self.held and self.held.key or nil
end

-- Lifts says whether a frame is the entry held: its container leaves it alone (it is on the drag layer).
---@param frame Frame
---@return boolean
function drag:Lifts(frame)
  return self.held ~= nil and self.held.frame == frame
end

-- IsFrom says whether the entry held came from a container.
---@param container NextCurrencyContainer
---@return boolean
function drag:IsFrom(container)
  return self.held ~= nil and self.held.source == container
end

-- RoomIn is where the room is in a container: after how many of its entries (nothing: no room there).
---@param container NextCurrencyContainer
---@return number?
function drag:RoomIn(container)
  local held = self.held
  if held == nil or held.over ~= container then
    return nil
  end
  return held.index
end

---@param ctx? Context
function drag:ApplyStyle(ctx)
  local _ = ctx
  if self.hint then
    style:SetFont(self.hint, style.Theme.Drag.HintFont)
  end
end

-- parts makes the hint and the puff's emitter on the drag layer, the first time.
---@private
function drag:parts()
  if self.hint then
    return
  end
  local layer = lift:Layer()
  self.hint = layer:CreateFontString(nil, "OVERLAY")
  style:SetFont(self.hint, style.Theme.Drag.HintFont)
  self.hint:Hide()
  self.burst = sparkles:Create(layer, {
    Direction = 1,
    Spawn = function() return self.burstX or 0, self.burstY or 0 end,
  })
  sonataNext:RegisterWidget(self)
end

-- Start lifts an entry alone out of a container: nothing else held or dragged, no item on the cursor. It returns
-- whether it did.
---@param ctx Context
---@param source NextCurrencyContainer
---@param e NextCurrencyEntryFrame
---@return boolean
function drag:Start(ctx, source, e)
  local state = e.state
  if self.held ~= nil or state == nil or lift:IsHolding() or nextDrag:IsActive() or CursorHasItem() then
    return false
  end
  self:parts()
  ---@type NextCurrencyEntryDrag
  local held = { key = state.key, kind = state.kind, id = state.id, source = source }
  if not lift:Pick(held, e.frame, function(elapsed) self:Update(elapsed) end) then
    return false
  end
  self.held = held
  GameTooltip:Hide()
  e:Settle()
  -- Its room starts at its own place, so nothing moves until the cursor does: where the room goes is worked out from
  -- where the others are with the room among them.
  for i, key in ipairs(source:Keys()) do
    if key == held.key then
      held.over, held.index = source, i - 1
    end
  end
  self:relayout(ctx)
  if self:follow() then
    self:relayout(ctx)
  end
  return true
end

-- follow finds where the entry would land under the cursor and says what letting go does; it returns whether that
-- changed.
---@private
---@return boolean
function drag:follow()
  local held = self.held
  if held == nil then
    return false
  end
  local x, y = lift:Cursor()
  local over, index
  for _, container in ipairs(self.containers) do
    if container.frame:IsVisible() and container:IsOver(x, y) then
      over, index = container, container:IndexAt(x, y)
      break
    end
  end
  local changed = over ~= held.over or index ~= held.index
  held.over, held.index = over, index
  local hint = self.hint
  hint:SetText(over and L:G("Move Here") or L:G("Stop Tracking"))
  hint:ClearAllPoints()
  hint:SetPoint("TOP", held.frame, "BOTTOM", 0, -style.Theme.Drag.HintGap)
  hint:Show()
  return changed
end

-- Update follows the cursor while the entry is held: the room moves under it. A release the client missed lets it
-- go (as NextDrag does).
---@param elapsed number
function drag:Update(elapsed)
  local _ = elapsed
  local held = self.held
  if held == nil or held.landing then
    return
  end
  if not IsMouseButtonDown("LeftButton") then
    held.released = (held.released or 0) + 1
    if held.released >= 2 then
      self:Drop(context:New('NextCurrencyDrag_Drop'))
      return
    end
  else
    held.released = 0
  end
  if not tween:IsPlaying(held) then
    lift:Place(held, lift:Cursor())
  end
  if self:follow() then
    self:relayout(context:New('NextCurrencyDrag_Room'))
  end
end

-- relayout lays every container out again: the entry held left out, a room where it would land.
---@private
---@param ctx Context
function drag:relayout(ctx)
  for _, container in ipairs(self.containers) do
    container:Relayout(ctx)
  end
end

-- afterFor turns a room into Currencies:Move's place: after the entry at that place in the tracked list as it was
-- (counted with the entry held; 0: first). Nothing when it lands among no other entry.
---@private
---@param container NextCurrencyContainer
---@param index number
---@return number?
function drag:afterFor(container, index)
  local others = container:Keys()
  if #others == 0 then
    return nil
  end
  local positions = {}
  for i, entry in ipairs(currencies:Tracked()) do
    positions[currencies:Key(entry.kind, entry.id)] = i
  end
  if index < #others then
    local before = positions[others[index + 1]]
    return before and before - 1 or nil
  end
  return positions[others[#others]]
end

-- Drop lets the entry go: into its room, moving it there in the tracked order; anywhere else it stops being tracked,
-- shrinking away where it was let go in a puff of sparkles.
---@param ctx Context
function drag:Drop(ctx)
  local held = self.held
  if held == nil or held.landing then
    return
  end
  held.landing = true
  tween:Stop(held)
  self.hint:Hide()
  local over, index = held.over, held.index
  if over ~= nil and index ~= nil then
    local after = self:afterFor(over, index)
    lift:Land(held, function(left0, top0)
      local left, top, s = over:RoomPoint()
      if left == nil then
        return left0, top0
      end
      return left, top, s
    end, function()
      self:finish(held)
      if after == nil or not currencies:Move(context:New('NextCurrencyDrag_Move'), held.key, after) then
        self:relayout(context:New('NextCurrencyDrag_Landed'))
      end
    end)
    return
  end
  local x, y = lift:Cursor()
  self:puff(x, y)
  currencies:Untrack(ctx, held.kind, held.id)
  lift:FlyAway(held, x, y, function()
    self:finish(held)
    self:relayout(context:New('NextCurrencyDrag_Removed'))
  end)
end

-- puff bursts the theme's pop sparkles where the entry was let go (UIParent's coordinates).
---@private
---@param x number
---@param y number
function drag:puff(x, y)
  local S = style.Theme.Sparkles
  local spec = S and S.Pop
  if not spec then
    return
  end
  local o = self.burst.options
  for _, key in ipairs({ "Rate", "Max", "Life", "Size", "Speed", "Rise", "Wobble", "Spin", "Alpha" }) do
    o[key] = spec[key]
  end
  self.burst:SetEnabled(true)
  self.burstX, self.burstY = x, y - UIParent:GetHeight()
  local n = spec.Burst or 6
  o.Direction = -1
  self.burst:Burst(math.ceil(n / 2))
  o.Direction = 1
  self.burst:Burst(math.floor(n / 2))
end

-- finish puts the entry back in the container it came from and forgets it: that container places it.
---@private
---@param held NextCurrencyEntryDrag
function drag:finish(held)
  lift:Put(held, held.source.frame)
  if self.held == held then
    self.held = nil
  end
end

-- Cancel puts the entry held straight back where it was, nothing changed (its container hid, BetterBags Next was
-- switched off).
---@param ctx Context
function drag:Cancel(ctx)
  local held = self.held
  if held == nil then
    return
  end
  self.hint:Hide()
  self:finish(held)
  self:relayout(ctx)
end

-- MovingParts are what moves by nature (next-pixel-perfect.md): the puff.
---@param parts table<table, boolean>
function drag:MovingParts(parts)
  if self.burst then
    parts[self.burst] = true
  end
end
