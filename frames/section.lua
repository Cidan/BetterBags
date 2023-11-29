local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class SectionFrame: AceModule
local sectionFrame = addon:NewModule('SectionFrame')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
---@field title FontString The title of the section.
---@field private content Grid The main content frame of the section.
local sectionProto = {}

---@param view? BagView
---@return number width
---@return number height
function sectionProto:Draw(view)
  return self:Grid()
end

-- SetTitle will set the title of the section.
---@param text string The text to set the title to.
function sectionProto:SetTitle(text)
  self.title:SetText(text)
end

function sectionProto:AddCell(id, cell)
  self.content:AddCell(id, cell)
end

function sectionProto:RemoveCell(id, cell)
  self.content:RemoveCell(id, cell)
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

function sectionProto:Wipe()
  self.content:Wipe()
  self.view = const.BAG_VIEW.SECTION_GRID
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
end

---@param item Item
---@return boolean
function sectionProto:HasItem(item)
  for _, i in pairs(self.content.cells) do
    if item == i then
      return true
    end
  end
  return false
end

function sectionProto:Release()
  sectionFrame._pool:Release(self)
end

local function sortFn(a, b)
  ---@cast a +Item
  ---@cast b +Item
  if a == nil or b == nil or a:GetMixin() == nil or b:GetMixin() == nil then return false end
  if a:GetMixin():GetItemQuality() == nil or b:GetMixin():GetItemQuality() == nil then return false end
  if a:GetMixin():GetItemQuality() == b:GetMixin():GetItemQuality() then
    if a:GetMixin():GetItemName() == nil or b:GetMixin():GetItemName() == nil then return false end
    return a:GetMixin():GetItemName() < b:GetMixin():GetItemName()
  end
  return a:GetMixin():GetItemQuality() > b:GetMixin():GetItemQuality()
end

-- Grid will render the section as a grid of icons.
---@return number width
---@return number height
function sectionProto:Grid()
  self.content:Sort(sortFn)
  local w, h = self.content:Draw()
  self.content:GetContainer():SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, 0)
  self.content:GetContainer():SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -6, 0)
  self.content:Show()
  if w == 0 then
    self.frame:Hide()
    return 0, 0
  end
  self.frame:Show()
  self.frame:SetSize(w + 12, h + self.title:GetHeight() + 6)
  return w+12, h + self.title:GetHeight() + 6
end

-------
--- Section Frame
-------

function sectionFrame:OnInitialize()
  self._pool = CreateObjectPool(self._DoCreate, self._DoReset)
end

---@param f Section
function sectionFrame:_DoReset(f)
  f:Wipe()
end

---@return Section
function sectionFrame:_DoCreate()
  ---@class Section
  local s = {}
  setmetatable(s, { __index = sectionProto })

  ---@class Frame: BackdropTemplate
  local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
  s.frame = f

  --debug:DrawDebugBorder(f, 1, 1, 1)

  -- Create the section title.
  local title = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText("Not set")
  title:SetFontObject("GameFontNormal")
  title:SetHeight(18)
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", s.frame, "TOPLEFT", 6, 0)
  title:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -6, 0)
  title:SetScript("OnEnter", function(t)
    GameTooltip:SetOwner(t, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(t:GetText())
    local info = strjoin(" ",
      "\n",
      "Item Count: " .. #s.content.cells
    )
    GameTooltip:AddLine(info, 1, 1, 1)
    GameTooltip:Show()
  end)
  title:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
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
