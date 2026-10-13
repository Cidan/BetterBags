local addonName = ...
---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class ItemLoader: AceModule
local loader = addon:NewModule('ItemLoader')
local const = addon:GetModule('Constants')
local events = addon:GetModule('Events')
---@class Perf: AceModule
local perf = addon:GetModule('Perf')

function loader:Init()
  self.itemMixinsBySlotKey = {}
  self.itemMixinsByBag = {}
  self.bagUpdateCallbacks = {}
  self.pendingBags = {}
  self.held = false
end

-- Hold keeps bag batches from loading while the client delivers the bags at startup: a
-- BAG_UPDATE only marks its bag dirty. The refresh scheduler holds the loader until its
-- startup read (.claude/rules/refresh-scheduler.md §8).
function loader:Hold()
  self.held = true
end

-- Release ends the hold and drops the bags marked meanwhile: the startup read that releases
-- the loader reads every bag.
function loader:Release()
  self.held = false
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

-- PrimeAll loads the item data of every managed bag slot and every equipped slot in one
-- ContinuableContainer and calls callback once, when all of it has loaded. The startup read
-- waits for it, so the one read of the bags at login sees warm item data and warm gear. It
-- does not go through the bag-update callbacks.
---@param callback fun()
function loader:PrimeAll(callback)
  local mixins = {}
  self:ForEachManagedBag(function(bagID)
    self:ScanBag(bagID)
    for _, mixin in ipairs(self.itemMixinsByBag[bagID] or {}) do
      mixins[#mixins + 1] = mixin
    end
  end)
  for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
    mixins[#mixins + 1] = Item:CreateFromEquipmentSlot(slot)
  end
  self:LoadTheseItemsAndCallback(mixins, callback)
end

-- PrimeBank loads the item data of every bank slot in one ContinuableContainer and calls
-- callback once, when all of it has loaded (synchronously when it already is). Bank containers
-- have no slots until the bank opens, so PrimeAll at login cannot cover them. It does not go
-- through the bag-update callbacks.
---@param callback fun()
function loader:PrimeBank(callback)
  local mixins = {}
  local function add(bagID)
    self:ScanBag(bagID)
    for _, mixin in ipairs(self.itemMixinsByBag[bagID] or {}) do
      mixins[#mixins + 1] = mixin
    end
  end
  for bagID in pairs(const.BANK_BAGS or {}) do add(bagID) end
  for bagID in pairs(const.ACCOUNT_BANK_BAGS or {}) do add(bagID) end
  self:LoadTheseItemsAndCallback(mixins, callback)
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
  if self.held or next(self.pendingBags) == nil then return end

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
    -- Usually runs later, from Blizzard's item-load listener, outside any measured call;
    -- the span gives the work it starts a root that names the bags whose data arrived.
    local token = perf.active and perf:Enter('[loaded] item data', updatedBags)
    for _, callback in ipairs(self.bagUpdateCallbacks) do
      callback(updatedBags)
    end
    if token then perf:Exit(token) end
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
