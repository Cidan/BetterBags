-- mock_data.lua -- Shared mock factories for BetterBags test data.
-- Usage: local mocks = require("spec.helpers.mock_data")
-- local item = mocks.ItemData({name = "Thunderfury", quality = 4})

local M = {}

local nextSlotID = 0
local function autoSlotKey()
  nextSlotID = nextSlotID + 1
  return "bag:0:slot:" .. nextSlotID
end

--- Create a comprehensive mock ItemData.
--- All fields have sensible defaults; override any via opts.
---@param opts? table
---@return table ItemData
function M.ItemData(opts)
  opts = opts or {}
  local slotkey = opts.slotkey or autoSlotKey()
  local bagid = opts.bagid or 0
  local slotid = opts.slotid or 0

  return {
    basic = opts.basic or false,
    bagid = bagid,
    slotid = slotid,
    slotkey = slotkey,
    isItemEmpty = opts.isItemEmpty or false,
    kind = opts.kind or 0,
    newItemTime = opts.newItemTime or 0,
    stacks = opts.stacks or 0,
    stackedOn = opts.stackedOn or "",
    stackedCount = opts.stackedCount or 0,
    itemHash = opts.itemHash or ("hash:" .. (opts.name or "item")),
    bagName = opts.bagName or "Backpack",
    forceClear = opts.forceClear or false,
    nextStack = opts.nextStack or "",
    inventoryType = opts.inventoryType or 0,
    inventorySlots = opts.inventorySlots or {},
    itemInfo = {
      itemID = opts.itemID or 1000,
      itemGUID = opts.guid or ("guid:" .. slotkey),
      itemName = opts.name or "Test Item",
      itemLink = opts.itemLink or "|cff0070dd|Hitem:1000|h[Test Item]|h|r",
      itemQuality = opts.quality or 1,
      itemLevel = opts.itemLevel or 1,
      itemMinLevel = opts.itemMinLevel or 0,
      itemType = opts.itemType or "Miscellaneous",
      itemSubType = opts.subType or "Junk",
      itemStackCount = opts.maxStack or 1,
      itemEquipLoc = opts.equipLoc or "INVTYPE_NON_EQUIP_IGNORE",
      itemTexture = opts.texture or 134400,
      sellPrice = opts.sellPrice or 0,
      classID = opts.classID or 15,
      subclassID = opts.subclassID or 0,
      bindType = opts.bindType or 0,
      expacID = opts.expacID,
      setID = opts.setID or 0,
      isCraftingReagent = opts.isReagent or false,
      effectiveIlvl = opts.effectiveIlvl or opts.itemLevel or 1,
      isPreview = false,
      baseIlvl = opts.baseIlvl or opts.itemLevel or 1,
      isBound = opts.isBound or false,
      isLocked = opts.isLocked or false,
      isNewItem = opts.isNewItem or false,
      currentItemCount = opts.count or 1,
      category = opts.category or "Other",
      currentItemLevel = opts.currentItemLevel or opts.itemLevel or 1,
      equipmentSets = opts.equipmentSets,
      tooltipText = opts.tooltipText,
    },
    containerInfo = opts.containerInfo or {
      iconFileID = 134400,
      stackCount = opts.count or 1,
      isLocked = false,
      quality = opts.quality or 1,
      isReadable = false,
      hasLoot = false,
      hyperlink = opts.itemLink or "|cff0070dd|Hitem:1000|h[Test Item]|h|r",
      isFiltered = false,
      hasNoValue = false,
      itemID = opts.itemID or 1000,
      isBound = opts.isBound or false,
    },
    questInfo = {
      isQuestItem = opts.isQuest or false,
      isActive = opts.isActiveQuest or false,
    },
    transmogInfo = opts.transmogInfo or {
      itemAppearanceID = 0,
      itemModifiedAppearanceID = 0,
      hasTransmog = false,
    },
    bindingInfo = {
      binding = opts.bindingScope or 0,
      bound = opts.bound or false,
    },
    itemLinkInfo = {
      itemID = opts.itemID or 1000,
      enchantID = "",
      gemID1 = "",
      gemID2 = "",
      gemID3 = "",
      gemID4 = "",
      suffixID = "",
      uniqueID = "",
      linkLevel = "",
      specializationID = "",
      modifiersMask = "",
      itemContext = "",
      bonusIDs = opts.bonusIDs or {},
      modifierIDs = {},
      relic1BonusIDs = {},
      relic2BonusIDs = {},
      relic3BonusIDs = {},
      crafterGUID = "",
      extraEnchantID = "",
    },
  }
end

--- Create an empty-slot ItemData (for free slot tests).
---@param opts? table
---@return table ItemData
function M.EmptySlot(opts)
  opts = opts or {}
  local item = M.ItemData(opts)
  item.isItemEmpty = true
  item.itemInfo.itemName = ""
  item.itemInfo.itemQuality = -1
  item.itemInfo.currentItemCount = 0
  item.itemHash = ""
  return item
end

--- Create a mock Section for sort tests.
---@param opts table {title, fillWidth, cellCount}
---@return table Section
function M.Section(opts)
  return {
    title = { GetText = function() return opts.title or "" end },
    GetFillWidth = function() return opts.fillWidth or false end,
    GetCellCount = function() return opts.cellCount or 0 end,
  }
end

--- Create a mock Item wrapper (for sort functions that expect item:GetItemData()).
---@param opts table Same opts as ItemData, plus isFreeSlot
---@return table Item
function M.Item(opts)
  local data = nil
  if not opts.isFreeSlot then
    data = M.ItemData(opts)
  end
  return {
    isFreeSlot = opts.isFreeSlot or false,
    GetItemData = function() return data end,
  }
end

--- Create a mock frame with Show/Hide/IsShown and fadeIn/fadeOut.
---@param opts? table {name, shown}
---@return table Frame
function M.Frame(opts)
  opts = opts or {}
  local shown = opts.shown or false
  return {
    name = opts.name or "MockFrame",
    fadeIn = true,
    fadeOut = true,
    Show = function() shown = true end,
    Hide = function(_, callback)
      shown = false
      if callback then callback() end
    end,
    IsShown = function() return shown end,
  }
end

-- Make helpers available globally for spec files
_G.MockData = M

return M
