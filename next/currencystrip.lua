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

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class NextSparkles: AceModule
local sparkles = addon:GetModule('NextSparkles')

---@class NextCurrencyEntry: AceModule
local currencyEntry = addon:GetModule('NextCurrencyEntry')

---@class NextCurrencyTracker: AceModule
local tracker = addon:GetModule('NextCurrencyTracker')

---@class NextCurrencyDrag: AceModule
local currencyDrag = addon:GetModule('NextCurrencyDrag')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class Motion: AceModule
local motion = addon:GetModule('Motion')

---@class Texels: AceModule
local texels = addon:GetModule('Texels')

-- NextCurrencyStrip is the row of tracked currencies at the bottom of BetterBags Next's backpack (.claude/rules/
-- currency.md §4), where "N free slots" was: each currency or item its icon, count and cap bar, in the player's order,
-- as many as fit beside the gold, the rest (and, unless told, what you have none of) behind "+N", a menu. Gains play
-- on it as they happen. An item picked up that can be tracked makes a slot open at its end: drop it there (or
-- anywhere on the strip) to track it. Dragged, a copy of it pops out of the backpack to stay on screen (the
-- tracker, NextCurrencyTracker), and dropped back on the backpack, that copy flies back in. With Shift, one entry is
-- dragged on its own instead (NextCurrencyDrag): to another place, or off to stop tracking it.
---@class NextCurrencyStrip: AceModule
local currencyStrip = addon:NewModule('NextCurrencyStrip')

---@class NextCurrencyStripFrame: NextCurrencyOwner, NextCurrencyContainer
---@field panel NextBackpack
---@field frame Frame
---@field glow Texture Lit while a tracker held over the backpack would be put away, and while the slot is hovered.
---@field fx Frame Where sparkles burst.
---@field burst NextSparkleEmitter
---@field entries table<string, NextCurrencyEntryFrame>
---@field order string[] The keys shown, in order.
---@field hidden NextCurrencyState[] What does not show: no room, or none of it.
---@field more Button "+N": what does not show, in a menu.
---@field moreText FontString
---@field hint Button "Track Currencies" while nothing is tracked: the Currency page.
---@field hintText FontString
---@field slot Button Where an item held can be dropped to track it.
---@field slotIcon Texture
---@field slotGlow Texture
---@field slotShown boolean
---@field dirty boolean Something changed while the backpack was hidden.
---@field laidOut boolean
---@field glowKey table
---@field slotKey table
---@field tracker NextCurrencyTrackerFrame
---@field centers number[] Each shown entry's middle along the strip, from its left (a room where one is held).
---@field roomX? number Where the room for an entry held is, from the strip's left.
local stripProto = {}
addon:GetModule('Perf'):RegisterPrototype(stripProto, 'NextCurrencyStripFrame')

-- The frame levels above the panel's frame: the strip, and where its sparkles burst (over the content).
local STRIP_LEVEL, FX_LEVEL = 6, 52

---@param panel NextBackpack
---@return NextCurrencyStripFrame
function currencyStrip:Create(panel)
  local frame = CreateFrame("Frame", nil, panel.frame)
  frame:SetFrameLevel(panel.frame:GetFrameLevel() + STRIP_LEVEL)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  ---@type NextCurrencyStripFrame
  local s = setmetatable({
    panel = panel, frame = frame, entries = {}, order = {}, hidden = {}, slotShown = false, dirty = true,
    laidOut = false, glowKey = {}, slotKey = {}, centers = {},
  }, { __index = stripProto })
  s.glow = frame:CreateTexture(nil, "BACKGROUND")
  s.glow:SetAlpha(0)
  s.fx = CreateFrame("Frame", nil, panel.frame)
  s.fx:SetAllPoints(frame)
  s.fx:SetFrameLevel(panel.frame:GetFrameLevel() + FX_LEVEL)
  s.burst = sparkles:Create(s.fx, {
    Direction = 1,
    Spawn = function() return s.burstX or 0, s.burstY or 0 end,
  })

  s.more = CreateFrame("Button", nil, frame)
  s.more:RegisterForClicks("LeftButtonUp")
  s.moreText = style:CreateText(s.more, style.Theme.Currency.MoreFont)
  addon.SetScript(s.more, "OnClick", function(ctx) s:OpenMore(ctx) end)
  addon.SetScript(s.more, "OnEnter", function()
    GameTooltip:SetOwner(s.more, "ANCHOR_TOP")
    GameTooltip:SetText(L:G("More Currencies"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("What does not fit here, and what you have none of."), nil, nil, nil, true)
    GameTooltip:Show()
  end)
  addon.SetScript(s.more, "OnLeave", function() GameTooltip:Hide() end)

  s.hint = CreateFrame("Button", nil, frame)
  s.hint:RegisterForClicks("LeftButtonUp")
  s.hintText = style:CreateText(s.hint, style.Theme.Currency.HintFont)
  addon.SetScript(s.hint, "OnClick", function()
    s:OpenSettings(currencies:Available() and "currencies" or "items")
  end)
  addon.SetScript(s.hint, "OnEnter", function()
    s.hintText:SetAlpha(1)
    GameTooltip:SetOwner(s.hint, "ANCHOR_TOP")
    GameTooltip:SetText(L:G("Track Currencies"), 1, 1, 1, 1, true)
    GameTooltip:AddLine(L:G("Pick currencies to keep an eye on here, or drop an item on this spot to track it."),
      nil, nil, nil, true)
    GameTooltip:Show()
  end)
  addon.SetScript(s.hint, "OnLeave", function()
    s.hintText:SetAlpha(0.8)
    GameTooltip:Hide()
  end)

  s.slot = CreateFrame("Button", nil, frame)
  s.slot:RegisterForClicks("LeftButtonUp")
  s.slotGlow = s.slot:CreateTexture(nil, "BACKGROUND")
  s.slotIcon = s.slot:CreateTexture(nil, "ARTWORK")
  s.slot:SetAlpha(0)
  s.slot:Hide()
  addon.SetScript(s.slot, "OnClick", function(ctx) s:TrackCursorItem(ctx) end)
  addon.SetScript(s.slot, "OnReceiveDrag", function(ctx) s:TrackCursorItem(ctx) end)
  addon.SetScript(s.slot, "OnEnter", function()
    s:SetGlow(true)
    local _, id = GetCursorInfo()
    GameTooltip:SetOwner(s.slot, "ANCHOR_TOP")
    GameTooltip:SetText(L:G("Track This Item"), 1, 1, 1, 1, true)
    local name = id and C_Item.GetItemNameByID(id)
    if name then
      GameTooltip:AddLine(string.format(L:G("Drop it here to count your %s as a currency."), name), nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  addon.SetScript(s.slot, "OnLeave", function()
    s:SetGlow(false)
    GameTooltip:Hide()
  end)

  addon.SetScript(frame, "OnDragStart", function(ctx) s:DragStart(ctx) end)
  addon.SetScript(frame, "OnDragStop", function(ctx) s:DragStop(ctx) end)
  addon.SetScript(frame, "OnReceiveDrag", function(ctx) s:ReceiveItem(ctx) end)
  addon.SetScript(frame, "OnMouseUp", function(ctx, _, button)
    if button == "LeftButton" then
      s:ReceiveItem(ctx)
    elseif button == "RightButton" then
      s:OpenSettings()
    end
  end)
  addon.HookScript(panel.body, "OnSizeChanged", function()
    if s.laidOut then
      s:Layout(false)
    end
  end)
  s:Watch()
  currencyEntry:Watch()
  currencyDrag:Register(s)
  sonataNext:RegisterWidget(s)
  s:Style()
  -- Made with the backpack, in BetterBags Next's event scope (next.md §11): it shows once something is drawn, when it
  -- was left out.
  s.tracker = tracker:Create(s)
  return s
end

-- Watch follows what changes the strip: the tracked list and what each read, the options, the cursor (an item that
-- can be tracked), the gold (its width).
---@private
function stripProto:Watch()
  events:RegisterMessage('currencies/Updated', function(ctx, gains)
    self:Draw(ctx, gains)
  end)
  for _, message in ipairs({ 'currencies/Changed', 'currencies/OptionsChanged' }) do
    events:RegisterMessage(message, function(ctx)
      self:Draw(ctx)
    end)
  end
  events:RegisterEvent('CURSOR_CHANGED', function()
    self:UpdateSlot()
  end)
  events:RegisterEvent('PLAYER_MONEY', function()
    -- The gold's frame updates its width on the same event.
    C_Timer.After(0, function()
      if self.laidOut then
        self:Layout(false)
      end
    end)
  end)
end

-- Style draws the strip's own parts from the theme (Currency): the glow, the slot, "+N" and the hint; its entries
-- restyle themselves.
function stripProto:Style()
  local C = style.Theme.Currency
  local drop = C.Drop
  if drop then
    style:Paint(self.glow, drop)
  end
  self.glow:SetAlpha(0)
  local slot = C.Slot
  self.slotIcon:SetTexture(style:TexturePath(slot.Icon))
  self.slotIcon:SetVertexColor(style:RGBA(slot.Color, slot.Alpha))
  if drop then
    style:Paint(self.slotGlow, drop)
  end
  style:SetFont(self.moreText, C.MoreFont)
  style:SetFont(self.hintText, C.HintFont)
  self.hintText:SetAlpha(0.8)
  local S = style.Theme.Sparkles
  self.burst:SetEnabled(S ~= nil and S.Gain ~= nil)
  for _, e in pairs(self.entries) do
    e:Style()
  end
end

---@param ctx Context
function stripProto:ApplyStyle(ctx)
  self:Style()
  self.laidOut = false
  self:Draw(ctx)
end

-- entryFor returns the entry drawing a key, made the first time.
---@private
---@param key string
---@return NextCurrencyEntryFrame
function stripProto:entryFor(key)
  local e = self.entries[key]
  if e == nil then
    e = currencyEntry:Create(self.frame, self)
    e.frame:Hide()
    self.entries[key] = e
  end
  return e
end

-- Draw shows what is tracked: what fits, then "+N" for the rest; a gain plays on its entry. While the backpack is
-- hidden it waits for it to show.
---@param ctx Context
---@param gains? table<string, number>
function stripProto:Draw(ctx, gains)
  local _ = ctx
  if not self.panel.frame:IsShown() then
    self.dirty = true
    return
  end
  self.dirty = false
  self:Layout(self.laidOut)
  if gains and database:GetNextCurrencyOption("gains") and not self.panel.opening then
    for key, delta in pairs(gains) do
      local e = self.entries[key]
      if e and e.frame:IsShown() then
        e:Gain(delta)
        if delta > 0 then
          self:Burst(e)
        end
      end
    end
  end
end

-- room is how wide the strip may be: the body from its inner side's text inset to the gold, less MoneyGap.
---@private
---@return number
function stripProto:room()
  local panel = self.panel
  local left = panel:InnerPad() + style.TITLE_INSET
  local m = panel.moneyFrame
  local money = m and m.frame:GetWidth() or 0
  return panel:LayoutWidth() - left - style.PAD - money - style.Theme.Currency.MoneyGap
end

-- Layout lays the strip out: what fits in its room in order (none of what you have none of, unless told), "+N" for
-- the rest, the slot at the end while an item that can be tracked is held, and "Track Currencies" while nothing is
-- tracked. Entries that moved glide there (Motion), new ones fade in, with animate.
---@param animate boolean
function stripProto:Layout(animate)
  local C = style.Theme.Currency
  local frame, panel = self.frame, self.panel
  local hideEmpty = database:GetNextCurrencyOption("hideEmpty")
  local bars = database:GetNextCurrencyOption("capBars")
  local room = pixel:Floor(frame, self:room())
  local gap = pixel:Length(frame, C.Gap)
  local icon = pixel:Length(frame, C.Icon)
  local height = icon
  if bars then
    height = height + pixel:Length(frame, C.Bar.Gap) + pixel:Length(frame, C.Bar.Height)
  end
  local states = currencies:States()
  -- An entry dragged on its own is left out (NextCurrencyDrag), a room its size where it would land.
  local heldKey = currencyDrag:HeldKey()
  local candidates, hidden, heldState = {}, {}, nil
  for _, state in ipairs(states) do
    if state.key == heldKey then
      heldState = state
    elseif hideEmpty and state.none then
      table.insert(hidden, state)
    else
      table.insert(candidates, state)
    end
  end
  local roomIndex = heldState and currencyDrag:RoomIn(self)
  local roomWidth = 0
  if roomIndex ~= nil then
    local held = self:entryFor(heldKey)
    held:Draw(heldState, "row", bars)
    roomWidth = (held:Measure())
  end
  -- Each candidate's width, and what fits: "+N" (and the slot) need their room too.
  local widths = {}
  for i, state in ipairs(candidates) do
    local e = self:entryFor(state.key)
    e:Draw(state, "row", bars)
    widths[i] = (e:Measure())
  end
  local slot = self.slotShown and icon or 0
  local fits = #candidates
  local function moreWidth(n)
    if n == 0 then
      return 0
    end
    self.moreText:SetText("+" .. n)
    return gap + pixel:Ceil(frame, self.moreText:GetStringWidth())
  end
  local function used(k)
    local w = 0
    for i = 1, k do
      w = w + widths[i] + (i > 1 and gap or 0)
    end
    if roomWidth > 0 then
      w = w + (k > 0 and gap or 0) + roomWidth
    end
    return w + moreWidth(#candidates - k + #hidden) + (slot > 0 and (k > 0 and gap or 0) + slot or 0)
  end
  while fits > 0 and used(fits) > room do
    fits = fits - 1
  end
  local order = {}
  for i = 1, fits do
    order[i] = candidates[i].key
  end
  for i = fits + 1, #candidates do
    table.insert(hidden, i - fits, candidates[i])
  end
  self.order, self.hidden = order, hidden

  local left = pixel:Snap(frame, panel:InnerPad() + style.TITLE_INSET)
  local bottom = pixel:Snap(frame, style.FOOTER_MONEY) - (height - icon)
  frame:ClearAllPoints()
  pixel:Point(frame, "BOTTOMLEFT", panel.body, "BOTTOMLEFT", left, bottom)
  pixel:Size(frame, math.max(1, room), height)

  local shown = {}
  if animate then
    motion:BeginPass(frame, style.Time.Interaction, style.StopMotion)
  else
    motion:Forget(frame)
    motion:BeginPass(frame, style.Time.Interaction, style.StopMotion)
  end
  local x = 0
  local centers, roomX = {}, nil
  if roomIndex ~= nil then
    roomIndex = math.min(roomIndex, #order)
  end
  for i, key in ipairs(order) do
    if roomIndex == i - 1 then
      roomX = x
      x = x + roomWidth + gap
    end
    local e = self.entries[key]
    shown[key] = true
    e:Place(widths[i], height)
    local appearing = not e.frame:IsShown()
    motion:Place(e.frame, frame, x, 0)
    e.frame:Show()
    if appearing and animate then
      e:FadeIn()
    end
    centers[i] = x + widths[i] / 2
    x = x + widths[i] + gap
  end
  if roomIndex ~= nil and roomX == nil then
    roomX = x
    x = x + roomWidth + gap
  end
  self.centers, self.roomX = centers, roomX
  motion:EndPass()
  for key, e in pairs(self.entries) do
    if not shown[key] and not currencyDrag:Lifts(e.frame) then
      e.frame:Hide()
    end
  end

  local n = #hidden
  self.more:SetShown(n > 0)
  if n > 0 then
    self.moreText:SetText("+" .. n)
    local w = pixel:Ceil(frame, self.moreText:GetStringWidth())
    pixel:Size(self.more, w, icon)
    self.more:ClearAllPoints()
    pixel:Point(self.more, "TOPLEFT", frame, "TOPLEFT", #order > 0 and x or 0, 0)
    self.moreText:ClearAllPoints()
    pixel:Row(self.moreText, "TOPLEFT", self.more, 0, icon)
    x = x + w + gap
  end
  self.slot:SetShown(self.slotShown)
  if self.slotShown then
    self.slot:ClearAllPoints()
    pixel:Point(self.slot, "TOPLEFT", frame, "TOPLEFT", (#order > 0 or n > 0) and x or 0, 0)
    pixel:Size(self.slot, icon, icon)
    self.slotIcon:ClearAllPoints()
    pixel:Inset(self.slotIcon, self.slot, 0, 0, 0, 0)
    self.slotGlow:ClearAllPoints()
    local spread = pixel:Snap(frame, icon * 0.6)
    pixel:Inset(self.slotGlow, self.slot, -spread, -spread, -spread, -spread)
  end
  local nothing = #states == 0
  self.hint:SetShown(nothing and not self.slotShown)
  if nothing then
    self.hintText:SetText(L:G("Track Currencies"))
    local w = pixel:Ceil(frame, self.hintText:GetStringWidth())
    pixel:Size(self.hint, w, icon)
    self.hint:ClearAllPoints()
    pixel:Point(self.hint, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    self.hintText:ClearAllPoints()
    pixel:Row(self.hintText, "TOPLEFT", self.hint, 0, icon)
  end
  self.glow:ClearAllPoints()
  local spread = pixel:Snap(frame, C.Gap)
  pixel:Inset(self.glow, frame, -spread, -spread, -spread, -spread)
  self.laidOut = true
  texels:Unsharpen(frame)
end

-- MinWidth is the least room the strip needs in a small backpack's footer: "Track Currencies".
---@return number
function stripProto:MinWidth()
  self.hintText:SetText(L:G("Track Currencies"))
  return self.hintText:GetStringWidth() + style.Theme.Currency.MoneyGap
end

-- Settle ends whatever plays on the strip and forgets where its entries were: the backpack hid. An entry dragged on
-- its own out of it goes back where it was.
function stripProto:Settle()
  if currencyDrag:IsFrom(self) then
    currencyDrag:Cancel(context:New('NextCurrencyStrip_Settle'))
  end
  for _, e in pairs(self.entries) do
    e:Settle()
  end
  motion:Forget(self.frame)
  self:SetDropTarget(false)
  self.laidOut = false
end

-- SetGlow lights the strip (or puts it out): a tracker held over the backpack, the slot hovered.
---@param on boolean
function stripProto:SetGlow(on)
  local drop = style.Theme.Currency.Drop
  local to = (on and drop) and (drop.Alpha or 1) or 0
  tween:Play(self.glowKey, {
    duration = style.Time.Hover, from = self.glow:GetAlpha(), to = to, ease = style:Ease("Hover"),
    onUpdate = function(v)
      self.glow:SetAlpha(v)
      self.slotGlow:SetAlpha(v)
    end,
  })
end

-- SetDropTarget lights the strip while a tracker held over the backpack would be put away.
---@param on boolean
function stripProto:SetDropTarget(on)
  self:SetGlow(on)
end

-- Welcome plays the strip's entries popping one after the other: a tracker was put away into it.
function stripProto:Welcome()
  if not self.panel.frame:IsShown() then
    return
  end
  for i, key in ipairs(self.order) do
    local e = self.entries[key]
    C_Timer.After((i - 1) * style.Time.Stagger, function()
      if e.frame:IsShown() then
        e:Arrive()
      end
    end)
  end
end

-- Burst bursts the theme's gain sparkles from an entry's icon.
---@param e NextCurrencyEntryFrame
function stripProto:Burst(e)
  local S = style.Theme.Sparkles
  local spec = S and S.Gain
  if not spec then
    return
  end
  local o = self.burst.options
  for _, key in ipairs({ "Rate", "Max", "Life", "Size", "Speed", "Rise", "Wobble", "Spin", "Alpha" }) do
    o[key] = spec[key]
  end
  local half = (e.iconSize or 0) / 2
  local x = select(4, e.frame:GetPoint(1)) or 0
  self.burstX, self.burstY = x + half, -half
  local n = spec.Burst or 4
  o.Direction = -1
  self.burst:Burst(math.ceil(n / 2))
  o.Direction = 1
  self.burst:Burst(math.floor(n / 2))
end

-- UpdateSlot opens the slot at the strip's end while an item that can be tracked (and is not) is held over the
-- open backpack, fading it in, and closes it when it is not.
function stripProto:UpdateSlot()
  local kind, id = GetCursorInfo()
  local show = self.panel.frame:IsShown() and kind == "item" and id ~= nil and currencies:CanTrackItem(id)
    and not currencies:IsTracked("item", id)
  if show == self.slotShown then
    return
  end
  self.slotShown = show
  if self.laidOut then
    self:Layout(true)
  end
  tween:Play(self.slotKey, {
    duration = style.Time.Hover * 2, from = self.slot:GetAlpha(), to = show and 1 or 0, ease = style:Ease("Hover"),
    onUpdate = function(v) self.slot:SetAlpha(v) end,
  })
end

-- TrackCursorItem tracks the item held, when it can be (it stacks and is not tracked), putting it back where it was
-- picked up (Plumber's way). It returns whether it did.
---@param ctx Context
---@return boolean
function stripProto:TrackCursorItem(ctx)
  local kind, id = GetCursorInfo()
  if kind ~= "item" or id == nil or not currencies:CanTrackItem(id) or currencies:IsTracked("item", id) then
    return false
  end
  ClearCursor()
  currencies:Track(ctx, "item", id)
  local e = self.entries[currencies:Key("item", id)]
  if e and e.frame:IsShown() then
    e:Arrive()
    self:Burst(e)
  end
  return true
end

-- ReceiveItem tracks an item dropped on the strip, or, one that cannot be tracked, puts it in the bags as a drop on
-- the backpack does (bag-drop-zone.md).
---@param ctx Context
function stripProto:ReceiveItem(ctx)
  if not CursorHasItem() then
    return
  end
  if not self:TrackCursorItem(ctx) then
    self.panel:PlaceCursorItem()
  end
end

-- DragStart pulls the tracker out of the strip; with Shift held, nothing (Shift drags one entry on its own).
---@param ctx Context
function stripProto:DragStart(ctx)
  if IsShiftKeyDown() then
    return
  end
  self:PopOut(ctx)
end

-- PopOut pulls the tracker out of the strip (NextCurrencyTracker:PopOut).
---@param ctx Context
function stripProto:PopOut(ctx)
  self.tracker:PopOut(ctx, self)
end

-- DragStop lets the tracker go (a drag that started on the strip ends on it).
---@param ctx Context
function stripProto:DragStop(ctx)
  self.tracker:Drop(ctx)
end

-- OpenMore opens the menu of what does not show: what does not fit (picked: brought to the front) and what you have
-- none of.
---@param ctx Context
function stripProto:OpenMore(ctx)
  local _ = ctx
  local items = {}
  for _, state in ipairs(self.hidden) do
    local icon = state.icon and ("|T" .. state.icon .. ":14:14:0:0|t ") or ""
    table.insert(items, {
      text = icon .. (state.name or L:G("Loading...")) .. "  " .. BreakUpLargeNumbers(state.count),
      value = state.key, disabled = state.none and database:GetNextCurrencyOption("hideEmpty"),
    })
  end
  addon:GetModule('NextMenu'):Toggle(self.more, {
    items = items,
    onPick = function(pctx, item)
      currencies:Move(pctx, item.value, 0)
    end,
  })
end

-- OpenSettings opens the settings window on the Currencies page: on a tab (tab), else on what is tracked.
---@param tab? string
function stripProto:OpenSettings(tab)
  addon:GetModule('NextSettings'):Open("currencies", tab or "tracked")
end

-- FindItem searches the backpack for a tracked item (Shift-click), opening it; again, clears the search.
---@param ctx Context
---@param state NextCurrencyState
function stripProto:FindItem(ctx, state)
  local panel = self.panel
  local box = panel.searchBox and panel.searchBox.textBox
  if box == nil or state.name == nil then
    return
  end
  if not panel:IsShown() then
    panel:Show(ctx)
  end
  local query = 'name == "' .. state.name:gsub('"', '') .. '"'
  box:SetText(box:GetText() == query and "" or query)
end

-- The entries' owner (NextCurrencyOwner).

---@param ctx Context
---@param e NextCurrencyEntryFrame
---@param button string
function stripProto:EntryClicked(ctx, e, button)
  if button == "RightButton" then
    self:OpenSettings()
    return
  end
  if CursorHasItem() then
    self:ReceiveItem(ctx)
    return
  end
  if IsShiftKeyDown() and e.state and e.state.kind == "item" then
    self:FindItem(ctx, e.state)
  end
end

---@param e NextCurrencyEntryFrame
function stripProto:EntryHovered(e)
  local _ = e
end

-- EntryDragStart pulls the tracker out of the strip, or with Shift, drags the entry on its own.
---@param ctx Context
---@param e NextCurrencyEntryFrame
function stripProto:EntryDragStart(ctx, e)
  if IsShiftKeyDown() then
    currencyDrag:Start(ctx, self, e)
    return
  end
  self:PopOut(ctx)
end

---@param ctx Context
---@param e NextCurrencyEntryFrame
function stripProto:EntryDragStop(ctx, e)
  if currencyDrag:Lifts(e.frame) then
    currencyDrag:Drop(ctx)
    return
  end
  self:DragStop(ctx)
end

---@param ctx Context
---@param e NextCurrencyEntryFrame
function stripProto:EntryReceiveDrag(ctx, e)
  local _ = e
  self:ReceiveItem(ctx)
end

---@param e NextCurrencyEntryFrame
function stripProto:EntryTooltip(e)
  local hints = { L:G("Drag it out to keep it on screen."), L:G("Shift-drag to move it, or off to stop tracking it."),
    L:G("Right-click for options.") }
  if e.state and e.state.kind == "item" then
    table.insert(hints, 1, L:G("Shift-click to find it in your bags."))
  end
  currencyEntry:Tooltip(e, hints)
end

---@return Frame
function stripProto:FloatLayer()
  return self.panel.overlay
end

-- The strip as a container of an entry dragged on its own (NextCurrencyContainer): a row.

---@param x number
---@param y number
---@return boolean
function stripProto:IsOver(x, y)
  local lx, ly = currencyDrag:Local(self.frame, x, y)
  return currencyDrag:Near(self.frame, lx, ly)
end

---@param x number
---@param y number
---@return number
function stripProto:IndexAt(x, y)
  local lx = currencyDrag:Local(self.frame, x, y)
  return lx and currencyDrag.Count(self.centers, lx) or #self.centers
end

---@return number? left, number? top, number? scale
function stripProto:RoomPoint()
  local at = lift:ScreenPoint(self.frame)
  if at == nil or self.roomX == nil then
    return nil, nil, nil
  end
  return at.left + self.roomX * at.scale, at.top, at.scale
end

---@return string[]
function stripProto:Keys()
  return self.order
end

---@param ctx Context
function stripProto:Relayout(ctx)
  local _ = ctx
  if self.panel.frame:IsShown() and self.laidOut then
    self:Layout(true)
  else
    self.dirty = true
  end
end

-- MovingParts are what moves by nature (next-pixel-perfect.md): gains playing, sparkles, the glow and slot fading.
---@param parts table<table, boolean>
function stripProto:MovingParts(parts)
  parts[self.fx] = true
  parts[self.glow] = true
  parts[self.slotGlow] = true
  for _, e in pairs(self.entries) do
    e:MovingParts(parts)
  end
end
