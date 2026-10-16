-- measured_blizzard_calls_spec.lua -- Blizzard calls the profiler must be able to measure.
--
-- The profiler measures functions on modules, registered prototypes and the root addon,
-- never a Blizzard call made inline (perf-profiler.md §2). A capture of switching bank tabs
-- showed 12.6-15 ms of unmeasured time inside every Bank.SwitchToGroup, the same with zero
-- or 529 buttons reacting, and its only unmeasured calls were BankPanel:SetBankType and
-- ItemButtonUtil.TriggerEvent(ItemContextChanged). Both go through root-addon functions in
-- core/hooks.lua, so a capture shows which one costs the time (data-driven.md).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("Blizzard calls the profiler measures", function()
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = { "Debug", "Events", "Context", "Constants" }
  local oldModules, oldAddons = {}, {}
  local savedEnum, savedBankPanel, savedItemButtonUtil
  local savedSetType, savedTrigger

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end
    StubBetterBagsModule("Debug").Log = function() end
    StubBetterBagsModule("Events").SendMessage = function() end
    StubBetterBagsModule("Context")
    StubBetterBagsModule("Constants").BAG_KIND = { BACKPACK = 0, BANK = 1 }
    savedEnum = _G.Enum
    _G.Enum = _G.Enum or {}
    _G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {
      TradePartner = 1, Banker = 2, Merchant = 3, MailInfo = 4, Auctioneer = 5,
      GuildBanker = 6, VoidStorageBanker = 7, ScrappingMachine = 8, ItemUpgrade = 9,
      AccountBanker = 10,
    }
    savedBankPanel, savedItemButtonUtil = _G.BankPanel, _G.ItemButtonUtil
    savedSetType, savedTrigger = addon.SetBlizzardBankType, addon.TriggerItemContextChanged
    loadfile("core/hooks.lua")("BetterBags")
  end)

  after_each(function()
    _G.Enum = savedEnum
    _G.BankPanel, _G.ItemButtonUtil = savedBankPanel, savedItemButtonUtil
    addon.SetBlizzardBankType, addon.TriggerItemContextChanged = savedSetType, savedTrigger
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  it("sets the BankPanel bank type", function()
    local set = {}
    _G.BankPanel = { SetBankType = function(_, bankType) table.insert(set, bankType) end }
    addon.SetBlizzardBankType(2)
    assert.same({ 2 }, set)
  end)

  it("does nothing on a client without the BankPanel", function()
    _G.BankPanel = nil
    assert.has_no.errors(function() addon.SetBlizzardBankType(1) end)
  end)

  it("tells item buttons their context changed", function()
    local fired = {}
    _G.ItemButtonUtil = {
      Event = { ItemContextChanged = "ItemContextChanged" },
      TriggerEvent = function(event) table.insert(fired, event) end,
    }
    addon.TriggerItemContextChanged()
    assert.same({ "ItemContextChanged" }, fired)
  end)

  -- Every call site must go through the measured functions, or its time is charged to
  -- whichever measured function called it.
  it("is never called inline outside core/hooks.lua", function()
    local inline = {}
    local files = io.popen("find bags frames core data config integrations views forms render sonata window -name '*.lua' 2>&1")
    local scanned = {}
    for path in files:lines() do
      scanned[path] = true
      if path ~= "core/hooks.lua" then
        local f = assert(io.open(path), "cannot scan " .. path)
        local n = 0
        for line in f:lines() do
          n = n + 1
          if line:find("BankPanel:SetBankType(", 1, true)
            or line:find("ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)", 1, true) then
            table.insert(inline, path .. ":" .. n)
          end
        end
        f:close()
      end
    end
    files:close()
    -- A folder missing from the list (or renamed) must fail here, not pass with nothing scanned.
    for _, path in ipairs({ "core/hooks.lua", "frames/bag.lua", "bags/bank.lua", "window/window.lua",
      "sonata/decoration.lua", "render/render.lua" }) do
      assert.is_true(scanned[path] == true, "the scan did not reach " .. path)
    end
    assert.same({}, inline)
  end)
end)
