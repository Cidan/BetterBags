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

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Database: AceModule
local DB = addon:GetModule('Database')

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
  self:SetFullWidth(true)
  self:SetRelativeWidth(1)
  self:DoLayout()
  self.section:WipeOnlyContents()
  items:GetItemData(itemList, function(itemData)
    ---@cast itemData +ItemData[]
    self:PauseLayout()
    for _, v in pairs(itemData) do
      local item = itemRowFrame:Create()
      item:SetItem(v)
      item.button.frame:SetPoint("LEFT", item.frame, "LEFT", 4, 0)
      item.button.button:SetScript("OnClick", function()
        -- TODO(lobato): Add context menu.
        context:Show({{
          text = L:G("Remove"),
          notCheckable = true,
          hasArrow = false,
          func = function()
            ---@type CustomCategoryFilter
            local list = self:GetUserData("values")
            DB:DeleteItemFromCategory(v.itemInfo.itemID, list.name)
            self:SetList(DB:GetItemCategory(list.name))
          end
        }})
      end)
      self.section:AddCell(v.itemInfo.itemID, item)
    end
    self.section:SetMaxCellWidth(1)
    local w, h = self.section:Draw(0, 3)
    for _, cell in pairs(self.section:GetAllCells()) do
      cell.frame:SetWidth(w * 2 - 35)
    end
    self:SetLayout("Fill")
    self:SetFullWidth(true)
    self:SetRelativeWidth(1)
    self:SetHeight(h + 6 * 2) -- 6 for the offset set in CreateItemListWidget
    self:ResumeLayout()
    self:DoLayout()
    self:SetUserData("values", values)
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
  section:SetFillWidth(true)
  section:SetTitle("Items")
  section.frame:SetParent(widget.frame)
  section.frame:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 6, -6)
  section.frame:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -6, 6)
  widget.section = section
  return widget
end
