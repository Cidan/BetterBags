-- config_spec.lua -- The Config module (config/config.lua) once the classic settings window is gone
-- (next-settings.md §7): its slash commands, opening the one settings window (next/settings/window.lua)
-- for either design, and showing it the design the bags switch to.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = stubModule("Events")
local db = stubModule("Database")
local bagSystem = stubModule("BagSystem")
local nextSettings = stubModule("NextSettings")
LoadFreshBetterBagsModule("Config", "config/config.lua")
local config = addon:GetModule("Config")

describe("Config", function()
  local handlers, sent, log, saved, console

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    handlers, sent, log, saved = {}, {}, {}, {}
    console = LibStub("AceConsole-3.0")
    override(console, "RegisterChatCommand", function(_, command, fn) handlers[command] = fn end)
    override(events, "RegisterMessage", function(_, name, fn) handlers["message " .. name] = fn end)
    override(events, "SendMessage", function(_, _, message) table.insert(sent, message) end)
    override(nextSettings, "Open", function(_, page) table.insert(log, "open " .. tostring(page)) end)
    override(nextSettings, "OnDesignChanged", function(_, ctx)
      assert.is_not_nil(ctx)
      table.insert(log, "design changed")
    end)
    override(_G, "UISpecialFrames", {})
    config:OnEnable()
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("opens the one settings window for either design, on /bb and config/Open", function()
    for _, design in ipairs({ "next", "classic" }) do
      override(bagSystem, "ActiveDesign", function() return design end)
      handlers.bb("")
      handlers["message config/Open"](context:New("Test"))
    end
    assert.are.same({ "open nil", "open nil", "open nil", "open nil" }, log)
  end)

  it("builds no classic window", function()
    assert.is_nil(config.configFrame)
    assert.is_nil(config.CreateConfig)
    assert.are.same({}, UISpecialFrames)
  end)

  it("shows the settings window the design the bags switch to", function()
    handlers["message bags/DesignChanged"](context:New("Test"), "classic")
    handlers["message bags/DesignChanged"](context:New("Test"), "next")
    assert.are.same({ "design changed", "design changed" }, log)
  end)

  -- BetterBagsNext (next.md §11): /bb next switches the bags to the other design, no reload.
  it("switches the bags to the other design on /bb next, without a reload", function()
    local on = false
    override(db, "GetNextEnabled", function() return on end)
    local switched = {}
    override(bagSystem, "Switch", function(_, c, design)
      assert.is_not_nil(c)
      table.insert(switched, design)
      on = design == "next"
      return true
    end)
    handlers.bb(" Next ")
    handlers.bb("next")
    assert.are.same({ "next", "classic" }, switched)
    assert.are.same({}, log, "the settings stay closed")
  end)

  it("opens the changelog on /bb changelog, in any case and spacing", function()
    handlers.bb("changelog")
    handlers.bb("  ChangeLog ")
    assert.are.same({}, log)
    assert.are.same({ "changelog/Open", "changelog/Open" }, sent)
  end)

  -- A BetterBagsNext backpack has no anchor (next.md §1).
  it("shows the bags' anchors on /bbanchor, skipping a backpack without one", function()
    local shown = 0
    local anchor = { Activate = function() end, Show = function() shown = shown + 1 end }
    override(addon, "Bags", { Backpack = {}, Bank = { anchor = anchor } })
    handlers.bbanchor()
    assert.are.equal(1, shown)
    addon.Bags = { Backpack = { anchor = anchor }, Bank = {} }
    handlers.bbanchor()
    assert.are.equal(2, shown, "a BetterBags Next bank has no anchor either")
  end)

  it("turns debug mode on and off on /bbdb", function()
    local on = false
    override(db, "GetDebugMode", function() return on end)
    override(db, "SetDebugMode", function(_, value) on = value end)
    handlers.bbdb()
    assert.is_true(on)
    assert.are.same({ "config/DebugMode" }, sent)
  end)
end)
