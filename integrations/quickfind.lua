local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

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

---@class Themes: AceModule
local themes = addon:GetModule('Themes')

---@class QuickFindIntegration: AceModule
local quickfind = addon:NewModule('QuickFind')

function quickfind:OnEnable()
  -- Check if QuickFind addon exists
  if not _G.QuickFind then return end
  if not QuickFind.RegisterSource then return end

  -- Register our source
  self:RegisterBetterBagsSource()

  print("BetterBags: QuickFind integration enabled.")
end

---Builds the item results list for QuickFind
---@return table
function quickfind:GetItemResults()
  local results = {}
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

  -- Find and switch to the appropriate tab
  local tabID = self:GetTabIDForItem(itemData, bagKind)
  if tabID and bag.tabs then
    bag.tabs:SetTabByID(ctx, tabID)
  end

  -- Set search to the exact item name in the embedded in-bag search box
  -- Delay to ensure the bag is fully rendered and search box is ready
  local itemName = itemData.itemInfo.itemName
  C_Timer.After(0.1, function()
    if not database:GetInBagSearch() then
      print("QuickFind: In-bag search is disabled. Enable it in BetterBags settings.")
      return
    end

    -- Get the in-bag search box from the themes module
    local searchBox = themes:GetInBagSearchBox(bag.frame)
    if searchBox and searchBox.textBox then
      searchBox.textBox:SetText(itemName)
      searchBox.textBox:SetFocus()
      searchBox.textBox:HighlightText()
    end
  end)
end

---Gets the tab ID for an item based on its category/group
---@param itemData ItemData
---@param bagKind BagKind
---@return number?
function quickfind:GetTabIDForItem(itemData, bagKind)
  if bagKind == const.BAG_KIND.BACKPACK then
    -- For backpack, tabs are groups
    if database:GetGroupsEnabled(bagKind) and itemData.itemInfo.category then
      local groupID = groups:GetGroupForCategory(itemData.itemInfo.category)
      return groupID
    end
    return nil
  else
    -- For bank, tabs are bag IDs for character bank, or special handling for account bank
    -- For now, just return the bag ID as the tab
    return itemData.bagid
  end
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
