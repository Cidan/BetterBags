local addonName = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local DB = addon:NewModule('Database')
DB:Enable()

-- Set the default option values.
DB.data = {
  profile = {
    enabled = true
  },
  char = {}
}

function DB:OnInitialize()
  -- Create the settings database.
  DB.data = LibStub('AceDB-3.0'):New(addonName .. 'DB', DB.data, true)
end