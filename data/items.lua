local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceEvent-3.0
local events = addon:GetModule('Events')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Items: AceModule
---@field items table<number, table<string, ItemMixin>>
---@field itemsByBagAndSlot table<number, table<number, ItemMixin>>
---@field dirtyItems table<number, table<number, ItemMixin>>
---@field _continueCounter number
---@field _doingRefreshAll boolean
local items = addon:NewModule('Items')

-- Small debug function for printing items after every refresh.
local function printDirtyItems(event, it)
  for bid, _ in ipairs(it) do
    for _, item in ipairs(it[bid]) do
      debug:Log("items/printDirtyItems/dirty", item:GetItemLink())
    end
  end
end

function items:OnInitialize()
  self.items = {}
  self.dirtyItems = {}
  self.itemsByBagAndSlot = {}
  self._continueCounter = 0
end

function items:OnEnable()
  events:RegisterMessage('items/RefreshAllItems/Done', printDirtyItems)
  events:RegisterEvent('BAG_UPDATE', self.RefreshAllItems, self)
end

function items:Disable()
  events:UnregisterEvent('BAG_UPDATE')
end

-- RefreshAllItems will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshAllItems()
  wipe(self.items)
  self._continueCounter = 0
  self._doingRefreshAll = true
  for i = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    self.items[i] = {}
    self.itemsByBagAndSlot[i] = self.itemsByBagAndSlot[i] or {}
    self.dirtyItems[i] = self.dirtyItems[i] or {}
    self:RefreshBag(i)
  end
end

-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@private
---@param bagid number
function items:RefreshBag(bagid)
  local container = ContinuableContainer:Create()
  local size = C_Container.GetContainerNumSlots(bagid)

  -- Loop through every container slot and create an item for it.
  for slot = 1, size do
    local item = Item:CreateFromBagAndSlot(bagid, slot)

    -- Check if this slot already has an item in it, and if it's not the same,
    -- mark the item as dirty.
    if not item:Matches(self.itemsByBagAndSlot[bagid][slot]) then
      self.dirtyItems[bagid][slot] = item
    end

    -- If this is an actual item, add it to the callback container
    -- so data is fetched from the server.
    if not item:IsItemEmpty() then
      container:AddContinuable(item)
      self.items[bagid][item:GetItemGUID()] = item
    end

    -- All items are added to the bag/slot lookup table, including
    -- empty items.
    self.itemsByBagAndSlot[bagid][slot] = item
  end

  -- Delete old entries that no longer exist because the bag size shrunk.
  for i = size, #self.itemsByBagAndSlot[bagid] do
    self.itemsByBagAndSlot[bagid][i] = nil
  end

  -- Load item data in the background, and fire a message when
  -- all bags are done loading if this is a full refresh.
  -- Additionally, fire a message when this bag is done loading.
  container:ContinueOnLoad(function()
    if items._doingRefreshAll then
      items._continueCounter = items._continueCounter + 1
      if items._continueCounter == NUM_TOTAL_EQUIPPED_BAG_SLOTS then
        items._continueCounter = 0
        items._doingRefreshAll = false
        events:SendMessage('items/RefreshAllItems/Done', items.dirtyItems)
        wipe(items.dirtyItems)
      end
    end
    events:SendMessage('items/RefreshBag/Done', bagid)
  end)
end
