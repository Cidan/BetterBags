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

---@param kind BagKind
function DB:GetBagPosition(kind)
  return DB.data.profile.positions[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
end

---@param kind BagKind
---@return BagView
function DB:GetBagView(kind)
  return DB.data.profile.views[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
end

---@param kind BagKind
---@param view BagView
function DB:SetBagView(kind, view)
  DB.data.profile.views[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'] = view
end

function DB:GetCategoryFilter(kind, filter)
  return DB.data.profile.categoryFilters[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'][filter]
end

function DB:SetCategoryFilter(kind, filter, value)
  DB.data.profile.categoryFilters[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'][filter] = value
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
function DB:GetBagSizeInfo(kind)
  return DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
end

---@param kind BagKind
---@param count number
function DB:SetBagSizeColumn(kind, count)
  DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'].columnCount = count
end

---@param kind BagKind
---@param count number
function DB:SetBagSizeItems(kind, count)
  DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'].itemsPerRow = count
end

---@param kind BagKind
---@return number, number
function DB:GetBagFrameSize(kind)
  local s = DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
  return s.width, s.height
end

---@param kind BagKind
---@param width number
---@param height number
function DB:SetBagFrameSize(kind, width, height)
  DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'].width = width
  DB.data.profile.size[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'].height = height
end

---@param kind BagKind
---@return GridCompactStyle
function DB:GetBagCompaction(kind)
  return DB.data.profile.compaction[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
end

---@param kind BagKind
---@param style GridCompactStyle
function DB:SetBagCompaction(kind, style)
  DB.data.profile.compaction[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank'] = style
end

DB:Enable()
