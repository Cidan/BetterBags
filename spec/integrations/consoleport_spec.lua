-- consoleport_spec.lua -- the ConsolePort integration (integrations/consoleport.lua): with ConsolePort
-- loaded, its gamepad cursor can reach BetterBags' bag frames.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local events = trackStub("Events")

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end

ResetModuleStub("ConsolePort", "integrations/consoleport.lua")
LoadBetterBagsModule("integrations/consoleport.lua")
local consoleport = addon:GetModule("ConsolePort")

describe("ConsolePort integration", function()
  local added

  before_each(function()
    added = {}
    override(_G, "ConsolePort", { AddInterfaceCursorFrame = function(_, frame) table.insert(added, frame) end })
    override(events, "RegisterMessage", function() end)
    consoleport:Init()
  end)

  after_each(function()
    for i = #replaced, 1, -1 do replaced[i][1][replaced[i][2]] = replaced[i][3] end
    replaced = {}
  end)

  teardown(function()
    ResetModuleStub("ConsolePort", "integrations/consoleport.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("gives the cursor the backpack, the bank and BetterBags Next's guild bank", function()
    local backpack, bank, guild = CreateFrame("Frame"), CreateFrame("Frame"), CreateFrame("Frame")
    override(addon, "Bags", { Backpack = { frame = backpack }, Bank = { frame = bank }, GuildBank = { frame = guild } })
    consoleport:OnEnable()
    assert.are.same({ backpack, bank, guild }, added)
  end)

  it("gives it only the bags there are", function()
    local backpack = CreateFrame("Frame")
    override(addon, "Bags", { Backpack = { frame = backpack } })
    consoleport:OnEnable()
    assert.are.same({ backpack }, added)
  end)

  it("does nothing without ConsolePort", function()
    override(_G, "ConsolePort", nil)
    consoleport:Init()
    override(addon, "Bags", { Backpack = { frame = CreateFrame("Frame") } })
    consoleport:OnEnable()
    assert.are.same({}, added)
  end)
end)
