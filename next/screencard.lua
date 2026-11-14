local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

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

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

-- NextScreenCard is a small card of the theme's that stays on screen where it was dropped, the bags open or not: the
-- currency tracker dragged out of the backpack (currency.md §5) and the Food & Drink bar (food-drink.md §4) are both
-- kinds of it. It grows from a corner, is kept on the screen, is picked up and dropped with the shared lift (NextLift),
-- is put away by a drop on the open backpack, fades out in combat (when told) and pet battles, and follows BetterBags
-- Next being switched off and on. Each kind says what is its own: its options, where it is saved, its backpack, what it
-- shows and how it lays that out.
---@class NextScreenCard: AceModule
local card = addon:NewModule('NextScreenCard')

-- How far a card pulled out of the backpack pops past its size before it settles to its size held (the theme's
-- Drag.LiftScale), as a share of that size.
card.POP = 0.12

---@class NextScreenCardFrame
---@field frame Frame
---@field fill Texture
---@field edge NextEdge
---@field art NextFrameArtSet
---@field floats Frame Where what rises off its content rises.
---@field fx Frame Where sparkles burst.
---@field burst NextSparkleEmitter
---@field burstX? number
---@field burstY? number
---@field hint FontString What letting go does, under it while held.
---@field held? NextScreenCardDrag
---@field emerging? NextLifted It is coming out of the backpack (Emerge).
---@field layOutLater? boolean Its kind put a layout off while it moved (held or coming out): it lays out once at rest.
---@field active boolean BetterBags Next is in use.
---@field combat boolean
---@field petBattle boolean
---@field hovered boolean
---@field alphaKey table
---@field fillKey table
---@field watch Frame Its OnUpdate watches the pointer while it is over the card.
local cardProto = {}
addon:GetModule('Perf'):RegisterPrototype(cardProto, 'NextScreenCardFrame')

-- NextScreenCardDrag is a card held: NextLift fills in where it was grabbed and its scale.
---@class NextScreenCardDrag: NextLifted
---@field released? number Frames the left button was found up.
---@field over boolean Over the backpack: letting go puts it away.
---@field popped boolean It came out of the backpack under the cursor: never placed yet.

-- Extend makes a kind of card: what proto does not have, a card does.
---@generic T
---@param proto T
---@return T
function card:Extend(proto)
  return setmetatable(proto, { __index = cardProto })
end

-- Build makes c's card (c a table of a kind made with Extend): its frame on UIParent, hidden, its fill, edge and frame
-- art, the layers what plays on it uses, and what it follows (combat, pet battles, the screen).
---@param c NextScreenCardFrame
---@param name? string
---@return NextScreenCardFrame
function card:Build(c, name)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  c.frame = frame
  c.active, c.combat, c.petBattle, c.hovered = true, false, false, false
  c.alphaKey, c.fillKey = {}, {}
  c.fill = frame:CreateTexture(nil, "BACKGROUND")
  c.fill:SetAllPoints(frame)
  c.edge = controls:CreateEdge(frame)
  c.art = frameArt:Create(frame, frame)
  c.floats = CreateFrame("Frame", nil, frame)
  c.floats:SetAllPoints(frame)
  c.floats:SetFrameLevel(frame:GetFrameLevel() + 20)
  c.fx = CreateFrame("Frame", nil, frame)
  c.fx:SetAllPoints(frame)
  c.fx:SetFrameLevel(frame:GetFrameLevel() + 30)
  c.burst = sparkles:Create(c.fx, {
    Direction = 1,
    Spawn = function() return c.burstX or 0, c.burstY or 0 end,
  })
  c.hint = lift:Layer():CreateFontString(nil, "OVERLAY")
  c.hint:Hide()
  c.watch = CreateFrame("Frame", nil, frame)
  addon.SetScript(frame, "OnDragStart", function() c:DragStart() end)
  addon.SetScript(frame, "OnDragStop", function(ctx) c:Drop(ctx) end)
  addon.SetScript(frame, "OnMouseUp", function(_, _, button)
    if button == "RightButton" then
      c:OpenSettings()
    end
  end)
  addon.SetScript(frame, "OnEnter", function() c:SetHovered(true) end)
  addon.SetScript(frame, "OnLeave", function()
    if not frame:IsMouseOver() then
      c:SetHovered(false)
    end
  end)
  addon.SetScript(frame, "OnHide", function()
    c:OnCardHidden()
    motion:Forget(c.frame)
    if c.hovered then
      c:SetHovered(false)
    end
  end)
  c:WatchCard()
  return c
end

-- WatchCard follows what hides the card (combat, pet battles) and keeps it on the screen when the screen changes.
function cardProto:WatchCard()
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

-- What a kind says of its own. Option reads one of its options (scale, layout, growX, growY, background,
-- hideInCombat); Saved and Save read and write whether it is out and where it was left (the corner it grows from, in
-- UIParent's units from the screen's top left); LayOut lays out what it shows and sizes the card; OpenSettings opens
-- its options.

-- Home is the backpack it is put away in (NextBackpack: its frame, body and closing), nothing without one.
---@return table?
function cardProto:Home()
  return nil
end

-- PutAwayPoint is where on screen it flies to as it is put away (UIParent's units).
---@return number? x, number? y
function cardProto:PutAwayPoint()
  local home = self:Home()
  if home == nil then
    return nil, nil
  end
  return lift:Center(home.body)
end

-- SetHomeLit shows on the backpack that letting go puts it away there.
---@param on boolean
function cardProto:SetHomeLit(on)
  local _ = on
end

-- OnPutAway is told once it is put away.
---@param ctx Context
function cardProto:OnPutAway(ctx)
  local _ = ctx
end

-- Wants says whether it has something to show.
---@return boolean
function cardProto:Wants()
  return true
end

-- StyleContent restyles what it shows, after its card.
function cardProto:StyleContent()
end

-- OnCardHidden ends what plays on what it shows as it hides.
function cardProto:OnCardHidden()
end

-- OnDeactivate ends what of its own is held as BetterBags Next is switched off.
---@param ctx Context
function cardProto:OnDeactivate(ctx)
  local _ = ctx
end

-- Draw shows what it shows, laid out, and shows or hides the card.
---@param ctx Context
function cardProto:Draw(ctx)
  self:LayOut()
  self:UpdateShown(ctx)
end

-- Theme is its card's art and spacing: the currency tracker's (Currency.Tracker), for every kind.
---@return table
function cardProto:Theme()
  return style.Theme.Currency.Tracker
end

-- IsOut says whether the player has it out.
---@return boolean
function cardProto:IsOut()
  local out = self:Saved()
  return out
end

-- Scale is its scale on screen.
---@return number
function cardProto:Scale()
  return (self:Option("scale") or 100) / 100
end

---@return string
function cardProto:Layout()
  return self:Option("layout")
end

-- Style draws the card from the theme: its fill, its edge and its frame art, none of them with the background turned
-- off (its fill fading in while the pointer is over it, to show what to grab).
function cardProto:Style()
  local T = self:Theme()
  local background = self:Option("background")
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
  self:StyleContent()
end

---@param ctx Context
function cardProto:ApplyStyle(ctx)
  self:Style()
  self:Draw(ctx)
end

-- SetHovered shows the fill faintly while the pointer is over a card without a background. While it is, the pointer is
-- watched every frame and the fill fades once it is off the card: what it shows may be buttons over the card, so
-- leaving one straight off the card, the card is told nothing (reported: the fill stayed).
---@param on boolean
function cardProto:SetHovered(on)
  self.hovered = on
  self.watch:SetScript("OnUpdate", on and function()
    if not self.frame:IsMouseOver() then
      self:SetHovered(false)
    end
  end or nil)
  if self:Option("background") then
    return
  end
  tween:Play(self.fillKey, {
    duration = style.Time.Hover, from = self.fill:GetAlpha(), to = on and 0.6 or 0, ease = style:Ease("Hover"),
    onUpdate = function(v) self.fill:SetAlpha(v) end,
  })
end

-- ShouldShow says whether the card shows now: it is out, BetterBags Next is in use, it has something to show and
-- nothing hides it (combat, with Hide in Combat on; a pet battle).
---@return boolean
function cardProto:ShouldShow()
  return self.active and self:IsOut() and self:Wants() and not self.petBattle
    and not (self.combat and self:Option("hideInCombat"))
end

-- UpdateShown shows or hides the card as ShouldShow says, fading in and out. Held, or coming out, it stays.
---@param ctx Context
function cardProto:UpdateShown(ctx)
  local _ = ctx
  if self.held ~= nil or self.emerging ~= nil then
    return
  end
  local frame = self.frame
  if self:ShouldShow() then
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

-- fade fades the card to alpha, then calls done.
---@private
---@param alpha number
---@param done? fun()
function cardProto:fade(alpha, done)
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

-- SetActive shows or hides the card with BetterBags Next (next.md §11): hidden while the classic bags are in use, back
-- where it was when Next is again.
---@param ctx Context
---@param on boolean
function cardProto:SetActive(ctx, on)
  self.active = on
  if not on then
    self:OnDeactivate(ctx)
    self:Cancel()
    tween:Stop(self.alphaKey)
    self.frame:Hide()
    return
  end
  self:Draw(ctx)
end

-- Corner is the corner the card grows from (Grows, its options; asked of the tracker: "grow direction should probably
-- be left (anchor point is right, frame grows out left) ... for list view we need up and down as options"): its right
-- edge growing left, or its left growing right; in a column or a list, its top growing down, or its bottom growing up
-- (a row's height does not grow: its top). Its point, and whether that is its right and its bottom.
---@return FramePoint point, boolean right, boolean bottom
function cardProto:Corner()
  local right = self:Option("growX") ~= "right"
  local bottom = self:Layout() ~= "row" and self:Option("growY") == "up"
  return (bottom and "BOTTOM" or "TOP") .. (right and "RIGHT" or "LEFT"), right, bottom
end

-- span is how big the card is on screen at a scale (UIParent's units).
---@private
---@param s number
---@return number width, number height
function cardProto:span(s)
  return self.frame:GetWidth() * s, self.frame:GetHeight() * s
end

-- cornerOf turns a top left (UIParent's units, x from the left, y down from the top) into the corner the card grows
-- from, at a scale.
---@param left number
---@param top number
---@param s number
---@return number x, number y
function cardProto:cornerOf(left, top, s)
  local _, right, bottom = self:Corner()
  local w, h = self:span(s)
  return left + (right and w or 0), top + (bottom and h or 0)
end

-- clamp keeps the corner the card grows from (as cornerOf) where the whole card is on screen.
---@param x number
---@param y number
---@return number x, number y
function cardProto:clamp(x, y)
  local _, right, bottom = self:Corner()
  local w, h = self:span(self:Scale())
  local left, top = x - (right and w or 0), y - (bottom and h or 0)
  left = math.max(0, math.min(left, UIParent:GetWidth() - w))
  top = math.max(0, math.min(top, UIParent:GetHeight() - h))
  return left + (right and w or 0), top + (bottom and h or 0)
end

-- PlaceSaved puts the card where it was left, on the screen and on whole pixels (the middle of the screen's top third
-- before it was ever placed).
function cardProto:PlaceSaved()
  local _, x, y = self:Saved()
  if x == nil then
    local s = self:Scale()
    local w = self:span(s)
    x, y = self:cornerOf((UIParent:GetWidth() - w) / 2, UIParent:GetHeight() / 3, s)
  end
  self:PlaceAt(x, y)
end

-- PlaceAt puts the corner the card grows from at x, y (UIParent's units from the screen's top left), kept on screen,
-- on whole pixels of its own grid: it grows from there.
---@param x number
---@param y number
function cardProto:PlaceAt(x, y)
  local frame = self.frame
  local s = self:Scale()
  x, y = self:clamp(x, y)
  frame:SetScale(s)
  frame:ClearAllPoints()
  pixel:Point(frame, (self:Corner()), UIParent, "TOPLEFT", x / s, -y / s)
end

-- Reanchor keeps the card where it is on screen, now growing from the corner its options name (they changed: which way
-- it grows, its layout, its scale), and remembers that corner.
function cardProto:Reanchor()
  if self.held ~= nil or self.emerging ~= nil or not self:IsOut() or not self.frame:IsShown() then
    return
  end
  local at = lift:ScreenPoint(self.frame)
  if at == nil then
    return
  end
  local x, y = self:cornerOf(at.left, UIParent:GetHeight() - at.top, at.scale)
  self:Save(true, x, y)
  self:PlaceAt(x, y)
end

-- CanPick says whether the card can be picked up now: nothing else is held or dragged, and it is not coming out.
---@return boolean
function cardProto:CanPick()
  return self.held == nil and self.emerging == nil and not lift:IsHolding() and not nextDrag:IsActive()
    and not CursorHasItem()
end

-- DragStart picks the card up.
function cardProto:DragStart()
  self:PickUp()
end

-- PickUp picks the card up where it is (a drag on it or on what it shows).
---@return boolean
function cardProto:PickUp()
  if not self:CanPick() or not self.frame:IsShown() then
    return false
  end
  local held = { over = false, popped = false }
  ---@cast held NextScreenCardDrag
  tween:Stop(self.alphaKey)
  self.frame:SetAlpha(1)
  if not lift:Pick(held, self.frame, function(elapsed) self:Update(elapsed) end) then
    return false
  end
  self.held = held
  GameTooltip:Hide()
  return true
end

-- pop grows the held card from where it starts to its size held, a little past it and back (the lift's own shrink
-- replaced: the same tween key), the shadow coming in; a card that was already out flies from where it was.
---@param held NextScreenCardDrag
---@param from? NextDragPoint
function cardProto:pop(held, from)
  local s0 = from and from.scale or held.scale
  local target = self:Scale() * style.Theme.Drag.LiftScale
  local pop = card.POP
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

-- overBackpack says whether the cursor is over the backpack, open: letting go there puts the card away.
---@return boolean
function cardProto:overBackpack()
  local panel = self:Home()
  if panel == nil then
    return false
  end
  return panel.frame:IsVisible() and not panel.closing and panel.body:IsMouseOver()
end

-- Update follows the cursor while the card is held: over the backpack the backpack lights and the card fades a little
-- ("Put Away"), elsewhere it says where it goes. A release the client missed drops it (as NextDrag does).
---@param elapsed number
function cardProto:Update(elapsed)
  local _ = elapsed
  local held = self.held
  if held == nil or held.landing then
    return
  end
  if not IsMouseButtonDown("LeftButton") then
    held.released = (held.released or 0) + 1
    if held.released >= 2 then
      self:Drop(context:New('NextScreenCardDrop'))
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
    self:SetHomeLit(over)
    self.frame:SetAlpha(over and 0.75 or 1)
  end
  local hint = self.hint
  hint:SetText(over and L:G("Put Away") or L:G("Keep on Screen"))
  hint:ClearAllPoints()
  hint:SetPoint("TOP", self.frame, "BOTTOM", 0, -style.Theme.Drag.HintGap)
  hint:Show()
end

-- Drop lets the card go: over the backpack it flies in and is put away; elsewhere it lands there, on the screen, and
-- stays.
---@param ctx Context
function cardProto:Drop(ctx)
  local held = self.held
  if held == nil or held.landing then
    return
  end
  held.landing = true
  self.hint:Hide()
  tween:Stop(held)
  self:SetHomeLit(false)
  if held.over or (held.popped and self:overBackpack()) then
    self:putAway(ctx, held)
    return
  end
  local s = self:Scale()
  local cx, cy = lift:Cursor()
  local left, top = cx - held.grabX * held.scale, cy + held.grabY * held.scale
  -- Its top left, kept on the screen and on whole pixels of its own grid where it comes to rest.
  local x, y = self:clamp(self:cornerOf(left, UIParent:GetHeight() - top, s))
  local _, right, bottom = self:Corner()
  local w, h = self:span(s)
  x, y = x - (right and w or 0), y - (bottom and h or 0)
  local unit = pixel:UnitAt(UIParent:GetEffectiveScale() * s) * s
  x, y = pixel:SnapIn(unit, x), pixel:SnapIn(unit, y)
  self.frame:SetAlpha(1)
  lift:Land(held, function() return x, UIParent:GetHeight() - y, s end, function()
    lift:Put(held, UIParent)
    self.frame:SetFrameStrata("MEDIUM")
    self.held = nil
    -- Remembered by the corner it grows from.
    local px, py = self:cornerOf(x, y, s)
    self:Save(true, px, py)
    self:PlaceAt(px, py)
    self:settle()
    self:UpdateShown(ctx)
  end)
end

-- settle lays the card out once it is at rest at its scale again, when its kind put a layout off while it moved
-- (layOutLater): lengths on a grid are read at the scale it is drawn at, and moving, that is the lift's.
---@private
function cardProto:settle()
  if self.layOutLater then
    self:LayOut()
  end
end

-- putAway flies the held card into the backpack and puts it away; its kind is told.
---@private
---@param ctx Context
---@param held NextScreenCardDrag
function cardProto:putAway(ctx, held)
  local x, y = self:PutAwayPoint()
  if x == nil then
    x, y = lift:Cursor()
  end
  lift:FlyAway(held, x, y, function()
    lift:Put(held, UIParent)
    self.held = nil
    self.frame:Hide()
    self.frame:SetAlpha(1)
    self.frame:SetFrameStrata("MEDIUM")
    local _, px, py = self:Saved()
    self:Save(false, px, py)
    self:OnPutAway(ctx)
    self:UpdateShown(ctx)
  end)
end

-- Emerge brings the card out of the open backpack (its switch turned on, food-drink.md §4): from the backpack's middle
-- at the theme's Drag.FlyScale to where it was left at its scale, fading in, sparkles bursting, on the drag layer over
-- the backpack as a card put away flies (NextLift), back on the screen once there. With the backpack closed, or nothing
-- to show, it shows as UpdateShown says.
---@param ctx Context
function cardProto:Emerge(ctx)
  local home = self:Home()
  if not self:ShouldShow() or self.held ~= nil or self.emerging ~= nil or home == nil or not home.frame:IsVisible()
    or home.closing then
    self:UpdateShown(ctx)
    return
  end
  local cx, cy = lift:Center(home.body)
  if cx == nil then
    self:UpdateShown(ctx)
    return
  end
  local frame = self.frame
  tween:Stop(self.alphaKey)
  frame:SetAlpha(0)
  frame:Show()
  self:LayOut()
  self:PlaceSaved()
  local at = lift:ScreenPoint(frame)
  if at == nil then
    self:UpdateShown(ctx)
    return
  end
  local s = self:Scale()
  local fly = style.Theme.Drag.FlyScale * s
  local w, h = self:span(fly)
  local from = { left = cx - w / 2, top = cy + h / 2, scale = fly }
  ---@type NextLifted
  local emerging = { frame = frame, grabX = frame:GetWidth() / 2, grabY = frame:GetHeight() / 2, scale = fly, base = s,
    landing = true }
  self.emerging = emerging
  lift:Raise(frame)
  frame:SetScale(fly)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", from.left / fly, from.top / fly)
  self:fade(1)
  self:Burst(nil, emerging)
  lift:Land(emerging, function() return at.left, at.top, s end, function()
    self:rest(emerging)
    self:settle()
    self:UpdateShown(ctx)
  end, from)
end

-- rest puts a card that came out of the backpack (emerging) back on the screen, where it was left, as faded in as it is:
-- its fade in may be longer than its flight.
---@private
---@param emerging NextLifted
function cardProto:rest(emerging)
  self.emerging = nil
  local alpha = self.frame:GetAlpha()
  lift:Put(emerging, UIParent)
  self.frame:SetAlpha(alpha)
  self.frame:SetFrameStrata("MEDIUM")
  self:PlaceSaved()
end

-- Cancel ends a drag, or a card coming out, at once: a card out goes back where it was, one that was not is put away.
function cardProto:Cancel()
  local emerging = self.emerging
  if emerging ~= nil then
    self:rest(emerging)
  end
  local held = self.held
  if held == nil then
    return
  end
  self.hint:Hide()
  lift:Put(held, UIParent)
  self.held = nil
  self.frame:SetFrameStrata("MEDIUM")
  self:SetHomeLit(false)
  if self:IsOut() then
    self:PlaceSaved()
  else
    self.frame:Hide()
  end
end

-- Burst bursts the theme's sparkles: its gain sparkles at what it shows (e, whose icon is iconSize and whose first point
-- is its top left on the card), else its pop sparkles where the card was grabbed (held).
---@param e? {frame: Frame, iconSize?: number}
---@param held? NextLifted
function cardProto:Burst(e, held)
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
