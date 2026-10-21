-- plugin_spec.lua -- Config:AddPluginConfig (config/plugin.lua): the plugin API. A plugin's AceConfig
-- options become its page of the settings window (NextSettingsContent:AddPlugin, next-settings.md §4);
-- the classic settings window that also took them is gone (§7).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local config = StubBetterBagsModule("Config")
local content = StubBetterBagsModule("NextSettingsContent")
LoadBetterBagsModule("config/plugin.lua")

describe("Config:AddPluginConfig", function()
  local added, savedAdd, savedEnable, enabled

  before_each(function()
    added, enabled = {}, 0
    savedAdd, savedEnable = content.AddPlugin, config.OnEnable
    content.AddPlugin = function(_, title, options) table.insert(added, { title, options }) end
    config.OnEnable = function() enabled = enabled + 1 end
  end)

  after_each(function()
    content.AddPlugin, config.OnEnable = savedAdd, savedEnable
  end)

  it("gives the plugin its page of the settings window, and builds nothing else", function()
    local options = { on = { type = "toggle", name = "On", get = function() return true end, set = function() end } }
    config:AddPluginConfig("Some Plugin", options)
    assert.are.same({ { "Some Plugin", options } }, added)
    assert.are.equal(0, enabled, "no classic window to build first")
    assert.is_nil(config.configFrame)
  end)

  it("is in the addon's modules", function()
    assert.are.equal(config, addon:GetModule("Config"))
  end)
end)
