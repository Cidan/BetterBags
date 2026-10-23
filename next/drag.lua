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

---@class NextDock: AceModule
local nextDock = addon:GetModule('NextDock')

---@class NextLift: AceModule
local lift = addon:GetModule('NextLift')

-- NextDrag moves BetterBagsNext's sections by their headers (next.md §7). A section picked up
-- leaves its canvas for the drag layer with its real item buttons and follows the cursor (NextLift,
-- which the settings lists' rows are dragged with too), the canvas keeping a gap where it would go; dropping it reorders it (saving its place), assigns its
-- category to a tab's group, moves its items to the other bag (and that bag's tab), or sells them
-- to a seller (the vendor). Drop targets are found from the cursor's position every frame. A move the
-- target confirms first (a sale past what buyback keeps, a deposit that cannot be taken back) ends the
-- drag and hands the section to the target's dock (NextDock, a list of sections waiting there), where
-- a double click confirms it and a right click sends it back to its place.
---@class NextDrag: AceModule
local nextDrag = addon:NewModule('NextDrag')


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

-- NextConfirmation is what a docked section's card says for a move its target confirms first.
---@class (exact) NextConfirmation
---@field title string What the move does ("Sell 23 items?").
---@field warning string Why it asks.
---@field hint string How to answer ("Double-click to sell · Right-click to cancel").

---@class (exact) NextDropTarget
---@field type NextDropKind
---@field panel NextPanelFrame
---@field tab? NextTab

-- NextDragState is a section's drag; NextLift fills in where it was grabbed and its scale. landing:
-- it was dropped and is flying to where it goes.
---@class NextDragState: NextLifted
---@field panel NextPanelFrame The panel the section came from.
---@field section NextSection
---@field name string
---@field startIndex number Where its gap was at pickup.
---@field target? NextDropTarget
---@field released? number Frames in a row the left button was up without a drop.

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

-- Begin picks a panel's section up, unless it is not a category, waits in a dock (NextDock), the panel
-- shows the Show Bags view, or a section is already being dragged. Sections waiting in docks wait on.
-- It returns whether it did.
---@param panel NextPanelFrame
---@param section NextSection
---@return boolean
function nextDrag:Begin(panel, section)
  if section.kind ~= "category" or not panel:IsShown() or panel.closing then
    return false
  end
  if self.current or panel.content:IsAway(section) or lift:IsHolding() then
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
  lift:FlyAway(state, x, y, function()
    self:reattach(true)
    canvas:EndDrag(false)
    canvas:MarkLeaving(state.name)
    self:finish()
    after()
  end, from)
end

-- styleLayer draws the hint naming the drop in its role (the theme's Drag.HintFont); NextLift draws
-- the shadow.
---@private
function nextDrag:styleLayer()
  style:SetFont(self.hint, style.Theme.Drag.HintFont)
end

-- ApplyStyle restyles the hint for the theme SonataNext applied (NextLift restyles the shadow, NextDock
-- its cards).
---@param ctx Context
function nextDrag:ApplyStyle(ctx)
  local _ = ctx
  if self.layer then
    self:styleLayer()
  end
end

-- Pend hands the dropped section to its target's dock (NextDock) to wait for a confirmation, ending the
-- drag: it flies from where it was dropped into its card there, out of its bag's column, which closes
-- up. A double click confirms (confirm moves the section's items as they are then, and the section flies
-- into the target); it is sent back to its place when nothing moved (nothing in it left to move, the
-- target closing) or on a right click.
---@param target NextDropTarget
---@param confirmation NextConfirmation
---@param confirm fun(ctx: Context, items: ItemData[]): boolean
function nextDrag:Pend(target, confirmation, confirm)
  local state = self.current
  local section, panel = state.section, target.panel
  local from = lift:ScreenPoint(section.frame)
  if from == nil then
    local cx, cy = lift:Cursor()
    from = { left = cx - state.grabX * state.scale, top = cy + state.grabY * state.scale, scale = state.scale }
  end
  self.hint:Hide()
  lift:Release(state)
  state.panel.content:EndDrag(false)
  self:finish()
  nextDock:Add(panel, {
    section = section, source = state.panel, from = from, tab = target.tab,
    offer = {
      text = function() return confirmation.title, confirmation.warning, confirmation.hint end,
      confirm = function(ctx)
        if panel:IsShown() and not panel.closing and confirm(ctx, self:SectionItems(section)) then
          return "moved"
        end
        return "back"
      end,
    },
  })
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

-- Cancel puts the dragged section straight back in its canvas, doing nothing.
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

-- PanelHidden cancels a drag from a panel that closed (NextDock sends back what waits in it).
---@param panel NextPanelFrame
function nextDrag:PanelHidden(panel)
  local state = self.current
  if state and state.panel == panel then
    self:Cancel()
  end
  panel:SetDropGlow(false)
end
