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
---@field _continueCounters table<number, number>
---@field _containers ContinuableContainer[]
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
  self._continueCounters = {}
  self._containers = {}
end

function items:OnEnable()
  --events:RegisterMessage('items/RefreshAllItems/Done', printDirtyItems)
  events:RegisterEvent('BAG_UPDATE', self.RefreshAllItems, self)
end

function items:Disable()
  --events:UnregisterEvent('BAG_UPDATE')
end

-- RefreshAllItems will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshAllItems()
  wipe(self.items)
  self._continueCounters = {}
  self._doingRefreshAll = true

  -- Loop through all the bags and schedule each item for a refresh.
  for i = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyItems[i] = self.dirtyItems[i] or {}
    self.previousItemGUID[i] = self.previousItemGUID[i] or {}
    self:RefreshBag(i)
  end

  --- Loop through all the containers and execute their callback.
  for bagid, container in ipairs(self._containers) do
    self:ProcessContainer(bagid, container)
  end
  wipe(self._containers)
end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading if this is a full refresh.
  -- Additionally, fire a message when this bag is done loading.
function items:ProcessContainer(bagid, container)
  container:ContinueOnLoad(function()
    if items._doingRefreshAll then
      self._continueCounters[bagid] = self._continueCounters[bagid] - 1

      -- Only fire the message when all bags are done loading, otherwise
      -- the baton is passed to the next container function.
      if items._continueCounters[bagid] == 0 then
        for i = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
          if items._continueCounters[i] > 0 then
            return
          end
        end
      end
      -- All items in all bags have finished loading, fire the all done event.
      items._doingRefreshAll = false
      events:SendMessage('items/RefreshAllItems/Done', items.dirtyItems)
      wipe(items.dirtyItems)
    end
    events:SendMessage('items/RefreshBag/Done', bagid)
  end)
end

-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
function items:RefreshBag(bagid)
  local container = ContinuableContainer:Create()
  local size = C_Container.GetContainerNumSlots(bagid)
  self._continueCounters[bagid] = 0

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
      container:AddContinuable(item)
      self._continueCounters[bagid] = self._continueCounters[bagid] + 1
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

  -- Store this container for processing later.
  self._containers[bagid] = container
end
