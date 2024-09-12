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

---@class Sort: AceModule
local sort = addon:GetModule('Sort')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

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
local sectionProto = {}

---@param kind BagKind
---@param view BagView
---@param freeSpaceShown boolean
---@param nosort? boolean
---@return number width
---@return number height
function sectionProto:Draw(kind, view, freeSpaceShown, nosort)
  return self:Grid(kind, view, freeSpaceShown, nosort)
end

-- SetTitle will set the title of the section.
---@param text string The text to set the title to.
function sectionProto:SetTitle(text)
  self.title:SetText(text)
  themes:UpdateSectionFont(self.title:GetFontString())
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

---@param ctx Context
function sectionProto:ReleaseAllCells(ctx)
  for _, cell in pairs(self.content.cells) do
    cell:Release(ctx)
  end
end

---@return Cell[]|Item[]|Section[]|any[]
function sectionProto:GetCellList()
  return self.content.cells
end

function sectionProto:Wipe()
  self.content:Wipe()
  self.frame:Hide()
  self.view = const.BAG_VIEW.SECTION_GRID
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.fillWidth = false
  self.frame:SetAlpha(1)
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

-- Grid will render the section as a grid of icons.
---@param kind BagKind
---@param view BagView
---@param freeSpaceShown boolean
---@param nosort? boolean
---@return number width
---@return number height
function sectionProto:Grid(kind, view, freeSpaceShown, nosort)
  if not nosort then
    if freeSpaceShown then
      self.content:Sort(sort.GetItemSortBySlot)
    else
      self.content:Sort(sort:GetItemSortFunction(kind, view))
    end
  end
  local w, h = self.content:Draw({
    cells = self.content.cells,
    maxWidthPerRow = ((37 + 4) * self.maxItemsPerRow) + 16,
  })
  self.content:GetContainer():SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -6, 0)
  self.content:Show()
  if w == 0 then
    self.frame:Hide()
    return 0, 0
  end
  if self.fillWidth or database:GetShowFullSectionNames(kind) then
    w = math.max(w, self.title:GetTextWidth())
  end
  self.frame:SetSize(w + 12, h + self.title:GetHeight() + 6)
  self.frame:Show()
  return w + 12, h + self.title:GetHeight() + 6
end

-------
--- Section Frame
-------

function sectionFrame:OnInitialize()
  self._pool = pool:Create(self._DoCreate, self._DoReset)
  events:RegisterEvent('MODIFIER_STATE_CHANGED', function()
    if self.currentTooltip then
      self.currentTooltip:onTitleMouseEnter()
    end
  end)
end

---@param ctx Context
---@param f Section
function sectionFrame._DoReset(ctx, f)
  _ = ctx
  f:EnableHeader()
  f:GetContent():SortHorizontal()
  f:Wipe()
end

---@param ctx Context
---@param section Section
function sectionFrame:OnTitleClickOrDrop(ctx, section)
  if not CursorHasItem() then return end
  if not IsShiftKeyDown() then return end
  local cursorType, itemID = GetCursorInfo()
  ---@cast cursorType string
  ---@cast itemID number
  if cursorType ~= "item" then return end
  local category = section.title:GetText()
  categories:AddPermanentItemToCategory(ctx, itemID, category)
  ClearCursor()
  events:SendMessage(ctx, 'bags/FullRefreshAll')
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

  addon.SetScript(title, "OnClick", function(ctx, _, e)
    if s.headerDisabled then return end
    if e == "RightButton" then
      sectionFrame:OnTitleRightClick(s)
    elseif e == "LeftButton" then
      sectionFrame:OnTitleClickOrDrop(ctx, s)
    end
  end)

  addon.SetScript(title, "OnReceiveDrag", function(ctx)
    if s.headerDisabled then return end
    sectionFrame:OnTitleClickOrDrop(ctx, s)
  end)

  s.title = title

  themes:RegisterSectionFont(title:GetFontString())

  local content = grid:Create(s.frame)
  content:Show()
  content:HideScrollBar()
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
