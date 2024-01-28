local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
---@field private data databaseOptions
local DB = addon:NewModule('Database')

function DB:OnInitialize()
  -- Create the settings database.
  DB.data = LibStub('AceDB-3.0'):New(addonName .. 'DB', const.DATABASE_DEFAULTS --[[@as AceDB.Schema]], true) --[[@as databaseOptions]]
end

---@return databaseOptions
function DB:GetData()
  return DB.data
end

---@param kind BagKind
---@return table
function DB:GetBagPosition(kind)
  return DB.data.profile.positions[kind]
end

---@param kind BagKind
---@return BagView
function DB:GetBagView(kind)
  return DB.data.profile.views[kind]
end

---@param kind BagKind
---@param view BagView
function DB:SetBagView(kind, view)
  DB.data.profile.views[kind] = view
end

function DB:GetCategoryFilter(kind, filter)
  return DB.data.profile.categoryFilters[kind][filter]
end

function DB:SetCategoryFilter(kind, filter, value)
  DB.data.profile.categoryFilters[kind][filter] = value
end

---@param show boolean
function DB:SetShowBagButton(show)
  DB.data.profile.showBagButton = show
end

---@return boolean
function DB:GetShowBagButton()
  return DB.data.profile.showBagButton
end

---@param kind BagKind
---@param view BagView
---@return table 
function DB:GetBagSizeInfo(kind, view)
  return DB.data.profile.size[view][kind]
end

---@param kind BagKind
---@param view BagView
---@param count number
function DB:SetBagViewSizeColumn(kind, view, count)
  DB.data.profile.size[view][kind].columnCount = count
end

---@param kind BagKind
---@param view BagView
---@param count number
function DB:SetBagViewSizeItems(kind, view, count)
  DB.data.profile.size[view][kind].itemsPerRow = count
end
---@param kind BagKind
---@param view BagView
---@param scale number
function DB:SetBagViewSizeScale(kind, view, scale)
  DB.data.profile.size[view][kind].scale = scale
end

---@param kind BagKind
---@param view BagView
---@return number, number
function DB:GetBagViewFrameSize(kind, view)
  local s = DB.data.profile.size[view][kind]
  return s.width, s.height
end

---@param kind BagKind
---@param view BagView
---@param width number
---@param height number
function DB:SetBagViewFrameSize(kind, view, width, height)
  DB.data.profile.size[view][kind].width = width
  DB.data.profile.size[view][kind].height = height
end

---@param kind BagKind
---@return GridCompactStyle
function DB:GetBagCompaction(kind)
  return DB.data.profile.compaction[kind]
end

---@param kind BagKind
---@param style GridCompactStyle
function DB:SetBagCompaction(kind, style)
  DB.data.profile.compaction[kind] = style
end

function DB:GetItemLevelOptions(kind)
  return DB.data.profile.itemLevel[kind]
end

function DB:SetItemLevelEnabled(kind, enabled)
  DB.data.profile.itemLevel[kind].enabled = enabled
end

function DB:SetItemLevelColorEnabled(kind, enabled)
  DB.data.profile.itemLevel[kind].color = enabled
end

function DB:GetFirstTimeMenu()
  return DB.data.profile.firstTimeMenu
end

function DB:SetFirstTimeMenu(value)
  DB.data.profile.firstTimeMenu = value
end

function DB:SetBagViewSizeOpacity(kind, view, opacity)
  DB.data.profile.size[view][kind].opacity = opacity
end

---@param kind BagKind
---@param view BagView
---@return SectionSortType
function DB:GetSectionSortType(kind, view)
  return DB.data.profile.sectionSort[kind][view]
end

---@param kind BagKind
---@param view BagView
---@param sort SectionSortType
function DB:SetSectionSortType(kind, view, sort)
  DB.data.profile.sectionSort[kind][view] = sort
end

---@param kind BagKind
---@param view BagView
---@return ItemSortType
function DB:GetItemSortType(kind, view)
  return DB.data.profile.itemSort[kind][view]
end

---@param kind BagKind
---@param view BagView
---@param sort ItemSortType
function DB:SetItemSortType(kind, view, sort)
  DB.data.profile.itemSort[kind][view] = sort
end

---@param itemID number
---@param category string
function DB:SaveItemToCategory(itemID, category)
  DB:CreateCategory(category)
  DB.data.profile.customCategoryFilters[category].itemList[itemID] = true
  local previousCategory = DB.data.profile.customCategoryIndex[itemID]
  if previousCategory and previousCategory ~= category then
    DB.data.profile.customCategoryFilters[previousCategory].itemList[itemID] = nil
  end
  DB.data.profile.customCategoryIndex[itemID] = category
end

---@param itemID number
---@param category string
function DB:DeleteItemFromCategory(itemID, category)
  if DB.data.profile.customCategoryFilters[category] then
    DB.data.profile.customCategoryFilters[category].itemList[itemID] = nil
    DB.data.profile.customCategoryIndex[itemID] = nil
  end
end

---@param category string
---@param enabled boolean
function DB:SetItemCategoryEnabled(category, enabled)
  DB:CreateCategory(category)
  DB.data.profile.customCategoryFilters[category].enabled = enabled
end

---@param category string
function DB:DeleteItemCategory(category)
  for itemID, _ in pairs(DB.data.profile.customCategoryFilters[category].itemList) do
    DB:DeleteItemFromCategory(itemID, category)
  end
  DB.data.profile.customCategoryFilters[category] = nil
end

---@param category string
function DB:WipeItemCategory(category)
  if DB.data.profile.customCategoryFilters[category] then
    for itemID, _ in pairs(DB.data.profile.customCategoryFilters[category].itemList) do
      DB:DeleteItemFromCategory(itemID, category)
    end
  end
end

---@return table<string, CustomCategoryFilter>
function DB:GetAllItemCategories()
  for category, _ in pairs(DB.data.profile.customCategoryFilters) do
    DB.data.profile.customCategoryFilters[category].name = category
  end
  return DB.data.profile.customCategoryFilters
end

---@param category string
---@return CustomCategoryFilter
function DB:GetItemCategory(category)
  return DB.data.profile.customCategoryFilters[category] or {}
end

---@param category string
---@return boolean
function DB:ItemCategoryExists(category)
  return DB.data.profile.customCategoryFilters[category] ~= nil
end

---@param itemID number
---@return CustomCategoryFilter
function DB:GetItemCategoryByItemID(itemID)
  return DB.data.profile.customCategoryFilters[DB.data.profile.customCategoryIndex[itemID]] or {}
end

---@param category string
function DB:CreateCategory(category)
  DB.data.profile.customCategoryFilters[category] = DB.data.profile.customCategoryFilters[category] or {itemList = {}}
  DB.data.profile.customCategoryFilters[category].name = category
  DB.data.profile.customCategoryFilters[category].enabled = true
end

DB:Enable()
