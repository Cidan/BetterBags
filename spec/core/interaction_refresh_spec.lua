-- interaction_refresh_spec.lua -- Which refresh opening and closing an interaction window
-- (merchant, mailbox, bank, ...) asks for (core/hooks.lua). Interactions change how items
-- match the open window (the grey-out) and whether stacks unmerge at a shop, both derived
-- by the data phase, so the bags are recalculated from the items already read instead of
-- read again (.claude/rules/refresh-scheduler.md §10). The layout is rebuilt, as the full
-- refresh it replaces did.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

describe("interaction window refreshes", function()
  local aceAddon = LibStub("AceAddon-3.0")
  local moduleNames = { "Debug", "Events", "Context", "Items", "Constants" }
  local oldModules, oldAddons = {}, {}
  local savedEnum, savedBags, savedGameMenu, savedState
  local sent, bankNeedsRecalculation

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end
    local debug = StubBetterBagsModule("Debug")
    debug.Log = function() end
    sent = {}
    local events = StubBetterBagsModule("Events")
    events.SendMessage = function(_, _, message, options)
      table.insert(sent, { message = message, options = options })
    end
    events.SendMessageLater = function() end
    StubBetterBagsModule("Context")
    StubBetterBagsModule("Constants").BAG_KIND = { BACKPACK = 0, BANK = 1 }
    bankNeedsRecalculation = false
    StubBetterBagsModule("Items").NeedsInteractionRecalculation = function(_, kind)
      assert.equal(1, kind, "asked about the bank")
      return bankNeedsRecalculation
    end

    savedEnum = _G.Enum
    _G.Enum = _G.Enum or {}
    _G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {
      TradePartner = 1, Banker = 2, Merchant = 3, MailInfo = 4, Auctioneer = 5,
      GuildBanker = 6, VoidStorageBanker = 7, ScrappingMachine = 8, ItemUpgrade = 9,
      AccountBanker = 10,
    }
    savedGameMenu = _G.GameMenuFrame
    _G.GameMenuFrame = { IsShown = function() return false end }
    savedState = {
      atInteracting = addon.atInteracting,
      atWarbank = addon.atWarbank,
      backpackShouldOpen = addon.backpackShouldOpen,
      backpackShouldClose = addon.backpackShouldClose,
      UpdateButtonHighlight = addon.UpdateButtonHighlight,
    }
    addon.UpdateButtonHighlight = function() end
    savedBags = addon.Bags
    addon.Bags = { Backpack = { Show = function() end, Hide = function() end } }

    loadfile("core/hooks.lua")("BetterBags")
  end)

  after_each(function()
    addon.Bags = savedBags
    _G.Enum = savedEnum
    _G.GameMenuFrame = savedGameMenu
    for key, value in pairs(savedState) do
      addon[key] = value
    end
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  local function refreshes()
    local out = {}
    for _, s in ipairs(sent) do
      if s.message:match("^bags/") and s.message ~= "bags/OpenClose" then
        out[#out + 1] = s
      end
    end
    return out
  end

  -- The backpack's grey-out depends on the open window, so it is always recalculated. The
  -- bank's only input that depends on it is stack unmerging, so it is recalculated only when
  -- its committed stacks were built under the other interaction state.
  for _, bank in ipairs({ false, true }) do
    local which = bank and "both bags" or "only the backpack"
    it("recalculates " .. which .. " when an interaction opens the backpack", function()
      bankNeedsRecalculation = bank
      addon.OpenInteractionWindow(nil, nil, Enum.PlayerInteractionType.Merchant)
      sent = {}
      addon.OnUpdate(nil)
      local requested = refreshes()
      assert.equal(1, #requested)
      assert.equal("bags/Rederive", requested[1].message)
      assert.same({ resetLayout = true, backpack = true, bank = bank }, requested[1].options)
    end)

    it("recalculates " .. which .. " when the interaction closes", function()
      bankNeedsRecalculation = bank
      addon.OpenInteractionWindow(nil, nil, Enum.PlayerInteractionType.Merchant)
      sent = {}
      addon.CloseInteractionWindow(nil, nil, Enum.PlayerInteractionType.Merchant)
      local requested = refreshes()
      assert.equal(1, #requested)
      assert.equal("bags/Rederive", requested[1].message)
      assert.same({ resetLayout = true, backpack = true, bank = bank }, requested[1].options)
    end)
  end
end)
