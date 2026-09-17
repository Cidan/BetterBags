local addonName = ...
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemLoader: AceModule
local loader = addon:NewModule('ItemLoader')
local const = addon:GetModule('Constants')
local events = addon:GetModule('Events')

function loader:Init()
  self.itemMixinsBySlotKey = {}
  self.itemMixinsByBag = {}
  self.bagUpdateCallbacks = {}
  self.pendingBags = {}
end

function loader:OnEnable()
  self:ScanAllBagsAndUpdateItemMixins()
  events:RegisterEvent('BAG_UPDATE', function(_, _, bagID)
    if bagID then
      self.pendingBags[bagID] = true
    end
  end)
  events:RegisterEvent('BAG_UPDATE_DELAYED', function()
    self:ProcessPendingBagUpdates()
  end)
end

---@param fn fun(bagID: number)
function loader:ForEachManagedBag(fn)
  if const.BACKPACK_BAGS then
    for bagID in pairs(const.BACKPACK_BAGS) do fn(bagID) end
  end
  if const.BANK_BAGS then
    for bagID in pairs(const.BANK_BAGS) do fn(bagID) end
  end
  if const.ACCOUNT_BANK_BAGS then
    for bagID in pairs(const.ACCOUNT_BANK_BAGS) do fn(bagID) end
  end
end

function loader:ScanAllBagsAndUpdateItemMixins()
  self:ForEachManagedBag(function(bagID) self:ScanBag(bagID) end)
end

-- LoadAllBagsAndUpdate primes the item cache for every managed bag through the exact same
-- ContinuableContainer path a BAG_UPDATE takes: it marks every bag dirty (what the
-- BAG_UPDATE handler does per-bag) and then runs ProcessPendingBagUpdates (what
-- BAG_UPDATE_DELAYED calls). It exists for the initial login sweep, where no BAG_UPDATE may
-- have fired yet, so the first harvest never reads a cold cache -- an uncached
-- C_Item.GetItemInfo returns nil type/subtype and mislabels items into "Everything" until a
-- /reload. ProcessPendingBagUpdates no-ops on an empty dirty set, which is why the login
-- sweep must seed the bags here rather than just calling it.
function loader:LoadAllBagsAndUpdate()
  self:ForEachManagedBag(function(bagID) self.pendingBags[bagID] = true end)
  self:ProcessPendingBagUpdates()
end

function loader:ScanBag(bagID)
  if not bagID then return end
  local ok, totalSlots = pcall(C_Container.GetContainerNumSlots, bagID)
  if not ok or not totalSlots or totalSlots <= 0 then return end
  for slotID = 1, totalSlots do
    local slotKey = bagID .. "_" .. slotID
    if self.itemMixinsBySlotKey[slotKey] == nil then
      local itemMixin = Item:CreateFromBagAndSlot(bagID, slotID)
      self.itemMixinsBySlotKey[slotKey] = itemMixin
      self.itemMixinsByBag[bagID] = self.itemMixinsByBag[bagID] or {}
      table.insert(self.itemMixinsByBag[bagID], itemMixin)
    end
  end
end

---@param slotKey string
---@return ItemMixin|nil
function loader:GetItemMixinFromSlotKey(slotKey)
  return self.itemMixinsBySlotKey[slotKey]
end

---@param callback function
function loader:TellMeWhenABagIsUpdated(callback)
  table.insert(self.bagUpdateCallbacks, callback)
end

function loader:ProcessPendingBagUpdates()
  if next(self.pendingBags) == nil then return end

  local updatedBags = self.pendingBags
  self.pendingBags = {}

  local mixinsToLoad = {}
  for bagID in pairs(updatedBags) do
    self:ScanBag(bagID)
    local bagMixins = self.itemMixinsByBag[bagID]
    if bagMixins then
      for _, mixin in ipairs(bagMixins) do
        table.insert(mixinsToLoad, mixin)
      end
    end
  end

  self:LoadTheseItemsAndCallback(mixinsToLoad, function()
    for _, callback in ipairs(self.bagUpdateCallbacks) do
      callback(updatedBags)
    end
  end)
end

---@param mixins table
---@param callback function
function loader:LoadTheseItemsAndCallback(mixins, callback)
  local container = ContinuableContainer:Create()
  for _, mixin in ipairs(mixins) do
    if not mixin:IsItemEmpty() then
      container:AddContinuable(mixin)
    end
  end
  container:ContinueOnLoad(callback)
end
