local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
---@field items table<number, table<string, ItemMixin>>
---@field itemsByBagAndSlot table<number, table<number, ItemMixin>>
---@field dirtyItems table<number, table<number, ItemMixin>>
---@field dirtyBankItems table<number, table<number, ItemMixin>>
---@field previousItemGUID table<number, table<number, string>>
---@field _container ContinuableContainer
---@field _bankContainer ContinuableContainer
---@field _doingRefreshAll boolean
local items = addon:NewModule('Items')

function items:OnInitialize()
  self.items = {}
  self.dirtyItems = {}
  self.dirtyBankItems = {}
  self.itemsByBagAndSlot = {}
  self.previousItemGUID = {}
end

function items:OnEnable()
  --events:RegisterMessage('items/RefreshAllItems/Done', printDirtyItems)
  --events:RegisterEvent('BAG_UPDATE_DELAYED', self.RefreshAll, self)
  events:BucketEvent('BAG_UPDATE_DELAYED', function() self:RefreshAll() end)
  events:RegisterEvent('BANKFRAME_OPENED', self.RefreshBank, self)
end

function items:Disable()
  --events:UnregisterEvent('BAG_UPDATE')
end

function items:RefreshAll()
  if addon.Bags.Bank.frame:IsShown() then
    if addon.Bags.Bank.isReagentBank then
      self:RefreshReagentBank()
    else
      self:RefreshBank()
    end
  end
  self:RefreshBackpack()
end

function items:RefreshReagentBank()
  self._bankContainer = ContinuableContainer:Create()

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.REAGENTBANK_BAGS) do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyBankItems[i] = self.dirtyBankItems[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, true)
  end

  --- Process the item container.
  self:ProcessBankContainer()
end

function items:RefreshBank()
  self._bankContainer = ContinuableContainer:Create()

  -- This is a small hack to force the bank bag quality data to be cached
  -- before the bank bag frame is drawn.
  for _, bag in pairs(const.BANK_ONLY_BAGS) do
    local id = C_Container.ContainerIDToInventoryID(bag)
    GetInventoryItemQuality("player", id)
  end

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BANK_BAGS) do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyBankItems[i] = self.dirtyBankItems[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, true)
  end

  --- Process the item container.
  self:ProcessBankContainer()
end

-- RefreshBackback will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshBackpack()
  if self._doingRefreshAll then
    return
  end
  self._doingRefreshAll = true
  wipe(self.items)
  self._container = ContinuableContainer:Create()

  -- Loop through all the bags and schedule each item for a refresh.
  for i in pairs(const.BACKPACK_BAGS) do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyItems[i] = self.dirtyItems[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i, false)
  end

  --- Process the item container.
  self:ProcessContainer()
end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading.
function items:ProcessContainer()
  self._container:ContinueOnLoad(function()
    -- All items in all bags have finished loading, fire the all done event.
    events:SendMessage('items/RefreshBackpack/Done', items.dirtyItems)
    wipe(items.dirtyItems)
    items._container = nil
    items._doingRefreshAll = false
  end)
end

-- Load item data in the background, and fire a message when
-- all bags are done loading.
function items:ProcessBankContainer()
  self._bankContainer:ContinueOnLoad(function()
    -- All items in all bags have finished loading, fire the all done event.
    events:SendMessage('items/RefreshBank/Done', items.dirtyBankItems)
    wipe(items.dirtyBankItems)
    items._bankContainer = nil
    items._doingRefreshAll = false
  end)
end

-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
---@param bankBag boolean
function items:RefreshBag(bagid, bankBag)
  local size = C_Container.GetContainerNumSlots(bagid)

  -- Loop through every container slot and create an item for it.
  for slot = 1, size do
    local item = Item:CreateFromBagAndSlot(bagid, slot)

    -- TODO(lobato): Store the previous item's state and compare it to current
    -- state to decide if we need to refresh this item.

    -- Mark all items as dirty so they are refreshed.
    if bankBag then
      self.dirtyBankItems[bagid][slot] = item
    else
      self.dirtyItems[bagid][slot] = item
    end

    -- If this is an actual item, add it to the callback container
    -- so data is fetched from the server.
    if not item:IsItemEmpty() and not item:IsItemDataCached() then
      if bankBag then
        self._bankContainer:AddContinuable(item)
      else
        self._container:AddContinuable(item)
      end
    elseif not item:IsItemEmpty() and item:GetItemGUID() then
      self.items[bagid][item:GetItemGUID() --[[@as string]]] = item
    end

    -- All items are added to the bag/slot lookup table, including
    -- empty items
    self.itemsByBagAndSlot[bagid][slot] = item
  end

  -- Delete old entries that no longer exist because the bag size shrunk.
  for i = size+1, #self.itemsByBagAndSlot[bagid] do
    self.itemsByBagAndSlot[bagid][i] = nil
  end
end
