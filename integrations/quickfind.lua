local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Items: AceModule
local items = addon:GetModule('Items')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

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
    lua = function()
      -- Placeholder: Future enhancement could highlight/flash the item
      -- For now, just a no-op
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
