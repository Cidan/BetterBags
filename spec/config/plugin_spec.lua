-- plugin_spec.lua -- Config:AddPluginConfig (config/plugin.lua): the plugin API. A plugin's options become
-- rows of the classic settings window, as they always did, and a page of BetterBags Next's
-- (NextSettingsContent:AddPlugin, next-settings.md §4).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local debugModule = StubBetterBagsModule("Debug")
debugModule.Log = debugModule.Log or function() end
local config = StubBetterBagsModule("Config")
local content = StubBetterBagsModule("NextSettingsContent")
LoadBetterBagsModule("config/plugin.lua")

describe("Config:AddPluginConfig", function()
  local added, rows, savedFrame, savedAdd

  before_each(function()
    added, rows = {}, {}
    savedFrame, savedAdd = config.configFrame, content.AddPlugin
    config.configFrame = setmetatable({}, { __index = function(_, method)
      return function(_, opts) table.insert(rows, { method, opts and opts.title }) end
    end })
    content.AddPlugin = function(_, title, options) table.insert(added, { title, options }) end
  end)

  after_each(function()
    config.configFrame, content.AddPlugin = savedFrame, savedAdd
  end)

  it("adds the plugin's options to the classic window and gives it a page in BetterBags Next's", function()
    local options = { on = { type = "toggle", name = "On", get = function() return true end, set = function() end } }
    config:AddPluginConfig("Some Plugin", options)
    assert.are.same({ { "AddSubIndex", "Some Plugin" }, { "AddCheckbox", "On" } }, rows)
    assert.are.same({ { "Some Plugin", options } }, added)
  end)

  it("is in the addon's modules", function()
    assert.are.equal(config, addon:GetModule("Config"))
  end)
end)
