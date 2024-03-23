local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Debug
local debug = addon:GetModule('Debug')

---@param data ItemData
---@param id number
---@return boolean
function debug:IsItem(data, id)
  if data and data.itemInfo and data.itemInfo.itemID == id then
    return true
  end
  return false
end

local tooltipLines = 0

function debug:AddTooltipDouble(first, second)
  if tooltipLines % 2 == 0 then
    self.tooltip:AddDoubleLine(first, second, 1, 1, 1, 1, 1, 1)
  else
    self.tooltip:AddDoubleLine(first, second, 0.8, 0.5, 0.8, 0.8, 0.5, 0.8)
  end
  tooltipLines = tooltipLines + 1
end

function debug:AddTooltip(line)
  self.tooltip:AddLine(line, 1, 1, 1)
end

---@param item Item
function debug:ShowItemTooltip(item)
  if not self.enabled then return end
  self.tooltip:SetOwner(item.button, 'ANCHOR_BOTTOM')
  if item.data.isItemEmpty then
    self:AddTooltip("Empty")
  else
    self:AddTooltip(item.data.itemInfo.itemLink)
  end

  ---@diagnostic disable: no-unknown
  for k, v in pairs(item.data) do
    if type(v) == "table" then
      self:AddTooltipDouble(k, "[table]")
    elseif v == nil then
      self:AddTooltipDouble(k, "nil")
    else
      self:AddTooltipDouble(k, v)
    end
  end

  self.tooltip:Show()
end

---@param item Item
function debug:HideItemTooltip(item)
  _ = item
  tooltipLines = 0
  self.tooltip:Hide()
end