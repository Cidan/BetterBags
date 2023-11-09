local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceEvent-3.0
local events = addon:GetModule('Events')

---@class Items: AceModule
---@field items table<number, table<string, ItemMixin>>
---@field _continueCounter number
---@field _doingRefreshAll boolean
local items = addon:NewModule('Items')

function items:OnEnable()
  self.items = {}
  self._continueCounter = 0
  events:RegisterEvent('BAG_UPDATE', self.RefreshAllItems, self)
  self:RefreshAllItems()
end

-- RefreshAllItems will refresh all bags' contents entirely and update
-- the item database.
function items:RefreshAllItems()
  wipe(self.items)
  self._continueCounter = 0
  self._doingRefreshAll = true
  for i = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
    self.items[i] = {}
    self:RefreshBag(i)
  end
end

-- RefreshBag will refresh a bag's contents entirely and update the
-- item database.
---@param bagid number
function items:RefreshBag(bagid)
  local container = ContinuableContainer:Create()
  local size = C_Container.GetContainerNumFreeSlots(bagid)
  for slot = 1, size do
    local item = Item:CreateFromBagAndSlot(bagid, slot)
    if not item:IsItemEmpty() then
      container:AddContinuable(item)
      self.items[bagid][item:GetItemGUID()] = item
    end
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
        events:SendMessage('items/RefreshAllItems/Done')
      end
    end
    events:SendMessage('items/RefreshBag/Done', bagid)
  end)
end

items:Enable()