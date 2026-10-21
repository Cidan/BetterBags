local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Database: AceModule
local db = addon:GetModule('Database')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class Events: AceModule
local events = addon:GetModule('Events')

-- Config opens BetterBags' one settings window (next/settings/window.lua, next-settings.md §7), the same
-- for the classic bags and BetterBags Next, and keeps the slash commands. The classic settings window
-- it built before is gone; plugins still register through it (Config:AddPluginConfig, plugin.lua).
---@class Config: AceModule
local config = addon:NewModule('Config')

-- Open opens the settings window, which shows the settings of the bags in use.
---@diagnostic disable-next-line: duplicate-set-field
function config:Open()
  addon:GetModule('NextSettings'):Open()
end

function config:RegisterSettings()
  -- /bb opens the settings; /bb changelog opens the changelog (frames/changelog.lua); /bb next
  -- switches the bags between the classic design and BetterBags Next (next.md §11).
  LibStub('AceConsole-3.0'):RegisterChatCommand("bb", function(input)
    local command = strtrim(input or ""):lower()
    if command == "changelog" then
      events:SendMessage(context:New('SlashChangelog'), 'changelog/Open')
      return
    end
    if command == "next" then
      addon:GetModule('BagSystem'):Switch(context:New('SlashNext'), db:GetNextEnabled() and "classic" or "next")
      return
    end
    self:Open()
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbanchor", function()
    -- A BetterBags Next bag has no anchor.
    if addon.Bags.Backpack.anchor then
      addon.Bags.Backpack.anchor:Activate()
      addon.Bags.Backpack.anchor:Show()
    end
    if addon.Bags.Bank and addon.Bags.Bank.anchor then
      addon.Bags.Bank.anchor:Activate()
      addon.Bags.Bank.anchor:Show()
    end
  end)

  events:RegisterMessage('config/Open', function()
    self:Open()
  end)

  -- The search box's Enter to Make Category: the Categories page asks for the new category's name, its
  -- rule the search (next-settings.md §5).
  events:RegisterMessage('config/NewCategoryFromSearch', function(_, query)
    addon:GetModule('NextSettingsCategories'):NewFromSearch(query)
    addon:GetModule('NextSettings'):Open("categories")
  end)

  -- The bags switched design (next.md §11), from the settings or elsewhere: the window, if open, shows
  -- the new design's settings and stays open (next-settings.md §7).
  events:RegisterMessage('bags/DesignChanged', function(ctx)
    addon:GetModule('NextSettings'):OnDesignChanged(ctx)
  end)

  LibStub('AceConsole-3.0'):RegisterChatCommand("bbdb", function()
    db:SetDebugMode(not db:GetDebugMode())
    local ctx = context:New('on_click')
    events:SendMessage(ctx, 'config/DebugMode', db:GetDebugMode())
  end)
end

function config:OnEnable()
  self:RegisterSettings()
end
