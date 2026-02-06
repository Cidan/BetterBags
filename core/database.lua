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

---@param enabled boolean
function DB:SetEnableBagFading(enabled)
  DB.data.profile.enableBagFading = enabled
end

---@return boolean
function DB:GetEnableBagFading()
  return DB.data.profile.enableBagFading
end

---@param kind BagKind
---@return boolean
function DB:GetGroupsEnabled(kind)
  if DB.data.profile.groupsEnabled == nil then
    return true
  end
  if DB.data.profile.groupsEnabled[kind] == nil then
    return true
  end
  return DB.data.profile.groupsEnabled[kind]
end

---@param kind BagKind
---@param value boolean
function DB:SetGroupsEnabled(kind, value)
  if DB.data.profile.groupsEnabled == nil then
    DB.data.profile.groupsEnabled = {}
  end
  DB.data.profile.groupsEnabled[kind] = value
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
  if previousCategory and previousCategory ~= category and DB.data.profile.customCategoryFilters[previousCategory] then
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

-------
--- Groups Feature
-------

---@return table<number, Group>
function DB:GetAllGroups()
  return DB.data.profile.groups
end

---@param groupID number
---@return Group?
function DB:GetGroup(groupID)
  return DB.data.profile.groups[groupID]
end

---@param name string
---@return number The new group ID
function DB:CreateGroup(name)
  local newID = DB.data.profile.groupCounter + 1
  DB.data.profile.groupCounter = newID
  DB.data.profile.groups[newID] = {
    id = newID,
    name = name,
    order = newID,
  }
  return newID
end

---@param groupID number
function DB:DeleteGroup(groupID)
  -- Don't allow deleting the default Backpack group (ID 1)
  if groupID == 1 then return end

  -- Remove category associations for this group
  for categoryName, gID in pairs(DB.data.profile.categoryToGroup) do
    if gID == groupID then
      DB.data.profile.categoryToGroup[categoryName] = nil
    end
  end

  -- Remove the group
  DB.data.profile.groups[groupID] = nil

  -- If this was the active group, switch to Backpack (ID 1)
  if DB.data.profile.activeGroup[const.BAG_KIND.BACKPACK] == groupID then
    DB.data.profile.activeGroup[const.BAG_KIND.BACKPACK] = 1
  end
end

---@param groupID number
---@param name string
function DB:RenameGroup(groupID, name)
  if DB.data.profile.groups[groupID] then
    DB.data.profile.groups[groupID].name = name
  end
end

-- RenameCategory renames a category by updating all data structures that use the category name as a key.
---@param oldName string
---@param newName string
---@return boolean success
function DB:RenameCategory(oldName, newName)
  -- Trim whitespace and validate new name
  newName = strtrim(newName)
  if newName == "" then
    return false
  end

  -- Validate old category exists and new name doesn't conflict
  if not DB.data.profile.customCategoryFilters[oldName] then
    return false
  end
  if DB.data.profile.customCategoryFilters[newName] then
    return false
  end

  -- 1. Move main category data structure
  DB.data.profile.customCategoryFilters[newName] = DB.data.profile.customCategoryFilters[oldName]
  DB.data.profile.customCategoryFilters[newName].name = newName
  DB.data.profile.customCategoryFilters[oldName] = nil

  -- 2. Update item index for all items pointing to old category
  for itemID, categoryName in pairs(DB.data.profile.customCategoryIndex) do
    if categoryName == oldName then
      DB.data.profile.customCategoryIndex[itemID] = newName
    end
  end

  -- 3. Update group mapping
  if DB.data.profile.categoryToGroup[oldName] then
    DB.data.profile.categoryToGroup[newName] = DB.data.profile.categoryToGroup[oldName]
    DB.data.profile.categoryToGroup[oldName] = nil
  end

  -- 4. Update ephemeral filters
  if DB.data.profile.ephemeralCategoryFilters[oldName] then
    DB.data.profile.ephemeralCategoryFilters[newName] = DB.data.profile.ephemeralCategoryFilters[oldName]
    DB.data.profile.ephemeralCategoryFilters[oldName] = nil
  end

  -- Delete grouped sub-categories from ephemeral filters (e.g., "OldName - Consumable")
  -- These will be recreated with the new name on next refresh
  local groupedPrefix = oldName .. " - "
  for categoryName, _ in pairs(DB.data.profile.ephemeralCategoryFilters) do
    if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
      DB.data.profile.ephemeralCategoryFilters[categoryName] = nil
    end
  end

  -- 5. Update display options
  if DB.data.profile.categoryOptions[oldName] then
    DB.data.profile.categoryOptions[newName] = DB.data.profile.categoryOptions[oldName]
    DB.data.profile.categoryOptions[oldName] = nil
  end

  -- Delete grouped sub-categories from display options
  for categoryName, _ in pairs(DB.data.profile.categoryOptions) do
    if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
      DB.data.profile.categoryOptions[categoryName] = nil
    end
  end

  -- 6. Update collapse state for all bag kinds
  for _, kind in pairs(const.BAG_KIND) do
    if DB.data.profile.collapsedSections[kind] and DB.data.profile.collapsedSections[kind][oldName] ~= nil then
      DB.data.profile.collapsedSections[kind][newName] = DB.data.profile.collapsedSections[kind][oldName]
      DB.data.profile.collapsedSections[kind][oldName] = nil
    end

    -- Delete grouped sub-categories from collapsed sections
    if DB.data.profile.collapsedSections[kind] then
      for categoryName, _ in pairs(DB.data.profile.collapsedSections[kind]) do
        if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
          DB.data.profile.collapsedSections[kind][categoryName] = nil
        end
      end
    end
  end

  -- 7. Update custom section sort (pinned position) for all bag kinds
  for _, kind in pairs(const.BAG_KIND) do
    if DB.data.profile.customSectionSort[kind] and DB.data.profile.customSectionSort[kind][oldName] ~= nil then
      DB.data.profile.customSectionSort[kind][newName] = DB.data.profile.customSectionSort[kind][oldName]
      DB.data.profile.customSectionSort[kind][oldName] = nil
    end

    -- Delete grouped sub-categories from custom section sort
    if DB.data.profile.customSectionSort[kind] then
      for categoryName, _ in pairs(DB.data.profile.customSectionSort[kind]) do
        if categoryName:sub(1, #groupedPrefix) == groupedPrefix then
          DB.data.profile.customSectionSort[kind][categoryName] = nil
        end
      end
    end
  end

  return true
end

---@return number
function DB:GetNextGroupID()
  return DB.data.profile.groupCounter + 1
end

---@param categoryName string
---@return number? The group ID, or nil if not assigned (belongs to Backpack)
function DB:GetCategoryGroup(categoryName)
  return DB.data.profile.categoryToGroup[categoryName]
end

---@param categoryName string
---@param groupID number
function DB:SetCategoryGroup(categoryName, groupID)
  DB.data.profile.categoryToGroup[categoryName] = groupID
end

---@param categoryName string
function DB:RemoveCategoryFromGroup(categoryName)
  DB.data.profile.categoryToGroup[categoryName] = nil
end

---@param groupID number
---@return table<string, boolean> Category names in this group
function DB:GetGroupCategories(groupID)
  local categories = {}
  for categoryName, gID in pairs(DB.data.profile.categoryToGroup) do
    if gID == groupID then
      categories[categoryName] = true
    end
  end
  return categories
end

---@param kind BagKind
---@return number The active group ID (defaults to 1 for Backpack)
function DB:GetActiveGroup(kind)
  return DB.data.profile.activeGroup[kind] or 1
end

---@param kind BagKind
---@param groupID number
function DB:SetActiveGroup(kind, groupID)
  DB.data.profile.activeGroup[kind] = groupID
end

---@param groupID number
---@param order number
function DB:SetGroupOrder(groupID, order)
  local group = DB.data.profile.groups[groupID]
  if group then
    group.order = order
  end
end

---@param groupID number
---@return number
function DB:GetGroupOrder(groupID)
  local group = DB.data.profile.groups[groupID]
  return group and group.order or groupID  -- Default to ID if order not set
end

-- Export category configuration to a base64-encoded string
---@return string
function DB:ExportSettings()
  ---@class Serialization: AceModule
  local serialization = addon:GetModule('Serialization')

  -- Create a table with only category configuration settings
  local exportData = {
    version = 1, -- Version number for future compatibility
    customCategoryFilters = serialization:DeepCopy(DB.data.profile.customCategoryFilters),
    customCategoryIndex = serialization:DeepCopy(DB.data.profile.customCategoryIndex),
    ephemeralCategoryFilters = serialization:DeepCopy(DB.data.profile.ephemeralCategoryFilters),
    categoryOptions = serialization:DeepCopy(DB.data.profile.categoryOptions),
    categoryFilters = serialization:DeepCopy(DB.data.profile.categoryFilters),
    customSectionSort = serialization:DeepCopy(DB.data.profile.customSectionSort),
  }

  -- Serialize the table
  local serialized = serialization:Serialize(exportData)

  -- Encode to base64
  local encoded = serialization:EncodeBase64(serialized)

  -- Add BetterBags prefix for identification
  return "!BB" .. encoded
end

-- Import category configuration from a base64-encoded string
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

  -- Validate and strip BetterBags prefix
  if not dataString:match("^!BB") then
    return false, "Invalid import string: Missing !BB prefix. Please make sure you copied the full export string."
  end
  dataString = dataString:sub(4) -- Remove "!BB" prefix

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

  -- Apply the imported category configuration
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

  return true, "Category configuration imported successfully"
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

  --[[
    Clear all collapsed section states since the collapse feature has been disabled.
    Do not remove before Q1'27.
  ]]--
  DB.data.profile.collapsedSections = {
    [const.BAG_KIND.BACKPACK] = {},
    [const.BAG_KIND.BANK] = {},
  }

  -- ============================================================
  -- Profile System Migration (Q1'26)
  -- Do not remove before Q3'26
  -- ============================================================
  if not DB.data.profile.__profileSystemMigrated then
    -- Detect current profile name
    local currentProfile = DB.data:GetCurrentProfile()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local autoProfile = playerName .. " - " .. realmName

    -- If using auto-generated character name profile, migrate to Default
    if currentProfile == autoProfile then
      local profiles = {}
      DB.data:GetProfiles(profiles)

      local hasDefault = false
      for _, name in ipairs(profiles) do
        if name == "Default" then
          hasDefault = true
          break
        end
      end

      if not hasDefault then
        -- Create Default and copy current settings
        DB.data:SetProfile("Default")
        DB.data:CopyProfile(autoProfile)
      else
        -- Switch to existing Default
        DB.data:SetProfile("Default")
      end
    end

    -- Mark migration complete
    DB.data.profile.__profileSystemMigrated = true
  end
end

-- ============================================================
-- Profile Management
-- ============================================================

--- Get the name of the currently active profile
---@return string
function DB:GetCurrentProfileName()
  return DB.data:GetCurrentProfile()
end

--- Get list of all available profiles
---@return table<number, string>
function DB:GetAvailableProfiles()
  local profiles = {}
  DB.data:GetProfiles(profiles)
  return profiles
end

--- Get how many characters are using each profile
---@return table<string, number>
function DB:GetProfileCharacterCounts()
  local counts = {}

  -- Initialize all profiles with 0 count
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, profileName in ipairs(profiles) do
    counts[profileName] = 0
  end

  -- Count characters per profile from profileKeys
  if DB.data.sv.profileKeys then
    for _, profileName in pairs(DB.data.sv.profileKeys) do
      counts[profileName] = (counts[profileName] or 0) + 1
    end
  end

  return counts
end

--- Switch to a different profile (creates if doesn't exist)
---@param name string
---@return boolean success
function DB:SwitchToProfile(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  DB.data:SetProfile(name)
  return true
end

--- Create a new profile with the given name
---@param name string
---@return boolean success
---@return string message
function DB:CreateProfile(name)
  if type(name) ~= "string" or name == "" then
    return false, "Profile name cannot be empty"
  end

  -- Check if profile already exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, existingName in ipairs(profiles) do
    if existingName == name then
      return false, "A profile with this name already exists"
    end
  end

  -- SetProfile creates new profile if doesn't exist
  DB.data:SetProfile(name)
  return true, "Profile created successfully"
end

--- Copy data from another profile to the current profile
---@param sourceName string
---@return boolean success
---@return string message
function DB:CopyFromProfile(sourceName)
  if type(sourceName) ~= "string" or sourceName == "" then
    return false, "Source profile name cannot be empty"
  end

  -- Verify source profile exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  local found = false
  for _, existingName in ipairs(profiles) do
    if existingName == sourceName then
      found = true
      break
    end
  end

  if not found then
    return false, "Source profile does not exist"
  end

  -- Copy from source to current profile
  DB.data:CopyProfile(sourceName)
  return true, "Profile copied successfully"
end

--- Rename the current profile
---@param oldName string
---@param newName string
---@return boolean success
---@return string message
function DB:RenameProfile(oldName, newName)
  if oldName == "Default" then
    return false, "Cannot rename the Default profile"
  end

  if type(newName) ~= "string" or newName == "" then
    return false, "Profile name cannot be empty"
  end

  -- Check if new name already exists
  local profiles = {}
  DB.data:GetProfiles(profiles)
  for _, existingName in ipairs(profiles) do
    if existingName == newName then
      return false, "A profile with this name already exists"
    end
  end

  -- Switch to old profile, copy to new name, delete old
  DB.data:SetProfile(oldName)
  DB.data:SetProfile(newName)
  DB.data:CopyProfile(oldName)

  -- Delete old profile
  DB.data:DeleteProfile(oldName, true)

  return true, "Profile renamed successfully"
end

--- Delete a profile (cannot delete Default or active profile)
---@param name string
---@return boolean success
---@return string message
function DB:DeleteProfile(name)
  if name == "Default" then
    return false, "Cannot delete the Default profile"
  end

  local currentProfile = DB.data:GetCurrentProfile()
  if currentProfile == name then
    return false, "Cannot delete the active profile. Switch to another profile first."
  end

  DB.data:DeleteProfile(name, true)
  return true, "Profile deleted successfully"
end

--- Reset the current profile to default settings
---@return boolean success
---@return string message
function DB:ResetCurrentProfile()
  DB.data:ResetProfile(false, true)
  return true, "Profile reset to defaults"
end

DB:Enable()
