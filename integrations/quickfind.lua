local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Groups: AceModule
local groups = addon:GetModule('Groups')

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class QuickFindIntegration: AceModule
local quickfind = addon:NewModule('QuickFind')

function quickfind:OnEnable()
  -- Check if QuickFind addon exists
  if not _G.QuickFind then return end
  if not QuickFind.RegisterSource then return end

  -- Registered while Enable QuickFind Integration is off too: QuickFind cannot take a source back
  -- (RegisterSource only), so the source is empty while it is off, and follows the switch at once.
  self:RegisterBetterBagsSource()

  if database:GetQuickFindEnabled() then
    print("BetterBags: QuickFind integration enabled.")
  end
end

---Builds the item results list for QuickFind: none while Enable QuickFind Integration is off
---@return table
function quickfind:GetItemResults()
  local results = {}
  if not database:GetQuickFindEnabled() then
    return results
  end
  local allSlotInfo = items:GetAllSlotInfo()

  -- Process backpack items
  for _, itemData in pairs(allSlotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey) do
    if not itemData.isItemEmpty and itemData.itemInfo then
      table.insert(results, self:CreateResultEntry(itemData, "Backpack"))
    end
  end

  -- Process bank items
  for _, itemData in pairs(allSlotInfo[const.BAG_KIND.BANK].itemsBySlotKey) do
    if not itemData.isItemEmpty and itemData.itemInfo then
      table.insert(results, self:CreateResultEntry(itemData, "Bank"))
    end
  end

  return results
end

---Creates a QuickFind result entry for an item
---@param itemData ItemData
---@param location string
---@return table
function quickfind:CreateResultEntry(itemData, location)
  local info = itemData.itemInfo

  -- Build tags for searching (include location in tags, not name)
  local tags = string.format("%s %s %s %s %s",
    info.itemType or "",
    info.itemSubType or "",
    info.category or "",
    info.itemEquipLoc or "",
    location
  )

  -- Build unique ID with location prefix
  local bagKindPrefix = location:lower()
  local uniqueID = string.format("%s:%s", bagKindPrefix, itemData.slotkey)

  return {
    type = QuickFind.LOOKUP_TYPE.LUA,
    name = info.itemName,
    icon = info.itemIcon,
    tags = tags,
    id = uniqueID,
    label = {
      text = location,
      color = {0.6, 0.8, 1}  -- Pale blue
    },
    lua = function(id)
      self:OnItemSelected(id)
    end
  }
end

---Registers BetterBags as a QuickFind source
function quickfind:RegisterBetterBagsSource()
  QuickFind:RegisterSource({
    name = 'BetterBags Items',
    get = function()
      return self:GetItemResults()
    end
  })
end

---Called when user presses Enter on an item in QuickFind
---@param id string Format: "backpack:bagid_slotid" or "bank:bagid_slotid"
function quickfind:OnItemSelected(id)
  self:ShowInBag(id)
end

---Shows the item in the bag
---@param id string
function quickfind:ShowInBag(id)
  local ctx = context:New('quickfind_show')
  local bagKind, slotkey = self:ParseID(id)

  -- Get item data
  local itemData = items:GetItemDataFromSlotKey(slotkey)
  if not itemData or not itemData.itemInfo then
    return
  end

  -- Get the bag frame
  local bag = bagKind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank
  if not bag then
    return
  end

  -- Open the bag
  bag:Show(ctx)

  -- Switch to the tab holding the item, as a click on that tab does.
  local tabID = self:GetTabIDForItem(itemData, bagKind)
  if tabID and bag.behavior then
    if bagKind == const.BAG_KIND.BACKPACK then
      if bag.behavior.SwitchToGroup then
        bag.behavior:SwitchToGroup(ctx, tabID)
      end
    elseif self:ShowsBlizzardBankTabs() then
      -- The classic bank's tab slots panel marks its tab, then has the bank show it; BetterBags Next's tab rail
      -- follows the bank.
      if bag.slots and bag.slots.SelectTab then
        bag.slots:SelectTab(ctx, tabID)
      else
        bag.behavior:SwitchToBlizzardTab(ctx, tabID)
      end
    elseif bag.tabs then
      -- The classic design's bank on Classic clients has no tabs (bags/classic/bank.lua, bags/era/bank.lua).
      bag.behavior:SwitchToGroup(ctx, tabID)
    end
  end

  -- Set search to the exact item name in the embedded in-bag search box
  if not database:GetInBagSearch() then
    print("QuickFind: In-bag search is disabled. Enable it in BetterBags settings.")
    return
  end

  local searchBox = bag.searchBox
  if searchBox and searchBox.textBox then
    searchBox.textBox:SetText(self:NameQuery(itemData.itemInfo.itemName))
    searchBox.textBox:SetFocus()
    searchBox.textBox:HighlightText()
  end
end

---Returns the search for the items of exactly this name: name == "...", the name one quoted text, its quotation marks
---escaped (util/query.lua). Unquoted, its words would be read as terms and operators.
---@param name string
---@return string
function quickfind:NameQuery(name)
  return 'name == "' .. name:gsub('"', '\\"') .. '"'
end

---Says whether the bank shows Blizzard's bank tabs (Show Bank Tabs, the classic bank's Show Bags) rather than its
---groups: retail's alone; a setting left on elsewhere splits the bank's data by bag, never by group.
---@return boolean
function quickfind:ShowsBlizzardBankTabs()
  return addon.isRetail and database:GetShowBankTabs() and true or false
end

---Gets the tab holding an item: for the backpack, the group its category is assigned to; for the bank, the Blizzard
---bank tab it is in while the bank shows those, else the group its category is assigned to for its bank type, or that
---bank type's default group, as the bank's data is split (data/items.lua, ItemBelongsToTab). Nil while the bag shows no
---tabs.
---@param itemData ItemData
---@param bagKind BagKind
---@return number?
function quickfind:GetTabIDForItem(itemData, bagKind)
  if bagKind == const.BAG_KIND.BACKPACK then
    -- For backpack, tabs are groups (only if groups are enabled)
    if not database:GetGroupsEnabled(bagKind) then
      -- Groups disabled: no tabs exist, return nil
      return nil
    end

    -- Groups enabled: find the group for this item
    if itemData.itemInfo.category then
      local groupID = groups:GetGroupForCategory(bagKind, itemData.itemInfo.category)
      if groupID then
        return groupID
      end
    end

    -- Default to group 1 (Backpack) for items without a group
    return 1
  end

  -- Each of Blizzard's bank tabs is one bag.
  if self:ShowsBlizzardBankTabs() then
    return itemData.bagid
  end
  if database:GetShowBankTabs() or not database:GetGroupsEnabled(bagKind) then
    return nil
  end

  -- A category is assigned to a bank group for a bank type: on retail, the Warbank's or the character bank's.
  local bankType = nil
  if addon.isRetail then
    bankType = const.ACCOUNT_BANK_BAGS[itemData.bagid] ~= nil and Enum.BankType.Account or Enum.BankType.Character
  end
  local category = itemData.itemInfo.category
  local groupID = category and groups:GetGroupForCategory(bagKind, category, bankType)
  if groupID then
    return groupID
  end
  local default = groups:GetDefaultBankGroup(bankType)
  return default and default.id
end

---Parses the QuickFind ID into bag kind and slotkey
---@param id string Format: "backpack:bagid_slotid" or "bank:bagid_slotid"
---@return BagKind, string
function quickfind:ParseID(id)
  local bagKindStr, slotkey = id:match("^([^:]+):(.+)$")
  local bagKind = bagKindStr == "backpack" and const.BAG_KIND.BACKPACK or const.BAG_KIND.BANK
  return bagKind, slotkey
end

---Parses slotkey into bagid and slotid
---@param slotkey string Format: "bagid_slotid"
---@return number, number
function quickfind:ParseSlotKey(slotkey)
  local bagid, slotid = slotkey:match("^(%d+)_(%d+)$")
  return tonumber(bagid), tonumber(slotid)
end
