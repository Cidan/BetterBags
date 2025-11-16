local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class EquipmentSets: AceModule
---@field bagAndSlotToSet table<number, table<number, string[]>>
local equipmentSets = addon:NewModule('EquipmentSets')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')



local EquipmentManager_UnpackLocation = EquipmentManager_UnpackLocation or function(packedLocation)
	local locationData = EquipmentManager_GetLocationData(packedLocation);
	-- Void Storage was removed from Retail in 11.2.0
	local voidStorage, tab, voidSlot = false, nil, nil;
	return locationData.isPlayer or false, locationData.isBank or false, locationData.isBags or false, voidStorage, locationData.slot, locationData.bag, tab, voidSlot;
end
function equipmentSets:OnInitialize()
  self.bagAndSlotToSet = {}
end

function equipmentSets:OnEnable()
  self:Update()
end

function equipmentSets:Update()
  if addon.isClassic then return end

  wipe(self.bagAndSlotToSet)
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    local setLocations = C_EquipmentSet.GetItemLocations(setID)
    if setLocations ~= nil then -- This is a bugfix for #113, no idea why this would return nil.
      for _, location in pairs(setLocations) do
        local _, bank, bags, void, slot, bag = EquipmentManager_UnpackLocation(location)
        -- There is no void bank in Wrath of the Lich King, so shift everything left by one.
        if not addon.isRetail then
          bag = slot
          slot = void --[[@as number]]
        end
        if (bank or bags) and slot ~= nil and bag ~= nil then
          self.bagAndSlotToSet[bag] = self.bagAndSlotToSet[bag] or {}
          self.bagAndSlotToSet[bag][slot] = self.bagAndSlotToSet[bag][slot] or {}
          table.insert(self.bagAndSlotToSet[bag][slot], setName)
        end
      end
    end
  end
end

---@param bagid number
---@param slotid number
---@return string[]|nil
function equipmentSets:GetItemSets(bagid, slotid)
  if not bagid or not slotid then return nil end
  return self.bagAndSlotToSet[bagid] and self.bagAndSlotToSet[bagid][slotid]
end

equipmentSets:Enable()