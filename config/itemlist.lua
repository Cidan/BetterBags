local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Config: AceModule
local config = addon:GetModule('Config')

---@class SectionFrame: AceModule
local sectionFrame = addon:GetModule('SectionFrame')

---@class ItemRowFrame: AceModule
local itemRowFrame = addon:GetModule('ItemRowFrame')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

local GUI = LibStub('AceGUI-3.0')

local function SetMultiselect(self, flag)
end

local function SetLabel(self, name)
end

---@param self AceGUIInlineGroup
---@param values CustomCategoryFilter
local function SetList(self, values)
  ---@cast self +AceItemList
  local itemList = {}
  for k, _ in pairs(values.itemList) do
    table.insert(itemList, k)
  end
  self.section:WipeOnlyContents()
  items:GetItemData(itemList, function(itemData)
    ---@cast itemData +ItemData[]
    self:PauseLayout()
    for _, v in pairs(itemData) do
      local item = itemRowFrame:Create()
      item:SetItem(v)
      self.section:AddCell(v.itemInfo.itemID, item)
    end
    self.section:SetMaxCellWidth(1)
    self.section:Draw(0, 3)
    local height = self.section.frame:GetHeight()
    self:SetLayout("Fill")
    self:SetFullWidth(true)
    self:SetHeight(height + 6 * 2) -- 6 for the offset set in CreateItemListWidget
    self:ResumeLayout()
    self:DoLayout()
  end)

end

local function SetDisabled(self, disabled)
end

local function SetItemValue(self, key, value)
end

function config:CreateItemListWidget()
  local widget = GUI:Create("InlineGroup")
  ---@cast widget +AceItemList
  widget.type = "ItemList"
  widget["SetMultiselect"] = SetMultiselect
  widget["SetLabel"] = SetLabel
  widget["SetList"] = SetList
  widget["SetDisabled"] = SetDisabled
  widget["SetItemValue"] = SetItemValue
  local section = sectionFrame:Create()
  section:SetTitle("Items")
  section.frame:SetParent(widget.frame)
  section.frame:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 6, -6)
  widget.section = section
  return widget
end
