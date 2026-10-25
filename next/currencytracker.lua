local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

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

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class NextDrag: AceModule
local nextDrag = addon:GetModule('NextDrag')

---@class NextSparkles: AceModule
local sparkles = addon:GetModule('NextSparkles')

---@class NextFrameArt: AceModule
local frameArt = addon:GetModule('NextFrameArt')

---@class NextCurrencyEntry: AceModule
local currencyEntry = addon:GetModule('NextCurrencyEntry')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class Texels: AceModule
local texels = addon:GetModule('Texels')

---@class PixelAudit: AceModule
local pixelAudit = addon:GetModule('PixelAudit')

-- NextCurrencyTracker is the currency tracker dragged out of the backpack (.claude/rules/currency.md §5): a copy of
-- the strip at the bottom of the backpack, a small card of the theme's that stays where it was dropped, the bag open
-- or not. One at a time: picking the strip up again picks this one up. Dropped back on the backpack, it flies into
-- the strip and is put away (the strip stays: it was a copy). Its layout (a row, a column, a list with names), scale,
-- background and whether it hides in combat are the player's (the Currency page's Display tab).
---@class NextCurrencyTracker: AceModule
---@field instance? NextCurrencyTrackerFrame
local tracker = addon:NewModule('NextCurrencyTracker')

-- How far a tracker dragged out of the strip pops past its size before it settles to its size held (the theme's
-- Drag.LiftScale), as a share of that size.
tracker.POP = 0.12

---@class NextCurrencyTrackerFrame: NextCurrencyOwner
---@field frame Frame
---@field fill Texture
---@field edge NextEdge
---@field art NextFrameArtSet
---@field floats Frame Where gains rise.
---@field fx Frame Where sparkles burst.
---@field burst NextSparkleEmitter
---@field hint FontString What letting go does, under it while held.
---@field entries table<string, NextCurrencyEntryFrame>
---@field order string[] The keys shown, in order.
---@field strip? NextCurrencyStripFrame The backpack's strip it is a copy of.
---@field held? NextCurrencyTrackerDrag
---@field active boolean BetterBags Next is in use.
---@field combat boolean
---@field petBattle boolean
---@field hovered boolean
---@field alphaKey table
---@field fillKey table
local trackerProto = {}
addon:GetModule('Perf'):RegisterPrototype(trackerProto, 'NextCurrencyTrackerFrame')

-- NextCurrencyTrackerDrag is the tracker held: NextLift fills in where it was grabbed and its scale.
---@class NextCurrencyTrackerDrag: NextLifted
---@field released? number Frames the left button was found up.
---@field over boolean Over the backpack: letting go puts it away.
---@field popped boolean It came out of the strip: never placed yet.

-- Create makes the tracker the first time (for the backpack's strip) and returns it.
---@param strip NextCurrencyStripFrame
---@return NextCurrencyTrackerFrame
function tracker:Create(strip)
  if self.instance then
    self.instance.strip = strip
    return self.instance
  end
  local frame = CreateFrame("Frame", "BetterBagsNextCurrencyTracker", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  ---@type NextCurrencyTrackerFrame
  local t = setmetatable({
    frame = frame, entries = {}, order = {}, strip = strip, active = true, combat = false, petBattle = false,
    hovered = false, alphaKey = {}, fillKey = {},
  }, { __index = trackerProto })
  t.fill = frame:CreateTexture(nil, "BACKGROUND")
  t.fill:SetAllPoints(frame)
  t.edge = controls:CreateEdge(frame)
  t.art = frameArt:Create(frame, frame)
  t.floats = CreateFrame("Frame", nil, frame)
  t.floats:SetAllPoints(frame)
  t.floats:SetFrameLevel(frame:GetFrameLevel() + 20)
  t.fx = CreateFrame("Frame", nil, frame)
  t.fx:SetAllPoints(frame)
  t.fx:SetFrameLevel(frame:GetFrameLevel() + 30)
  t.burst = sparkles:Create(t.fx, {
    Direction = 1,
    Spawn = function() return t.burstX or 0, t.burstY or 0 end,
  })
  t.hint = lift:Layer():CreateFontString(nil, "OVERLAY")
  t.hint:Hide()
  addon.SetScript(frame, "OnDragStart", function() t:PickUp() end)
  addon.SetScript(frame, "OnDragStop", function(ctx) t:Drop(ctx) end)
  addon.SetScript(frame, "OnMouseUp", function(_, _, button)
    if button == "RightButton" then
      t:OpenSettings()
    end
  end)
  addon.SetScript(frame, "OnEnter", function() t:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function()
    if not frame:IsMouseOver() then
      t:SetHovered(false)
    end
  end)
  addon.SetScript(frame, "OnHide", function()
    for _, e in pairs(t.entries) do
      e:Settle()
    end
    motion:Forget(t.frame)
  end)
  self.instance = t
  sonataNext:RegisterWidget(t)
  t:Watch()
  t:Style()
  pixelAudit:Register(frame, {
    title = L:G("Currency Tracker"), owners = { tracker = t },
    skip = function() return t:MovingParts() end,
  })
  return t
end

-- Watch follows what changes what it shows and whether it shows.
---@private
function trackerProto:Watch()
  events:RegisterMessage('currencies/Updated', function(ctx, gains)
    self:Draw(ctx, gains)
  end)
  events:RegisterMessage('currencies/Changed', function(ctx)
    self:Draw(ctx)
  end)
  events:RegisterMessage('currencies/OptionsChanged', function(ctx)
    self:Style()
    self:Draw(ctx)
    self:UpdateShown(ctx)
  end)
  events:RegisterEvent('PLAYER_REGEN_DISABLED', function(ctx)
    self.combat = true
    self:UpdateShown(ctx)
  end)
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function(ctx)
    self.combat = false
    self:UpdateShown(ctx)
  end)
  events:RegisterEvent('PET_BATTLE_OPENING_START', function(ctx)
    self.petBattle = true
    self:UpdateShown(ctx)
  end)
  events:RegisterEvent('PET_BATTLE_CLOSE', function(ctx)
    self.petBattle = false
    self:UpdateShown(ctx)
  end)
  for _, event in ipairs({ 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED' }) do
    events:RegisterEvent(event, function()
      if self:IsOut() then
        self:PlaceSaved()
      end
    end)
  end
end

-- IsOut says whether the player has the tracker out of the backpack.
---@return boolean
function trackerProto:IsOut()
  local out = database:GetNextCurrencyTracker()
  return out
end

-- Scale is the tracker's scale on screen (the Display tab's Tracker Scale).
---@return number
function trackerProto:Scale()
  return (database:GetNextCurrencyOption("scale") or 100) / 100
end

---@return NextCurrencyLayout
function trackerProto:Layout()
  return database:GetNextCurrencyOption("layout")
end

-- Style draws the card from the theme (Currency.Tracker): its fill, its edge and its frame art, none of them with the
-- background turned off (its fill fading in while the pointer is over it, to show what to grab).
function trackerProto:Style()
  local T = style.Theme.Currency.Tracker
  local background = database:GetNextCurrencyOption("background")
  if T.Fill then
    style:Paint(self.fill, T.Fill, T.Fill.Alpha)
  end
  self.fill:SetShown(T.Fill ~= nil and T.Fill ~= false)
  self.fill:SetAlpha((background or self.hovered) and (background and 1 or 0.6) or 0)
  controls:PaintEdge(self.edge, background and T.Edge or false)
  self.art:Apply(background and T.Frame or nil)
  style:SetFont(self.hint, style.Theme.Drag.HintFont)
  local S = style.Theme.Sparkles
  local spec = S and S.Gain
  if spec then
    local o = self.burst.options
    for _, key in ipairs({ "Rate", "Max", "Life", "Size", "Speed", "Rise", "Wobble", "Spin", "Alpha" }) do
      o[key] = spec[key]
    end
    self.burst:SetEnabled(true)
  else
    self.burst:SetEnabled(false)
  end
  for _, e in pairs(self.entries) do
    e:Style()
  end
end

---@param ctx Context
function trackerProto:ApplyStyle(ctx)
  self:Style()
  self:Draw(ctx)
end

-- SetHovered shows the fill faintly while the pointer is over a tracker without a background.
---@param on boolean
function trackerProto:SetHovered(on)
  self.hovered = on
  if database:GetNextCurrencyOption("background") then
    return
  end
  tween:Play(self.fillKey, {
    duration = style.Time.Hover, from = self.fill:GetAlpha(), to = on and 0.6 or 0, ease = style:Ease("Hover"),
    onUpdate = function(v) self.fill:SetAlpha(v) end,
  })
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
  for _, state in ipairs(currencies:States()) do
    if not (hideEmpty and state.none) then
      local e = self:entryFor(state.key)
      e:Draw(state, layout, bars)
      table.insert(order, state.key)
      shown[state.key] = true
    end
  end
  for key, e in pairs(self.entries) do
    if not shown[key] then
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
  local visible = frame:IsVisible()
  if visible then
    motion:BeginPass(frame, style.Time.Interaction)
  end
  local x, y, width, height = pad, pad, 0, 0
  for i, key in ipairs(self.order) do
    local e = self.entries[key]
    local w, h = sizes[i][1], sizes[i][2]
    if layout ~= "row" then
      w = widest
    end
    e:Place(w, h)
    motion:Place(e.frame, frame, x, -y)
    e.frame:Show()
    if layout == "row" then
      x = x + w + gap
      width, height = x - gap + pad, math.max(height, h)
    else
      y = y + h + gap
      width, height = pad + w + pad, y - gap - pad
    end
  end
  if visible then
    motion:EndPass()
  end
  pixel:Size(frame, math.max(width, pad * 2), pad + height + pad)
  texels:Unsharpen(frame)
end

-- UpdateShown shows the tracker while it is out, BetterBags Next is in use, something shows in it and nothing hides
-- it (combat, with Hide in Combat on; a pet battle), fading in and out. Held, it stays.
---@param ctx Context
function trackerProto:UpdateShown(ctx)
  local _ = ctx
  if self.held ~= nil then
    return
  end
  local show = self.active and self:IsOut() and #self.order > 0 and not self.petBattle
    and not (self.combat and database:GetNextCurrencyOption("hideInCombat"))
  local frame = self.frame
  if show then
    if not frame:IsShown() then
      self:PlaceSaved()
      frame:SetAlpha(0)
      frame:Show()
      self:LayOut()
    end
    self:fade(1)
  elseif frame:IsShown() then
    self:fade(0, function()
      frame:Hide()
    end)
  end
end

-- fade fades the tracker to alpha, then calls done.
---@private
---@param alpha number
---@param done? fun()
function trackerProto:fade(alpha, done)
  local from = self.frame:GetAlpha()
  if from == alpha and not tween:IsPlaying(self.alphaKey) then
    if done then
      done()
    end
    return
  end
  tween:Play(self.alphaKey, {
    duration = style.Time.Hover * 2, from = from, to = alpha, ease = style:Ease("Hover"),
    onUpdate = function(v) self.frame:SetAlpha(v) end,
    onDone = done,
  })
end

-- SetActive shows or hides the tracker with BetterBags Next (next.md §11): hidden while the classic bags are in use,
-- back where it was when Next is again.
---@param ctx Context
---@param on boolean
function trackerProto:SetActive(ctx, on)
  self.active = on
  if not on then
    self:Cancel()
    tween:Stop(self.alphaKey)
    self.frame:Hide()
    return
  end
  self:Draw(ctx)
end

-- clamp keeps a top left (UIParent's units, x from the left and y down from the top) for a tracker w x h on screen.
---@param x number
---@param y number
---@return number x, number y
function trackerProto:clamp(x, y)
  local s = self:Scale()
  local w, h = self.frame:GetWidth() * s, self.frame:GetHeight() * s
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  return math.max(0, math.min(x, sw - w)), math.max(0, math.min(y, sh - h))
end

-- PlaceSaved puts the tracker where it was left, on the screen and on whole pixels (the middle of the screen's top
-- third before it was ever placed).
function trackerProto:PlaceSaved()
  local _, x, y = database:GetNextCurrencyTracker()
  if x == nil then
    local s = self:Scale()
    x = (UIParent:GetWidth() - self.frame:GetWidth() * s) / 2
    y = UIParent:GetHeight() / 3
  end
  self:PlaceAt(x, y)
end

-- PlaceAt puts the tracker's top left at x, y (UIParent's units, y down from the top), kept on screen, on whole pixels
-- of its own grid.
---@param x number
---@param y number
function trackerProto:PlaceAt(x, y)
  local frame = self.frame
  local s = self:Scale()
  x, y = self:clamp(x, y)
  frame:SetScale(s)
  frame:ClearAllPoints()
  pixel:Point(frame, "TOPLEFT", UIParent, "TOPLEFT", x / s, -y / s)
end

-- where returns the tracker's top left as it is on screen (UIParent's units, y down from the top).
---@private
---@return number? x, number? y
function trackerProto:where()
  local at = lift:ScreenPoint(self.frame)
  if at == nil then
    return nil, nil
  end
  return at.left, UIParent:GetHeight() - at.top
end

-- CanPick says whether the tracker can be picked up now: nothing else is held or dragged.
---@return boolean
function trackerProto:CanPick()
  return self.held == nil and not lift:IsHolding() and not nextDrag:IsActive() and not CursorHasItem()
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

-- PickUp picks the tracker up where it is (a drag on it or one of its entries).
---@return boolean
function trackerProto:PickUp()
  if not self:CanPick() or not self.frame:IsShown() then
    return false
  end
  local held = { over = false, popped = false }
  ---@cast held NextCurrencyTrackerDrag
  tween:Stop(self.alphaKey)
  self.frame:SetAlpha(1)
  if not lift:Pick(held, self.frame, function(elapsed) self:Update(elapsed) end) then
    return false
  end
  self.held = held
  GameTooltip:Hide()
  return true
end

-- pop grows the held tracker from where it starts to its size held, a little past it and back (the lift's own shrink
-- replaced: the same tween key), the shadow coming in; a tracker that was already out flies from where it was.
---@private
---@param held NextCurrencyTrackerDrag
---@param from? NextDragPoint
function trackerProto:pop(held, from)
  local s0 = from and from.scale or held.scale
  local target = self:Scale() * style.Theme.Drag.LiftScale
  local pop = tracker.POP
  local fx, fy = from and from.left, from and from.top
  tween:Play(held, {
    duration = style.Time.CurrencyPop, from = 0, to = 1, ease = "linear",
    onUpdate = function(t)
      local e = tween.Ease.outCubic(t)
      held.scale = s0 + (target - s0) * e + target * pop * math.sin(math.pi * e)
      lift.shadow:SetAlpha(lift:ShadowAlpha() * e)
      local cx, cy = lift:Cursor()
      if fx ~= nil then
        -- From where it was to under the cursor.
        local s = held.scale
        local left, top = cx - held.grabX * s, cy + held.grabY * s
        left, top = fx + (left - fx) * e, fy + (top - fy) * e
        self.frame:SetScale(s)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
      else
        lift:Place(held, cx, cy)
      end
    end,
    onDone = function()
      held.scale = target
      fx = nil
    end,
  })
end

-- overBackpack says whether the cursor is over the backpack, open: letting go there puts the tracker away.
---@return boolean
function trackerProto:overBackpack()
  local strip = self.strip
  if strip == nil then
    return false
  end
  local panel = strip.panel
  return panel.frame:IsVisible() and not panel.closing and panel.body:IsMouseOver()
end

-- Update follows the cursor while the tracker is held: over the backpack the strip lights and the card fades a little
-- ("Put Away"), elsewhere it says where it goes. A release the client missed drops it (as NextDrag does).
---@param elapsed number
function trackerProto:Update(elapsed)
  local _ = elapsed
  local held = self.held
  if held == nil or held.landing then
    return
  end
  if not IsMouseButtonDown("LeftButton") then
    held.released = (held.released or 0) + 1
    if held.released >= 2 then
      self:Drop(context:New('NextCurrencyTrackerDrop'))
      return
    end
  else
    held.released = 0
  end
  if not tween:IsPlaying(held) then
    lift:Place(held, lift:Cursor())
  end
  local over = self:overBackpack()
  if over ~= held.over then
    held.over = over
    if self.strip then
      self.strip:SetDropTarget(over)
    end
    self.frame:SetAlpha(over and 0.75 or 1)
  end
  local hint = self.hint
  hint:SetText(over and L:G("Put Away") or L:G("Keep on Screen"))
  hint:ClearAllPoints()
  hint:SetPoint("TOP", self.frame, "BOTTOM", 0, -style.Theme.Drag.HintGap)
  hint:Show()
end

-- Drop lets the tracker go: over the backpack it flies into the strip and is put away; elsewhere it lands there, on
-- the screen, and stays.
---@param ctx Context
function trackerProto:Drop(ctx)
  local held = self.held
  if held == nil or held.landing then
    return
  end
  held.landing = true
  self.hint:Hide()
  tween:Stop(held)
  if self.strip then
    self.strip:SetDropTarget(false)
  end
  if held.over or (held.popped and self:overBackpack()) then
    self:putAway(ctx, held)
    return
  end
  local s = self:Scale()
  local cx, cy = lift:Cursor()
  local left, top = cx - held.grabX * held.scale, cy + held.grabY * held.scale
  local x, y = self:clamp(left, UIParent:GetHeight() - top)
  -- On whole pixels of its own grid where it comes to rest.
  local unit = pixel:UnitAt(UIParent:GetEffectiveScale() * s) * s
  x, y = pixel:SnapIn(unit, x), pixel:SnapIn(unit, y)
  self.frame:SetAlpha(1)
  lift:Land(held, function() return x, UIParent:GetHeight() - y, s end, function()
    lift:Put(held, UIParent)
    self.frame:SetFrameStrata("MEDIUM")
    self.held = nil
    database:SetNextCurrencyTracker(true, x, y)
    self:PlaceAt(x, y)
    self:UpdateShown(ctx)
  end)
end

-- putAway flies the held tracker into the strip and puts it away; the strip welcomes it back.
---@private
---@param ctx Context
---@param held NextCurrencyTrackerDrag
function trackerProto:putAway(ctx, held)
  local strip = self.strip
  local x, y = lift:Center(strip.frame)
  if x == nil then
    x, y = lift:Cursor()
  end
  lift:FlyAway(held, x, y, function()
    lift:Put(held, UIParent)
    self.held = nil
    self.frame:Hide()
    self.frame:SetAlpha(1)
    self.frame:SetFrameStrata("MEDIUM")
    local _, px, py = database:GetNextCurrencyTracker()
    database:SetNextCurrencyTracker(false, px, py)
    if strip then
      strip:Welcome()
    end
    self:UpdateShown(ctx)
  end)
end

-- Cancel ends a drag at once: a tracker that was out goes back where it was, one coming out of the strip is put away.
function trackerProto:Cancel()
  local held = self.held
  if held == nil then
    return
  end
  self.hint:Hide()
  lift:Put(held, UIParent)
  self.held = nil
  self.frame:SetFrameStrata("MEDIUM")
  if self.strip then
    self.strip:SetDropTarget(false)
  end
  if self:IsOut() then
    self:PlaceSaved()
  else
    self.frame:Hide()
  end
end

-- Burst bursts the theme's gain sparkles at an entry's icon (none: at the cursor, a tracker popping out).
---@param e? NextCurrencyEntryFrame
---@param held? NextCurrencyTrackerDrag
function trackerProto:Burst(e, held)
  local S = style.Theme.Sparkles
  local spec = S and (e and S.Gain or S.Pop)
  if not spec then
    return
  end
  local o = self.burst.options
  for _, key in ipairs({ "Rate", "Max", "Life", "Size", "Speed", "Rise", "Wobble", "Spin", "Alpha" }) do
    o[key] = spec[key]
  end
  self.burst:SetEnabled(true)
  if e then
    local half = (e.iconSize or 0) / 2
    local x, y = select(4, e.frame:GetPoint(1))
    self.burstX, self.burstY = (x or 0) + half, (y or 0) - half
  elseif held then
    self.burstX, self.burstY = held.grabX, -held.grabY
  end
  local n = spec.Burst or 6
  o.Direction = -1
  self.burst:Burst(math.ceil(n / 2))
  o.Direction = 1
  self.burst:Burst(math.floor(n / 2))
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

---@param ctx Context
---@param e NextCurrencyEntryFrame
function trackerProto:EntryDragStart(ctx, e)
  local _, _ = ctx, e
  self:PickUp()
end

---@param ctx Context
---@param e NextCurrencyEntryFrame
function trackerProto:EntryDragStop(ctx, e)
  local _ = e
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
  currencyEntry:Tooltip(e, { L:G("Drag it onto your backpack to put it away."), L:G("Right-click for options.") })
end

---@return Frame
function trackerProto:FloatLayer()
  return self.floats
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
