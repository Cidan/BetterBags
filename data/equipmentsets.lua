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

function equipmentSets:OnInitialize()
  self.bagAndSlotToSet = {}
end

function equipmentSets:OnEnable()
  self:Update()
end

function equipmentSets:Update()
  if addon.isClassic then return end
  if addon.isAnniversary then return end

  -- Use different implementation for Midnight vs War Within
  if addon.isMidnight then
    return self:UpdateMidnight()
  else
    return self:UpdatePreMidnight()
  end
end

-- Pre-Midnight implementation (War Within and earlier)
function equipmentSets:UpdatePreMidnight()
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

-- Midnight implementation (12.0.0+)
-- Uses the new EquipmentManager_GetLocationData() function instead of UnpackLocation
function equipmentSets:UpdateMidnight()
  wipe(self.bagAndSlotToSet)
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    local setLocations = C_EquipmentSet.GetItemLocations(setID)
    if setLocations ~= nil then
      for _, location in pairs(setLocations) do
        local locationData = EquipmentManager_GetLocationData(location)
        if (locationData.isBank or locationData.isBags) and locationData.slot ~= nil and locationData.bag ~= nil then
          self.bagAndSlotToSet[locationData.bag] = self.bagAndSlotToSet[locationData.bag] or {}
          self.bagAndSlotToSet[locationData.bag][locationData.slot] = self.bagAndSlotToSet[locationData.bag][locationData.slot] or {}
          table.insert(self.bagAndSlotToSet[locationData.bag][locationData.slot], setName)
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