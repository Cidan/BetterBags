local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Currencies: AceModule
local currencies = addon:GetModule('Currencies')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class NextCurrencyDrag: AceModule
local currencyDrag = addon:GetModule('NextCurrencyDrag')

---@class NextCurrencyEntry: AceModule
local currencyEntry = addon:GetModule('NextCurrencyEntry')

---@class NextScreenCard: AceModule
local card = addon:GetModule('NextScreenCard')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class Texels: AceModule
local texels = addon:GetModule('Texels')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

-- NextCurrencyTracker is the currency tracker dragged out of the backpack (.claude/rules/currency.md §5): a copy of
-- the strip at the bottom of the backpack, a card (NextScreenCard) that stays where it was dropped, the bag open or not.
-- One at a time: picking the strip up again picks this one up. Dropped back on the backpack, it flies into the strip
-- and is put away (the strip stays: it was a copy). Its layout (a row, a column, a list with names), scale, background
-- and whether it hides in combat are the player's (the Currency page's Display tab).
---@class NextCurrencyTracker: AceModule
---@field instance? NextCurrencyTrackerFrame
local tracker = addon:NewModule('NextCurrencyTracker')

---@class NextCurrencyTrackerFrame: NextScreenCardFrame, NextCurrencyOwner, NextCurrencyContainer
---@field entries table<string, NextCurrencyEntryFrame>
---@field order string[] The keys shown, in order.
---@field strip? NextCurrencyStripFrame The backpack's strip it is a copy of.
---@field heldState? NextCurrencyState What an entry dragged on its own (NextCurrencyDrag) reads, while one is.
---@field centers number[] Each shown entry's middle along its layout (x in a row, y down otherwise), from the top left.
---@field roomX? number Where the room for an entry held is.
---@field roomY? number
local trackerProto = card:Extend({})
addon:GetModule('Perf'):RegisterPrototype(trackerProto, 'NextCurrencyTrackerFrame')

-- NextCurrencyTrackerDrag is the tracker held (NextScreenCardDrag): popped, it came out of the strip.
---@class NextCurrencyTrackerDrag: NextScreenCardDrag

-- Create makes the tracker the first time (for the backpack's strip) and returns it.
---@param strip NextCurrencyStripFrame
---@return NextCurrencyTrackerFrame
function tracker:Create(strip)
  if self.instance then
    self.instance.strip = strip
    return self.instance
  end
  ---@type NextCurrencyTrackerFrame
  local t = setmetatable({ entries = {}, order = {}, strip = strip, centers = {} }, { __index = trackerProto })
  card:Build(t, "BetterBagsNextCurrencyTracker")
  self.instance = t
  currencyDrag:Register(t)
  sonataNext:RegisterWidget(t)
  t:Watch()
  t:Style()
  pixelAudit:Register(t.frame, {
    title = L:G("Currency Tracker"), owners = { tracker = t },
    skip = function() return t:MovingParts() end,
  })
  return t
end

-- Watch follows what changes what it shows (its card follows what hides it: NextScreenCard).
---@private
function trackerProto:Watch()
  events:RegisterMessage('currencies/Updated', function(ctx, gains)
    self:Draw(ctx, gains)
  end)
  events:RegisterMessage('currencies/Changed', function(ctx)
    self:Draw(ctx)
  end)
  events:RegisterMessage('currencies/OptionsChanged', function(ctx)
    self:Reanchor()
    self:Style()
    self:Draw(ctx)
    self:UpdateShown(ctx)
  end)
end

-- The card's (NextScreenCard): the Currencies page's Display tab, where it was left, the backpack's strip.

---@param name NextCurrencyOption
---@return any
function trackerProto:Option(name)
  return database:GetNextCurrencyOption(name)
end

---@return boolean out, number? x, number? y
function trackerProto:Saved()
  return database:GetNextCurrencyTracker()
end

---@param out boolean
---@param x? number
---@param y? number
function trackerProto:Save(out, x, y)
  database:SetNextCurrencyTracker(out, x, y)
end

---@return NextBackpack?
function trackerProto:Home()
  return self.strip and self.strip.panel
end

-- Over the backpack, the strip lights.
---@param on boolean
function trackerProto:SetHomeLit(on)
  if self.strip then
    self.strip:SetDropTarget(on)
  end
end

-- It flies into the strip.
---@return number? x, number? y
function trackerProto:PutAwayPoint()
  return lift:Center(self.strip.frame)
end

-- The strip welcomes it back.
---@param ctx Context
function trackerProto:OnPutAway(ctx)
  local _ = ctx
  if self.strip then
    self.strip:Welcome()
  end
end

-- Something shows in it, or an entry of its own is dragged on its own (it stays shown, to drop it back).
---@return boolean
function trackerProto:Wants()
  return #self.order > 0 or currencyDrag:IsFrom(self)
end

function trackerProto:StyleContent()
  for _, e in pairs(self.entries) do
    e:Style()
  end
end

function trackerProto:OnCardHidden()
  for _, e in pairs(self.entries) do
    e:Settle()
  end
end

-- An entry of its own dragged on its own goes back as BetterBags Next is switched off.
---@param ctx Context
function trackerProto:OnDeactivate(ctx)
  if currencyDrag:IsFrom(self) then
    currencyDrag:Cancel(ctx)
  end
end

-- entryFor returns the entry drawing a key, made the first time.
---@private
---@param key string
---@return NextCurrencyEntryFrame
function trackerProto:entryFor(key)
  local e = self.entries[key]
  if e == nil then
    e = currencyEntry:Create(self.frame, self)
    self.entries[key] = e
  end
  return e
end

-- Draw shows what is tracked (none of what you have none of, unless the Display tab says to), in its layout, and plays
-- each gain while it shows.
---@param ctx Context
---@param gains? table<string, number>
function trackerProto:Draw(ctx, gains)
  local hideEmpty = database:GetNextCurrencyOption("hideEmpty")
  local bars = database:GetNextCurrencyOption("capBars")
  local layout = self:Layout()
  local order = {}
  local shown = {}
  -- An entry dragged on its own is left out (NextCurrencyDrag), a room its size where it would land.
  local heldKey = currencyDrag:HeldKey()
  self.heldState = nil
  for _, state in ipairs(currencies:States()) do
    if state.key == heldKey then
      self.heldState = state
      self:entryFor(state.key):Draw(state, layout, bars)
    elseif not (hideEmpty and state.none) then
      local e = self:entryFor(state.key)
      e:Draw(state, layout, bars)
      table.insert(order, state.key)
      shown[state.key] = true
    end
  end
  for key, e in pairs(self.entries) do
    if not shown[key] and not currencyDrag:Lifts(e.frame) then
      e.frame:Hide()
    end
  end
  self.order = order
  self:LayOut()
  self:UpdateShown(ctx)
  if gains and self.frame:IsVisible() and database:GetNextCurrencyOption("gains") then
    for key, delta in pairs(gains) do
      local e = shown[key] and self.entries[key]
      if e then
        e:Gain(delta)
        if delta > 0 then
          self:Burst(e)
        end
      end
    end
  end
end

-- LayOut places the entries in the tracker's layout, the card Pad round them, on whole pixels; entries that moved
-- glide there (Motion) while it shows.
function trackerProto:LayOut()
  local T = style.Theme.Currency.Tracker
  local frame = self.frame
  local layout = self:Layout()
  -- Held, it is at the lift's scale.
  if self.held == nil then
    frame:SetScale(self:Scale())
  end
  local pad = pixel:Length(frame, T.Pad)
  local gap = pixel:Length(frame, layout == "row" and style.Theme.Currency.Gap or T.RowGap)
  local sizes, widest = {}, 0
  for i, key in ipairs(self.order) do
    local e = self.entries[key]
    local w, h = e:Measure(layout == "list" and T.ListWidth or nil)
    sizes[i] = { w, h }
    widest = math.max(widest, w)
  end
  -- The room for an entry dragged on its own (NextCurrencyDrag), its size, after roomIndex of the others.
  local roomIndex = self.heldState and currencyDrag:RoomIn(self)
  local roomW, roomH = 0, 0
  if roomIndex ~= nil then
    roomIndex = math.min(roomIndex, #self.order)
    roomW, roomH = self.entries[self.heldState.key]:Measure(layout == "list" and T.ListWidth or nil)
    widest = math.max(widest, roomW)
  end
  local visible = frame:IsVisible()
  if visible then
    motion:BeginPass(frame, style.Time.Interaction, style.StopMotion)
  end
  local x, y, width, height = pad, pad, 0, 0
  local centers, roomX, roomY = {}, nil, nil
  -- room steps past the room before the n-th entry (or at the end), its size counted as an entry's.
  local function room(n)
    if roomIndex ~= n then
      return
    end
    roomX, roomY = x, y
    if layout == "row" then
      x = x + roomW + gap
      width, height = x - gap + pad, math.max(height, roomH)
    else
      y = y + roomH + gap
      width, height = pad + widest + pad, y - gap - pad
    end
  end
  for i, key in ipairs(self.order) do
    room(i - 1)
    local e = self.entries[key]
    local w, h = sizes[i][1], sizes[i][2]
    if layout ~= "row" then
      w = widest
    end
    e:Place(w, h)
    motion:Place(e.frame, frame, x, -y)
    e.frame:Show()
    if layout == "row" then
      centers[i] = x - pad + w / 2
      x = x + w + gap
      width, height = x - gap + pad, math.max(height, h)
    else
      centers[i] = y - pad + h / 2
      y = y + h + gap
      width, height = pad + w + pad, y - gap - pad
    end
  end
  if roomX == nil then
    room(#self.order)
  end
  self.centers, self.roomX, self.roomY = centers, roomX, roomY
  if visible then
    motion:EndPass()
  end
  pixel:Size(frame, math.max(width, pad * 2), pad + height + pad)
  texels:Unsharpen(frame)
end

-- PopOut pulls a copy of the strip out of the backpack: the tracker, laid out where the strip is and as big, pops out
-- of it under the cursor (a little past its size and back, sparkles bursting) and follows it. A tracker already out
-- flies from where it is to the cursor instead: there is one at a time. It shows what is tracked now (it was made with
-- the backpack, maybe after the currencies were read). It returns whether it did.
---@param ctx Context
---@param strip NextCurrencyStripFrame
---@return boolean
function trackerProto:PopOut(ctx, strip)
  if not self:CanPick() or #currencies:Tracked() == 0 then
    return false
  end
  self.strip = strip
  local from = self.frame:IsShown() and lift:ScreenPoint(self.frame) or nil
  self:Draw(ctx)
  -- Laid out where the strip is, at its size on screen, so the copy comes out of it.
  local at = lift:ScreenPoint(strip.frame)
  if at == nil then
    return false
  end
  tween:Stop(self.alphaKey)
  self.frame:SetAlpha(1)
  self.frame:Show()
  self:LayOut()
  local pad = pixel:Length(self.frame, style.Theme.Currency.Tracker.Pad)
  local s = at.scale
  self.frame:SetScale(s)
  self.frame:ClearAllPoints()
  self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", at.left / s - pad, at.top / s + pad)
  local held = { over = false, popped = from == nil }
  ---@cast held NextCurrencyTrackerDrag
  if not lift:Pick(held, self.frame, function(elapsed) self:Update(elapsed) end) then
    return false
  end
  self.held = held
  self:pop(held, from)
  if from == nil then
    self:Burst(nil, held)
  end
  GameTooltip:Hide()
  return true
end

-- OpenSettings opens the settings window on the Currencies page's Display tab, where the tracker's options are.
function trackerProto:OpenSettings()
  addon:GetModule('NextSettings'):Open("currencies", "display")
end

-- The entries' owner (NextCurrencyOwner).

---@param ctx Context
---@param e NextCurrencyEntryFrame
---@param button string
function trackerProto:EntryClicked(ctx, e, button)
  if button == "RightButton" then
    self:OpenSettings()
    return
  end
  if self.strip and IsShiftKeyDown() and e.state and e.state.kind == "item" then
    self.strip:FindItem(ctx, e.state)
  end
end

-- DragStart picks the tracker up; with Shift held, nothing (Shift drags one entry on its own).
function trackerProto:DragStart()
  if IsShiftKeyDown() then
    return
  end
  self:PickUp()
end

-- EntryHovered fades the faint card in: the pointer came onto one of its entries (maybe straight from outside).
---@param e NextCurrencyEntryFrame
function trackerProto:EntryHovered(e)
  local _ = e
  self:SetHovered(true)
end

-- EntryDragStart picks the tracker up, or with Shift, drags the entry on its own.
---@param ctx Context
---@param e NextCurrencyEntryFrame
function trackerProto:EntryDragStart(ctx, e)
  if IsShiftKeyDown() then
    currencyDrag:Start(ctx, self, e)
    return
  end
  self:PickUp()
end

---@param ctx Context
---@param e NextCurrencyEntryFrame
function trackerProto:EntryDragStop(ctx, e)
  if currencyDrag:Lifts(e.frame) then
    currencyDrag:Drop(ctx)
    return
  end
  self:Drop(ctx)
end

---@param ctx Context
---@param e NextCurrencyEntryFrame
function trackerProto:EntryReceiveDrag(ctx, e)
  local _ = e
  if self.strip then
    self.strip:TrackCursorItem(ctx)
  end
end

---@param e NextCurrencyEntryFrame
function trackerProto:EntryTooltip(e)
  currencyEntry:Tooltip(e, { L:G("Drag it onto your backpack to put it away."),
    L:G("Shift-drag to move it, or off to stop tracking it."), L:G("Right-click for options.") })
end

---@return Frame
function trackerProto:FloatLayer()
  return self.floats
end

-- The tracker as a container of an entry dragged on its own (NextCurrencyContainer): a row, or a column.

---@param x number
---@param y number
---@return boolean
function trackerProto:IsOver(x, y)
  local lx, ly = currencyDrag:Local(self.frame, x, y)
  return currencyDrag:Near(self.frame, lx, ly)
end

---@param x number
---@param y number
---@return number
function trackerProto:IndexAt(x, y)
  local lx, ly = currencyDrag:Local(self.frame, x, y)
  if lx == nil then
    return #self.centers
  end
  local pad = pixel:Length(self.frame, style.Theme.Currency.Tracker.Pad)
  return currencyDrag.Count(self.centers, (self:Layout() == "row" and lx or ly) - pad)
end

---@return number? left, number? top, number? scale
function trackerProto:RoomPoint()
  local at = lift:ScreenPoint(self.frame)
  if at == nil or self.roomX == nil then
    return nil, nil, nil
  end
  return at.left + self.roomX * at.scale, at.top - self.roomY * at.scale, at.scale
end

---@return string[]
function trackerProto:Keys()
  return self.order
end

---@param ctx Context
function trackerProto:Relayout(ctx)
  self:Draw(ctx)
end

-- MovingParts are what moves by nature (next-pixel-perfect.md): gains playing, sparkles.
---@return table<table, boolean>
function trackerProto:MovingParts()
  local parts = { [self.fx] = true, [self.floats] = true }
  for _, e in pairs(self.entries) do
    e:MovingParts(parts)
  end
  return parts
end
