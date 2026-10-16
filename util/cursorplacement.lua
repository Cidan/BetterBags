local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

-- CursorPlacement puts the item on the cursor into a free slot of the bags a bag window
-- shows, the way dropping it on that slot does. It reads the client and calls
-- C_Container.PickupContainerItem, which is not protected, and writes nothing Blizzard's code
-- reads, so a drop taints nothing (.claude/rules/bag-drop-zone.md).
---@class CursorPlacement: AceModule
local cursorPlacement = addon:NewModule('CursorPlacement')

-- The bag family of keys, which only the Classic keyring holds (const.ITEM_BAG_FAMILY).
local KEYRING_FAMILY = 256

-- What a bag holds: 0 for anything, a bag family bitfield for a specialized bag, or
-- "reagent" for the retail reagent bag, which reports family 0 but holds only crafting
-- reagents.
---@param bagid number
---@return number|string
local function bagHolds(bagid)
  if const.BACKPACK_ONLY_REAGENT_BAGS and const.BACKPACK_ONLY_REAGENT_BAGS[bagid] then
    return "reagent"
  end
  local _, family = C_Container.GetContainerNumFreeSlots(bagid)
  family = family or 0
  if family == 0 and Enum.BagIndex.Keyring and bagid == Enum.BagIndex.Keyring then
    return KEYRING_FAMILY
  end
  return family
end

-- The bag families an item fits in, 0 for none. A bag or quiver reports the family it
-- holds instead, so it only fits a bag that holds anything.
---@param itemID number
---@return number
local function itemFits(itemID)
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
  if classID == Enum.ItemClass.Container or classID == Enum.ItemClass.Quiver then
    return 0
  end
  return C_Item.GetItemFamily(itemID) or 0
end

---@param itemID number
---@return boolean
local function isCraftingReagent(itemID)
  return select(17, C_Item.GetItemInfo(itemID)) == true
end

-- IsWindowBag reports whether a bag is shown by the window of a bag kind. The bank window
-- shows both bank types.
---@param kind BagKind
---@param bagid number
---@return boolean
function cursorPlacement:IsWindowBag(kind, bagid)
  if kind == const.BAG_KIND.BANK then
    return const.BANK_BAGS[bagid] ~= nil
      or (const.ACCOUNT_BANK_BAGS ~= nil and const.ACCOUNT_BANK_BAGS[bagid] ~= nil)
  end
  return const.BACKPACK_BAGS[bagid] ~= nil
end

-- ShowsWarbank reports whether a window shows the Warbank: the bank, while its active tab
-- is a Warbank tab.
---@param kind BagKind
---@param bankTab number|nil
---@return boolean
function cursorPlacement:ShowsWarbank(kind, bankTab)
  return kind == const.BAG_KIND.BANK and bankTab ~= nil
    and const.ACCOUNT_BANK_BAGS ~= nil and const.ACCOUNT_BANK_BAGS[bankTab] ~= nil
end

-- TargetBags lists, in the order they are tried, the bags a drop on a window can fill. The
-- bank fills the bank type it shows, starting with the active tab.
---@param kind BagKind
---@param bankTab number|nil
---@return number[]
function cursorPlacement:TargetBags(kind, bankTab)
  local source = const.BACKPACK_BAGS
  if self:ShowsWarbank(kind, bankTab) then
    source = const.ACCOUNT_BANK_BAGS
  elseif kind == const.BAG_KIND.BANK then
    source = const.BANK_BAGS
  end
  local bags = {}
  for bagid in pairs(source) do
    if bagid ~= bankTab then
      table.insert(bags, bagid)
    end
  end
  table.sort(bags)
  if kind == const.BAG_KIND.BANK and bankTab and source[bankTab] then
    table.insert(bags, 1, bankTab)
  end
  return bags
end

-- FindFreeSlot returns the first free slot, read from the client now, of the first of bags
-- made for the item (a profession bag of its family, the reagent bag for a crafting
-- reagent, the keyring for a key), else of the first bag that holds anything. A specialized
-- bag the item does not fit is never used.
---@param bags number[]
---@param itemID number
---@return number|nil bagid, number|nil slotid
function cursorPlacement:FindFreeSlot(bags, itemID)
  local fits = itemFits(itemID)
  local anyBag, anySlot
  for _, bagid in ipairs(bags) do
    local freeSlots = C_Container.GetContainerFreeSlots(bagid)
    local slotid = freeSlots and freeSlots[1]
    if slotid then
      local holds = bagHolds(bagid)
      if holds == "reagent" then
        if isCraftingReagent(itemID) then
          return bagid, slotid
        end
      elseif holds ~= 0 then
        if bit.band(fits, holds) ~= 0 then
          return bagid, slotid
        end
      elseif not anyBag then
        anyBag, anySlot = bagid, slotid
      end
    end
  end
  return anyBag, anySlot
end

-- PlaceCursorItem handles an item dropped on a bag window, or the window clicked while
-- holding one, and returns what it did: "placed" in a free slot of the window's bags,
-- "returned" to its own slot when it was picked up from this window, "full" when no bag
-- has room for it, or "ignored".
---@param kind BagKind
---@param bankTab number|nil The bank window's active tab (bag.bankTab).
---@return string
function cursorPlacement:PlaceCursorItem(kind, bankTab)
  local cursorType, itemID = GetCursorInfo()
  if cursorType ~= "item" or not itemID then
    return "ignored"
  end
  local location = C_Cursor.GetCursorItem()
  if location and location:IsBagAndSlot() then
    local fromBag = location:GetBagAndSlot()
    if self:IsWindowBag(kind, fromBag) then
      ClearCursor()
      return "returned"
    end
  end
  -- Blizzard's bank asks before a refundable item goes into the Warbank, where its refund
  -- is lost (BankPanelItemButtonMixin:HandleItemPickup). That prompt is Blizzard's to show.
  if location and self:ShowsWarbank(kind, bankTab) and C_Item.CanBeRefunded(location) then
    return "ignored"
  end
  local bagid, slotid = self:FindFreeSlot(self:TargetBags(kind, bankTab), itemID)
  if not bagid then
    UIErrorsFrame:AddMessage(kind == const.BAG_KIND.BANK and ERR_BANK_FULL or ERR_INV_FULL, 1.0, 0.1, 0.1, 1.0)
    return "full"
  end
  C_Container.PickupContainerItem(bagid, slotid)
  return "placed"
end
