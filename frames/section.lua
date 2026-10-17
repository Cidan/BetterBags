local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
---@field currentTooltip Section
local sectionFrame = addon:NewModule('SectionFrame')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class SonataElements: AceModule
local elements = addon:GetModule('SonataElements')

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class MovementFlow: AceModule
local movementFlow = addon:GetModule('MovementFlow')

---@class Pool: AceModule
local pool = addon:GetModule('Pool')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- Module-level variable to track dragged category
sectionFrame.draggingCategory = nil
sectionFrame.draggingKind = nil       -- BAG_KIND of the section being dragged
sectionFrame.draggingBankType = nil   -- bankType of the active bank group when dragging a bank section
sectionFrame.dragGhost = nil
sectionFrame.dragTargetTab = nil  -- Track the tab we're hovering over while dragging

-------
--- Section Prototype
-------

--- Section is a view of a single bag section. A section
--- has a title, and contains all the items views for a section.
---
--- Sections can be rendered in multiple different ways, such as
--- a list of icons, a list of rows, or a grid of icons.
---@class Section
---@field frame Frame The raw frame of the section.
---@field title Button The title of the section.
---@field overlay Frame The overlay frame of the section, used as a drop zone.
---@field private content Grid The main content frame of the section.
---@field private fillWidth boolean
---@field private headerDisabled boolean
---@field private maxItemsPerRow number
---@field private kind BagKind
local sectionProto = {}
addon:GetModule('Perf'):RegisterPrototype(sectionProto, 'Section')

---@param kind BagKind
---@param view BagView
---@param freeSpaceShown boolean
---@return number width
---@return number height
function sectionProto:Draw(kind, view, freeSpaceShown)
  return self:Grid(kind, view, freeSpaceShown)
end

-- SetTitle will set the title of the section.
---@param text string The text to set the title to.
---@param color? number[] Optional RGB color array {r, g, b} to apply to the title.
function sectionProto:SetTitle(text, color)
  self.title:SetText(text)

  -- The theme sets the title's font (a SectionHeader element), and a custom color stays on the
  -- font string until something resets it, so a pooled section always sets the color: the
  -- custom one, else the theme's.
  local fontString = self.title:GetFontString()
  if color and color[1] and color[2] and color[3] then
    fontString:SetTextColor(color[1], color[2], color[3], 1)
  else
    fontString:SetTextColor(elements:GetSectionHeaderColor(fontString))
  end
end

-- GetTitle returns the title text, which is the section's category.
---@return string
function sectionProto:GetTitle()
  return self.title:GetText()
end

function sectionProto:AddCell(id, cell)
  if self.content:GetCell(id) ~= nil then return end
  self.content:AddCell(id, cell)
end

function sectionProto:RemoveCell(id)
  self.content:RemoveCell(id)
end

function sectionProto:RekeyCell(oldID, newID)
  self.content:RekeyCell(oldID, newID)
end

function sectionProto:GetMaxCellWidth()
  return self.maxItemsPerRow
end

function sectionProto:SetMaxCellWidth(width)
  self.maxItemsPerRow = width
end

function sectionProto:GetCellCount()
  return #self.content.cells
end

function sectionProto:SetFillWidth(fill)
  self.fillWidth = fill
end

---@return boolean
function sectionProto:GetFillWidth()
  return self.fillWidth
end

function sectionProto:GetContent()
  return self.content
end

---@return BagKind
function sectionProto:GetKind()
  return self.kind
end

---@param ctx Context
function sectionProto:ReleaseAllCells(ctx)
  for _, cell in pairs(self.content.cells) do
    -- Gap cells are plain math tables ({ isGap = true, ... }) with no frame and
    -- no Release method; they must be skipped or the wipe path errors.
    if not cell.isGap then
      cell:Release(ctx)
    end
  end
end

function sectionProto:Wipe()
  self.content:Wipe()
  self.frame:Hide()
  self.view = const.BAG_VIEW.SECTION_GRID
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.fillWidth = false
  self.frame:SetAlpha(1)
  self.removeHeader = false
  self.title:Show()
end

-- PrepareForReuse readies a section kept from the previous render pass to be drawn
-- again: the per-pass state the pool reset clears, without hiding or unparenting it.
function sectionProto:PrepareForReuse()
  self:EnableHeader()
  self.content:SortHorizontal()
  self.content:Wipe()
  self.view = const.BAG_VIEW.SECTION_GRID
  self.fillWidth = false
  self.frame:SetAlpha(1)
  self.removeHeader = false
  self.title:Show()
end

function sectionProto:WipeOnlyContents()
  self.content:Wipe()
end

---@param alpha number
function sectionProto:SetAlpha(alpha)
  self.frame:SetAlpha(alpha)
end

function sectionProto:DisableHeader()
  self.headerDisabled = true
end

function sectionProto:EnableHeader()
  self.headerDisabled = false
end

function sectionProto:RemoveHeader()
  self.removeHeader = true
end

---@param item Item|ItemRow
---@return boolean
function sectionProto:HasItem(item)
  for _, i in pairs(self.content.cells) do
    if item == i then
      return true
    end
  end
  return false
end

function sectionProto:GetAllCells()
  return self.content.idToCell
end

---@return string[]
function sectionProto:GetKeys()
  local keys  = {}
  for k, _ in pairs(self.content.idToCell) do
    table.insert(keys, k)
  end
  return keys
end

---@return Cell[]|Item[]|Section[]
function sectionProto:GetRawCells()
  return self.content.cells
end

---@param ctx Context
function sectionProto:Release(ctx)
  sectionFrame._pool:Release(ctx, self)
end

function sectionProto:DislocateCell(slotkey)
  self.content:DislocateCell(slotkey)
end

function sectionProto:DislocateAllCellsWithID(slotkey)
  self.content:DislocateAllCellsWithID(slotkey)
end

-- The widest row a section of N items per row may lay out: N 37-pixel cells 4 apart, with room
-- to spare below the next cell (render/flow.lua checks a row without the gap before its last cell).
---@param itemsPerRow number
---@return number
local function rowLimit(itemsPerRow)
  return ((37 + 4) * itemsPerRow) + 16
end

---@class (exact) SectionMeasure
---@field itemsPerRow number
---@field content GridMeasure Where the section's cells go.
---@field width number The section's width: its cells (or its title) and 6 pixels on each side, in whole pixels.
---@field height number
---@field hidden? boolean It has nothing to show.

-- Measure works out the section's size with itemsPerRow cells in a row, moving nothing
-- (render-pipeline.md, the layout engine): 6 pixels of padding on each side of its cells, as wide
-- as its title's text (rounded up to a whole pixel) when full names show, and its title's height
-- above them unless the header is removed.
---@param kind BagKind
---@param itemsPerRow number
---@return SectionMeasure
function sectionProto:Measure(kind, itemsPerRow)
  local content = self.content:Measure({ cells = self.content.cells, maxWidthPerRow = rowLimit(itemsPerRow) })
  local w, h = content.width, content.height
  if w == 0 then
    return { itemsPerRow = itemsPerRow, content = content, width = 0, height = 0, hidden = true }
  end
  if self.fillWidth or database:GetShowFullSectionNames(kind) then
    w = math.max(w, math.ceil(self.title:GetTextWidth()))
  end
  local height = self.removeHeader and h or (h + self.title:GetHeight() + 6)
  return { itemsPerRow = itemsPerRow, content = content, width = w + 12, height = height }
end

-- Arrange applies a measure: the cells where it put them, the title, and the section's size.
---@param kind BagKind
---@param measured SectionMeasure
---@return number width
---@return number height
function sectionProto:Arrange(kind, measured)
  self.kind = kind
  self.maxItemsPerRow = measured.itemsPerRow
  if measured.hidden then
    self.frame:Hide()
    return 0, 0
  end
  self.content:Arrange(measured.content)
  if self.removeHeader then
    self.title:Hide()
    self.content:GetContainer():SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, 0)
  else
    self.title:Show()
    self.content:GetContainer():SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
  end
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -6, 0)
  self.content:Show()
  self.frame:SetSize(measured.width, measured.height)
  self.frame:Show()
  return measured.width, measured.height
end

-- GetItemsPerRowCap returns the items per row from which all the section's cells fit one row:
-- measuring it with more changes nothing.
---@return number
function sectionProto:GetItemsPerRowCap()
  local oneRow = self.content:Measure({ cells = self.content.cells, maxWidthPerRow = math.huge }).width
  return math.max(1, math.ceil((oneRow - 16) / (37 + 4)))
end

-- Grid will render the section as a grid of icons, at its items per row.
---@param kind BagKind
---@param _view BagView
---@param _freeSpaceShown boolean
---@return number width
---@return number height
function sectionProto:Grid(kind, _view, _freeSpaceShown)
  return self:Arrange(kind, self:Measure(kind, self.maxItemsPerRow))
end

-------
--- Section Frame
-------

function sectionFrame:Init()
  self._pool = pool:Create(self._DoCreate, self._DoReset)
  events:RegisterEvent('MODIFIER_STATE_CHANGED', function()
    if self.currentTooltip then
      self.currentTooltip:onTitleMouseEnter()
    end
  end)
end

-- Create and return the drag ghost frame (created once, reused)
function sectionFrame:GetDragGhost()
  if not self.dragGhost then
    local ghost = CreateFrame("Frame", "BetterBagsSectionDragGhost", UIParent, "BackdropTemplate")
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(100)
    ghost:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ghost:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    ghost:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    local text = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", ghost, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1, 1)
    ghost.text = text

    ghost:SetSize(100, 24)
    ghost:Hide()

    -- Update position to follow cursor
    ghost:SetScript("OnUpdate", function(frame)
      local x, y = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 20, y / scale - 10)
    end)

    self.dragGhost = ghost
  end
  return self.dragGhost
end

-- Show the drag ghost with the given category name
function sectionFrame:ShowDragGhost(categoryName)
  local ghost = self:GetDragGhost()
  ghost.text:SetText(categoryName)
  -- Size to fit text
  local textWidth = ghost.text:GetStringWidth()
  ghost:SetSize(math.max(textWidth + 20, 80), 24)
  ghost:ClearAllPoints()
  ghost:Show()
end

-- Hide the drag ghost
function sectionFrame:HideDragGhost()
  if self.dragGhost then
    self.dragGhost:Hide()
  end
end

-- ResetTabHighlights puts every tab of both bags back in its state after a drag ends.
function sectionFrame:ResetTabHighlights()
  local tabs = addon:GetModule("Tabs")
  local bags = addon.Bags or {}
  for _, bag in ipairs({ bags.Backpack or false, bags.Bank or false }) do
    if bag and bag.tabs then
      tabs:ResetDropHighlights(bag.tabs)
    end
  end
  GameTooltip:Hide()
end

-- Perform the drop action on the target tab
function sectionFrame:PerformDrop()
  if not self.draggingCategory then return end
  if not self.dragTargetTab then return end

  local category = self.draggingCategory
  local tabID = self.dragTargetTab

  local kind = self.draggingKind
  if not kind then return end

  local dropCtx = context:New("CategoryDropOnTab")
  local group = groups:GetGroup(kind, tabID)
  local bankType = group and group.bankType
  if groups:IsDefaultGroup(kind, tabID) then
    -- Dropping on default tabs removes group assignment
    groups:RemoveCategoryFromGroup(dropCtx, kind, category, bankType)
  else
    -- Dropping on other group assigns to that group
    groups:AssignCategoryToGroup(dropCtx, kind, category, tabID, bankType)
  end

  local eventsModule = addon:GetModule("Events")
  eventsModule:SendMessage(dropCtx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

---@param ctx Context
---@param f Section
function sectionFrame._DoReset(ctx, f)
  local _ = ctx
  f:EnableHeader()
  f:GetContent():SortHorizontal()
  f:Wipe()
end

---@param ctx Context
---@param section Section
function sectionFrame:OnTitleClickOrDrop(ctx, section)
  if not CursorHasItem() then return end
  if not IsShiftKeyDown() then
    -- Without Shift a title is part of its window's drop target (issue #408).
    local bag = addon:GetBagFromKind(section:GetKind())
    if bag then
      bag:PlaceCursorItem()
    end
    return
  end
  local cursorType, itemID = GetCursorInfo()
  ---@cast cursorType string
  ---@cast itemID number
  if cursorType ~= "item" then return end
  local category = section:GetTitle()
  categories:AddPermanentItemToCategory(ctx, itemID, category)
  ClearCursor()
  events:SendMessage(ctx, 'bags/Rederive', { resetLayout = true, buttons = true })
end

---@param section Section
function sectionFrame:OnTitleRightClick(section)
  local flow = movementFlow:GetMovementFlow()
  if flow == const.MOVEMENT_FLOW.UNDEFINED then return end
  if flow == const.MOVEMENT_FLOW.NPCSHOP and not db:GetCategorySell() then return end

  -- This list contains all items to move.
  ---@type ItemData[]
  local list = {}

  for _, cell in pairs(section:GetAllCells()) do
    -- Gap cells are plain math tables ({ isGap = true, ... }) with no frame and
    -- no GetItemData method; they persist in a section after items leave it
    -- (e.g. mailing away Recent Items) and must be skipped or this errors.
    if not cell.isGap then
      local data = cell:GetItemData()
      if not data.isItemEmpty then
        table.insert(list, data)

        -- checking stacks if Merge stacks is enabled and Unmerge at Shop disabled
        local stack = items:GetAllSlotInfo()[addon:GetBagFromBagID(data.bagid).kind].stacks:GetStackInfo(data.itemHash)
        if stack ~= nil then
          for subSlotKey in pairs(stack.slotkeys) do
            local subData = items:GetItemDataFromSlotKey(subSlotKey)
            table.insert(list, subData)
          end
        end
      end
    end
  end

  -- Limit the selling amount to be able to buy back
  if flow == const.MOVEMENT_FLOW.NPCSHOP then
    local newlist = {}
    for i=1, 10 do
      if list[i] then
        table.insert(newlist, list[i])
      end
    end
    list = newlist
  end

  -- Only DF since warbank has Enum.BankType
  local containerType = nil
  if Enum.BankType and flow == const.MOVEMENT_FLOW.WARBANK then
    containerType = Enum.BankType.Account
  end

  for _, item in pairs(list) do
    C_Container.UseContainerItem(item.bagid, item.slotid, nil, containerType, flow == const.MOVEMENT_FLOW.REAGENT)
  end
end

function sectionProto:onTitleMouseEnter()
  GameTooltip:SetOwner(self.title, "ANCHOR_TOPLEFT")
  GameTooltip:SetText(self.title:GetText())
  local info = strjoin(" ",
    "\n",
    "Item Count: " .. #self.content.cells
  )
  GameTooltip:AddLine(info, 1, 1, 1)

  -- Show group assignment info and drag hint for draggable sections
  local kind = self:GetKind()
  local category = self:GetTitle()
  if category ~= L:G("Free Space") and category ~= L:G("Recent Items") then
    local groupID = groups:GetGroupForCategory(kind, category)
    if groupID then
      local group = groups:GetGroup(kind, groupID)
      if group then
        GameTooltip:AddLine("Group: " .. group.name, 0.5, 0.8, 1)
      end
    end
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("Drag to a group tab to assign this category.", 0.7, 0.7, 0.7)
  end

  local cursorType, _, itemLink = GetCursorInfo()
  if CursorHasItem() and IsShiftKeyDown() then
    if cursorType == "item" then
      GameTooltip:AddLine(" ", 1, 1, 1)
      GameTooltip:AddLine("Drop "..itemLink.." here to add it to "..self.title:GetText()..".", 1, 1, 1)
    end
  elseif CursorHasItem() and cursorType == "item" then
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("Hold shift to add "..itemLink.." to "..self.title:GetText()..".", 1, 1, 1)
  end
  GameTooltip:Show()
end

---@return Section
function sectionFrame:_DoCreate()
  ---@class Section
  local s = {}
  setmetatable(s, { __index = sectionProto })

  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
  s.frame = f

  s.maxItemsPerRow = 5
  -- Create the section title.
  local title = CreateFrame("Button", nil, f)
  title:SetText("Not set")
  title:SetHeight(18)
  title:GetFontString():SetAllPoints()
  title:GetFontString():SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 6, 0)
  title:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -6, 0)
  title:SetScript("OnEnter", function()
    if s.headerDisabled then return end
    sectionFrame.currentTooltip = s
    s:onTitleMouseEnter()
  end)

  title:SetScript("OnLeave", function()
    if s.headerDisabled then return end
    sectionFrame.currentTooltip = nil
    GameTooltip:Hide()
  end)

  title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  title:RegisterForDrag("LeftButton")

  title:SetScript("OnDragStart", function()
    if s.headerDisabled then return end
    local category = s:GetTitle()
    -- Don't allow dragging special sections
    if category == L:G("Free Space") or category == L:G("Recent Items") then
      return
    end
    local kind = s:GetKind()
    if not kind then return end

    -- Determine bank type for bank sections so drop targets can be validated.
    local bankType = nil
    if kind == const.BAG_KIND.BANK then
      local activeGroupID = database:GetActiveGroup(const.BAG_KIND.BANK)
      if activeGroupID then
        local activeGroup = database:GetGroup(const.BAG_KIND.BANK, activeGroupID)
        if activeGroup then
          bankType = activeGroup.bankType
        end
      end
    end

    sectionFrame.draggingCategory = category
    sectionFrame.draggingKind = kind
    sectionFrame.draggingBankType = bankType
    sectionFrame.dragTargetTab = nil
    sectionFrame:ShowDragGhost(category)
  end)

  title:SetScript("OnDragStop", function()
    if sectionFrame.draggingCategory then
      -- Perform the drop if we have a valid target
      sectionFrame:PerformDrop()
    end
    sectionFrame.draggingCategory = nil
    sectionFrame.draggingKind = nil
    sectionFrame.draggingBankType = nil
    sectionFrame.dragTargetTab = nil
    sectionFrame:HideDragGhost()
    sectionFrame:ResetTabHighlights()
  end)

  addon.SetScript(title, "OnClick", function(ctx, _, e)
    if s.headerDisabled then return end
    if e == "RightButton" then
      sectionFrame:OnTitleRightClick(s)
    elseif e == "LeftButton" then
      -- Only handle left-click when cursor has an item for category assignment
      if CursorHasItem() then
        sectionFrame:OnTitleClickOrDrop(ctx, s)
      end
    end
  end)

  addon.SetScript(title, "OnReceiveDrag", function(ctx)
    if s.headerDisabled then return end
    sectionFrame:OnTitleClickOrDrop(ctx, s)
  end)

  s.title = title

  sonata:RegisterElement("SectionHeader", title:GetFontString())

  local content = grid:Create(s.frame)
  content:Show()
  content:HideScrollBar()
  -- Section content grids are not scrollable; disable mouse wheel so scroll
  -- events pass through to the outer scrollable bag container instead.
  content:EnableMouseWheelScroll(false)
  s.content = content
  f:Show()
  return s
end

-- Create will create a new section view.
---@param ctx Context
---@return Section
function sectionFrame:Create(ctx)
  ---@return Section
  return self._pool:Acquire(ctx)
end
