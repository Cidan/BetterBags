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

---@class Seller: AceModule
local seller = addon:GetModule('Seller')

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

---@class AutomationEntry
---@field data ItemData The item, as the bags last read it.
---@field category string Its category (without Recent Items).
---@field action string What its category does: "sell" or "destroy".
---@field blocked? string Why automation leaves it alone.

---@class AutomationSale
---@field list AutomationEntry[]
---@field job? SellerJob Its sale, once started (Seller).
---@field waitUntil? number Until when it waits for items whose upgrade state is not known yet.
---@field finished? boolean

-- How long a sale waits for items whose upgrade state its provider cannot tell yet, and how often it looks: a sale is one list, so what
-- it left out would wait for the next visit. Only a session's first read, or a read of more new items than Pawn's budget covers.
local WAIT_FOR_ANSWERS = 10
local LOOK_FOR_ANSWERS = 0.25

function automation:Init()
  self.atMerchant = false
  self.sale = nil
end

function automation:OnEnable()
  events:RegisterEvent('MERCHANT_SHOW', function(ctx) self:OnMerchantShow(ctx) end)
  events:RegisterEvent('MERCHANT_CLOSED', function(ctx) self:OnMerchantClosed(ctx) end)
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
  if data.upgradeUnknown then
    return L:G("Whether it is an upgrade is not known yet.")
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
-- automation leaves it alone, if it does: the items given (a section docked in BetterBags Next's vendor,
-- automation.md §4), else every item as the bags were last read.
---@param ctx Context
---@param only? ItemData[]
---@return AutomationEntry[]
function automation:Entries(ctx, only)
  local source = only
  if source == nil then
    local slotInfo = items.slotInfo and items.slotInfo[const.BAG_KIND.BACKPACK]
    source = slotInfo and slotInfo.itemsBySlotKey or {}
  end
  local list = {}
  for _, data in pairs(source) do
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
-- alone, that merchants buy and that the merchant open has not refused (Seller:Refuses: back in the bags
-- until a merchant buys them), of the items given (else of every item).
---@param ctx Context
---@param only? ItemData[]
---@return AutomationEntry[]
function automation:SellList(ctx, only)
  local list = {}
  for _, entry in ipairs(self:Entries(ctx, only)) do
    if not entry.blocked and not (entry.data.containerInfo and entry.data.containerInfo.hasNoValue)
      and not seller:Refuses(entry.data) then
      table.insert(list, entry)
    end
  end
  return list
end

-- DestroyQueue lists what destroying takes, in order: the items destroy categories hold, as the bags
-- were last read, that are not left alone and that no merchant buys (hasNoValue), of the items given
-- (a section docked in BetterBags Next's vendor) or of every item. It never holds an item a sale would
-- sell. Destroying skips an item no longer where the read had it (DestroyNext).
---@param ctx Context
---@param only? ItemData[]
---@return AutomationEntry[]
function automation:DestroyQueue(ctx, only)
  local list = {}
  for _, entry in ipairs(self:Entries(ctx, only)) do
    if entry.action == self.DESTROY and not entry.blocked and entry.data.containerInfo
      and entry.data.containerInfo.hasNoValue then
      table.insert(list, entry)
    end
  end
  return list
end

-- SaleOffer lists what of the items given Auto Sell sells once the player confirms it in BetterBags Next's
-- vendor dock (§4): the entries of SellList whose category confirms its sale (Confirm Auto Sell on), still
-- there to sell (StillThere: one already selling is locked).
---@param ctx Context
---@param only ItemData[]
---@return AutomationEntry[]
function automation:SaleOffer(ctx, only)
  local list = {}
  for _, entry in ipairs(self:SellList(ctx, only)) do
    if categories:ConfirmsSaleOf(entry.category) and self:StillThere(entry, true) then
      table.insert(list, entry)
    end
  end
  return list
end

-- DestroyLeft lists what of the items given is left to destroy: the entries of DestroyQueue still in
-- their slot (StillThere).
---@param ctx Context
---@param only ItemData[]
---@return AutomationEntry[]
function automation:DestroyLeft(ctx, only)
  local list = {}
  for _, entry in ipairs(self:DestroyQueue(ctx, only)) do
    if self:StillThere(entry, false) then
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

-- MerchantBuys says whether the merchant open buys items: not one that refused to buy anything
-- (Seller:BuysNothing); retail shows its Sell All Junk button (C_MerchantFrame.IsSellAllJunkEnabled)
-- only where it does, as Vendor reads it; a Classic merchant buys when it sells anything. A repair-only
-- merchant does not.
---@return boolean
function automation:MerchantBuys()
  if seller:BuysNothing() then
    return false
  end
  if C_MerchantFrame and C_MerchantFrame.IsSellAllJunkEnabled then
    return C_MerchantFrame.IsSellAllJunkEnabled() == true
  end
  return (GetMerchantNumItems() or 0) > 0
end

-- StillThere returns how many items a slot holds when it still holds the entry's item (the same item
-- GUID, never an empty one), unlocked and not refundable, and, to sell, one merchants buy; else nil
-- (Seller:StillThere, the check every sale makes before each item). The bags may have changed since
-- they were read.
---@param entry AutomationEntry
---@param forSale boolean
---@return number?
function automation:StillThere(entry, forSale)
  return seller:StillThere(entry.data, forSale)
end

-- saleNow lists what a merchant opening sells of its own: SellList, of the categories that do not confirm
-- their sale (Confirm Auto Sell off).
---@param ctx Context
---@return AutomationEntry[]
function automation:saleNow(ctx)
  local list = {}
  for _, entry in ipairs(self:SellList(ctx)) do
    if not categories:ConfirmsSaleOf(entry.category) then
      table.insert(list, entry)
    end
  end
  return list
end

-- waitsForAnswers says whether the backpack holds an item a merchant would buy that a provider cannot tell
-- about yet. Any such item: it may not be in a category that sells until the answer puts it there.
---@return boolean
function automation:waitsForAnswers()
  local slotInfo = items.slotInfo and items.slotInfo[const.BAG_KIND.BACKPACK]
  for _, data in pairs(slotInfo and slotInfo.itemsBySlotKey or {}) do
    if data.upgradeUnknown and const.BACKPACK_BAGS[data.bagid] ~= nil
      and not (data.containerInfo and data.containerInfo.hasNoValue) then
      return true
    end
  end
  return false
end

-- OnMerchantShow sells, when a merchant opens, what either action holds that merchants buy in the
-- categories that do not confirm their sale (Confirm Auto Sell off), from the frame after it opens
-- (StartSale), or once a provider can tell about the items it cannot yet. A category that confirms waits
-- in BetterBags Next's vendor dock for the player (§4); the classic design has no dock and leaves it to
-- the player. Holding Shift as it opens sells nothing. It returns what it did, for profiler traces.
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
  local list = self:saleNow(ctx)
  local waiting = self:waitsForAnswers()
  if #list == 0 and not waiting then
    return "nothing"
  end
  ---@type AutomationSale
  local sale = { list = list, waitUntil = waiting and GetTime() + WAIT_FOR_ANSWERS or nil }
  self.sale = sale
  C_Timer.After(0, function() self:StartSale(sale) end)
  return waiting and "waiting" or "selling"
end

---@param ctx Context
function automation:OnMerchantClosed(ctx)
  local _ = ctx
  self.atMerchant = false
end

-- StartSale sells the sale through the seller (Seller:Sell): one item at a time, each still there when
-- its turn comes, until all are sold, the merchant closes, or a new sale replaces it (the merchant
-- opened again). It returns what it did.
---@param sale AutomationSale
---@return string
function automation:StartSale(sale)
  if self.sale ~= sale then
    return "replaced"
  end
  if sale.waitUntil then
    if not self.atMerchant then
      return self:FinishSale(sale, "closed")
    end
    if GetTime() < sale.waitUntil and self:waitsForAnswers() then
      C_Timer.After(LOOK_FOR_ANSWERS, function() self:StartSale(sale) end)
      return "waiting"
    end
    sale.list = self:saleNow(context:New('AutomationSale'))
  end
  local list = {}
  for _, entry in ipairs(sale.list) do
    table.insert(list, entry.data)
  end
  sale.job = seller:Sell(list, {
    stillOpen = function() return self.atMerchant end,
    onDone = function(_, reason) self:FinishSale(sale, reason) end,
  })
  return "selling"
end

-- FinishSale ends a sale, once (a sale replaced stops selling), and says what it sold: the items the
-- merchant took, each with how many its slot held. It returns why it ended.
---@param sale AutomationSale
---@param reason string
---@return string
function automation:FinishSale(sale, reason)
  if sale.finished then
    return reason
  end
  sale.finished = true
  if self.sale == sale then
    self.sale = nil
  end
  local job = sale.job
  if job == nil then
    return reason
  end
  seller:Cancel(job)
  local sold, value = 0, 0
  for _, item in ipairs(job.sold) do
    sold = sold + 1
    value = value + (item.count or 1) * priceOf(item.data)
  end
  if sold > 0 then
    local what = sold == 1 and L:G("Sold %d item for %s.") or L:G("Sold %d items for %s.")
    print("BetterBags: " .. format(what, sold, coins(value)))
  end
  return reason
end

-- DestroyNext destroys the first item of the destroy queue (DestroyQueue, of the items given when given)
-- still in its slot (StillThere), the whole stack: one item each time, since Blizzard lets an addon
-- destroy only on a key press or a click (DeleteCursorItem has restrictions, GameCursorDocumentation.lua).
-- Not in combat, nor while the cursor holds an item. It says what it destroyed, and returns what it did.
---@param ctx Context
---@param only? ItemData[]
---@return string
function automation:DestroyNext(ctx, only)
  if InCombatLockdown() then
    print("BetterBags: " .. L:G("Cannot destroy items in combat."))
    return "combat"
  end
  if CursorHasItem() then
    print("BetterBags: " .. L:G("Put down the item you are holding first."))
    return "cursor"
  end
  local entry
  for _, queued in ipairs(self:DestroyQueue(ctx, only)) do
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
