local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class EquipmentSets: AceModule
---@field bagAndSlotToSet table<number, table<number, string>>
local equipmentSets = addon:NewModule('EquipmentSets')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

function equipmentSets:OnInitialize()
  self.bagAndSlotToSet = {}
end

function equipmentSets:OnEnable()
  self:Update()
end

function equipmentSets:Update()
  if not addon.isRetail then return end
  wipe(self.bagAndSlotToSet)
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    local setLocations = C_EquipmentSet.GetItemLocations(setID)
    for _, location in pairs(setLocations) do
      local _, bank, bags, _, slot, bag = EquipmentManager_UnpackLocation(location)
      if (bank or bags) and slot ~= nil and bag ~= nil then
        self.bagAndSlotToSet[bag] = self.bagAndSlotToSet[bag] or {}
        self.bagAndSlotToSet[bag][slot] = setName
      end
    end
  end
end

---@param bagid number
---@param slotid number
---@return string|nil
function equipmentSets:GetItemSet(bagid, slotid)
  if not bagid or not slotid then return nil end
  return self.bagAndSlotToSet[bagid] and self.bagAndSlotToSet[bagid][slotid]
end

equipmentSets:Enable()