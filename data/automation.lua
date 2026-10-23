local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

-- Automation is what a category does with its items on its own, set in its Automation tab
-- (.claude/rules/automation.md): Auto Sell sells them when a merchant opens, and Destroy What Can't Be
-- Sold (which needs Auto Sell) destroys, one at a time on a click (BetterBags Next's vendor card) or a
-- key press, those no merchant buys. It acts on the backpack's items by their category, a recent item by
-- the category it has once it is no longer recent.
---@class Automation: AceModule
---@field atMerchant boolean A merchant is open (MERCHANT_SHOW to MERCHANT_CLOSED).
---@field sale? AutomationSale The sale running.
local automation = addon:NewModule('Automation')

-- What a category's automation holds: Auto Sell, or Auto Sell and Destroy What Can't Be Sold.
automation.SELL = "sell"
automation.DESTROY = "destroy"
-- A sale sells this many items at once, then the next as many a moment later, until all are sold.
automation.WAVE = 12
automation.WAVE_DELAY = 0.2
-- How long a sale waits to look again while the cursor holds an item.
automation.CURSOR_WAIT = 0.2

---@class AutomationEntry
---@field data ItemData The item, as the bags last read it.
---@field category string Its category (without Recent Items).
---@field action string What its category does: "sell" or "destroy".
---@field blocked? string Why automation leaves it alone.

---@class AutomationSale
---@field list AutomationEntry[]
---@field index number The next entry to sell.
---@field sold number
---@field value number Copper.

function automation:Init()
  self.atMerchant = false
  self.sale = nil
end

function automation:OnEnable()
  events:RegisterEvent('MERCHANT_SHOW', function(ctx) self:OnMerchantShow(ctx) end)
  events:RegisterEvent('MERCHANT_CLOSED', function(ctx) self:OnMerchantClosed(ctx) end)
end

---@param data ItemData
---@return ItemLocationMixin
local function locationOf(data)
  return ItemLocation:CreateFromBagAndSlot(data.bagid, data.slotid)
end

-- refundable says whether a purchase can still be refunded now: Blizzard asks before refunding one
-- (ContainerFrame_GetExtendedPriceString), which automation would skip. Only for a location that holds
-- an item (CanBeRefunded raises an error for an empty one): StillThere, acting, after the slot's info.
---@param location ItemLocationMixin
---@return boolean
local function refundable(location)
  return C_Item.CanBeRefunded ~= nil and C_Item.CanBeRefunded(location) == true
end

---@param copper number
---@return string
local function coins(copper)
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
    return C_CurrencyInfo.GetCoinTextureString(copper)
  end
  return GetCoinTextureString(copper)
end

---@param data ItemData
---@return number
local function priceOf(data)
  local traits = data.itemInfo.traits
  return (traits and traits.sellPrice) or data.itemInfo.sellPrice or 0
end

-- BlockedReason says why automation leaves an item alone, or nil: an item whose data has not
-- loaded (its category may be wrong), one in an equipment set, a purchase that can still be
-- refunded, and, to sell, one merchants do not buy. It reads only the item as the bags last read it:
-- the client may have changed the slot since (a sale empties slots before the bags are read again),
-- so what is still there is asked only when acting (StillThere).
---@param data ItemData
---@param action string
---@return string?
function automation:BlockedReason(data, action)
  if data.harvestIncomplete then
    return L:G("Its item data has not loaded yet.")
  end
  if data.itemInfo.equipmentSets and data.itemInfo.equipmentSets[1] ~= nil then
    return L:G("It is in an equipment set.")
  end
  if data.itemInfo.refundable then
    return L:G("It can still be refunded.")
  end
  if action == self.SELL and data.containerInfo and data.containerInfo.hasNoValue then
    return L:G("Merchants do not buy it.")
  end
  return nil
end

-- Entries lists the backpack's items whose category has an action, by bag and slot, each with why
-- automation leaves it alone, if it does.
---@param ctx Context
---@return AutomationEntry[]
function automation:Entries(ctx)
  local slotInfo = items.slotInfo and items.slotInfo[const.BAG_KIND.BACKPACK]
  local list = {}
  for _, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
    if not data.isItemEmpty and data.itemInfo and const.BACKPACK_BAGS[data.bagid] ~= nil then
      local category = items:GetCategory(ctx, data, false, true)
      local action = categories:AutomationOf(category)
      if action then
        table.insert(list, { data = data, category = category, action = action,
          blocked = self:BlockedReason(data, action) })
      end
    end
  end
  table.sort(list, function(a, b)
    if a.data.bagid ~= b.data.bagid then
      return a.data.bagid < b.data.bagid
    end
    return a.data.slotid < b.data.slotid
  end)
  return list
end

-- SellList lists what a merchant is sold: the items either action holds (both sell) that are not left
-- alone and that merchants buy.
---@param ctx Context
---@return AutomationEntry[]
function automation:SellList(ctx)
  local list = {}
  for _, entry in ipairs(self:Entries(ctx)) do
    if not entry.blocked and not (entry.data.containerInfo and entry.data.containerInfo.hasNoValue) then
      table.insert(list, entry)
    end
  end
  return list
end

-- DestroyQueue lists what destroying takes, in order (BetterBags Next's vendor shows it on its destroy
-- card): the items destroy categories hold, as the bags were last read, that are not left alone and that
-- no merchant buys (hasNoValue). It never holds an item a sale would sell. Destroying skips an item no
-- longer where the read had it (DestroyNext).
---@param ctx Context
---@return AutomationEntry[]
function automation:DestroyQueue(ctx)
  local list = {}
  for _, entry in ipairs(self:Entries(ctx)) do
    if entry.action == self.DESTROY and not entry.blocked and entry.data.containerInfo
      and entry.data.containerInfo.hasNoValue then
      table.insert(list, entry)
    end
  end
  return list
end

-- changed tells whatever shows the destroy queue that it may have changed (automation/Changed).
---@param ctx? Context
local function changed(ctx)
  events:SendMessage(ctx or context:New('Automation_Changed'), 'automation/Changed')
end

-- MerchantBuys says whether the merchant open buys items: retail shows its Sell All Junk button
-- (C_MerchantFrame.IsSellAllJunkEnabled) only where it does, as Vendor reads it; a Classic merchant
-- buys when it sells anything. A repair-only merchant does not.
---@return boolean
function automation:MerchantBuys()
  if C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled then
    return C_MerchantFrame.IsSellAllJunkEnabled() == true
  end
  return (GetMerchantNumItems() or 0) > 0
end

-- StillThere returns how many items a slot holds when it still holds the entry's item (the same item
-- GUID), unlocked and not refundable, and, to sell, one merchants buy; else nil. The bags may have
-- changed since they were read.
---@param entry AutomationEntry
---@param forSale boolean
---@return number?
function automation:StillThere(entry, forSale)
  local data = entry.data
  local guid = data.itemInfo.itemGUID
  if guid == nil or guid == "" then
    return nil
  end
  local info = C_Container.GetContainerItemInfo(data.bagid, data.slotid)
  if info == nil or info.isLocked or (forSale and info.hasNoValue) then
    return nil
  end
  local location = locationOf(data)
  if C_Item.GetItemGUID(location) ~= guid or refundable(location) then
    return nil
  end
  return info.stackCount or 1
end

-- OnMerchantShow sells, when a merchant opens, what either action holds that merchants buy: a wave at
-- once from the frame after it opens (as a section dragged onto BetterBags Next's vendor sells), then the
-- next a moment later, until all are sold. Holding Shift as it opens sells nothing. It returns what it
-- did, for profiler traces.
---@param ctx Context
---@return string
function automation:OnMerchantShow(ctx)
  self.atMerchant = true
  if self.sale then
    self:FinishSale(self.sale, "replaced")
  end
  if IsShiftKeyDown() then
    return "shift"
  end
  if not self:MerchantBuys() then
    return "not buying"
  end
  local list = self:SellList(ctx)
  if #list == 0 then
    return "nothing"
  end
  ---@type AutomationSale
  local sale = { list = list, index = 1, sold = 0, value = 0 }
  self.sale = sale
  C_Timer.After(0, function() self:SellStep(sale) end)
  return "selling"
end

---@param ctx Context
function automation:OnMerchantClosed(ctx)
  local _ = ctx
  self.atMerchant = false
end

-- SellStep sells the sale's next wave: up to WAVE items still there, at once, then the next wave
-- WAVE_DELAY later. It waits while the cursor holds an item, and sells nothing once the merchant closed.
-- It returns what it did.
---@param sale AutomationSale
---@return string
function automation:SellStep(sale)
  if self.sale ~= sale then
    return "replaced"
  end
  if not self.atMerchant then
    return self:FinishSale(sale, "closed")
  end
  if CursorHasItem() then
    C_Timer.After(self.CURSOR_WAIT, function() self:SellStep(sale) end)
    return "waiting"
  end
  local wave = 0
  while sale.index <= #sale.list do
    local entry = sale.list[sale.index]
    sale.index = sale.index + 1
    local count = self:StillThere(entry, true)
    if count then
      C_Container.UseContainerItem(entry.data.bagid, entry.data.slotid)
      sale.sold = sale.sold + 1
      sale.value = sale.value + count * priceOf(entry.data)
      wave = wave + 1
      if wave >= self.WAVE and sale.index <= #sale.list then
        C_Timer.After(self.WAVE_DELAY, function() self:SellStep(sale) end)
        return "wave"
      end
    end
  end
  return self:FinishSale(sale, "done")
end

-- FinishSale ends a sale and says what it sold. It returns why it ended.
---@param sale AutomationSale
---@param reason string
---@return string
function automation:FinishSale(sale, reason)
  if self.sale == sale then
    self.sale = nil
  end
  if sale.sold > 0 then
    local what = sale.sold == 1 and L:G("Sold %d item for %s.") or L:G("Sold %d items for %s.")
    print("BetterBags: " .. format(what, sale.sold, coins(sale.value)))
  end
  return reason
end

-- DestroyNext destroys the first item of the destroy queue (DestroyQueue) still in its slot
-- (StillThere), the whole stack: one item each time, since Blizzard lets an addon destroy only on a key
-- press or a click (DeleteCursorItem has restrictions, GameCursorDocumentation.lua). Not in combat, nor
-- while the cursor holds an item. It says what it destroyed, and returns what it did.
---@param ctx Context
---@return string
function automation:DestroyNext(ctx)
  if InCombatLockdown() then
    print("BetterBags: " .. L:G("Cannot destroy items in combat."))
    return "combat"
  end
  if CursorHasItem() then
    print("BetterBags: " .. L:G("Put down the item you are holding first."))
    return "cursor"
  end
  local entry
  for _, queued in ipairs(self:DestroyQueue(ctx)) do
    if self:StillThere(queued, false) then
      entry = queued
      break
    end
  end
  if entry == nil then
    print("BetterBags: " .. L:G("There is nothing to destroy."))
    return "nothing"
  end
  C_Container.PickupContainerItem(entry.data.bagid, entry.data.slotid)
  if not CursorHasItem() then
    return "not picked up"
  end
  DeleteCursorItem()
  print("BetterBags: " .. format(L:G("Destroyed %s."), entry.data.itemInfo.itemLink or ""))
  changed(ctx)
  return "destroyed"
end

-- BetterBags_DestroyNextItem is the Destroy Next Item key binding (Bindings.xml).
function BetterBags_DestroyNextItem()
  automation:DestroyNext(context:New('BetterBags_DestroyNextItem'))
end
