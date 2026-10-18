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

---@class NextTween: AceModule
local tween = addon:GetModule('NextTween')

-- NextDrag moves BetterBagsNext's sections by their headers (next.md §7). A section picked up
-- leaves its canvas for the drag layer with its real item buttons and follows the cursor, the
-- canvas keeping a gap where it would go; dropping it reorders it (saving its place), assigns its
-- category to a tab's group, moves its items to the other bag (and that bag's tab), or sells them
-- to a seller (the vendor). Drop targets are found from the cursor's position every frame.
---@class NextDrag: AceModule
local nextDrag = addon:NewModule('NextDrag')

-- How much a picked-up section shrinks, and how small it gets flying into a target.
local LIFT_SCALE = 0.94
local FLY_SCALE = 0.15
-- How far from the scroll area's top or bottom it scrolls, and how fast at the edge (per second).
local SCROLL_EDGE = 40
local SCROLL_SPEED = 700
-- How long a section moved away stays out of its column while its items are still there.
local LEAVING_SECONDS = 3
-- How far past a dragged section's edges its cover reaches: the client starts a drag only once
-- the cursor has moved a little, so the point grabbed can be just outside the section.
local COVER_MARGIN = 20
-- How far above the highest frame in a dragged section its cover sits, for buttons drawn into it
-- while it is dragged.
local COVER_ABOVE = 100
-- The highest frame level there is (warcraft.wiki.gg "Frame Strata").
local MAX_LEVEL = 10000

---@alias NextDropKind "reorder"|"tab"|"bagtab"|"bag"|"sell"

-- NextSeller is a panel that buys sections (BetterBags Next's vendor, next.md §10): never a source,
-- a target for backpack sections anywhere on its body or tabs.
---@class NextSeller
---@field body Frame
---@field tabs NextTabRail
---@field scroll ScrollboxDrawable
---@field closing boolean
---@field IsShown fun(self): boolean
---@field SetDropGlow fun(self, on: boolean)
---@field SaleOf fun(self, list: ItemData[]): ItemData[] What of the section's items it would sell.
---@field Sell fun(self, ctx: Context, sale: ItemData[]): string "sold", or "asked" when it asks first.

---@class (exact) NextDropTarget
---@field type NextDropKind
---@field panel NextPanelFrame
---@field tab? NextTab

---@class (exact) NextDragState
---@field panel NextPanelFrame The panel the section came from.
---@field section NextSection
---@field name string
---@field grabX number From the section's left to the cursor at pickup.
---@field grabY number From the section's top down to the cursor at pickup.
---@field scale number
---@field startIndex number Where its gap was at pickup.
---@field target? NextDropTarget
---@field landing boolean It was dropped and is flying to where it goes.
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

-- cursor returns the cursor's position in UIParent's coordinates.
---@return number x, number y
local function cursor()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

-- buildLayer makes the full-screen drag layer above everything, with the shadow a picked-up
-- section casts and the line naming what dropping does. It takes no mouse.
---@private
function nextDrag:buildLayer()
  if self.layer then
    return
  end
  local layer = CreateFrame("Frame", "BetterBagsNextDragLayer", UIParent)
  layer:SetAllPoints(UIParent)
  layer:SetFrameStrata("TOOLTIP")
  layer:EnableMouse(false)
  local shadow = layer:CreateTexture(nil, "BACKGROUND")
  shadow:SetColorTexture(0, 0, 0, 1)
  shadow:Hide()
  local hint = layer:CreateFontString(nil, "OVERLAY")
  hint:SetFontObject(style:Font("TabSelected"))
  hint:Hide()
  -- The cover lies over a dragged section and takes the mouse, so the release lands on it and
  -- not on one of the section's item buttons: their OnReceiveDrag is a left click
  -- (ContainerFrameItemButtonMixin), which picks the item up. It does nothing with it. The drop
  -- is the header's OnDragStop, which the client sends to the frame being dragged wherever the
  -- cursor is, and targets are found by position, so neither depends on what is under the cursor.
  local cover = CreateFrame("Frame", nil, layer)
  cover:EnableMouse(true)
  cover:Hide()
  self.layer = layer
  self.shadow = shadow
  self.hint = hint
  self.cover = cover
end

-- maxLevel returns the highest frame level in frame and every frame below it.
---@param frame Frame
---@return number
local function maxLevel(frame)
  local level = frame:GetFrameLevel()
  for _, child in ipairs({ frame:GetChildren() }) do
    level = math.max(level, maxLevel(child))
  end
  return level
end

-- place puts the dragged section so that the point grabbed is at x, y, at its scale.
---@private
---@param x number
---@param y number
function nextDrag:place(x, y)
  local state = self.current
  local frame = state.section.frame
  local s = state.scale
  frame:SetScale(s)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x - state.grabX * s) / s, (y + state.grabY * s) / s)
end

-- Begin picks a panel's section up, unless it is not a category, the panel shows the Show Bags
-- view, or a section is already being dragged. It returns whether it did.
---@param panel NextPanelFrame
---@param section NextSection
---@return boolean
function nextDrag:Begin(panel, section)
  if self.current or section.kind ~= "category" or not panel:IsShown() or panel.closing then
    return false
  end
  if database:GetBagView(panel.kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
    return false
  end
  local frame = section.frame
  local left, top = frame:GetLeft(), frame:GetTop()
  if left == nil or top == nil then
    return false
  end
  self:buildLayer()
  local x, y = cursor()
  local canvas = panel.content
  canvas:BeginDrag(section, function()
    self:Cancel()
  end)
  ---@type NextDragState
  self.current = {
    panel = panel, section = section, name = section.name, grabX = x - left, grabY = top - y, scale = 1,
    startIndex = canvas.drag.index, landing = false,
  }
  GameTooltip:Hide()
  frame:SetParent(self.layer)
  frame:SetFrameStrata("TOOLTIP")
  -- Never lower it: every frame in it moves with it, and one that would go below 0 jumps to the top
  -- level (warcraft.wiki.gg "Frame Strata"), where the cover cannot be above it.
  frame:SetFrameLevel(math.max(frame:GetFrameLevel(), self.layer:GetFrameLevel() + 2))
  self:place(x, y)
  self.shadow:ClearAllPoints()
  self.shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 10)
  self.shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, -10)
  self.shadow:SetAlpha(0)
  self.shadow:Show()
  local cover = self.cover
  cover:ClearAllPoints()
  cover:SetPoint("TOPLEFT", frame, "TOPLEFT", -COVER_MARGIN, COVER_MARGIN)
  cover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", COVER_MARGIN, -COVER_MARGIN)
  cover:SetFrameLevel(math.min(MAX_LEVEL, maxLevel(frame) + COVER_ABOVE))
  cover:Show()
  local state = self.current
  tween:Play(self, {
    duration = style.Time.Lift,
    from = 0,
    to = 1,
    onUpdate = function(t)
      state.scale = 1 - (1 - LIFT_SCALE) * t
      self.shadow:SetAlpha(0.35 * t)
      if not state.landing then
        self:place(cursor())
      end
    end,
  })
  self.layer:SetScript("OnUpdate", function(_, elapsed)
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
    if panel:InTabMode() or tab.id == panel:GetCurrentTabID() then
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
  if not addon.atBank then
    return false
  end
  return panel:InTabMode() or groups:GetGroup(panel.kind, tab.id) ~= nil
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
        if addon.atBank then
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
    self.hint:SetPoint("TOP", state.section.frame, "BOTTOM", 0, -6)
    self.hint:Show()
  else
    self.hint:Hide()
  end
end

-- autoScroll scrolls the source panel's content while the cursor is near its top or bottom.
---@private
---@param y number
---@param elapsed number
function nextDrag:autoScroll(y, elapsed)
  local scroll = self.current.panel.scroll
  local top, bottom = scroll.frame:GetTop(), scroll.frame:GetBottom()
  if top == nil or bottom == nil then
    return
  end
  local closeness = 0
  if y > top - SCROLL_EDGE then
    closeness = -math.min(1, (y - (top - SCROLL_EDGE)) / SCROLL_EDGE)
  elseif y < bottom + SCROLL_EDGE then
    closeness = math.min(1, ((bottom + SCROLL_EDGE) - y) / SCROLL_EDGE)
  end
  if closeness ~= 0 then
    local box = scroll.scrollBox
    box:ScrollToOffset(math.max(0, box:GetDerivedScrollOffset() + closeness * SCROLL_SPEED * elapsed), true)
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
  local x, y = cursor()
  self:place(x, y)
  local target = self:FindTarget()
  self:showTarget(target)
  if target and target.type == "reorder" then
    local canvas = state.panel.content
    local top = canvas.frame:GetTop()
    if top then
      canvas:SetDragIndex(canvas:DragIndexAt(top - y))
    end
    self:autoScroll(y, elapsed)
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
  frame:SetParent(canvas.frame)
  frame:SetScale(1)
  frame:SetAlpha(1)
  frame:SetFrameStrata(canvas.frame:GetFrameStrata())
  frame:SetFrameLevel(canvas.frame:GetFrameLevel() + 1)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", canvas.frame, "TOPLEFT", 0, -(canvas:GetDragSlotY() or state.section.y or 0))
  if hidden then
    frame:Hide()
  end
  self.shadow:Hide()
  self.hint:Hide()
  self.cover:Hide()
end

-- finish ends the drag: the target unlit, the driver stopped.
---@private
function nextDrag:finish()
  local state = self.current
  if state and state.target then
    self:showTarget(nil)
  end
  self.current = nil
  tween:Stop(self)
  if self.layer then
    self.layer:SetScript("OnUpdate", nil)
  end
end

-- land flies the section from where it is into its canvas's gap and back to full size, aiming at
-- the gap every frame, then puts it back in the canvas there.
---@private
---@param commit boolean The section takes its gap's place in the order.
---@param after? fun()
function nextDrag:land(commit, after)
  local state = self.current
  local canvas = state.panel.content
  local frame = state.section.frame
  local s0 = state.scale
  -- Where place put it: the client reports a scaled frame's edges in its own scale.
  local cx, cy = cursor()
  local left0, top0 = cx - state.grabX * s0, cy + state.grabY * s0
  local shadow0 = self.shadow:GetAlpha()
  tween:Play(self, {
    duration = style.Time.Land,
    from = 0,
    to = 1,
    ease = "outCubic",
    onUpdate = function(t)
      local left = (canvas.frame:GetLeft() or left0)
      local top = (canvas.frame:GetTop() or top0) - (canvas:GetDragSlotY() or 0)
      local s = s0 + (1 - s0) * t
      local x, y = left0 + (left - left0) * t, top0 + (top - top0) * t
      frame:SetScale(s)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
      self.shadow:SetAlpha(shadow0 * (1 - t))
    end,
    onDone = function()
      self:reattach(false)
      canvas:EndDrag(commit)
      self:finish()
      if after then
        after()
      end
    end,
  })
end

-- flyAway flies the section into a point (a tab, the other panel), shrinking and fading, then
-- puts it back in its canvas hidden and leaving.
---@private
---@param x number
---@param y number
---@param after fun()
function nextDrag:flyAway(x, y, after)
  local state = self.current
  local canvas = state.panel.content
  local frame = state.section.frame
  local s0 = state.scale
  local x0, y0 = cursor()
  tween:Play(self, {
    duration = style.Time.FlyAway,
    from = 0,
    to = 1,
    ease = "inCubic",
    onUpdate = function(t)
      state.scale = s0 + (FLY_SCALE - s0) * t
      frame:SetAlpha(1 - t)
      self.shadow:SetAlpha(0.35 * (1 - t))
      self:place(x0 + (x - x0) * t, y0 + (y - y0) * t)
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
  if target.type == "sell" then
    -- Back in its place when nothing sells, or while the seller asks first.
    local sale = target.panel:SaleOf(list)
    if #sale == 0 or target.panel:Sell(ctx, sale) ~= "sold" then
      canvas:SetDragIndex(state.startIndex)
      self:land(false)
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

  local x, y
  if target.tab then
    x, y = target.tab.button:GetCenter()
  else
    x, y = target.panel.scroll.frame:GetCenter()
  end
  if x == nil then
    x, y = cursor()
  end
  self:flyAway(x, y, function()
    if target.tab then
      target.panel.tabs:Pulse(target.tab.id)
    end
    if rederive then
      events:SendMessage(ctx, 'bags/Rederive', rederive)
    end
  end)
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
  tween:Stop(self)
  local canvas = state.panel.content
  local dragging = canvas.drag ~= nil and canvas.drag.section == state.section
  self:reattach(false)
  if dragging then
    canvas:EndDrag(false)
  end
  self:finish()
end

-- PanelHidden cancels a drag from a panel that closed.
---@param panel NextPanelFrame
function nextDrag:PanelHidden(panel)
  if self.current and self.current.panel == panel then
    self:Cancel()
  end
  panel:SetDropGlow(false)
end
