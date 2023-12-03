local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class EquipmentSets: AceModule
---@field itemToSet table<number, string>
local equipmentSets = addon:NewModule('EquipmentSets')

---@class Events: AceModule
local events = addon:GetModule('Events')

function equipmentSets:OnInitialize()
  self.itemToSet = {}
end

function equipmentSets:OnEnable()
  events:RegisterEvent('EQUIPMENT_SETS_CHANGED', function() self:Update() end)
  self:Update()
end

function equipmentSets:Update()
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    local items = C_EquipmentSet.GetItemIDs(setID)
    for _, itemID in ipairs(items) do
      self.itemToSet[itemID] = setName
    end
  end
end

---@param itemID number|nil
---@return string|nil
function equipmentSets:GetItemSet(itemID)
  if not itemID then return nil end
  return self.itemToSet[itemID]
end

equipmentSets:Enable()