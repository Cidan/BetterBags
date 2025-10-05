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
  DB:Migrate()
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
---@return table
function DB:GetAnchorPosition(kind)
  return DB.data.profile.anchorPositions[kind]
end

---@param kind BagKind
---@return AnchorState
function DB:GetAnchorState(kind)
  return DB.data.profile.anchorState[kind]
end

---@param kind BagKind
---@return BagView
function DB:GetBagView(kind)
  return DB.data.profile.views[kind]
end

---@param kind BagKind
---@return boolean
function DB:GetMarkRecentItems(kind)
  return DB.data.profile.newItems[kind].markRecentItems
end

---@param kind BagKind
---@param value boolean
function DB:SetMarkRecentItems(kind, value)
  DB.data.profile.newItems[kind].markRecentItems = value
end

---@param kind BagKind
---@return boolean
function DB:GetShowNewItemFlash(kind)
  return DB.data.profile.newItems[kind].showNewItemFlash
end

---@param kind BagKind
---@param value boolean
function DB:SetShowNewItemFlash(kind, value)
  DB.data.profile.newItems[kind].showNewItemFlash = value
end

---@param kind BagKind
---@param view BagView
function DB:SetBagView(kind, view)
  DB.data.profile.views[kind] = view
end

---@param kind BagKind
---@param view BagView
function DB:SetPreviousView(kind, view)
  DB.data.profile.previousViews[kind] = view
end

---@param kind BagKind
---@return BagView
function DB:GetPreviousView(kind)
  return DB.data.profile.previousViews[kind]
end

function DB:GetCategoryFilter(kind, filter)
  return DB.data.profile.categoryFilters[kind][filter]
end

function DB:SetCategoryFilter(kind, filter, value)
  DB.data.profile.categoryFilters[kind][filter] = value
end

function DB:GetCategoryFilters(kind)
  return DB.data.profile.categoryFilters[kind]
end

---@param show boolean
function DB:SetShowBagButton(show)
  DB.data.profile.showBagButton = show
end

---@return boolean
function DB:GetShowBagButton()
  return DB.data.profile.showBagButton
end

---@param enabled boolean
function DB:SetCharacterBankTabsEnabled(enabled)
  DB.data.profile.characterBankTabsEnabled = enabled
end

---@return boolean
function DB:GetCharacterBankTabsEnabled()
  return DB.data.profile.characterBankTabsEnabled
end

---@param enabled boolean
function DB:SetEnableBankBag(enabled)
  DB.data.profile.enableBankBag = enabled
end

---@return boolean
function DB:GetEnableBankBag()
  return DB.data.profile.enableBankBag
end

---@param kind BagKind
---@param view BagView
---@return SizeInfo
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

---@param kind BagKind
---@param view BagView
---@param opacity number
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
---@return boolean
function DB:GetExtraGlowyButtons(kind)
  return DB.data.profile.extraGlowyButtons[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetExtraGlowyButtons(kind, value)
  DB.data.profile.extraGlowyButtons[kind] = value
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
  assert(DB.data.profile.customCategoryFilters[category] ~= nil, "Category does not exist: " .. category)
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

---@param kind BagKind
---@param category string
---@param enabled boolean
function DB:SetItemCategoryEnabled(kind, category, enabled)
  assert(DB.data.profile.customCategoryFilters[category] ~= nil, "Category does not exist: " .. category)
  DB.data.profile.customCategoryFilters[category].enabled[kind] = enabled
end

function DB:SetEphemeralItemCategoryEnabled(kind, category, enabled)
  DB.data.profile.ephemeralCategoryFilters[category].enabled[kind] = enabled
end

---@param category string
function DB:DeleteItemCategory(category)
  if DB.data.profile.customCategoryFilters[category] ~= nil then
    for itemID, _ in pairs(DB.data.profile.customCategoryFilters[category].itemList) do
      DB:DeleteItemFromCategory(itemID, category)
    end
  end
  DB.data.profile.customCategoryFilters[category] = nil
  DB.data.profile.ephemeralCategoryFilters[category] = nil
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
---@return CustomCategoryFilter?
function DB:GetItemCategory(category)
  return DB.data.profile.customCategoryFilters[category]
end

---@param category string
---@return CustomCategoryFilter?
function DB:GetEphemeralItemCategory(category)
  return DB.data.profile.ephemeralCategoryFilters[category]
end

function DB:GetAllEphemeralItemCategories()
  return DB.data.profile.ephemeralCategoryFilters
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

---@param category CustomCategoryFilter
function DB:CreateOrUpdateCategory(category)
  if category.save then
    DB.data.profile.customCategoryFilters[category.name] = category
    for itemID, _ in pairs(category.itemList) do
      DB.data.profile.customCategoryIndex[itemID] = category.name
    end
  else
    DB.data.profile.ephemeralCategoryFilters[category.name] = {
      name = category.name,
      enabled = category.enabled,
      dynamic = category.dynamic,
      itemList = {},
    }
  end
end

---@param category string
---@return boolean
function DB:IsSearchCategory(category)
  return DB.data.profile.searchCategories[category] ~= nil
end

---@param category string
---@return CategoryOptions
function DB:GetCategoryOptions(category)
  local options = DB.data.profile.categoryOptions[category]
  if not options then
    options = {
      shown = true,
    }
    DB.data.profile.categoryOptions[category] = options
  end
  return options
end

---@return boolean
function DB:GetEnterToMakeCategory()
  return DB.data.profile.enterToMakeCategory
end

---@param value boolean
function DB:SetEnterToMakeCategory(value)
  DB.data.profile.enterToMakeCategory = value
end

---@param kind BagKind
function DB:ClearCustomSectionSort(kind)
  DB.data.profile.customSectionSort[kind] = {}
end

---@param kind BagKind
---@param category string
---@param sort number
function DB:SetCustomSectionSort(kind, category, sort)
  DB.data.profile.customSectionSort[kind][category] = sort
end

---@param kind BagKind
---@return table<string, number>
function DB:GetCustomSectionSort(kind)
  return DB.data.profile.customSectionSort[kind]
end

---@param kind BagKind
---@param category string
---@return boolean
function DB:GetSectionCollapsed(kind, category)
  return DB.data.profile.collapsedSections[kind][category] or false
end

---@param kind BagKind
---@param category string
---@param collapsed boolean
function DB:SetSectionCollapsed(kind, category, collapsed)
  DB.data.profile.collapsedSections[kind][category] = collapsed
end

---@param kind BagKind
---@param category string
function DB:ToggleSectionCollapsed(kind, category)
  local current = DB:GetSectionCollapsed(kind, category)
  DB:SetSectionCollapsed(kind, category, not current)
end

---@param guid string
---@param locked boolean
function DB:SetItemLock(guid, locked)
  DB.data.profile.lockedItems[guid] = locked
end

---@param guid string
---@return boolean
function DB:GetItemLock(guid)
  return DB.data.profile.lockedItems[guid]
end

---@param t number
function DB:SetNewItemTime(t)
  DB.data.profile.newItemTime = t
end

---@return number
function DB:GetNewItemTime()
  return DB.data.profile.newItemTime
end

---@param enabled boolean
function DB:SetDebugMode(enabled)
  DB.data.profile.debug = enabled
end

---@return boolean
function DB:GetDebugMode()
  return DB.data.profile.debug
end

---@param enabled boolean
function DB:SetInBagSearch(enabled)
  DB.data.profile.inBagSearch = enabled
end

---@return boolean
function DB:GetInBagSearch()
  return DB.data.profile.inBagSearch
end

---@param enabled boolean
function DB:SetCategorySell(enabled)
  DB.data.profile.categorySell = enabled
end

---@return boolean
function DB:GetCategorySell()
  return DB.data.profile.categorySell
end

function DB:GetStackingOptions(kind)
  return DB.data.profile.stacking[kind]
end

function DB:SetMergeItems(kind, value)
  DB.data.profile.stacking[kind].mergeStacks = value
end

function DB:SetMergeUnstackable(kind, value)
  DB.data.profile.stacking[kind].mergeUnstackable = value
end

function DB:SetUnmergeAtShop(kind, value)
  DB.data.profile.stacking[kind].unmergeAtShop = value
end

function DB:SetDontMergePartial(kind, value)
  DB.data.profile.stacking[kind].dontMergePartial = value
end

function DB:SetDontMergeTransmog(kind, value)
  DB.data.profile.stacking[kind].dontMergeTransmog = value
end

function DB:GetShowKeybindWarning()
  return DB.data.profile.showKeybindWarning
end

function DB:SetShowKeybindWarning(value)
  DB.data.profile.showKeybindWarning = value
end

---@param kind BagKind
---@return boolean
function DB:GetShowFullSectionNames(kind)
  return DB.data.profile.showFullSectionNames[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetShowFullSectionNames(kind, value)
  DB.data.profile.showFullSectionNames[kind] = value
end

---@param key string
function DB:SetTheme(key)
  DB.data.profile.theme = key
end

---@return string
function DB:GetTheme()
  return DB.data.profile.theme
end

---@return string
function DB:GetUpgradeIconProvider()
  return DB.data.profile.upgradeIconProvider
end

---@param value string
function DB:SetUpgradeIconProvider(value)
  DB.data.profile.upgradeIconProvider = value
end

---@param kind BagKind
---@return boolean
function DB:GetShowAllFreeSpace(kind)
  return DB.data.profile.showAllFreeSpace[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetShowAllFreeSpace(kind, value)
  DB.data.profile.showAllFreeSpace[kind] = value
end

-- Export settings to a base64-encoded string
---@return string
function DB:ExportSettings()
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  -- Create a table with all exportable settings
  local exportData = {
    version = 1, -- Version number for future compatibility
    customCategoryFilters = serialization:DeepCopy(DB.data.profile.customCategoryFilters),
    customCategoryIndex = serialization:DeepCopy(DB.data.profile.customCategoryIndex),
    ephemeralCategoryFilters = serialization:DeepCopy(DB.data.profile.ephemeralCategoryFilters),
    categoryOptions = serialization:DeepCopy(DB.data.profile.categoryOptions),
    categoryFilters = serialization:DeepCopy(DB.data.profile.categoryFilters),
    customSectionSort = serialization:DeepCopy(DB.data.profile.customSectionSort),
    size = serialization:DeepCopy(DB.data.profile.size),
    itemSort = serialization:DeepCopy(DB.data.profile.sectionSort),
    sectionSort = serialization:DeepCopy(DB.data.profile.itemSort),
    stacking = serialization:DeepCopy(DB.data.profile.stacking),
    itemLevel = serialization:DeepCopy(DB.data.profile.itemLevel),
    theme = DB.data.profile.theme,
    upgradeIconProvider = DB.data.profile.upgradeIconProvider,
    inBagSearch = DB.data.profile.inBagSearch,
    categorySell = DB.data.profile.categorySell,
    enterToMakeCategory = DB.data.profile.enterToMakeCategory,
    showBagButton = DB.data.profile.showBagButton,
    enableBankBag = DB.data.profile.enableBankBag,
    showFullSectionNames = serialization:DeepCopy(DB.data.profile.showFullSectionNames),
    showAllFreeSpace = serialization:DeepCopy(DB.data.profile.showAllFreeSpace),
    extraGlowyButtons = serialization:DeepCopy(DB.data.profile.extraGlowyButtons),
    newItems = serialization:DeepCopy(DB.data.profile.newItems),
    newItemTime = DB.data.profile.newItemTime,
  }

  -- Serialize the table
  local serialized = serialization:Serialize(exportData)

  -- Encode to base64
  local encoded = serialization:EncodeBase64(serialized)

  return encoded
end

-- Import settings from a base64-encoded string
---@param dataString string
---@return boolean, string
function DB:ImportSettings(dataString)
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  if not dataString or dataString == "" then
    return false, "Import data is empty"
  end

  -- Remove whitespace
  dataString = dataString:gsub("%s+", "")

  -- Decode from base64
  local decoded = serialization:DecodeBase64(dataString)
  if not decoded then
    return false, "Failed to decode import data"
  end

  -- Deserialize the table
  local importData, err = serialization:Deserialize(decoded)
  if not importData then
    return false, "Failed to parse import data: " .. (err or "unknown error")
  end

  -- Validate version
  if not importData.version or type(importData.version) ~= "number" then
    return false, "Invalid import data format"
  end

  -- Apply the imported settings
  if importData.customCategoryFilters then
    DB.data.profile.customCategoryFilters = serialization:DeepCopy(importData.customCategoryFilters)
  end

  if importData.customCategoryIndex then
    DB.data.profile.customCategoryIndex = serialization:DeepCopy(importData.customCategoryIndex)
  end

  if importData.ephemeralCategoryFilters then
    DB.data.profile.ephemeralCategoryFilters = serialization:DeepCopy(importData.ephemeralCategoryFilters)
  end

  if importData.categoryOptions then
    DB.data.profile.categoryOptions = serialization:DeepCopy(importData.categoryOptions)
  end

  if importData.categoryFilters then
    DB.data.profile.categoryFilters = serialization:DeepCopy(importData.categoryFilters)
  end

  if importData.customSectionSort then
    DB.data.profile.customSectionSort = serialization:DeepCopy(importData.customSectionSort)
  end

  if importData.size then
    DB.data.profile.size = serialization:DeepCopy(importData.size)
  end

  if importData.itemSort then
    DB.data.profile.sectionSort = serialization:DeepCopy(importData.itemSort)
  end

  if importData.sectionSort then
    DB.data.profile.itemSort = serialization:DeepCopy(importData.sectionSort)
  end

  if importData.stacking then
    DB.data.profile.stacking = serialization:DeepCopy(importData.stacking)
  end

  if importData.itemLevel then
    DB.data.profile.itemLevel = serialization:DeepCopy(importData.itemLevel)
  end

  if importData.theme then
    DB.data.profile.theme = importData.theme
  end

  if importData.upgradeIconProvider then
    DB.data.profile.upgradeIconProvider = importData.upgradeIconProvider
  end

  if importData.inBagSearch ~= nil then
    DB.data.profile.inBagSearch = importData.inBagSearch
  end

  if importData.categorySell ~= nil then
    DB.data.profile.categorySell = importData.categorySell
  end

  if importData.enterToMakeCategory ~= nil then
    DB.data.profile.enterToMakeCategory = importData.enterToMakeCategory
  end

  if importData.showBagButton ~= nil then
    DB.data.profile.showBagButton = importData.showBagButton
  end

  if importData.enableBankBag ~= nil then
    DB.data.profile.enableBankBag = importData.enableBankBag
  end

  if importData.showFullSectionNames then
    DB.data.profile.showFullSectionNames = serialization:DeepCopy(importData.showFullSectionNames)
  end

  if importData.showAllFreeSpace then
    DB.data.profile.showAllFreeSpace = serialization:DeepCopy(importData.showAllFreeSpace)
  end

  if importData.extraGlowyButtons then
    DB.data.profile.extraGlowyButtons = serialization:DeepCopy(importData.extraGlowyButtons)
  end

  if importData.newItems then
    DB.data.profile.newItems = serialization:DeepCopy(importData.newItems)
  end

  if importData.newItemTime then
    DB.data.profile.newItemTime = importData.newItemTime
  end

  return true, "Settings imported successfully"
end

function DB:Migrate()

  --[[
    Deletion of the old lockedItems table.
    Do not remove before Q1'25.
  ]]--
  DB.data.profile.lockedItems = {}

  --[[
    Migration away from multi-view bags and bank to a single view.
    Do not remove before Q1'25.
  ]]--
  if DB:GetBagView(const.BAG_KIND.BACKPACK) ~= const.BAG_VIEW.SECTION_GRID and DB:GetBagView(const.BAG_KIND.BACKPACK) ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    DB:SetBagView(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID)
  end

  if DB:GetBagView(const.BAG_KIND.BANK) ~= const.BAG_VIEW.SECTION_GRID and DB:GetBagView(const.BAG_KIND.BANK) ~= const.BAG_VIEW.SECTION_ALL_BAGS then
    DB:SetBagView(const.BAG_KIND.BANK, const.BAG_VIEW.SECTION_GRID)
  end

  --[[
    Migration of the custom category filters from single filter to per-bag filter.
    Do not remove before Q4'24.
  ]]
  for name, _ in pairs(DB.data.profile.customCategoryFilters) do
    if type(DB.data.profile.customCategoryFilters[name].enabled) == "boolean" then
      local value = DB.data.profile.customCategoryFilters[name].enabled --[[@as boolean]]
      DB.data.profile.customCategoryFilters[name].enabled = {
        [const.BAG_KIND.BACKPACK] = value,
        [const.BAG_KIND.BANK] = value
      }
    end
  end

  -- Fix the column count and items per row values from a previous bug.
  -- Do not remove before Q1'25.
  for _, bagView in pairs(const.BAG_VIEW) do
    for _, bagKind in pairs(const.BAG_KIND) do
      if DB.data.profile.size[bagView] then
        local t = DB.data.profile.size[bagView][bagKind]
        if t then
          if t.itemsPerRow ~= nil and t.itemsPerRow > 30 or t.itemsPerRow < 1 then
            t.itemsPerRow = 7
          end
        end
      end
    end
  end

  -- Removal of bags for bank in retail, do not remove before Q3 '26

  if addon.isRetail then
    DB.data.profile.views[const.BAG_KIND.BANK] = const.BAG_VIEW.SECTION_GRID
  end
end

DB:Enable()
