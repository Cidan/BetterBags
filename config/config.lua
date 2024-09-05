---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Localization: AceModule
local L = addon:GetModule('Localization')

---@class Database: AceModule
local DB = addon:GetModule('Database')

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class HelpText
---@field title string
---@field text string
---@field group string

---@class Config: AceModule
---@field frame Frame
---@field category string
---@field helpText HelpText[]
---@field private pluginOptions table<string, AceConfig.OptionsTable>
local config = addon:NewModule('Config')

---@class Events: AceModule
local events = addon:GetModule('Events')

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

---@param kind BagKind
---@return Bag
function config:GetBag(kind)
  return kind == const.BAG_KIND.BACKPACK and addon.Bags.Backpack or addon.Bags.Bank
end

---@return AceConfig.OptionsTable
function config:GetGeneralOptions()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("General"),
    order = 0,
    args = {
      inBagSearch = {
        type = "toggle",
        width = "full",
        order = 0,
        name = L:G("Enable In-Bag Search"),
        desc = L:G("If enabled, a search bar will appear at the top of your bags."),
        get = function()
          return DB:GetInBagSearch()
        end,
        set = function(_, value)
          DB:SetInBagSearch(value)
          events:SendMessage(context:New('OnClick_InBagSearch'), 'search/SetInFrame', value)
        end,
      },
      enableEnterToMakeCategory = {
        type = "toggle",
        width = "full",
        order = 1,
        name = L:G("Enable Enter to Make Category"),
        desc = L:G("If enabled, pressing Enter with a search query will open the make category menu."),
        get = function()
          return DB:GetEnterToMakeCategory()
        end,
        set = function(_, value)
          DB:SetEnterToMakeCategory(value)
        end,
      },
      categorySell = {
        type = "toggle",
        width = "full",
        order = 2,
        name = L:G("Enable Category Sell"),
        desc = L:G("If enabled, right-clicking a category header at a NPC shop will sell all its contents (limited to 10 stacks to allow buy-backs)."),
        get = function()
          return DB:GetCategorySell()
        end,
        set = function(_, value)
          DB:SetCategorySell(value)
        end,
      },
      showBagButton = {
        type = "toggle",
        width = "full",
        order = 3,
        name = L:G("Show Blizzard Bag Button"),
        desc = L:G("Show or hide the default Blizzard bag button."),
        get = DB.GetShowBagButton,
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
      upgradeIconProvider = {
        type = "select",
        width = "double",
        order = 4,
        name = L:G("Upgrade Icon Provider"),
        desc = L:G("Select the provider for the upgrade icon."),
        values = {
          ["None"] = L:G("None"),
          ["BetterBags"] = L:G("BetterBags"),
        },
        get = function()
          return DB:GetUpgradeIconProvider()
        end,
        set = function(_, value)
          DB:SetUpgradeIconProvider(value)
          local ctx = context:New('on_click')
          events:SendMessage(ctx, 'bag/RedrawIcons')
        end,
      },
      newItemTime = {
        type = "range",
        order = 5,
        name = L:G("New Item Duration"),
        desc = L:G("The time, in minutes, to consider an item a new item."),
        min = 0,
        max = 240,
        step = 1,
        bigStep = 5,
        get = function()
          return DB:GetData().profile.newItemTime / 60
        end,
        set = function(_, value)
          DB:GetData().profile.newItemTime = value * 60
        end,
      }
    }
  }
  return options
end

-- AddPluginConfig adds a plugin's configuration to the BetterBags configuration.
---@param name string
---@param opts AceConfig.OptionsTable
function config:AddPluginConfig(name, opts)
  assert(self.pluginOptions[name] == nil, "Plugin option already exists, did you call AddPluginConfig twice?")
  self.pluginOptions[name] = opts
end

---@return AceConfig.OptionsTable
function config:GetPluginsOptions()
  local options = {
    type = "group",
    name = L:G("Plugins"),
    order = 100,
    args = {
      header = {
        name = L:G("Plugins"),
        type = "group",
        inline = true,
        order = 0,
        args = {
          help = {
            type = "description",
            name = L:G("Plugin configuration options can be accessed on the left by expanding the 'Plugins' menu option."),
            order = 0,
          }
        }
      },
    },
  }

  for name, opts in pairs(self.pluginOptions) do
    options.args[name] = {
      name = name,
      type = 'group',
      args = opts,
    }
  end

  return options
end

function config:GetOptions()
  ---@type AceConfig.OptionsTable
  local options = {
    type = "group",
    name = L:G("BetterBags"),
    args = {
      general = self:GetGeneralOptions(),
      customCategories = self:GetCustomCategoryConfig(),
      backpack = self:GetBagOptions(const.BAG_KIND.BACKPACK),
      bank = self:GetBagOptions(const.BAG_KIND.BANK),
      help = self:GenerateHelp(),
      plugins = self:GetPluginsOptions(),
    }
  }
  return options
end

function config:Open()
  LibStub("AceConfigDialog-3.0"):Open(addonName)
  local ctx = context:New('on_click')
  events:SendMessage(ctx, 'config/Opened')
end

function config:OnEnable()
  self.helpText = {}
  self:CreateAllHelp()
  LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, function() return self:GetOptions() end)
  self.frame, self.category = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "BetterBags")
  LibStub("AceConfigDialog-3.0"):SetDefaultSize(addonName, 700, 800)
  LibStub('AceConsole-3.0'):RegisterChatCommand("bb", function()
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbanchor", function()
    addon.Bags.Backpack.anchor:Activate()
    addon.Bags.Backpack.anchor:Show()
    addon.Bags.Bank.anchor:Activate()
    addon.Bags.Bank.anchor:Show()
  end)

  events:RegisterMessage('categories/Changed', function()
    LibStub('AceConfigRegistry-3.0'):NotifyChange(addonName)
  end)

  events:RegisterMessage('config/Open', function()
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbdb", function()
    DB:SetDebugMode(not DB:GetDebugMode())
    local ctx = context:New('on_click')
    events:SendMessage(ctx, 'config/DebugMode', DB:GetDebugMode())
  end)
end

function config:OnInitialize()
  self.pluginOptions = {}
end