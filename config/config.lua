local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Config: AceModule
local config = addon:NewModule('Config')

---@param info table
---@return any, string, string
function config:ResolvePath(info)
  ---@type string|tablelib
  local path = info[#info]

  local db = DB:GetData().profile
  if type(path) == "string" then
		return db, path, path
	elseif type(path) == "table" then
		local n = #path
		for i = 1, n-1 do
      ---@type table
			db = db[path[i]]
		end
		return db, path[n], strjoin('.', unpack(path))
	else
    error("Invalid config option table -- this is a bug, please report it to github.com/Cidan/BetterBags", 2)
  end
end

function config:Get(k)
  local db, key = config:ResolvePath(k)
  return db[key]
end

function config:GetGeneralOptions()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("General"),
    handler = config,
    get = 'Get',
    args = {
      showBagButton = {
        type = "toggle",
        name = L:G("Show Blizzard Bag Button"),
        desc = L:G("Show or hide the default Blizzard bag button."),
        set = function(_, value)
          local sneakyFrame = _G["BetterBagsSneakyFrame"] ---@type Frame
          if value then
            BagsBar:SetParent(UIParent)
          else
            BagsBar:SetParent(sneakyFrame)
          end
          DB:SetShowBagButton(value)
        end,
      },
    }
  }
  return options
end

function config:OnEnable()
  LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, self:GetGeneralOptions())
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)

  LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName .. "/Bags", self:GetBagOptions())
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName .. "/Bags", L:G("Bags"), addonName)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bb", function()
    Settings.OpenToCategory(addonName)
  end)
end