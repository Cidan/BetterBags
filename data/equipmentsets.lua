local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class (exact) EquipmentSet
---@field id number The set's ID, which a rename in the Equipment Manager keeps.
---@field name string

---@class EquipmentSets: AceModule
---@field bagAndSlotToSet table<number, table<number, string[]>>
---@field sets EquipmentSet[] Every set, in the client's order.
local equipmentSets = addon:NewModule('EquipmentSets')

function equipmentSets:Init()
  self.bagAndSlotToSet = {}
  self.sets = {}
end

function equipmentSets:OnEnable()
  self:Update(context:New('EquipmentSets'))
end

-- Update reads every set and where its items are, then makes each set's category (Categories:SyncGearSets,
-- category-lifecycle.md §12), so the items a sweep reads next find their set's.
---@param ctx Context
function equipmentSets:Update(ctx)
  if addon.isClassic then return end
  if addon.isAnniversary then return end

  -- Route by which EquipmentManager API the client actually provides, not by TOC
  -- version. Midnight (12.0+) removed EquipmentManager_UnpackLocation in favor of
  -- EquipmentManager_GetLocationData; WoW: Forever (a mainline retail fork) also ships
  -- only GetLocationData but reports a sub-12.0 TOC, so a version gate (addon.isMidnight)
  -- misrouted it to the UnpackLocation path and crashed with "attempt to call a nil value".
  if EquipmentManager_UnpackLocation ~= nil then
    self:UpdatePreMidnight()
  else
    self:UpdateMidnight()
  end
  addon:GetModule('Categories'):SyncGearSets(ctx, self.sets)
end

-- Pre-Midnight implementation (War Within and earlier)
function equipmentSets:UpdatePreMidnight()
  wipe(self.bagAndSlotToSet)
  self.sets = {}
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    -- GetEquipmentSetInfo may return nothing (MayReturnNothing, EquipmentManagerDocumentation.lua).
    if setName ~= nil then
      table.insert(self.sets, { id = setID, name = setName })
    end
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
  self.sets = {}
  local sets = C_EquipmentSet.GetEquipmentSetIDs()
  for _, setID in ipairs(sets) do
    local setName = C_EquipmentSet.GetEquipmentSetInfo(setID)
    -- GetEquipmentSetInfo may return nothing (MayReturnNothing, EquipmentManagerDocumentation.lua).
    if setName ~= nil then
      table.insert(self.sets, { id = setID, name = setName })
    end
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

-- GetSets returns every set the last Update read, in the client's order.
---@return EquipmentSet[]
function equipmentSets:GetSets()
  return self.sets
end

equipmentSets:Enable()
