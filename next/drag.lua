local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class NextStyle: AceModule
local style = addon:GetModule('NextStyle')

---@class SonataNext: AceModule
local sonataNext = addon:GetModule('SonataNext')

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

---@class NextDockCard: AceModule
local dockCard = addon:GetModule('NextDockCard')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

-- NextDrag moves BetterBagsNext's sections by their headers (next.md §7). A section picked up
-- leaves its canvas for the drag layer with its real item buttons and follows the cursor (NextLift,
-- which the settings lists' rows are dragged with too), the canvas keeping a gap where it would go; dropping it reorders it (saving its place), assigns its
-- category to a tab's group, moves its items to the other bag (and that bag's tab), or sells them
-- to a seller (the vendor). Drop targets are found from the cursor's position every frame. A move the
-- target confirms first (a sale past what buyback keeps, a deposit that cannot be taken back) docks
-- the section in the target, glowing, until a double click confirms it or it is cancelled; the
-- source keeps its gap meanwhile.
---@class NextDrag: AceModule
local nextDrag = addon:NewModule('NextDrag')

-- How long a section moved away stays out of its column while its items are still there.
local LEAVING_SECONDS = 3

---@alias NextDropKind "reorder"|"tab"|"bagtab"|"bag"|"sell"

-- NextSeller is a panel that buys sections (BetterBags Next's vendor, next.md §10): never a source,
-- a target for backpack sections anywhere on its body or tabs.
---@class NextSeller
---@field frame Frame
---@field body Frame
---@field tabs NextTabRail
---@field scroll ScrollboxDrawable
---@field closing boolean
---@field IsShown fun(self): boolean
---@field SetDropGlow fun(self, on: boolean)
---@field SaleOf fun(self, list: ItemData[]): ItemData[] What of the section's items it would sell.
---@field Sell fun(self, ctx: Context, sale: ItemData[], confirmed?: boolean): string, NextConfirmation? "sold", or "confirm" and what to confirm with.

-- NextConfirmation is what a dock shows for a move its target confirms first.
---@class (exact) NextConfirmation
---@field title string What the move does ("Sell 23 items?").
---@field warning string Why it asks.
---@field hint string How to answer ("Double-click to sell · Right-click to cancel").

-- NextPending is a move waiting to be confirmed: where, and what confirming does with the section's
-- items as they are then (true when it moved them).
---@class (exact) NextPending
---@field target NextDropTarget
---@field confirm fun(ctx: Context, items: ItemData[]): boolean

---@class NextDock
---@field frame Frame Over the target's scroll area, dimming it and taking its clicks.
---@field scrim Texture
---@field box NextDockCardFrame The card (NextDockCard), whose parts the fields below name.
---@field card Frame
---@field halo Texture
---@field glow Texture[]
---@field title FontString
---@field warning FontString
---@field hint FontString
---@field slot Frame Where the section sits in the card.
---@field catcher Button Over the card and the section's item buttons, taking the clicks.
---@field elapsed number
---@field laidOut? number The section height the card was laid out for.

---@class (exact) NextDropTarget
---@field type NextDropKind
---@field panel NextPanelFrame
---@field tab? NextTab

-- NextDragState is a section's drag; NextLift fills in where it was grabbed and its scale. landing:
-- it was dropped and is flying to where it goes, or waits in a dock.
---@class NextDragState: NextLifted
---@field panel NextPanelFrame The panel the section came from.
---@field section NextSection
---@field name string
---@field startIndex number Where its gap was at pickup.
---@field target? NextDropTarget
---@field released? number Frames in a row the left button was up without a drop.
---@field pending? NextPending A move waiting to be confirmed, the section in the dock.

---@type NextDragState?
nextDrag.current = nil

function nextDrag:Init()
  if self.current then
    self:Cancel()
  end
  self.current = nil
  self.panels = {} ---@type NextPanelFrame[]
  self.sellers = {} ---@type NextSeller[]
end

nextDrag:Init()

-- Register makes a panel a source and a target of section drags.
---@param panel NextPanelFrame
function nextDrag:Register(panel)
  table.insert(self.panels, panel)
end

-- RegisterSeller makes a panel a target that sells the backpack sections dropped on it.
---@param seller NextSeller
function nextDrag:RegisterSeller(seller)
  table.insert(self.sellers, seller)
end

---@return boolean
function nextDrag:IsActive()
  return self.current ~= nil
end

-- buildLayer adds the line naming what dropping does to the drag layer (NextLift's: it holds the
-- section and its shadow and cover).
---@private
function nextDrag:buildLayer()
  if self.layer then
    return
  end
  local layer = lift:Layer()
  local hint = layer:CreateFontString(nil, "OVERLAY")
  hint:Hide()
  self.layer, self.shadow, self.cover, self.hint = layer, lift.shadow, lift.cover, hint
  self:styleLayer()
  sonataNext:RegisterWidget(self)
end

-- Begin picks a panel's section up, unless it is not a category, the panel shows the Show Bags
-- view, or a section is already being dragged. It returns whether it did.
---@param panel NextPanelFrame
---@param section NextSection
---@return boolean
function nextDrag:Begin(panel, section)
  if section.kind ~= "category" or not panel:IsShown() or panel.closing then
    return false
  end
  -- A move waiting to be confirmed is put back at once: picking up another section answers it.
  if self.current and self.current.pending then
    self:Cancel()
  end
  if self.current then
    return false
  end
  if database:GetBagView(panel.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    return false
  end
  local frame = section.frame
  if frame:GetLeft() == nil or frame:GetTop() == nil then
    return false
  end
  self:buildLayer()
  local canvas = panel.content
  canvas:BeginDrag(section, function()
    self:Cancel()
  end)
  ---@type NextDragState
  self.current = { panel = panel, section = section, name = section.name, startIndex = canvas.drag.index }
  lift:Pick(self.current, frame, function(elapsed)
    self:Update(elapsed)
  end)
  canvas:Invalidate()
  return true
end

-- groupBankType returns a bank group's bank type on a client with bank types.
---@param group Group
---@return number?
local function groupBankType(group)
  if addon.isRetail then
    return group.bankType
  end
  return nil
end

-- isGuild says whether a panel is BetterBags Next's guild bank (guild-bank.md §5).
---@param panel NextPanelFrame
---@return boolean
local function isGuild(panel)
  return const.BAG_KIND.GUILD ~= nil and panel.kind == const.BAG_KIND.GUILD
end

-- CanMoveBetween says whether a section can move from src to the other panel now: between the
-- backpack and the bank at the bank, between the backpack and the guild bank at the guild bank.
---@param src NextPanelFrame
---@param panel NextPanelFrame
---@return boolean
function nextDrag:CanMoveBetween(src, panel)
  if isGuild(src) or isGuild(panel) then
    return addon.atGuildBank == true
  end
  return addon.atBank == true
end

-- CanDropOnTab says whether a section from src can be dropped on a panel's tab.
---@param panel NextPanelFrame
---@param tab NextTab
---@param src NextPanelFrame
---@return boolean
function nextDrag:CanDropOnTab(panel, tab, src)
  if tab.secure then
    return false
  end
  if panel == src then
    -- The guild bank's tabs hold no groups to assign a category to.
    if isGuild(panel) or panel:InTabMode() or tab.id == panel:GetCurrentTabID() then
      return false
    end
    local group = groups:GetGroup(panel.kind, tab.id)
    if group == nil then
      return false
    end
    local shown = src:ShownBankType()
    local bankType = groupBankType(group)
    return shown == nil or bankType == nil or bankType == shown
  end
  if not self:CanMoveBetween(src, panel) then
    return false
  end
  if isGuild(panel) then
    return panel:CanDepositIn(tab.id)
  end
  return panel:InTabMode() or groups:GetGroup(panel.kind, tab.id) ~= nil
end

-- CanDropOnBody says whether a section from src can be dropped on the other panel's body: the guild
-- bank only while it has a tab the player may deposit in (its DepositTab).
---@param panel NextPanelFrame
---@param src NextPanelFrame
---@return boolean
function nextDrag:CanDropOnBody(panel, src)
  if not self:CanMoveBetween(src, panel) then
    return false
  end
  return not isGuild(panel) or panel:DepositTab() ~= nil
end

-- FindTarget returns what dropping the dragged section where the cursor is would do, or nil.
---@return NextDropTarget?
function nextDrag:FindTarget()
  local src = self.current.panel
  for _, seller in ipairs(self.sellers) do
    if seller:IsShown() and not seller.closing and (seller.tabs:TabAt() ~= nil or seller.body:IsMouseOver()) then
      if src.kind == const.BAG_KIND.BACKPACK then
        return { type = "sell", panel = seller }
      end
      return nil
    end
  end
  for _, panel in ipairs(self.panels) do
    if panel:IsShown() and not panel.closing then
      local tab = panel.tabs:TabAt()
      if tab then
        if self:CanDropOnTab(panel, tab, src) then
          return { type = panel == src and "tab" or "bagtab", panel = panel, tab = tab }
        end
        return nil
      end
      if panel.body:IsMouseOver() then
        if panel == src then
          return { type = "reorder", panel = panel }
        end
        if self:CanDropOnBody(panel, src) then
          return { type = "bag", panel = panel }
        end
        return nil
      end
    end
  end
  return nil
end

-- describe names what dropping on a target does.
---@param target NextDropTarget
---@return string?
local function describe(target)
  if target.type == "sell" then
    local n = #target.panel:SaleOf(nextDrag:SectionItems(nextDrag.current.section))
    if n == 0 then
      return L:G("Nothing in it sells")
    end
    if n == 1 then
      return L:G("Sell 1 item")
    end
    return format(L:G("Sell %d items"), n)
  end
  if target.type == "tab" or target.type == "bagtab" then
    return format(L:G("Move to %s"), target.tab.text:GetText())
  end
  if target.type == "bag" then
    if target.panel.kind == const.BAG_KIND.BACKPACK then
      return L:G("Move to the Backpack")
    end
    if isGuild(target.panel) then
      return L:G("Move to the Guild Bank")
    end
    if Enum.BankType and target.panel:ShownBankType() == Enum.BankType.Account then
      return L:G("Move to the Warbank")
    end
    return L:G("Move to the Bank")
  end
  return nil
end

---@param a? NextDropTarget
---@param b? NextDropTarget
---@return boolean
local function sameTarget(a, b)
  if a == nil or b == nil then
    return a == b
  end
  return a.type == b.type and a.panel == b.panel and a.tab == b.tab
end

-- showTarget lights the target (a tab, or the other panel's body), and names the drop.
---@private
---@param target? NextDropTarget
function nextDrag:showTarget(target)
  local state = self.current
  local old = state.target
  if sameTarget(old, target) then
    return
  end
  state.target = target
  if old then
    if old.tab then
      old.panel.tabs:SetDropTarget(nil)
    elseif old.type == "bag" or old.type == "sell" then
      old.panel:SetDropGlow(false)
    end
  end
  if target and target.tab then
    target.panel.tabs:SetDropTarget(target.tab.id)
  elseif target and (target.type == "bag" or target.type == "sell") then
    target.panel:SetDropGlow(true)
  end
  local text = target and describe(target)
  if text then
    self.hint:SetText(text)
    self.hint:ClearAllPoints()
    self.hint:SetPoint("TOP", state.section.frame, "BOTTOM", 0, -style.Theme.Drag.HintGap)
    self.hint:Show()
  else
    self.hint:Hide()
  end
end

-- Update runs a frame of the drag: the section follows the cursor, the target under the cursor
-- lights up, and over its own panel the gap moves under the cursor and the content scrolls near
-- its edges.
---@param elapsed number
function nextDrag:Update(elapsed)
  local state = self.current
  if state == nil or state.landing then
    return
  end
  -- The client can miss the release (another window took the mouse), as Blizzard's own drags
  -- allow for (FloatingChatFrame.lua). The release's own OnDragStop gets a frame first.
  if not IsMouseButtonDown("LeftButton") then
    state.released = (state.released or 0) + 1
    if state.released >= 2 then
      self:Drop(context:New('NextSectionDrop'), true)
      return
    end
  else
    state.released = 0
  end
  local x, y = lift:Cursor()
  lift:Place(state, x, y)
  local target = self:FindTarget()
  self:showTarget(target)
  if target and target.type == "reorder" then
    local canvas = state.panel.content
    local top = canvas.frame:GetTop()
    if top then
      canvas:SetDragIndex(canvas:DragIndexAt(top - y))
    end
    local scroll = state.panel.scroll
    lift:AutoScroll(scroll.frame, scroll.scrollBox, y, elapsed)
  end
end

-- SaveOrder saves a tab's categories in a new order, the dropped one at index (next.md §7, saving
-- the order): everything up to it, and everything after it already pinned, become one block of
-- the pinned order, where the first of them was; the rest stay unpinned.
---@param kind BagKind
---@param names string[] The tab's categories, in their new order.
---@param index number
function nextDrag:SaveOrder(kind, names, index)
  local pinned = database:GetCustomSectionSort(kind)
  local inTab, block = {}, {}
  for i, name in ipairs(names) do
    inTab[name] = true
    if i <= index or pinned[name] ~= nil then
      table.insert(block, name)
    end
  end
  local list = {}
  for name, position in pairs(pinned) do
    table.insert(list, { name = name, position = position })
  end
  table.sort(list, function(a, b) return a.position < b.position end)
  local order, at = {}, nil
  for _, entry in ipairs(list) do
    if inTab[entry.name] then
      at = at or (#order + 1)
    else
      table.insert(order, entry.name)
    end
  end
  at = at or (#order + 1)
  for i, name in ipairs(block) do
    table.insert(order, at + i - 1, name)
  end
  for i, name in ipairs(order) do
    database:SetCustomSectionSort(kind, name, i - 1)
  end
end

-- items returns the item data of a section's buttons, not its free slots.
---@param section NextSection
---@return ItemData[]
function nextDrag:SectionItems(section)
  local list = {}
  for _, entry in ipairs(section.entries) do
    local button = entry.item
    if button ~= nil and not button.isFreeSlot then
      local data = button:GetItemData()
      if data then
        table.insert(list, data)
      end
    end
  end
  return list
end

-- reattach puts the dragged section back in its canvas: at its gap, or hidden.
---@private
---@param hidden boolean
function nextDrag:reattach(hidden)
  local state = self.current
  local canvas = state.panel.content
  local frame = state.section.frame
  lift:Put(state, canvas.frame)
  frame:SetPoint("TOPLEFT", canvas.frame, "TOPLEFT", 0, -(canvas:GetDragSlotY() or state.section.y or 0))
  if hidden then
    frame:Hide()
  end
  self.hint:Hide()
end

-- finish ends the drag: the target unlit, the driver stopped.
---@private
function nextDrag:finish()
  local state = self.current
  if state and state.target then
    self:showTarget(nil)
  end
  self:hideDock()
  self.current = nil
  if state then
    tween:Stop(state)
  end
end

-- land flies the section from where it is (the cursor's place, or from) into its canvas's gap and back
-- to full size, aiming at the gap every frame, then puts it back in the canvas there.
---@private
---@param commit boolean The section takes its gap's place in the order.
---@param after? fun()
---@param from? NextDragPoint
function nextDrag:land(commit, after, from)
  local state = self.current
  local canvas = state.panel.content
  lift:Land(state, function(left0, top0)
    return canvas.frame:GetLeft() or left0, (canvas.frame:GetTop() or top0) - (canvas:GetDragSlotY() or 0)
  end, function()
    self:reattach(false)
    canvas:EndDrag(commit)
    self:finish()
    if after then
      after()
    end
  end, from)
end

-- flyAway flies the section from where it is (the cursor's place, or from) into a point (a tab, the
-- other panel), shrinking and fading, then puts it back in its canvas hidden and leaving.
---@private
---@param x number
---@param y number
---@param after fun()
---@param from? NextDragPoint
function nextDrag:flyAway(x, y, after, from)
  local state = self.current
  local canvas = state.panel.content
  local frame = state.section.frame
  local s0 = from and from.scale or state.scale
  local x0, y0 = lift:Cursor()
  if from then
    state.scale = s0
    x0, y0 = from.left + state.grabX * s0, from.top - state.grabY * s0
  end
  local flyScale, shadow = style.Theme.Drag.FlyScale, lift:ShadowAlpha()
  tween:Play(state, {
    duration = style.Time.FlyAway,
    from = 0,
    to = 1,
    ease = style:Ease("FlyAway"),
    onUpdate = function(t)
      state.scale = s0 + (flyScale - s0) * t
      frame:SetAlpha(1 - t)
      self.shadow:SetAlpha(shadow * (1 - t))
      lift:Place(state, x0 + (x - x0) * t, y0 + (y - y0) * t)
    end,
    onDone = function()
      self:reattach(true)
      canvas:EndDrag(false)
      canvas:MarkLeaving(state.name, LEAVING_SECONDS)
      self:finish()
      after()
    end,
  })
end

-- buildDock makes the dock a move waits in to be confirmed (asked: a sale past what buyback keeps
-- asked in a dialog that "blends right in" while the section snapped back to the backpack). Over the
-- target's scroll area: a scrim that dims it and takes its clicks (nothing behind is bought), and a
-- card holding the section, edged in a pulsing amber glow, with what the move does, why it asks, and
-- how to answer. A catcher lies over the card above the section's item buttons, so a click there
-- answers rather than picking an item up: a double click confirms, a right click cancels.
---@private
function nextDrag:buildDock()
  if self.dock then
    return
  end
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:EnableMouse(true)
  frame:Hide()
  local scrim = frame:CreateTexture(nil, "BACKGROUND")
  scrim:SetAllPoints(frame)
  local box = dockCard:Create(frame)
  local catcher = CreateFrame("Button", nil, frame)
  catcher:SetAllPoints(box.frame)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- A double click is a mouse click, the hardware event selling and moving items need.
  addon.SetScript(catcher, "OnDoubleClick", function(ctx, _, button)
    if button == "LeftButton" then
      self:ConfirmPending(ctx)
    end
  end)
  addon.SetScript(catcher, "OnClick", function(_, _, button)
    if button == "RightButton" then
      self:CancelPending()
    end
  end)
  addon.SetScript(frame, "OnMouseUp", function(_, _, button)
    if button == "RightButton" then
      self:CancelPending()
    end
  end)
  self.dock = {
    frame = frame, scrim = scrim, box = box, card = box.frame, halo = box.halo, background = box.background,
    glow = box.glow, title = box.title, warning = box.warning, hint = box.hint, slot = box.slot, catcher = catcher,
    elapsed = 0,
  }
  self:styleDock()
  sonataNext:RegisterWidget(self)
end

-- styleLayer draws the hint naming the drop in its role (the theme's Drag.HintFont); NextLift draws
-- the shadow.
---@private
function nextDrag:styleLayer()
  style:SetFont(self.hint, style.Theme.Drag.HintFont)
end

-- styleDock draws the dock from the theme (Dock): the scrim (a texture spec) and the card
-- (NextDockCard), at the top of the dock.
---@private
function nextDrag:styleDock()
  local d, D = self.dock, style.Theme.Dock
  style:Paint(d.scrim, D.Scrim)
  d.box:Style()
  d.card:ClearAllPoints()
  d.card:SetPoint("TOP", d.frame, "TOP", 0, -D.Top)
end

-- ApplyStyle restyles what the drag has made for the theme SonataNext applied: the hint, and the dock,
-- laid out again while a move waits in it (NextLift restyles the shadow).
---@param ctx Context
function nextDrag:ApplyStyle(ctx)
  local _ = ctx
  if self.layer then
    self:styleLayer()
  end
  if self.dock then
    self:styleDock()
    if self.current ~= nil and self.current.pending ~= nil then
      self:layoutDock()
      self:pulse(0)
    end
  end
end

-- layoutDock sizes the card round the section and its lines, scaled down to fit the target's scroll
-- area when it is taller.
---@private
function nextDrag:layoutDock()
  local d = self.dock
  local section = self.current.section
  local D = style.Theme.Dock
  local width = section.frame:GetWidth()
  local height = section.height or section.frame:GetHeight()
  local cardHeight = d.box:Size(width, height)
  local room = d.frame:GetHeight()
  local scale = 1
  if room ~= nil and room > D.Top * 2 then
    scale = math.min(1, (room - D.Top * 2) / cardHeight)
  end
  d.card:SetScale(scale)
  d.laidOut = height
end

-- pulse brightens and dims the dock's glow, and lays the card out again when the section's height
-- changed (the backpack drew it again).
---@private
---@param elapsed number
function nextDrag:pulse(elapsed)
  local d = self.dock
  d.elapsed = d.elapsed + elapsed
  d.box:Pulse(d.elapsed)
  local state = self.current
  if state and state.section.height ~= d.laidOut then
    self:layoutDock()
  end
end

-- Pend docks the dropped section in its target to wait for a confirmation: the dock over the target's
-- scroll area, with the confirmation's text, and the section flying from where it was dropped into
-- its card. The source keeps its gap (the drag goes on), so nothing goes back to it meanwhile.
-- confirm moves the section's items, as they are when confirmed.
---@param target NextDropTarget
---@param confirmation NextConfirmation
---@param confirm fun(ctx: Context, items: ItemData[]): boolean
function nextDrag:Pend(target, confirmation, confirm)
  local state = self.current
  self:buildDock()
  local d = self.dock
  local panel = target.panel
  state.pending = { target = target, confirm = confirm }
  local frame = state.section.frame
  local from = lift:ScreenPoint(frame)
  local cx, cy = lift:Cursor()
  if from == nil then
    from = { left = cx - state.grabX * state.scale, top = cy + state.grabY * state.scale, scale = state.scale }
  end
  d.frame:SetParent(panel.frame)
  d.frame:SetFrameStrata(panel.frame:GetFrameStrata())
  d.frame:SetFrameLevel(math.min(lift.MAX_LEVEL - lift.COVER_ABOVE * 2, lift:MaxLevel(panel.scroll.frame) + 10))
  d.frame:ClearAllPoints()
  d.frame:SetAllPoints(panel.scroll.frame)
  d.title:SetText(confirmation.title)
  d.warning:SetText(confirmation.warning)
  d.hint:SetText(confirmation.hint)
  d.elapsed = 0
  self:layoutDock()
  self:pulse(0)
  d.frame:SetAlpha(0)
  d.frame:Show()
  addon.SetScript(d.frame, "OnUpdate", function(_, _, elapsed)
    self:pulse(elapsed)
  end)
  lift:Detach()
  self.hint:Hide()
  local to = lift:ScreenPoint(d.slot)
  tween:Play(state, {
    duration = style.Time.Land,
    from = 0,
    to = 1,
    ease = style:Ease("Land"),
    onUpdate = function(t)
      d.frame:SetAlpha(t)
      if to then
        local s = from.scale + (to.scale - from.scale) * t
        frame:SetScale(s)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (from.left + (to.left - from.left) * t) / s,
          (from.top + (to.top - from.top) * t) / s)
      end
    end,
    onDone = function()
      self:seat()
    end,
  })
end

-- seat puts the section in the card's slot, at full size, under the catcher.
---@private
function nextDrag:seat()
  local d = self.dock
  local frame = self.current.section.frame
  frame:SetParent(d.card)
  frame:SetScale(1)
  frame:SetAlpha(1)
  frame:SetFrameStrata(d.frame:GetFrameStrata())
  -- Above the card, never lower: every frame in it moves with it, and one that would go below 0
  -- jumps to the top level (warcraft.wiki.gg "Frame Strata"), where the catcher cannot be above it.
  frame:SetFrameLevel(math.max(frame:GetFrameLevel(), d.card:GetFrameLevel() + 1))
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", d.slot, "TOPLEFT", 0, 0)
  frame:Show()
  d.catcher:SetFrameLevel(math.min(lift.MAX_LEVEL, lift:MaxLevel(frame) + lift.COVER_ABOVE))
  d.frame:SetAlpha(1)
end

-- undock takes the section out of the dock onto the drag layer where it was on screen, and hides the
-- dock. It returns where the section was, for its flight out (nil before the client placed it).
---@private
---@return NextDragPoint?
function nextDrag:undock()
  local state = self.current
  tween:Stop(state, true)
  local from = lift:Raise(state.section.frame)
  state.pending = nil
  self:hideDock()
  return from
end

-- hideDock hides the dock and stops its pulse.
---@private
function nextDrag:hideDock()
  local d = self.dock
  if d == nil then
    return
  end
  d.frame:SetScript("OnUpdate", nil)
  d.frame:Hide()
end

-- ConfirmPending confirms the move waiting in the dock (a double click on it): the target moves the
-- section's items as they are now, and the section flies into it, or lands back in its gap when
-- nothing was moved (nothing in it is left to move, or the target is closing).
---@param ctx Context
function nextDrag:ConfirmPending(ctx)
  local state = self.current
  local pending = state and state.pending
  if pending == nil then
    return
  end
  local target = pending.target
  local moved = false
  if target.panel:IsShown() and not target.panel.closing then
    moved = pending.confirm(ctx, self:SectionItems(state.section))
  end
  local from = self:undock()
  if not moved then
    state.panel.content:SetDragIndex(state.startIndex)
    self:land(false, nil, from)
    return
  end
  self:moveDone(ctx, target, nil, from)
end

-- CancelPending cancels the move waiting in the dock (a right click): the section lands back in its
-- gap, as the player asked.
function nextDrag:CancelPending()
  local state = self.current
  if state == nil or state.pending == nil then
    return
  end
  local from = self:undock()
  state.panel.content:SetDragIndex(state.startIndex)
  self:land(false, nil, from)
end

-- Drop drops the dragged section where the cursor is (the header's OnDragStop: a mouse release,
-- the hardware event moving items needs). Without that event (noMoves) a drop that would move
-- items lands back instead.
---@param ctx Context
---@param noMoves? boolean
function nextDrag:Drop(ctx, noMoves)
  local state = self.current
  if state == nil or state.landing then
    return
  end
  local target = self:FindTarget()
  if noMoves and target and (target.type == "bag" or target.type == "bagtab" or target.type == "sell") then
    target = nil
  end
  state.landing = true
  self:showTarget(nil)
  local src, canvas, name = state.panel, state.panel.content, state.name
  local kind = src.kind

  if target == nil or target.type == "reorder" then
    if target == nil then
      canvas:SetDragIndex(state.startIndex)
      self:land(false)
      return
    end
    local others = canvas:othersExcept(state.section)
    table.insert(others, math.min(canvas.drag.index, #others + 1), state.section)
    local names, index = {}, 0
    for _, section in ipairs(others) do
      if section.kind == "category" then
        table.insert(names, section.name)
        if section == state.section then
          index = #names
        end
      end
    end
    self:SaveOrder(kind, names, index)
    self:land(true, function()
      events:SendMessage(ctx, 'bags/Rederive', {
        backpack = kind == const.BAG_KIND.BACKPACK,
        bank = kind == const.BAG_KIND.BANK,
      })
    end)
    return
  end

  local list = self:SectionItems(state.section)
  local rederive
  if (target.type == "bag" or target.type == "bagtab") and isGuild(target.panel) then
    -- Deposited into the tab dropped on, else the guild bank's deposit tab; docked there while the
    -- guild bank waits for a confirmation; back in its place when nothing in it can go in.
    local container = target.tab and target.tab.id or nil
    local result, confirmation = target.panel:Deposit(ctx, list, container)
    if result == "confirm" then
      self:Pend(target, confirmation, function(c, items)
        return target.panel:Deposit(c, items, container, true) == "deposited"
      end)
      return
    end
    if result ~= "deposited" then
      canvas:SetDragIndex(state.startIndex)
      self:land(false)
      return
    end
  elseif (target.type == "bag" or target.type == "bagtab") and isGuild(src) then
    src:Withdraw(list)
    if target.type == "bagtab" then
      groups:AssignCategoryToGroup(ctx, target.panel.kind, name, target.tab.id)
      rederive = { resetLayout = true }
    end
  elseif target.type == "sell" then
    -- Back in its place when nothing sells; docked in the seller while it waits for a confirmation,
    -- which sells what of the section's items sells then.
    local sale = target.panel:SaleOf(list)
    if #sale == 0 then
      canvas:SetDragIndex(state.startIndex)
      self:land(false)
      return
    end
    local result, confirmation = target.panel:Sell(ctx, sale)
    if result == "confirm" then
      local seller = target.panel
      self:Pend(target, confirmation, function(c, items)
        local now = seller:SaleOf(items)
        return #now > 0 and seller:Sell(c, now, true) == "sold"
      end)
      return
    end
  elseif target.type == "tab" then
    groups:AssignCategoryToGroup(ctx, kind, name, target.tab.id)
    rederive = { backpack = kind == const.BAG_KIND.BACKPACK, bank = kind == const.BAG_KIND.BANK, resetLayout = true }
  elseif target.type == "bagtab" then
    local panel, id = target.panel, target.tab.id
    if panel.kind == const.BAG_KIND.BANK and panel:InTabMode() then
      sectionFrame:MoveItems(list, panel:BankTypeOfTab(id))
    elseif panel.kind == const.BAG_KIND.BANK then
      local group = groups:GetGroup(panel.kind, id)
      sectionFrame:MoveItems(list, groupBankType(group))
      groups:AssignCategoryToGroup(ctx, panel.kind, name, id, group.bankType)
      rederive = { resetLayout = true }
    else
      sectionFrame:MoveItems(list)
      groups:AssignCategoryToGroup(ctx, panel.kind, name, id)
      rederive = { resetLayout = true }
    end
  elseif target.type == "bag" then
    sectionFrame:MoveItems(list)
  end

  self:moveDone(ctx, target, rederive)
end

-- moveDone flies a section whose items moved into its target (the tab, else the panel's scroll
-- area), pulses the tab, and recalculates when the move assigned a category.
---@private
---@param ctx Context
---@param target NextDropTarget
---@param rederive? table What to recalculate (bags/Rederive), if anything.
---@param from? NextDragPoint
function nextDrag:moveDone(ctx, target, rederive, from)
  local x, y
  if target.tab then
    x, y = target.tab.button:GetCenter()
  else
    x, y = target.panel.scroll.frame:GetCenter()
  end
  if x == nil then
    x, y = lift:Cursor()
  end
  self:flyAway(x, y, function()
    if target.tab then
      target.panel.tabs:Pulse(target.tab.id)
    end
    if rederive then
      events:SendMessage(ctx, 'bags/Rederive', rederive)
    end
  end, from)
end

-- Cancel puts the dragged section straight back in its canvas, doing nothing (a move waiting to be
-- confirmed too: finish hides the dock).
function nextDrag:Cancel()
  local state = self.current
  if state == nil then
    return
  end
  if state.target then
    self:showTarget(nil)
  end
  local canvas = state.panel.content
  local dragging = canvas.drag ~= nil and canvas.drag.section == state.section
  self:reattach(false)
  if dragging then
    canvas:EndDrag(false)
  end
  self:finish()
end

-- PanelHidden cancels a drag from a panel that closed, and a move waiting to be confirmed in it.
---@param panel NextPanelFrame
function nextDrag:PanelHidden(panel)
  local state = self.current
  if state and (state.panel == panel or (state.pending and state.pending.target.panel == panel)) then
    self:Cancel()
  end
  panel:SetDropGlow(false)
end
