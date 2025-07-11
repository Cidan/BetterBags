

---@type BetterBags
local addon = GetBetterBags()

---@class Database: AceModule
local database = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Debug: AceModule
local debug = addon:GetModule('Debug')

---@class Categories: AceModule
local categories = addon:GetModule('Categories')

---@class Sort: AceModule
local sort = addon:NewModule('Sort')

---@class Localization: AceModule
local L =  addon:GetModule('Localization')

---@param aData ItemData
---@param bData ItemData
---@return boolean
local function invalidData(aData, bData)
  if not aData or not bData
  or not aData.itemInfo or not bData.itemInfo
  or not aData.itemInfo.itemQuality or not bData.itemInfo.itemQuality
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
    return function(a, b)
      return self.SortSectionsAlphabetically(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_ASCENDING then
    return function(a, b)
      return self.SortSectionsBySizeAscending(kind, a, b)
    end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_DESCENDING then
    return function(a, b)
      return self.SortSectionsBySizeDescending(kind, a, b)
    end
  end
  -- Return the default sort in case of an unknown sort type.
  return self:GetSectionSortFunction(kind, const.SECTION_SORT_TYPE.ALPHABETICALLY)
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
  elseif sortType == const.ITEM_SORT_TYPE.ITEM_LEVEL then
    return self.SortItemsByItemLevel
  end
  assert(false, "Unknown sort type: " .. sortType)
  return function() end
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean, boolean
function sort.SortSectionsByPriority(kind, a, b)
  _ = kind
  if not a or not b then return false, false end
  local aTitle, bTitle = a.title:GetText(), b.title:GetText()
  local aCategory, bCategory = categories:GetCategoryByName(aTitle), categories:GetCategoryByName(bTitle)
  if not aCategory and not bCategory then return false, false end
  if aCategory and not bCategory then return true, true end
  if not aCategory and bCategory then return true, false end
  if aCategory.sortOrder == -1 and bCategory.sortOrder == -1 then return false, false end
  if aCategory.sortOrder == -1 and bCategory.sortOrder ~= -1 then return true, false end
  if aCategory.sortOrder ~= -1 and bCategory.sortOrder == -1 then return true, true end

  return true, aCategory.sortOrder < bCategory.sortOrder
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsAlphabetically(kind, a, b)
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
  return a.title:GetText() < b.title:GetText()
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeDescending(kind, a, b)
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
  local aSize, bSize = a:GetCellCount(), b:GetCellCount()
  if aSize ~= bSize then
    return aSize > bSize
  end
  return a.title:GetText() < b.title:GetText()
end

---@param kind BagKind
---@param a Section
---@param b Section
---@return boolean
function sort.SortSectionsBySizeAscending(kind, a, b)
  local shouldSort, sortResult = sort.SortSectionsByPriority(kind, a, b)
  if shouldSort then return sortResult end

  if a.title:GetText() == L:G("Recent Items") then return true end
  if b.title:GetText() == L:G("Recent Items") then return false end

  if a:GetFillWidth() then return false end
  if b:GetFillWidth() then return true end

  if a.title:GetText() == L:G("Free Space") then return false end
  if b.title:GetText() == L:G("Free Space") then return true end
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
  if a.isFreeSlot then return false end
  if b.isFreeSlot then return true end
  local aData, bData = a:GetItemData(), b:GetItemData()
  if invalidData(aData, bData) then return false end
  if aData.itemInfo.itemQuality ~= bData.itemInfo.itemQuality then
    return aData.itemInfo.itemQuality > bData.itemInfo.itemQuality
  elseif aData.itemInfo.itemName ~= bData.itemInfo.itemName then
    return aData.itemInfo.itemName < bData.itemInfo.itemName
  elseif aData.itemInfo.currentItemCount ~= bData.itemInfo.currentItemCount then
    return aData.itemInfo.currentItemCount > bData.itemInfo.currentItemCount
  end
  return aData.itemInfo.itemGUID < bData.itemInfo.itemGUID
end

---@param a Item
---@param b Item
---@return boolean
function sort.SortItemsByAlphaThenQuality(a, b)
  if a.isFreeSlot then return false end
  if b.isFreeSlot then return true end
  local aData, bData = a:GetItemData(), b:GetItemData()
  if invalidData(aData, bData) then return false end
  if aData.itemInfo.itemName ~= bData.itemInfo.itemName then
    return aData.itemInfo.itemName < bData.itemInfo.itemName
  elseif aData.itemInfo.itemQuality ~= bData.itemInfo.itemQuality then
    return aData.itemInfo.itemQuality > bData.itemInfo.itemQuality
  elseif aData.itemInfo.currentItemCount ~= bData.itemInfo.currentItemCount then
    return aData.itemInfo.currentItemCount > bData.itemInfo.currentItemCount
  end
  return aData.itemInfo.itemGUID < bData.itemInfo.itemGUID
end

---@param a Item
---@param b Item
---@return boolean
function sort.SortItemsByItemLevel(a, b)
  if a.isFreeSlot then return false end
  if b.isFreeSlot then return true end
  local aData, bData = a:GetItemData(), b:GetItemData()
  if invalidData(aData, bData) then return false end
  if aData.itemInfo.currentItemLevel ~= bData.itemInfo.currentItemLevel then
    return aData.itemInfo.currentItemLevel > bData.itemInfo.currentItemLevel
  elseif aData.itemInfo.itemName ~= bData.itemInfo.itemName then
    return aData.itemInfo.itemName < bData.itemInfo.itemName
  elseif aData.itemInfo.currentItemCount ~= bData.itemInfo.currentItemCount then
    return aData.itemInfo.currentItemCount > bData.itemInfo.currentItemCount
  end
  return aData.itemInfo.itemGUID < bData.itemInfo.itemGUID
end
---@param a Item
---@param b Item
---@return boolean
function sort.GetItemSortBySlot(a, b)
  local aData, bData = a:GetItemData(), b:GetItemData()
  if not aData then return false end
  if not bData then return true end
  return aData.slotid < bData.slotid
end