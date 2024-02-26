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

---@class GridFrame: AceModule
local grid = addon:GetModule('Grid')

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
local sectionProto = {}

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
function sectionProto:SetTitle(text)
  self.title:SetText(text)
end

function sectionProto:AddCell(id, cell)
  if self.content:GetCell(id) ~= nil then return end
  self.content:AddCell(id, cell)
end

function sectionProto:RemoveCell(id)
  self.content:RemoveCell(id)
end

function sectionProto:GetMaxCellWidth()
  return self.content.maxCellWidth
end

function sectionProto:SetMaxCellWidth(width)
  self.content.maxCellWidth = width
end

function sectionProto:GetCellCount()
  return #self.content.cells
end

function sectionProto:SetFillWidth(fill)
  self.fillWidth = fill
end

function sectionProto:GetContent()
  return self.content
end

function sectionProto:ReleaseAllCells()
  for _, cell in pairs(self.content.cells) do
    cell:Release()
  end
end

function sectionProto:Wipe()
  self.content:Wipe()
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

function sectionProto:Release()
  sectionFrame._pool:Release(self)
end

-- Grid will render the section as a grid of icons.
---@param kind BagKind
---@param view BagView
---@param freeSpaceShown boolean
---@return number width
---@return number height
function sectionProto:Grid(kind, view, freeSpaceShown)
  if freeSpaceShown then
    self.content:Sort(sort.GetItemSortBySlot)
  else
    self.content:Sort(sort:GetItemSortFunction(kind, view))
  end
  local w, h = self.content:Draw()
  self.content:GetContainer():SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -6, 0)
  self.content:Show()
  if w == 0 then
    self.frame:Hide()
    return 0, 0
  end
  self.frame:SetSize(w + 12, h + self.title:GetHeight() + 6)
  self.frame:Show()
  return w+12, h + self.title:GetHeight() + 6
end

-------
--- Section Frame
-------

function sectionFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
  events:RegisterEvent('MODIFIER_STATE_CHANGED', function()
    if self.currentTooltip then
      self.currentTooltip:onTitleMouseEnter()
    end
  end)
end

---@param f Section
function sectionFrame:_DoReset(f)
  f:Wipe()
end

---@param section Section
local function onTitleClickOrDrop(section)
  if not CursorHasItem() then return end
  if not IsShiftKeyDown() then return end
  local cursorType, itemID = GetCursorInfo()
  ---@cast cursorType string
  ---@cast itemID number
  if cursorType ~= "item" then return end
  local category = section.title:GetText()
  categories:AddItemToCategory(itemID, category)
  ClearCursor()
  events:SendMessage('bags/FullRefreshAll')
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

  -- Create the section title.
  local title = CreateFrame("Button", nil, f)
  title:SetText("Not set")
  title:SetNormalFontObject("GameFontNormal")
  title:SetHeight(18)
  title:GetFontString():SetAllPoints()
  title:GetFontString():SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 6, 0)
  title:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -6, 0)
  title:SetScript("OnEnter", function()
    sectionFrame.currentTooltip = s
    s:onTitleMouseEnter()
  end)

  title:SetScript("OnLeave", function()
    sectionFrame.currentTooltip = nil
    GameTooltip:Hide()
  end)

  title:SetScript("OnClick", function() onTitleClickOrDrop(s) end)
  title:SetScript("OnReceiveDrag", function() onTitleClickOrDrop(s) end)

  s.title = title

  local content = grid:Create(s.frame)
  content:Show()
  content:HideScrollBar()
  s.content = content
  f:Show()
  return s
end

-- Create will create a new section view.
---@return Section
function sectionFrame:Create()
  ---@return Section
  return self._pool:Acquire()
end
