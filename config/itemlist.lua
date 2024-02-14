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

local function SetMultiselect(_, _)
end

local function SetLabel(_, _)
end

---@param self AceGUIInlineGroup
---@param values CustomCategoryFilter
local function SetList(self, values)
  ---@cast self +AceItemList
  values.itemList = values.itemList or {}
  ---@type number[]
  local itemList = {}
  for k, _ in pairs(values.itemList) do
    table.insert(itemList, k)
  end
  self:ReleaseChildren()
  self:SetFullWidth(true)
  self:SetRelativeWidth(1)
  self:DoLayout()
  self.section:ReleaseAllCells()
  self.section:WipeOnlyContents()
  self:SetUserData("values", values)

  -- TODO(lobato): Move this to a local file function.
  local rec = function()
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not tonumber(id) then return end
    ClearCursor()
    local itemid = tonumber(id) --[[@as number]]
    local list = self:GetUserData("values")
    DB:SaveItemToCategory(itemid, list.name)
    self:SetList(DB:GetItemCategory(list.name))
    items:RefreshAll()
  end

  if #itemList == 0 then
    local label = GUI:Create("Label") --[[@as AceGUILabel]]
    label:SetText(L:G("Drag an item here from your inventory, bank, or another source to add it to this category."))
    label:SetFullWidth(true)
    self:AddChild(label)
    self:SetFullWidth(true)
    self:SetRelativeWidth(1)
    self:DoLayout()
    items:RefreshAll()
    label.frame:EnableMouse(true)
    label.frame:SetScript("OnReceiveDrag", rec)
    if self.parent then
      self.parent:DoLayout()
    end
    return
  end

  items:GetItemData(itemList, function(itemData)
    ---@cast itemData +ItemData[]
    self:PauseLayout()
    for _, v in pairs(itemData) do
      local item = itemRowFrame:Create()
      item:SetItem(v)
      item.button.frame:SetPoint("LEFT", item.frame, "LEFT", 4, 0)

      local fn = function(_, b)
        if b == "LeftButton" then
          rec()
          return
        end
        ClearCursor()
        context:Show({{
          text = L:G("Remove"),
          notCheckable = true,
          hasArrow = false,
          func = function()
            ---@type CustomCategoryFilter
            local list = self:GetUserData("values")
            DB:DeleteItemFromCategory(v.itemInfo.itemID, list.name)
            self:SetList(DB:GetItemCategory(list.name))
            items:RefreshAll()
          end
        }})
      end
      item.button.button:SetScript("OnReceiveDrag", rec)
      item.rowButton:SetScript("OnReceiveDrag", rec)
      item.button.button:SetScript("OnClick", fn)
      item.rowButton:SetScript("OnClick", fn)
      self.section:AddCell(v.itemInfo.itemID, item)
    end
    self.section:SetMaxCellWidth(1)
    local w, h = self.section:Draw(0, 3, false)
    for _, cell in pairs(self.section:GetAllCells()) do
      cell.frame:SetWidth(w * 2 - 35)
    end
    self:SetLayout("Fill")
    self:SetFullWidth(true)
    self:SetRelativeWidth(1)
    self:SetHeight(h + 6 * 2) -- 6 for the offset set in CreateItemListWidget
    self:ResumeLayout()
    self:DoLayout()
    if self.parent then
      self.parent:DoLayout()
    end
    self:SetUserData("values", values)
  end)

end

local function SetDisabled(_, _)
end

local function SetItemValue(_, _, _)
end

function config:CreateItemListWidget()
  local widget = GUI:Create("InlineGroup")
  ---@cast widget +AceItemList,+AceGUIInlineGroup
  widget.type = "ItemList"
  widget["SetMultiselect"] = SetMultiselect
  widget["SetLabel"] = SetLabel
  widget["SetList"] = SetList
  widget["SetDisabled"] = SetDisabled
  widget["SetItemValue"] = SetItemValue

  widget.frame:EnableMouse(true)

  local section = sectionFrame:Create()
  section:SetFillWidth(true)
  section:SetTitle("Items")
  section.frame:SetParent(widget.frame)
  section.frame:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 6, -6)
  section.frame:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -6, 6)
  widget.section = section

  return widget
end
