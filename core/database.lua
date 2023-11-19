local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Database: AceModule
---@field data databaseOptions
local DB = addon:NewModule('Database')

-- Set the default option values.

DB:Enable()

function DB:OnInitialize()
  -- Create the settings database.
  DB.data = LibStub('AceDB-3.0'):New(addonName .. 'DB', const.DATABASE_DEFAULTS --[[@as AceDB.Schema]], true) --[[@as databaseOptions]]
end

---@param kind BagKind
function DB:GetBagPosition(kind)
  return DB.data.profile.positions[kind == const.BAG_KIND.BACKPACK and 'Backpack' or 'Bank']
end
