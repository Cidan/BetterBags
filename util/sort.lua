local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Sort: AceModule
local sort = addon:NewModule('Sort')

---@param aData ItemData
---@param bData ItemData
---@return boolean
local function invalidData(aData, bData)
  if not aData or not bData
  or not aData.itemInfo or not bData.itemInfo
  or not aData.itemInfo.itemQuality or not bData.itemInfo.itemQuality
  or not aData.itemInfo.currentItemLevel or not bData.itemInfo.currentItemLevel
  or not aData.itemInfo.currentItemCount or not bData.itemInfo.currentItemCount
  or not aData.itemInfo.itemGUID or not bData.itemInfo.itemGUID
  or not aData.itemInfo.itemName or not bData.itemInfo.itemName then
    return true
  end
  return false
end

---@param kind BagKind
---@param view BagView
---@return function
function sort:GetSectionSortFunction(kind, view)
  local sortType = database:GetSectionSortType(kind, view)
  if sortType == const.SECTION_SORT_TYPE.ALPHABETICALLY then
    return self.SortSectionsAlphabetically
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_ASCENDING then
    return self.SortSectionsBySizeAscending
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_DESCENDING then
    return self.SortSectionsBySizeDescending
  end
  assert(false, "Unknown sort type: " .. sortType)
  return function() end
end

---@param kind BagKind
---@param view BagView
---@return function
function sort:GetItemSortFunction(kind, view)
  if kind == const.BAG_KIND.UNDEFINED then
    return function() return false end
  end
  local sortType = database:GetItemSortType(kind, view)
  if sortType == const.ITEM_SORT_TYPE.ALPHABETICALLY_THEN_QUALITY then
    return self.SortItemsByAlphaThenQuality
  elseif sortType == const.ITEM_SORT_TYPE.QUALITY_THEN_ALPHABETICALLY then
    return self.SortItemsByQualityThenAlpha
  end
  assert(false, "Unknown sort type: " .. sortType)
  return function() end
end

---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsAlphabetically(a, b)
  return a.title:GetText() < b.title:GetText()
end

---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeDescending(a, b)
  local aSize, bSize = a:GetCellCount(), b:GetCellCount()
  if aSize ~= bSize then
    return aSize > bSize
  end
  return a.title:GetText() < b.title:GetText()
end

---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeAscending(a, b)
  local aSize, bSize = a:GetCellCount(), b:GetCellCount()
  if aSize ~= bSize then
    return aSize < bSize
  end
  return a.title:GetText() < b.title:GetText()
end

---@param a Item
---@param b Item
---@return boolean
function sort.SortItemsByQualityThenAlpha(a, b)
  if invalidData(a.data, b.data) then return false end
  if a.data.itemInfo.itemQuality ~= b.data.itemInfo.itemQuality then
    return a.data.itemInfo.itemQuality > b.data.itemInfo.itemQuality
  elseif a.data.itemInfo.currentItemLevel ~= b.data.itemInfo.currentItemLevel then
    return a.data.itemInfo.currentItemLevel > b.data.itemInfo.currentItemLevel
  elseif a.data.itemInfo.itemName ~= b.data.itemInfo.itemName then
    return a.data.itemInfo.itemName < b.data.itemInfo.itemName
  elseif a.data.itemInfo.currentItemCount ~= b.data.itemInfo.currentItemCount then
    return a.data.itemInfo.currentItemCount > b.data.itemInfo.currentItemCount
  end
  return a.data.itemInfo.itemGUID < b.data.itemInfo.itemGUID
end

---@param a Item
---@param b Item
---@return boolean
function sort.SortItemsByAlphaThenQuality(a, b)
  if invalidData(a.data, b.data) then return false end
  if a.data.itemInfo.itemName ~= b.data.itemInfo.itemName then
    return a.data.itemInfo.itemName < b.data.itemInfo.itemName
  elseif a.data.itemInfo.itemQuality ~= b.data.itemInfo.itemQuality then
    return a.data.itemInfo.itemQuality > b.data.itemInfo.itemQuality
  elseif a.data.itemInfo.currentItemLevel ~= b.data.itemInfo.currentItemLevel then
    return a.data.itemInfo.currentItemLevel > b.data.itemInfo.currentItemLevel
  elseif a.data.itemInfo.currentItemCount ~= b.data.itemInfo.currentItemCount then
    return a.data.itemInfo.currentItemCount > b.data.itemInfo.currentItemCount
  end
  return a.data.itemInfo.itemGUID < b.data.itemInfo.itemGUID
end