local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

---@class NextDockCard: AceModule
local dockCard = addon:GetModule('NextDockCard')

---@class NextPixel: AceModule
local pixel = addon:GetModule('NextPixel')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

-- NextDock holds sections waiting in a panel for the player (next.md §7, "Docked sections"): a sale or a
-- deposit to confirm (a section dragged onto the vendor or the guild bank, a category Auto Sell offers)
-- or a category's items to destroy. One interface for every such move (CLAUDE.md, "UI Consistency" 5;
-- asked: "a list of categories that move over to the vendor window (scroll the vendor window if needed)
-- to double click to sell, and selling (or cancelling) animates the next section to the position above
-- it"). Each section leaves its bag's column (NextContent:HoldOut) and flies into its own card
-- (NextDockCard) at the top of the panel's column (NextContent:SetLead), one under another, scrolling
-- with the panel. Its offer says what the card reads and glows in, and what a double click (confirm) and
-- a click (one item destroyed) do; a right click sends it back to its place in its bag. When one goes,
-- the ones below slide up (Motion, through the panel's column).
---@class NextDock: AceModule
---@field lists table<NextPanelFrame, NextDockList>
local nextDock = addon:NewModule('NextDock')

-- NextDockOffer is what a docked section is for.
---@class NextDockOffer
---@field text fun(): string, string, string Its card's title, warning and hint, read at every layout.
---@field color? fun(): (string|number[])? The color its card glows in (the theme's when nil).
---@field confirm? fun(ctx: Context): string? A double click: "moved" (its items moved: it flies into the panel), "stay" (it waits on, its card read again), "back" (sent back), else nothing.
---@field click? fun(ctx: Context): string? A click (destroying one item): the same answers.
---@field tooltip? fun(owner: Frame) What hovering its card shows.
---@field docked? fun(entry: NextDockEntry) Called once it is docked: an offer that acts on its own (a sale selling one item at a time) answers later, with NextDock:Answer.
---@field cancel? fun() Called when it leaves the dock, whichever way: whatever it started stops.

-- NextDockSpec is what Add docks.
---@class NextDockSpec
---@field section NextSection
---@field source NextPanelFrame The panel whose column it leaves.
---@field offer NextDockOffer
---@field from? NextDragPoint Where its frame is on screen now (else read from it).
---@field tab? NextTab A tab it came in by: it flies into it when it moves, and the tab pulses.

---@class NextDockEntry
---@field list NextDockList
---@field section NextSection
---@field source NextPanelFrame
---@field offer NextDockOffer
---@field tab? NextTab
---@field card NextDockCardSlot
---@field holder Frame
---@field box NextDockCardFrame
---@field catcher Button
---@field docked boolean It waits in the list.
---@field seated boolean Its section sits in its card.
---@field scale number The section's scale in its card.
---@field flight? NextLifted The section's flight running (in, away or back).
---@field color? string|number[] The color its card was styled in.
---@field seen? string Its section's height and size when last laid out.
---@field top? number Where its holder starts in the panel's column, in the last layout.
---@field bottom? number Where its holder ends in the panel's column, in the last layout.
---@field reveal? boolean The panel scrolls to show it once it is laid out.

-- NextDockCardSlot is a card, kept for the next entry once its own goes.
---@class NextDockCardSlot
---@field holder Frame In the panel's column, as tall as the card and its halo.
---@field box NextDockCardFrame
---@field catcher Button Over the card, above the section's item buttons: it takes the clicks.
---@field entry? NextDockEntry

---@class NextDockList
---@field panel NextPanelFrame
---@field entries NextDockEntry[]
---@field free NextDockCardSlot[]
---@field driver Frame
---@field elapsed number
local listProto = {}
addon:GetModule('Perf'):RegisterPrototype(listProto, 'NextDockList')

function nextDock:Init()
  for _, list in pairs(self.lists or {}) do
    list.driver:SetScript("OnUpdate", nil)
  end
  self.lists = {}
end

nextDock:Init()

-- ListOf returns a panel's list, made the first time: its cards lead the panel's column.
---@param panel NextPanelFrame
---@return NextDockList
function nextDock:ListOf(panel)
  local list = self.lists[panel]
  if list == nil then
    list = setmetatable({ panel = panel, entries = {}, free = {}, driver = CreateFrame("Frame"), elapsed = 0 },
      { __index = listProto })
    panel.content:SetLead(function(width) return list:Lead(width) end)
    self.lists[panel] = list
    sonataNext:RegisterWidget(self)
  end
  return list
end

-- Add docks a section in a panel, unless it waits there already (then its entry).
---@param panel NextPanelFrame
---@param spec NextDockSpec
---@return NextDockEntry
function nextDock:Add(panel, spec)
  local list = self:ListOf(panel)
  return list:EntryOf(spec.section.name) or list:Add(spec)
end

-- Entries returns what waits in a panel, top first.
---@param panel NextPanelFrame
---@return NextDockEntry[]
function nextDock:Entries(panel)
  local list = self.lists[panel]
  local out = {}
  for i, entry in ipairs(list and list.entries or {}) do
    out[i] = entry
  end
  return out
end

-- EntryOf returns what waits in a panel for a section's name, or nil.
---@param panel NextPanelFrame
---@param name string
---@return NextDockEntry?
function nextDock:EntryOf(panel, name)
  local list = self.lists[panel]
  return list and list:EntryOf(name)
end

-- Answer gives a docked section its offer's answer later ("moved", "stay", "back"), as a click would:
-- a sale that sold one item at a time answers once it ends. Nothing for one no longer docked.
---@param entry NextDockEntry
---@param answer? string
function nextDock:Answer(entry, answer)
  entry.list:Answer(entry, answer)
end

-- Refresh reads a docked section's card again, for an offer whose text changed (a sale's progress; a
-- card that leaves the dock stops its sale first, cancel).
---@param entry NextDockEntry
function nextDock:Refresh(entry)
  entry.list:Read(entry)
  entry.list:Invalidate()
end

-- PanelHidden sends back at once what waits in a panel that closed, and what came from it.
---@param panel NextPanelFrame
function nextDock:PanelHidden(panel)
  for _, list in pairs(self.lists) do
    for i = #list.entries, 1, -1 do
      local entry = list.entries[i]
      if list.panel == panel or entry.source == panel then
        list:SendBackNow(entry)
      end
    end
  end
end

---@param ctx Context
function nextDock:ApplyStyle(ctx)
  local _ = ctx
  for _, list in pairs(self.lists) do
    for _, entry in ipairs(list.entries) do
      list:Restyle(entry, true)
    end
    list:Invalidate()
  end
end

---@param name string
---@return NextDockEntry?
function listProto:EntryOf(name)
  for _, entry in ipairs(self.entries) do
    if entry.section.name == name then
      return entry
    end
  end
  return nil
end

-- Invalidate lays the panel's column out again: the cards and the sections below them.
function listProto:Invalidate()
  self.panel.content:Invalidate()
end

-- card returns a card no entry has, made the first time.
---@private
---@return NextDockCardSlot
function listProto:card()
  local card = table.remove(self.free)
  if card ~= nil then
    return card
  end
  local holder = CreateFrame("Frame", nil, self.panel.content.frame)
  holder:Hide()
  local box = dockCard:Create(holder)
  local catcher = CreateFrame("Button", nil, box.frame)
  catcher:SetAllPoints(box.frame)
  catcher:EnableMouse(true)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  card = { holder = holder, box = box, catcher = catcher }
  -- A click is the hardware event selling, moving and destroying need.
  addon.SetScript(catcher, "OnClick", function(ctx, _, button)
    if card.entry ~= nil then
      self:Click(ctx, card.entry, button)
    end
  end)
  addon.SetScript(catcher, "OnDoubleClick", function(ctx, _, button)
    if card.entry ~= nil and button == "LeftButton" then
      self:DoubleClick(ctx, card.entry)
    end
  end)
  addon.SetScript(catcher, "OnEnter", function()
    local entry = card.entry
    if entry ~= nil and entry.offer.tooltip then
      entry.offer.tooltip(catcher)
    end
  end)
  addon.SetScript(catcher, "OnLeave", function()
    if GameTooltip:IsOwned(catcher) then
      GameTooltip:Hide()
    end
  end)
  return card
end

-- Add docks a section: it leaves its bag's column and flies from where it is into its card.
---@param spec NextDockSpec
---@return NextDockEntry
function listProto:Add(spec)
  local card = self:card()
  ---@type NextDockEntry
  local entry = {
    list = self, section = spec.section, source = spec.source, offer = spec.offer, tab = spec.tab, card = card,
    holder = card.holder, box = card.box, catcher = card.catcher, docked = true, seated = false, scale = 1,
  }
  card.entry = entry
  entry.reveal = true
  table.insert(self.entries, entry)
  spec.source.content:HoldOut(spec.section, function() self:Lost(entry) end)
  card.holder:Show()
  entry.box:SetText(entry.offer.text())
  self:Restyle(entry, true)
  self:Invalidate()
  self:start()
  local frame = spec.section.frame
  local from = spec.from or lift:ScreenPoint(frame)
  if from == nil then
    self:Seat(entry)
    self:Docked(entry)
    return entry
  end
  lift:Raise(frame)
  local flight = { frame = frame, grabX = 0, grabY = 0, scale = from.scale, landing = true }
  entry.flight = flight
  lift:Land(flight, function(left0, top0)
    local to = lift:ScreenPoint(entry.box.slot)
    if to == nil then
      return left0, top0, entry.scale
    end
    return to.left, to.top, entry.scale * to.scale
  end, function()
    entry.flight = nil
    self:Seat(entry)
  end, from)
  self:Docked(entry)
  return entry
end

-- Docked tells an entry's offer it is docked (NextDockOffer.docked).
---@param entry NextDockEntry
function listProto:Docked(entry)
  if entry.offer.docked then
    entry.offer.docked(entry)
  end
end

-- Seat puts a docked section in its card's slot, at its scale, under the catcher. Its level is only ever
-- raised: lowering a frame lowers every frame in it, and one that would go below 0 jumps to the top level
-- (warcraft.wiki.gg "Frame Strata"), above the catcher.
---@param entry NextDockEntry
function listProto:Seat(entry)
  local frame, box = entry.section.frame, entry.box
  frame:SetParent(box.frame)
  frame:SetScale(entry.scale)
  frame:SetAlpha(1)
  frame:SetFrameStrata(box.frame:GetFrameStrata())
  frame:SetFrameLevel(math.max(frame:GetFrameLevel(), box.frame:GetFrameLevel() + 1))
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", box.slot, "TOPLEFT", 0, 0)
  frame:Show()
  entry.catcher:SetFrameLevel(math.min(lift.MAX_LEVEL, lift:MaxLevel(frame) + lift.COVER_ABOVE))
  entry.seated = true
end

-- Lead lays the cards out for the panel's column (NextContent:SetLead), width wide: each card round its
-- section, the section scaled down to fit with the card's halo inside the column, its holder as tall as
-- the card and the halo above it; each card reads its offer again.
---@param width number
---@return {frame: Frame, height: number}[]
function listProto:Lead(width)
  local D = style.Theme.Dock
  local frame = self.panel.content.frame
  local spread = pixel:Length(frame, (D.Halo and D.Halo.Spread) or (D.Glow and D.Glow.Width) or 0)
  local pad, spacing = pixel:Lengths(frame, D.Pad, style.SECTION_SPACING)
  local leads, y = {}, 0
  for i, entry in ipairs(self.entries) do
    local section = entry.section
    local w = section.frame:GetWidth()
    entry.scale = math.min(1, (width - 2 * spread - 2 * pad) / w)
    -- Seated, the section is laid out on the grid it is drawn on at its card's scale (whole pixels there,
    -- docs/next-pixel-perfect.md), and its card is sized from that: its size times its scale is whole.
    local h = section.height or section.frame:GetHeight()
    if entry.seated then
      section.frame:SetScale(entry.scale)
      w, h = entry.source.content:LayoutSection(section, w)
    end
    local cardHeight = entry.box:Size(w * entry.scale, h * entry.scale)
    self:Read(entry)
    local cardWidth = entry.box.frame:GetWidth()
    entry.box.frame:ClearAllPoints()
    entry.box.frame:SetPoint("TOPLEFT", entry.holder, "TOPLEFT", pixel:Floor(frame, (width - cardWidth) / 2), -spread)
    entry.holder:SetSize(width, spread + cardHeight)
    table.insert(leads, { frame = entry.holder, height = spread + cardHeight })
    if i > 1 then
      y = y + spacing
    end
    entry.top, entry.bottom = y, y + spread + cardHeight
    y = entry.bottom
    if entry.reveal then
      entry.reveal = false
      -- The scroll box takes its child's new height after this layout: it scrolls a frame later.
      C_Timer.After(0, function() self:Reveal(entry) end)
    end
  end
  return leads
end

-- Reveal scrolls the panel so a card shows, when it is out of view (the vendor scrolled down): to its
-- top when above, until its bottom shows when below.
---@param entry NextDockEntry
function listProto:Reveal(entry)
  local box = self.panel.scroll and self.panel.scroll.scrollBox
  if box == nil or not entry.docked or entry.top == nil then
    return
  end
  local offset, visible = box:GetDerivedScrollOffset(), box:GetVisibleExtent()
  if entry.top < offset then
    box:ScrollToOffset(entry.top)
  elseif entry.bottom > offset + visible then
    box:ScrollToOffset(entry.bottom - visible)
  end
end

-- Read reads a card's offer again: its text, and its color.
---@param entry NextDockEntry
function listProto:Read(entry)
  entry.box:SetText(entry.offer.text())
  self:Restyle(entry, false)
end

-- Restyle draws a card in the color its offer gives, when it changed (or always with force).
---@param entry NextDockEntry
---@param force boolean
function listProto:Restyle(entry, force)
  local color = entry.offer.color and entry.offer.color() or nil
  if force or color ~= entry.color then
    entry.color = color
    entry.box:Style(color)
    entry.box:Pulse(self.elapsed)
  end
end

-- start pulses the cards every frame while any waits, and lays the column out again when a section's
-- size changed (its bag was read again).
---@private
function listProto:start()
  if self.driver:GetScript("OnUpdate") ~= nil then
    return
  end
  addon.SetScript(self.driver, "OnUpdate", function(_, _, elapsed)
    self:Pulse(elapsed)
  end)
end

---@param elapsed number
function listProto:Pulse(elapsed)
  self.elapsed = self.elapsed + elapsed
  local changed = false
  for _, entry in ipairs(self.entries) do
    entry.box:Pulse(self.elapsed)
    local seen = (entry.section.height or 0) .. ":" .. #entry.section.entries
    if seen ~= entry.seen then
      entry.seen = seen
      changed = true
    end
  end
  if changed then
    self:Invalidate()
  end
end

-- Click answers a click on a card (its catcher, which has no entry once the card is free): a right
-- click sends it back, a left one goes to its offer.
---@param ctx Context
---@param entry NextDockEntry
---@param button string
function listProto:Click(ctx, entry, button)
  if button == "RightButton" then
    self:SendBack(entry)
  elseif entry.offer.click then
    self:Answer(entry, entry.offer.click(ctx))
  end
end

-- DoubleClick confirms what a card waits for (its offer's confirm).
---@param ctx Context
---@param entry NextDockEntry
function listProto:DoubleClick(ctx, entry)
  if entry.offer.confirm then
    self:Answer(entry, entry.offer.confirm(ctx))
  end
end

-- Answer does what an offer answered, for a section still docked: an offer may answer while a click on
-- it is still answering (a sale that ended as it started).
---@param entry NextDockEntry
---@param answer? string
function listProto:Answer(entry, answer)
  if not entry.docked then
    return
  end
  if answer == "moved" then
    self:FlyAway(entry)
  elseif answer == "back" then
    self:SendBack(entry)
  elseif answer == "stay" then
    self:Read(entry)
    self:Invalidate()
    if entry.offer.tooltip and GameTooltip:IsOwned(entry.catcher) then
      entry.offer.tooltip(entry.catcher)
    end
  end
end

-- remove takes an entry out of the list, its card kept for the next one; the ones below slide up.
---@private
---@param entry NextDockEntry
function listProto:remove(entry)
  for i, e in ipairs(self.entries) do
    if e == entry then
      table.remove(self.entries, i)
      break
    end
  end
  entry.docked = false
  entry.card.entry = nil
  if entry.offer.cancel then
    entry.offer.cancel()
  end
  if GameTooltip:IsOwned(entry.catcher) then
    GameTooltip:Hide()
  end
  entry.holder:Hide()
  table.insert(self.free, entry.card)
  self:Invalidate()
  if #self.entries == 0 then
    self.driver:SetScript("OnUpdate", nil)
  end
end

-- FlyAway flies a section whose items moved into the panel (the tab it came in by, else the middle of
-- the panel's scroll area), shrinking and fading, then puts it back in its bag's column hidden and
-- leaving (until its category is gone from it), and pulses the tab.
---@param entry NextDockEntry
function listProto:FlyAway(entry)
  local section, canvas = entry.section, entry.source.content
  local frame = section.frame
  local from = lift:ScreenPoint(frame)
  local x, y
  if entry.tab then
    x, y = lift:Center(entry.tab.button)
  else
    x, y = lift:Center(self.panel.scroll.frame)
  end
  if entry.flight then
    tween:Stop(entry.flight)
  end
  if from ~= nil then
    lift:Raise(frame)
  end
  self:remove(entry)
  local flight = { frame = frame, grabX = frame:GetWidth() / 2,
    grabY = (section.height or frame:GetHeight()) / 2, scale = from and from.scale or 1, landing = true }
  entry.flight = flight
  local function gone()
    entry.flight = nil
    canvas:MarkLeaving(section.name)
    lift:Put(flight, canvas.frame)
    canvas:Return(section)
    frame:Hide()
    if entry.tab then
      self.panel.tabs:Pulse(entry.tab.id)
    end
  end
  if from == nil or x == nil then
    gone()
    return
  end
  lift:FlyAway(flight, x, y, gone, from)
end

-- SendBack sends a section back: it flies from its card to its place in its bag's column, which makes
-- room for it, and takes it.
---@param entry NextDockEntry
function listProto:SendBack(entry)
  local section, canvas = entry.section, entry.source.content
  local frame = section.frame
  local from = lift:ScreenPoint(frame)
  if entry.flight then
    tween:Stop(entry.flight)
  end
  if from ~= nil then
    lift:Raise(frame)
  end
  self:remove(entry)
  canvas:Returning(section)
  local flight = { frame = frame, grabX = 0, grabY = 0, scale = from and from.scale or 1, landing = true }
  entry.flight = flight
  local function home()
    entry.flight = nil
    lift:Put(flight, canvas.frame)
    canvas:Return(section)
  end
  if from == nil then
    home()
    return
  end
  lift:Land(flight, function(left0, top0)
    local at = lift:ScreenPoint(canvas.frame)
    if at == nil then
      return left0, top0
    end
    return at.left, at.top - (section.y or 0) * at.scale, at.scale
  end, home, from)
end

-- SendBackNow puts a docked section back in its place in its bag's column at once (a panel closed).
---@param entry NextDockEntry
function listProto:SendBackNow(entry)
  local section, canvas = entry.section, entry.source.content
  if entry.flight then
    tween:Stop(entry.flight)
    entry.flight = nil
  end
  self:remove(entry)
  lift:Put({ frame = section.frame, grabX = 0, grabY = 0, scale = 1, landing = true }, canvas.frame)
  canvas:Return(section)
end

-- Lost lets a section go that left its bag's data while docked or flying (NextContent's onLost, called
-- before the bag lets it go): its frame goes back to its bag's canvas first, and its card goes.
---@param entry NextDockEntry
function listProto:Lost(entry)
  if entry.flight then
    tween:Stop(entry.flight)
    entry.flight = nil
  end
  lift:Put({ frame = entry.section.frame, grabX = 0, grabY = 0, scale = 1, landing = true },
    entry.source.content.frame)
  if entry.docked then
    self:remove(entry)
  end
end
