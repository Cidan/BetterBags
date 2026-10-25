local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextControls: AceModule
local controls = addon:GetModule('NextControls')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class Currencies: AceModule
local currencies = addon:GetModule('Currencies')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- NextCurrencyEntry draws one tracked currency or item (.claude/rules/currency.md §4), for the strip at the bottom of
-- the backpack and the tracker dragged out of it alike: its icon, its count beside it, a bar under both toward its
-- cap, and in the tracker's list its name. A gain plays on it: the count rolls to its new number, the icon pops and
-- glows, and "+N" rises off it (a loss: the count rolls, "-N" sinks). Everything is drawn from the theme's Currency
-- and placed on whole pixels (next-pixel-perfect.md); what moves while it plays is left out of the pixel checks
-- (MovingParts).
---@class NextCurrencyEntry: AceModule
local currencyEntry = addon:NewModule('NextCurrencyEntry')

---@alias NextCurrencyLayout "row"|"column"|"list"

-- NextCurrencyOwner is what an entry asks of the strip or tracker it is in.
---@class NextCurrencyOwner
---@field EntryClicked fun(self: any, ctx: Context, entry: NextCurrencyEntryFrame, button: string)
---@field EntryDragStart fun(self: any, ctx: Context, entry: NextCurrencyEntryFrame)
---@field EntryDragStop fun(self: any, ctx: Context, entry: NextCurrencyEntryFrame)
---@field EntryReceiveDrag fun(self: any, ctx: Context, entry: NextCurrencyEntryFrame)
---@field EntryTooltip fun(self: any, entry: NextCurrencyEntryFrame)
---@field FloatLayer fun(self: any): Frame Where gains rise: over whatever is around the entry.

---@class NextCurrencyEntryFrame
---@field frame Button
---@field hover Texture
---@field flash Texture
---@field icon Texture
---@field count FontString
---@field name FontString
---@field track Texture
---@field fill Texture
---@field owner NextCurrencyOwner
---@field state? NextCurrencyState
---@field shown? number The count it shows now (rolling toward the state's).
---@field layout NextCurrencyLayout
---@field bars boolean
---@field width number
---@field height number
---@field progress? number The bar's fill shown now (gliding toward the state's).
---@field rollKey table
---@field bumpKey table
---@field flashKey table
---@field barKey table
---@field hoverKey table
---@field float? NextCurrencyFloat
local entryProto = {}
addon:GetModule('Perf'):RegisterPrototype(entryProto, 'NextCurrencyEntryFrame')

-- NextCurrencyFloat is a gain rising off an entry (or a loss sinking).
---@class NextCurrencyFloat
---@field text FontString
---@field amount number
---@field born number
---@field key table

-- The font strings floats are drawn with, by the layer they rise on, reused.
local floatPools = setmetatable({}, { __mode = "k" })

---@param parent Frame
---@param owner NextCurrencyOwner
---@return NextCurrencyEntryFrame
function currencyEntry:Create(parent, owner)
  local C = style.Theme.Currency
  local frame = CreateFrame("Button", nil, parent)
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame:RegisterForDrag("LeftButton")
  ---@type NextCurrencyEntryFrame
  local e = setmetatable({
    frame = frame, owner = owner, layout = "row", bars = true, width = 0, height = 0,
    rollKey = {}, bumpKey = {}, flashKey = {}, barKey = {}, hoverKey = {},
  }, { __index = entryProto })
  e.hover = frame:CreateTexture(nil, "BACKGROUND")
  e.hover:SetAlpha(0)
  e.flash = frame:CreateTexture(nil, "BORDER")
  e.flash:SetAlpha(0)
  e.icon = frame:CreateTexture(nil, "ARTWORK")
  e.track = frame:CreateTexture(nil, "ARTWORK")
  e.fill = frame:CreateTexture(nil, "OVERLAY")
  e.count = style:CreateText(frame, C.Font)
  e.count:SetJustifyH("LEFT")
  e.count:SetWordWrap(false)
  e.name = style:CreateText(frame, C.NameFont)
  e.name:SetJustifyH("LEFT")
  e.name:SetWordWrap(false)
  e.name:Hide()
  addon.SetScript(frame, "OnEnter", function()
    e:SetHovered(true)
    owner:EntryTooltip(e)
  end)
  addon.SetScript(frame, "OnLeave", function()
    e:SetHovered(false)
    GameTooltip:Hide()
  end)
  addon.SetScript(frame, "OnClick", function(ctx, _, button)
    owner:EntryClicked(ctx, e, button)
  end)
  addon.SetScript(frame, "OnDragStart", function(ctx)
    owner:EntryDragStart(ctx, e)
  end)
  addon.SetScript(frame, "OnDragStop", function(ctx)
    owner:EntryDragStop(ctx, e)
  end)
  addon.SetScript(frame, "OnReceiveDrag", function(ctx)
    owner:EntryReceiveDrag(ctx, e)
  end)
  e:Style()
  return e
end

-- format writes a count as Blizzard writes large numbers.
---@param n number
---@return string
local function format(n)
  return BreakUpLargeNumbers(n)
end

-- countFont is the role an entry's count is in: capped, none of it, or plain.
---@param state NextCurrencyState
---@return string
local function countFont(state)
  local C = style.Theme.Currency
  if state.capped then
    return C.CappedFont
  end
  if state.none then
    return C.NoneFont
  end
  return C.Font
end

-- Style draws the entry's parts from the theme (Currency): its fonts, its hover, glow and bar, its icon's crop.
function entryProto:Style()
  local C = style.Theme.Currency
  style:SetFont(self.name, C.NameFont)
  if self.state then
    style:SetFont(self.count, countFont(self.state))
  else
    style:SetFont(self.count, C.Font)
  end
  controls:Paint(self.hover, C.Hover)
  local flash = C.Flash
  if flash then
    style:Paint(self.flash, flash)
  end
  self.flash:SetAlpha(0)
  local B = C.Bar
  style:Paint(self.track, B.Track, B.Track.Alpha)
  self:paintFill()
  local crop = C.Crop or 0
  self.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
end

-- paintFill colors the bar's fill: capped in its own color.
---@private
function entryProto:paintFill()
  local B = style.Theme.Currency.Bar
  local spec = (self.state and self.state.capped and B.Capped) or B.Fill
  style:Paint(self.fill, spec, spec.Alpha)
end

-- SetHovered fades the hover in or out.
---@param on boolean
function entryProto:SetHovered(on)
  local from = self.hover:GetAlpha()
  local C = style.Theme.Currency
  local to = on and ((C.Hover and C.Hover.Alpha) or 1) or 0
  if not C.Hover then
    to = 0
  end
  tween:Play(self.hoverKey, {
    duration = style.Time.Hover, from = from, to = to, ease = style:Ease("Hover"),
    onUpdate = function(v) self.hover:SetAlpha(v) end,
  })
end

-- Draw shows a state: its icon (desaturated and faded with none of it), its count in its role, its bar's fill. It
-- leaves the count and the bar where an animation left them while one plays (Gain).
---@param state NextCurrencyState
---@param layout NextCurrencyLayout
---@param bars boolean
function entryProto:Draw(state, layout, bars)
  self.state, self.layout, self.bars = state, layout, bars
  if state.icon then
    self.icon:SetTexture(state.icon)
  else
    self.icon:SetTexture(134400)
  end
  self.icon:SetDesaturated(state.none == true)
  self.icon:SetAlpha(state.none and 0.55 or 1)
  style:SetFont(self.count, countFont(state))
  if not tween:IsPlaying(self.rollKey) then
    self.shown = state.count
    self.count:SetText(format(state.count))
  end
  self.name:SetText(state.name or "")
  self.name:SetShown(layout == "list")
  self:paintFill()
  if not tween:IsPlaying(self.barKey) then
    self.fromProgress = self.progress
    self.progress = state.progress
  end
end

-- Measure returns how big the entry is drawn for a layout, in whole pixels of its grid: its icon, its count CountGap
-- beside it (its final count's width, rounded up: a rolling count never pushes the entries beside it), and the bar
-- under them; a list row is width wide.
---@param width? number A list row's width.
---@return number width, number height
function entryProto:Measure(width)
  local C, frame = style.Theme.Currency, self.frame
  local icon = pixel:Length(frame, C.Icon)
  -- With bars, every entry is as tall, with a cap or not, so a row's icons line up.
  local height = icon
  if self.bars then
    height = height + pixel:Length(frame, C.Bar.Gap) + pixel:Length(frame, C.Bar.Height)
  end
  if self.layout == "list" and width then
    return pixel:Length(frame, width), height
  end
  local count = self.state and format(self.state.count) or ""
  local was = self.count:GetText()
  self.count:SetText(count)
  local w = icon + pixel:Length(frame, C.CountGap) + pixel:Ceil(frame, self.count:GetStringWidth())
  self.count:SetText(was)
  return w, height
end

-- Place lays the entry's parts out in a box width x height, from its corners on whole pixels: the icon at the top
-- left, the count beside it (a list row's at its right), the name between them, the bar under them across.
---@param width number
---@param height number
function entryProto:Place(width, height)
  local C, frame = style.Theme.Currency, self.frame
  self.width, self.height = width, height
  pixel:Size(frame, width, height)
  local icon = pixel:Length(frame, C.Icon)
  local gap = pixel:Length(frame, C.CountGap)
  self.iconSize = icon
  if not tween:IsPlaying(self.bumpKey) then
    self:placeIcon(icon)
  end
  self.flash:ClearAllPoints()
  local glow = pixel:Length(frame, icon * ((C.Flash and C.Flash.Size) or 1))
  local inset = pixel:Snap(frame, (glow - icon) / 2)
  pixel:Point(self.flash, "TOPLEFT", frame, "TOPLEFT", -inset, inset)
  pixel:Size(self.flash, glow, glow)
  local pad = pixel:Snap(frame, C.HoverPad or 0)
  self.hover:ClearAllPoints()
  pixel:Inset(self.hover, frame, -pad, -pad, -pad, -pad)
  self.count:ClearAllPoints()
  if self.layout == "list" then
    pixel:Row(self.count, "TOPRIGHT", frame, 0, icon)
    local countWidth = pixel:Ceil(frame, self.count:GetStringWidth())
    local nameX = icon + pixel:Length(frame, C.NameGap or C.CountGap)
    self.name:ClearAllPoints()
    pixel:Row(self.name, "TOPLEFT", frame, nameX, icon)
    self.name:SetWidth(math.max(1, pixel:Floor(frame, width - nameX - countWidth - gap)))
  else
    pixel:Row(self.count, "TOPLEFT", frame, icon + gap, icon)
  end
  local B = C.Bar
  local barTop = icon + pixel:Length(frame, B.Gap)
  local barHeight = pixel:Length(frame, B.Height)
  self.track:ClearAllPoints()
  pixel:Point(self.track, "TOPLEFT", frame, "TOPLEFT", 0, -barTop)
  pixel:Size(self.track, width, barHeight)
  self.fill:ClearAllPoints()
  pixel:Point(self.fill, "TOPLEFT", frame, "TOPLEFT", 0, -barTop)
  self:sizeFill()
end

-- placeIcon puts the icon at its size s, grown from its middle (the pop of a gain), at rest on whole pixels.
---@private
---@param s number
function entryProto:placeIcon(s)
  local icon = self.iconSize or s
  local grow = (s - icon) / 2
  self.icon:ClearAllPoints()
  if grow == 0 then
    pixel:Point(self.icon, "TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    pixel:Size(self.icon, s, s)
    return
  end
  self.icon:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -grow, grow)
  self.icon:SetSize(s, s)
end

-- sizeFill draws the bar's fill to its progress, in whole pixels (none: hidden), the track with it; neither shows
-- without bars or a cap.
---@private
function entryProto:sizeFill()
  local shown = self.bars and self.state ~= nil and self.state.progress ~= nil
  self.track:SetShown(shown)
  local p = self.progress or 0
  if not shown or p <= 0 then
    self.fill:Hide()
    return
  end
  local frame = self.frame
  local barHeight = pixel:Length(frame, style.Theme.Currency.Bar.Height)
  local w = tween:IsPlaying(self.barKey) and (self.width * p) or pixel:Length(frame, self.width * p)
  self.fill:SetSize(math.max(w, 0.001), barHeight)
  self.fill:Show()
end

-- Gain plays a gain (or a loss) on the entry, from the count it showed to its state's: the count rolls there; a gain
-- pops the icon and glows round it and "+N" rises off the count, a loss's "-N" sinks; the bar glides to its new
-- fill. Nothing plays while it is not shown: it only shows its state.
---@param delta number
function entryProto:Gain(delta)
  local state = self.state
  if state == nil or delta == 0 then
    return
  end
  -- Draw already shows the new count: from what it was (or where a roll still playing is).
  local from = tween:IsPlaying(self.rollKey) and self.shown or (state.count - delta)
  self:roll(from, state.count)
  self:glideBar()
  self:rise(delta)
  if delta > 0 then
    self:pop()
  end
end

-- Arrive pops the entry and glows round its icon: it was just tracked, or came back with a tracker put away.
function entryProto:Arrive()
  self:pop()
end

-- FadeIn fades the entry in as it appears.
function entryProto:FadeIn()
  self.fadeKey = self.fadeKey or {}
  tween:Play(self.fadeKey, {
    duration = style.Time.CurrencyEnter, from = 0, to = 1, ease = style:Ease("CurrencyEnter"),
    onUpdate = function(v) self.frame:SetAlpha(v) end,
  })
end

-- roll counts the shown number from from to to.
---@private
---@param from number
---@param to number
function entryProto:roll(from, to)
  if from == to then
    return
  end
  tween:Play(self.rollKey, {
    duration = style.Time.CurrencyCount, from = from, to = to, ease = style:Ease("CurrencyCount"),
    onUpdate = function(v)
      local n = to >= from and math.floor(v) or math.ceil(v)
      if n ~= self.shown then
        self.shown = n
        self.count:SetText(format(n))
      end
    end,
    onDone = function()
      self.shown = to
      self.count:SetText(format(to))
    end,
  })
end

-- glideBar slides the bar's fill to the state's progress.
---@private
function entryProto:glideBar()
  local to = self.state and self.state.progress
  local from = self.fromProgress or 0
  if to == nil or to == from then
    self.progress = to
    self:sizeFill()
    return
  end
  tween:Play(self.barKey, {
    duration = style.Time.Interaction, from = from, to = to, ease = style:Ease("Glide"),
    onUpdate = function(v)
      self.progress = v
      self:sizeFill()
    end,
    onDone = function()
      self.progress = to
      self:sizeFill()
    end,
  })
end

-- pop grows the icon from its middle by the theme's Bump and back, and fades its glow out from bright.
---@private
function entryProto:pop()
  local C = style.Theme.Currency
  local icon = self.iconSize or pixel:Length(self.frame, C.Icon)
  tween:Play(self.bumpKey, {
    duration = style.Time.CurrencyBump, from = 0, to = 1, ease = "linear",
    onUpdate = function(t)
      self:placeIcon(icon * (1 + (C.Bump or 0) * math.sin(math.pi * tween.Ease.outCubic(t))))
    end,
    onDone = function()
      self:placeIcon(icon)
    end,
  })
  local flash = C.Flash
  if not flash then
    return
  end
  tween:Play(self.flashKey, {
    duration = style.Time.CurrencyBump * 2, from = flash.Alpha or 1, to = 0, ease = style:Ease("CurrencyCount"),
    onUpdate = function(v) self.flash:SetAlpha(v) end,
  })
end

-- rise lifts "+N" off the count (a loss's "-N" sinks), fading, on the owner's float layer. A gain while the last one
-- still rises adds to it.
---@private
---@param delta number
function entryProto:rise(delta)
  local C = style.Theme.Currency
  local layer = self.owner:FloatLayer()
  local float = self.float
  local now = GetTime()
  if float and float.text:GetParent() == layer and (float.amount > 0) == (delta > 0)
    and now - float.born < style.Time.CurrencyGain * 0.5 then
    float.amount = float.amount + delta
  else
    if float then
      tween:Stop(float.key, true)
    end
    local pool = floatPools[layer]
    if pool == nil then
      pool = {}
      floatPools[layer] = pool
    end
    local text = table.remove(pool) or layer:CreateFontString(nil, "OVERLAY")
    float = { text = text, amount = delta, born = now, key = {} }
    self.float = float
  end
  float.born = now
  local text = float.text
  style:SetFont(text, delta > 0 and C.GainFont or C.LossFont)
  text:SetText((float.amount > 0 and "+" or "-") .. format(math.abs(float.amount)))
  text:SetAlpha(1)
  text:Show()
  local x = self.layout == "list" and (self.width - (self.count:GetStringWidth() or 0))
    or ((self.iconSize or C.Icon) + C.CountGap)
  local rise = (C.Rise or 0) * (float.amount > 0 and 1 or -0.5)
  tween:Play(float.key, {
    duration = style.Time.CurrencyGain, from = 0, to = 1, ease = style:Ease("CurrencyGain"),
    onUpdate = function(t)
      text:ClearAllPoints()
      text:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", x, rise * t)
      text:SetAlpha(t < 0.45 and 1 or (1 - (t - 0.45) / 0.55))
    end,
    onDone = function()
      text:Hide()
      text:ClearAllPoints()
      table.insert(floatPools[layer], text)
      if self.float == float then
        self.float = nil
      end
    end,
  })
end

-- Settle ends whatever plays, where it was going (the owner hid).
function entryProto:Settle()
  for _, key in ipairs({ self.rollKey, self.bumpKey, self.flashKey, self.barKey }) do
    tween:Stop(key, true)
  end
  if self.fadeKey then
    tween:Stop(self.fadeKey, true)
  end
  if self.float then
    tween:Stop(self.float.key, true)
  end
  self.flash:SetAlpha(0)
end

-- IsPlaying says whether a gain plays on the entry: its moving parts are off the pixel grid meanwhile.
---@return boolean
function entryProto:IsPlaying()
  return tween:IsPlaying(self.bumpKey) or tween:IsPlaying(self.barKey) or tween:IsPlaying(self.flashKey)
    or (self.float ~= nil and tween:IsPlaying(self.float.key))
end

-- MovingParts adds the entry's parts that move while a gain plays to parts (next-pixel-perfect.md, the checks).
---@param parts table<table, boolean>
function entryProto:MovingParts(parts)
  parts[self.flash] = true
  if tween:IsPlaying(self.bumpKey) then
    parts[self.icon] = true
  end
  if tween:IsPlaying(self.barKey) then
    parts[self.fill] = true
  end
  if self.float ~= nil then
    parts[self.float.text] = true
  end
end

-- The tooltip's colors are Blizzard's (SharedColorConstants.lua: NORMAL, HIGHLIGHT, GREEN, GRAY, and the warning
-- orange of its "Unique" lines): a tooltip is Blizzard's own art whatever the Next theme.
local GOLD, WHITE, GREEN, GRAY, WARN = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.1, 1, 0.1 }, { 0.5, 0.5, 0.5 }, { 1, 0.5, 0.25 }

-- The most of a Warband's characters a tooltip lists.
currencyEntry.MAX_ALTS = 6

-- addLine adds a line in a color.
---@param text string
---@param c number[]
local function addLine(text, c)
  GameTooltip:AddLine(text, c[1], c[2], c[3], true)
end

-- addPair adds a label and its number.
---@param label string
---@param n number
local function addPair(label, n)
  GameTooltip:AddDoubleLine(label, BreakUpLargeNumbers(n), GOLD[1], GOLD[2], GOLD[3], WHITE[1], WHITE[2], WHITE[3])
end

-- capLines says how far a currency is from its caps: at a cap, more is wasted; else what is left to earn.
---@param state NextCurrencyState
local function capLines(state)
  if state.capped then
    addLine(L:G("At its cap: more is wasted."), WARN)
    return
  end
  if state.weekly then
    addPair(L:G("Left to Earn This Week"), state.weekly.max - state.weekly.earned)
  end
  if state.season then
    addPair(L:G("Left to Earn This Season"), state.season.max - state.season.earned)
  end
  if state.max and (state.progress or 0) >= 0.9 then
    addPair(L:G("Room for"), state.max - state.count)
  end
end

-- placeLines says where an item is: the bags, the bank, the reagent bank and the Warband bank, each that has some.
---@param state NextCurrencyState
local function placeLines(state)
  local places = currencies:ItemPlaces(state.id)
  addPair(L:G("In Your Bags"), places.bags)
  for _, place in ipairs({ { "bank", L:G("Bank") }, { "reagent", L:G("Reagent Bank") }, { "warband", L:G("Warband Bank") } }) do
    local n = places[place[1]]
    if n > 0 then
      addPair(place[2], n)
    end
  end
end

-- altLines lists the Warband's other characters' amounts of a currency that moves between them, the most first (the
-- server asked the first time: the tooltip is shown again when it answers).
---@param state NextCurrencyState
local function altLines(state)
  if not state.transferable then
    return
  end
  local alts = currencies:Alts(state.id)
  GameTooltip:AddLine(" ")
  if alts == nil then
    addLine(L:G("Asking your Warband..."), GRAY)
    return
  end
  if #alts == 0 then
    return
  end
  local total = state.count
  for _, alt in ipairs(alts) do
    total = total + alt.quantity
  end
  addPair(L:G("Your Warband"), total)
  for i, alt in ipairs(alts) do
    if i > currencyEntry.MAX_ALTS then
      addLine(string.format(L:G("and %d more"), #alts - currencyEntry.MAX_ALTS), GRAY)
      break
    end
    GameTooltip:AddDoubleLine(alt.name, BreakUpLargeNumbers(alt.quantity), WHITE[1], WHITE[2], WHITE[3],
      WHITE[1], WHITE[2], WHITE[3])
  end
end

-- Tooltip shows an entry's tooltip: Blizzard's own for the currency or item, then what BetterBags knows of it (how
-- far it is from its caps, where an item is, what it gained this session, the Warband's amounts),
-- then hints. It is shown again when the Warband's amounts arrive.
---@param e NextCurrencyEntryFrame
---@param hints string[]
function currencyEntry:Tooltip(e, hints)
  local state = e.state
  if state == nil then
    return
  end
  self.shown = { entry = e, hints = hints }
  GameTooltip:SetOwner(e.frame, "ANCHOR_TOP")
  if state.kind == "currency" then
    GameTooltip:SetCurrencyByID(state.id)
    capLines(state)
    altLines(state)
  else
    GameTooltip:SetItemByID(state.id)
    placeLines(state)
  end
  local gain = currencies:SessionGain(state.key)
  if gain ~= 0 then
    addLine(string.format(gain > 0 and L:G("+%s this session") or L:G("%s this session"),
      BreakUpLargeNumbers(gain)), gain > 0 and GREEN or GRAY)
  end
  if #hints > 0 then
    GameTooltip:AddLine(" ")
    for _, hint in ipairs(hints) do
      addLine(hint, GRAY)
    end
  end
  GameTooltip:Show()
end

-- Watch shows an entry's tooltip again when the Warband's amounts arrive (once; the strip calls it as it is made, in
-- BetterBags Next's event scope, next.md §11).
function currencyEntry:Watch()
  if self.watching then
    return
  end
  self.watching = true
  events:RegisterMessage('currencies/AltsReady', function()
    local shown = self.shown
    if shown and GameTooltip:IsOwned(shown.entry.frame) then
      self:Tooltip(shown.entry, shown.hints)
    end
  end)
end
