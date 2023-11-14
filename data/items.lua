local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
---@field items table<number, table<string, ItemMixin>>
---@field itemsByBagAndSlot table<number, table<number, ItemMixin>>
---@field dirtyItems table<number, table<number, ItemMixin>>
---@field previousItemGUID table<number, table<number, string>>
---@field _container ContinuableContainer
---@field _doingRefreshAll boolean
local items = addon:NewModule('Items')

-- Small debug function for printing items after every refresh.
local function printDirtyItems(event, it)
  for _, bagData in pairs(it) do
    for _, itemData in pairs(bagData) do
      debug:Log("items/printDirtyItems/dirty", itemData:GetItemLink())
    end
  end
end

function items:OnInitialize()
  self.items = {}
  self.dirtyItems = {}
  self.itemsByBagAndSlot = {}
  self.previousItemGUID = {}
end

function items:OnEnable()
  --events:RegisterMessage('items/RefreshAllItems/Done', printDirtyItems)
  events:RegisterEvent('BAG_UPDATE_DELAYED', self.RefreshAllItems, self)
end

function items:Disable()
  --events:UnregisterEvent('BAG_UPDATE')
end

-- RefreshAllItems will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshAllItems()
  if self._doingRefreshAll then
    return
  end
  self._doingRefreshAll = true
  wipe(self.items)
  self._container = ContinuableContainer:Create()

  -- Loop through all the bags and schedule each item for a refresh.
  for i = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyItems[i] = self.dirtyItems[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i)
  end

  --- Process the item container.
  self:ProcessContainer()
end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading.
function items:ProcessContainer()
  self._container:ContinueOnLoad(function()
    -- All items in all bags have finished loading, fire the all done event.
    events:SendMessage('items/RefreshAllItems/Done', items.dirtyItems)
    wipe(items.dirtyItems)
    items._container = nil
    items._doingRefreshAll = false
  end)
end

-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
function items:RefreshBag(bagid)
  local size = C_Container.GetContainerNumSlots(bagid)

  -- Loop through every container slot and create an item for it.
  for slot = 1, size do
    local item = Item:CreateFromBagAndSlot(bagid, slot)

    -- TODO(lobato): Store the previous item's state and compare it to current
    -- state to decide if we need to refresh this item.

    -- Mark all items as dirty so they are refreshed.
    self.dirtyItems[bagid][slot] = item

    -- If this is an actual item, add it to the callback container
    -- so data is fetched from the server.
    if not item:IsItemEmpty() and not item:IsItemDataCached() then
      self._container:AddContinuable(item)
    elseif not item:IsItemEmpty() then
      self.items[bagid][item:GetItemGUID()] = item
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
