-- currencies_spec.lua -- Currencies (data/currencies.lua): what BetterBags Next tracks as currencies (currency.md):
-- currencies and items, in the player's order, per profile; what each one reads (counts, caps, where an item is);
-- how much each one changed between reads (gains), and the Warband's amounts.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local events = trackStub("Events")
local database = trackStub("Database")

ResetModuleStub("Currencies", "data/currencies.lua")
LoadBetterBagsModule("data/currencies.lua")
local currencies = addon:GetModule("Currencies")
local context = addon:GetModule("Context")

describe("Currencies", function()
  local saved, replaced, sent, registered, messages, options, containers

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  -- sentOf returns the messages sent of a name, each its arguments after the context.
  local function sentOf(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m.name == name then
        table.insert(out, m.args)
      end
    end
    return out
  end

  -- A currency as GetCurrencyInfo returns it (CurrencyInfoDocumentation.lua), with what a spec gives.
  local function currency(id, fields)
    local info = {
      name = "Currency " .. id, description = "", currencyID = id, isHeader = false, isHeaderExpanded = false,
      currencyListDepth = 0, isTypeUnused = false, isShowInBackpack = false, quantity = 0, trackedQuantity = 0,
      iconFileID = 1000 + id, maxQuantity = 0, canEarnPerWeek = false, quantityEarnedThisWeek = 0,
      isTradeable = false, quality = 1, maxWeeklyQuantity = 0, totalEarned = 0, discovered = true,
      useTotalEarnedForMaxQty = false, isAccountWide = false, isAccountTransferable = false,
      rechargingCycleDurationMS = 0, rechargingAmountPerCycle = 0,
    }
    for k, v in pairs(fields or {}) do
      info[k] = v
    end
    _G._currencies[id] = info
    return info
  end

  before_each(function()
    replaced, sent, registered, messages = {}, {}, {}, {}
    ResetMockCurrencies()
    saved = {}
    options = { itemsEverywhere = true }
    containers = {}
    override(database, "GetNextCurrencies", function()
      local out = {}
      for _, e in ipairs(saved) do table.insert(out, { kind = e.kind, id = e.id }) end
      return out
    end)
    override(database, "SetNextCurrencies", function(_, list)
      saved = {}
      for _, e in ipairs(list) do table.insert(saved, { kind = e.kind, id = e.id }) end
    end)
    override(database, "GetNextCurrencyOption", function(_, name) return options[name] end)
    override(events, "SendMessage", function(_, _, name, ...)
      table.insert(sent, { name = name, args = { ... } })
    end)
    override(events, "RegisterEvent", function(_, name, fn) registered[name] = fn end)
    override(events, "RegisterMessage", function(_, name, fn) messages[name] = fn end)
    addon.isRetail, addon.isMists, addon.hasWarbank = true, false, true
    -- Item data loads when a spec says (the client loads it later: data-loader.md §19).
    override(ContinuableContainer, "Create", function()
      local c = { items = {} }
      function c:AddContinuable(item) table.insert(self.items, item) end
      function c:ContinueOnLoad(fn) self.done = fn end
      table.insert(containers, c)
      return c
    end)
    override(C_Item, "GetItemNameByID", function(id) return _G._itemNames and _G._itemNames[id] end)
    override(C_Item, "GetItemQualityByID", function(id) return _G._itemNames and _G._itemNames[id] and 3 or nil end)
    override(C_Item, "GetItemInfoInstant", function(id) return id, "Tradeskill", "Herb", "", 2000 + id end)
    _G._itemNames = {}
    currencies:Init()
    currencies:OnEnable()
  end)

  after_each(function()
    for i = #replaced, 1, -1 do
      local r = replaced[i]
      r[1][r[2]] = r[3]
    end
    _G._itemNames = nil
    addon.isRetail, addon.isMists, addon.hasWarbank = true, false, true
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("what is tracked", function()
    it("tracks currencies and items in the order they were added, and says when the list changed", function()
      assert.is_true(currencies:Track(ctx(), "currency", 3008))
      assert.is_true(currencies:Track(ctx(), "item", 210796))
      assert.are.same({ { kind = "currency", id = 3008 }, { kind = "item", id = 210796 } }, currencies:Tracked())
      assert.is_true(currencies:IsTracked("item", 210796))
      assert.is_false(currencies:IsTracked("currency", 210796))
      assert.are.equal(2, #sentOf("currencies/Changed"))
    end)

    it("tracks something once", function()
      currencies:Track(ctx(), "currency", 3008)
      assert.is_false(currencies:Track(ctx(), "currency", 3008))
      assert.are.equal(1, #currencies:Tracked())
      assert.are.equal(1, #sentOf("currencies/Changed"))
    end)

    it("tracks something at a place in the list", function()
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      currencies:Track(ctx(), "item", 3, 1)
      assert.are.same({ 3, 1, 2 }, { currencies:Tracked()[1].id, currencies:Tracked()[2].id, currencies:Tracked()[3].id })
    end)

    it("stops tracking something, and says nothing for what it does not track", function()
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "item", 2)
      assert.is_true(currencies:Untrack(ctx(), "currency", 1))
      assert.are.same({ { kind = "item", id = 2 } }, currencies:Tracked())
      assert.is_false(currencies:Untrack(ctx(), "currency", 1))
      assert.are.equal(3, #sentOf("currencies/Changed"))
    end)

    -- NextListReorder's contract: let go after the entry at after in the list as it was, counted with the row itself.
    it("moves an entry after another, as a list's dragged row lands, and does nothing where it was", function()
      for id = 1, 3 do currencies:Track(ctx(), "currency", id) end
      local function ids()
        local out = {}
        for _, e in ipairs(currencies:Tracked()) do table.insert(out, e.id) end
        return out
      end
      assert.is_true(currencies:Move(ctx(), currencies:Key("currency", 1), 2))
      assert.are.same({ 2, 1, 3 }, ids())
      assert.is_true(currencies:Move(ctx(), currencies:Key("currency", 3), 0))
      assert.are.same({ 3, 2, 1 }, ids())
      local before = #sentOf("currencies/Changed")
      assert.is_false(currencies:Move(ctx(), currencies:Key("currency", 2), 2), "it landed where it was")
      assert.is_false(currencies:Move(ctx(), "currency:99", 0))
      assert.are.equal(before, #sentOf("currencies/Changed"))
    end)

    it("names an entry by its kind and ID", function()
      assert.are.equal("currency:3008", currencies:Key("currency", 3008))
      assert.are.equal("item:210796", currencies:Key("item", 210796))
    end)

    it("tracks only items that stack, which the client says once it has loaded them", function()
      _G._itemStackSizes[1] = 200
      _G._itemStackSizes[2] = 1
      assert.is_true(currencies:CanTrackItem(1))
      assert.is_false(currencies:CanTrackItem(2), "gear does not stack")
      assert.is_false(currencies:CanTrackItem(3), "not loaded yet")
    end)

    it("has currencies on retail, WoW: Forever and Mists Classic, items everywhere", function()
      assert.is_true(currencies:Available())
      addon.isRetail, addon.isMists = false, true
      assert.is_true(currencies:Available())
      addon.isRetail, addon.isMists = false, false
      assert.is_false(currencies:Available())
    end)
  end)

  describe("reading a currency", function()
    it("reads its name, icon, quality and count", function()
      currency(3008, { name = "Valorstones", quantity = 1350, iconFileID = 5868902, quality = 3 })
      currencies:Track(ctx(), "currency", 3008)
      local s = currencies:State("currency:3008")
      assert.are.equal("Valorstones", s.name)
      assert.are.equal(5868902, s.icon)
      assert.are.equal(3, s.quality)
      assert.are.equal(1350, s.count)
      assert.is_false(s.none)
      assert.is_nil(s.progress, "no cap")
    end)

    it("is none while it has nothing or was never discovered", function()
      currency(1, { quantity = 0 })
      currency(2, { quantity = 5, discovered = false })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      assert.is_true(currencies:State("currency:1").none)
      assert.is_true(currencies:State("currency:2").none)
    end)

    it("reads its progress toward the cap it has: a weekly one, a season's, or the most it can hold", function()
      currency(1, { quantity = 40, canEarnPerWeek = true, quantityEarnedThisWeek = 300, maxWeeklyQuantity = 400 })
      currency(2, { quantity = 90, useTotalEarnedForMaxQty = true, totalEarned = 1500, maxQuantity = 2000 })
      currency(3, { quantity = 1000, maxQuantity = 4000 })
      for id = 1, 3 do currencies:Track(ctx(), "currency", id) end
      local week, season, most = currencies:State("currency:1"), currencies:State("currency:2"),
        currencies:State("currency:3")
      assert.are.equal("week", week.cap)
      assert.are.equal(0.75, week.progress)
      assert.are.same({ earned = 300, max = 400 }, week.weekly)
      assert.are.equal("season", season.cap)
      assert.are.equal(0.75, season.progress)
      assert.are.same({ earned = 1500, max = 2000 }, season.season)
      assert.are.equal("most", most.cap)
      assert.are.equal(0.25, most.progress)
      assert.are.equal(4000, most.max)
    end)

    it("goes by the cap closest to being reached when it has more than one", function()
      currency(1, { quantity = 10, canEarnPerWeek = true, quantityEarnedThisWeek = 100, maxWeeklyQuantity = 400,
        useTotalEarnedForMaxQty = true, totalEarned = 1800, maxQuantity = 2000 })
      currencies:Track(ctx(), "currency", 1)
      local s = currencies:State("currency:1")
      assert.are.equal("season", s.cap)
      assert.are.equal(0.9, s.progress)
    end)

    it("is capped at its cap, and when the client says it holds the most or earned the week's most", function()
      currency(1, { quantity = 2000, maxQuantity = 2000 })
      currency(2, { quantity = 10, maxQuantity = 0 })
      currency(3, { quantity = 10, canEarnPerWeek = true, quantityEarnedThisWeek = 50, maxWeeklyQuantity = 400 })
      override(C_CurrencyInfo, "PlayerHasMaxQuantity", function(id) return id == 2 end)
      override(C_CurrencyInfo, "PlayerHasMaxWeeklyQuantity", function(id) return id == 3 end)
      for id = 1, 3 do currencies:Track(ctx(), "currency", id) end
      assert.is_true(currencies:State("currency:1").capped)
      assert.are.equal(1, currencies:State("currency:1").progress)
      assert.is_true(currencies:State("currency:2").capped)
      assert.is_true(currencies:State("currency:3").capped)
      currency(4, { quantity = 10, maxQuantity = 2000 })
      currencies:Track(ctx(), "currency", 4)
      assert.is_false(currencies:State("currency:4").capped)
    end)

    it("says whether it belongs to the Warband and moves between its characters", function()
      currency(1, { isAccountWide = true })
      currency(2, { isAccountTransferable = true })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      assert.is_true(currencies:State("currency:1").accountWide)
      assert.is_true(currencies:State("currency:2").transferable)
    end)

    it("reads nothing for a currency the client does not know", function()
      currencies:Track(ctx(), "currency", 99)
      local s = currencies:State("currency:99")
      assert.are.equal(0, s.count)
      assert.is_true(s.none)
      assert.is_nil(s.name)
    end)
  end)

  describe("reading an item", function()
    it("counts it in the bags, the bank and the Warband, and in the bags alone when told", function()
      _G._itemCounts[5] = { bags = 20, bank = 100, reagent = 30, warband = 7 }
      currencies:Track(ctx(), "item", 5)
      local s = currencies:State("item:5")
      assert.are.equal(157, s.count)
      assert.are.equal(20, s.bags)
      assert.are.same({ bags = 20, bank = 100, reagent = 30, warband = 7 }, currencies:ItemPlaces(5))
      options.itemsEverywhere = false
      currencies:Refresh(ctx())
      assert.are.equal(20, currencies:State("item:5").count)
    end)

    it("leaves out the Warband where there is none (WoW: Forever, a retail client without one)", function()
      addon.isRetail, addon.isMists, addon.hasWarbank = true, false, false
      _G._itemCounts[5] = { bags = 2, bank = 3, warband = 7 }
      currencies:Track(ctx(), "item", 5)
      assert.are.equal(5, currencies:State("item:5").count)
    end)

    it("has its icon at once, and its name and quality only once the client loaded it", function()
      _G._itemCounts[5] = { bags = 1 }
      currencies:Track(ctx(), "item", 5)
      local s = currencies:State("item:5")
      assert.are.equal(2005, s.icon)
      assert.is_nil(s.name, "rule #1: nothing but GetItemInfoInstant before the item loaded")
      assert.are.equal(1, #containers, "its data asked for")
      _G._itemNames[5] = "Mycobloom"
      local before = #sentOf("currencies/Updated")
      containers[1].done()
      assert.are.equal("Mycobloom", currencies:State("item:5").name)
      assert.are.equal(3, currencies:State("item:5").quality)
      assert.are.equal(before + 1, #sentOf("currencies/Updated"))
    end)

    it("asks for an item's data once while it loads", function()
      currencies:Track(ctx(), "item", 5)
      currencies:Refresh(ctx())
      currencies:Refresh(ctx())
      assert.are.equal(1, #containers)
    end)

    it("is none while you have none", function()
      currencies:Track(ctx(), "item", 5)
      assert.is_true(currencies:State("item:5").none)
      _G._itemCounts[5] = { bank = 3 }
      currencies:Refresh(ctx())
      assert.is_false(currencies:State("item:5").none)
    end)

    it("has no cap", function()
      _G._itemCounts[5] = { bags = 3 }
      currencies:Track(ctx(), "item", 5)
      assert.is_nil(currencies:State("item:5").progress)
      assert.is_false(currencies:State("item:5").capped)
    end)
  end)

  describe("gains", function()
    -- ready reads the bags once, as the startup read's draw does (items/RefreshBackpack/Done).
    local function ready()
      messages["items/RefreshBackpack/Done"](ctx())
    end

    local function lastGains()
      local updates = sentOf("currencies/Updated")
      return updates[#updates][1]
    end

    it("says nothing changed before the bags were first read: counts arriving at login are no gains", function()
      currency(1, { quantity = 10 })
      currencies:Track(ctx(), "currency", 1)
      _G._currencies[1].quantity = 50
      currencies:Refresh(ctx())
      assert.are.same({}, lastGains())
    end)

    it("says how much a currency gained or lost", function()
      currency(1, { quantity = 10 })
      currencies:Track(ctx(), "currency", 1)
      ready()
      _G._currencies[1].quantity = 35
      currencies:Refresh(ctx())
      assert.are.same({ ["currency:1"] = 25 }, lastGains())
      _G._currencies[1].quantity = 5
      currencies:Refresh(ctx())
      assert.are.same({ ["currency:1"] = -30 }, lastGains())
    end)

    it("sends nothing when nothing changed", function()
      currency(1, { quantity = 10 })
      currencies:Track(ctx(), "currency", 1)
      ready()
      local before = #sentOf("currencies/Updated")
      currencies:Refresh(ctx())
      assert.are.equal(before, #sentOf("currencies/Updated"))
    end)

    it("counts an item looted as a gain, one moved between the bags and the bank as none", function()
      _G._itemCounts[5] = { bags = 10, bank = 40 }
      currencies:Track(ctx(), "item", 5)
      ready()
      _G._itemCounts[5] = { bags = 14, bank = 40 }
      currencies:Refresh(ctx())
      assert.are.same({ ["item:5"] = 4 }, lastGains(), "looted")
      _G._itemCounts[5] = { bags = 4, bank = 50 }
      currencies:Refresh(ctx())
      assert.are.same({}, lastGains(), "moved to the bank: a new count, no loss")
      _G._itemCounts[5] = { bags = 9, bank = 45 }
      currencies:Refresh(ctx())
      assert.are.same({}, lastGains(), "moved back: no gain")
      _G._itemCounts[5] = { bags = 6, bank = 45 }
      currencies:Refresh(ctx())
      assert.are.same({ ["item:5"] = -3 }, lastGains(), "used")
    end)

    it("counts the bank arriving late as no gain", function()
      _G._itemCounts[5] = { bags = 10 }
      currencies:Track(ctx(), "item", 5)
      ready()
      _G._itemCounts[5] = { bags = 10, bank = 200 }
      currencies:Refresh(ctx())
      assert.are.same({}, lastGains())
      assert.are.equal(210, currencies:State("item:5").count)
    end)

    it("counts what the bags gained when the bank's count arrives with a loot", function()
      _G._itemCounts[5] = { bags = 10 }
      currencies:Track(ctx(), "item", 5)
      ready()
      _G._itemCounts[5] = { bags = 15, bank = 20 }
      currencies:Refresh(ctx())
      assert.are.same({ ["item:5"] = 5 }, lastGains(), "the 5 looted, not the bank's 20")
      _G._itemCounts[5] = { bags = 12, bank = 0 }
      currencies:Refresh(ctx())
      assert.are.same({ ["item:5"] = -3 }, lastGains(), "the 3 used, not the bank's count going")
    end)

    it("counts an item in the bags alone when told", function()
      options.itemsEverywhere = false
      _G._itemCounts[5] = { bags = 10, bank = 40 }
      currencies:Track(ctx(), "item", 5)
      ready()
      _G._itemCounts[5] = { bags = 4, bank = 46 }
      currencies:Refresh(ctx())
      assert.are.same({ ["item:5"] = -6 }, lastGains())
    end)

    it("gives no gain for something just tracked", function()
      currency(1, { quantity = 10 })
      ready()
      currencies:Track(ctx(), "currency", 1)
      assert.are.same({}, lastGains())
    end)

    it("keeps what each gained since the bags were first read", function()
      currency(1, { quantity = 10 })
      currencies:Track(ctx(), "currency", 1)
      ready()
      _G._currencies[1].quantity = 30
      currencies:Refresh(ctx())
      _G._currencies[1].quantity = 25
      currencies:Refresh(ctx())
      assert.are.equal(15, currencies:SessionGain("currency:1"))
      assert.are.equal(0, currencies:SessionGain("currency:2"))
    end)
  end)

  describe("events", function()
    it("reads a tracked currency again when the client says it changed, and only it", function()
      currency(1, { quantity = 1 })
      currency(2, { quantity = 2 })
      currencies:Track(ctx(), "currency", 1)
      currencies:Track(ctx(), "currency", 2)
      messages["items/RefreshBackpack/Done"](ctx())
      _G._currencies[1].quantity = 11
      _G._currencies[2].quantity = 12
      registered["CURRENCY_DISPLAY_UPDATE"](ctx(), "CURRENCY_DISPLAY_UPDATE", 1, 11, 10)
      assert.are.equal(11, currencies:State("currency:1").count)
      assert.are.equal(2, currencies:State("currency:2").count, "not read again")
      registered["CURRENCY_DISPLAY_UPDATE"](ctx(), "CURRENCY_DISPLAY_UPDATE")
      assert.are.equal(12, currencies:State("currency:2").count, "none named: every currency read again")
    end)

    it("ignores a currency it does not track", function()
      currency(1, { quantity = 1 })
      currencies:Track(ctx(), "currency", 1)
      local before = #sentOf("currencies/Updated")
      registered["CURRENCY_DISPLAY_UPDATE"](ctx(), "CURRENCY_DISPLAY_UPDATE", 7, 3, 3)
      assert.are.equal(before, #sentOf("currencies/Updated"))
    end)

    it("reads its items again after every read of the backpack and the bank", function()
      _G._itemCounts[5] = { bags = 1 }
      currencies:Track(ctx(), "item", 5)
      _G._itemCounts[5] = { bags = 9 }
      messages["items/RefreshBackpack/Done"](ctx())
      assert.are.equal(9, currencies:State("item:5").count)
      _G._itemCounts[5] = { bags = 9, bank = 1 }
      messages["items/RefreshBank/Done"](ctx())
      assert.are.equal(10, currencies:State("item:5").count)
    end)

    it("reads everything again when how items are counted changes", function()
      _G._itemCounts[5] = { bags = 1, bank = 4 }
      currencies:Track(ctx(), "item", 5)
      options.itemsEverywhere = false
      messages["currencies/OptionsChanged"](ctx())
      assert.are.equal(1, currencies:State("item:5").count)
    end)
  end)

  describe("the Warband", function()
    it("asks the server for its characters' amounts, and tells when they arrive", function()
      currency(1, { isAccountTransferable = true })
      assert.is_nil(currencies:Alts(1))
      assert.are.equal(1, _G._accountCurrencyRequests)
      registered["ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED"](ctx())
      assert.are.equal(1, #sentOf("currencies/AltsReady"))
    end)

    it("lists its other characters' amounts, the most first, and none of those who have none", function()
      _G._accountCurrencyReady = true
      _G._accountCurrencies[1] = {
        { characterName = "Alt", fullCharacterName = "Alt-Realm", quantity = 30 },
        { characterName = "Poor", fullCharacterName = "Poor-Realm", quantity = 0 },
        { characterName = "Main", fullCharacterName = "Main-Realm", quantity = 300 },
      }
      local alts = currencies:Alts(1)
      assert.are.same({ { name = "Main", quantity = 300 }, { name = "Alt", quantity = 30 } }, alts)
      assert.are.equal(0, _G._accountCurrencyRequests)
    end)

    it("has none where the client cannot say", function()
      override(C_CurrencyInfo, "FetchCurrencyDataFromAccountCharacters", nil)
      override(C_CurrencyInfo, "IsAccountCharacterCurrencyDataReady", nil)
      assert.are.same({}, currencies:Alts(1))
    end)
  end)

  describe("Blizzard's currency list", function()
    -- A list as the player keeps it: an open heading, a collapsed one, and a collapsed one inside an open one.
    local function playerList()
      currency(1, { name = "Valorstones", quantity = 1350, maxQuantity = 2000, iconFileID = 11 })
      currency(2, { name = "Honor", quantity = 50, iconFileID = 12 })
      currency(3, { name = "Kej", quantity = 4, iconFileID = 13 })
      currency(4, { name = "Resonance Crystals", quantity = 0, iconFileID = 14 })
      _G._currencyList = {
        { name = "The War Within", isHeader = true, isHeaderExpanded = true, children = {
          { currencyID = 1 },
          { name = "Delves", isHeader = true, isHeaderExpanded = false, children = { { currencyID = 3 } } },
          { currencyID = 4 },
        } },
        { name = "Player vs. Player", isHeader = true, isHeaderExpanded = false, children = { { currencyID = 2 } } },
      }
    end

    local function expanded()
      local out = {}
      local function walk(nodes)
        for _, node in ipairs(nodes) do
          if node.isHeader then
            out[node.name] = node.isHeaderExpanded
            walk(node.children or {})
          end
        end
      end
      walk(_G._currencyList)
      return out
    end

    it("reads every heading and every currency under it, with its ID, depth, count and icon", function()
      playerList()
      local list = currencies:List()
      local names, ids, depths = {}, {}, {}
      for _, e in ipairs(list) do
        table.insert(names, e.name)
        table.insert(ids, e.id or "-")
        table.insert(depths, e.depth)
      end
      assert.are.same({ "The War Within", "Valorstones", "Delves", "Kej", "Resonance Crystals", "Player vs. Player",
        "Honor" }, names)
      assert.are.same({ "-", 1, "-", 3, 4, "-", 2 }, ids)
      assert.are.same({ 0, 1, 1, 2, 1, 0, 1 }, depths)
      assert.are.equal(1350, list[2].quantity)
      assert.are.equal(2000, list[2].maxQuantity)
      assert.are.equal(11, list[2].icon)
      assert.is_true(list[1].isHeader)
      assert.is_false(list[2].isHeader)
    end)

    it("opens a collapsed heading to read it and closes it again, leaving the list as the player had it", function()
      playerList()
      local before = expanded()
      currencies:List()
      assert.are.same(before, expanded())
      -- Opened as met (Delves at 3, then Player vs. Player at 6 with Delves open), closed again the last opened
      -- first, so each is still at its own place.
      local calls = {}
      for _, c in ipairs(_G._currencyListCalls) do table.insert(calls, c[2] .. (c[3] and "+" or "-")) end
      assert.are.same({ "3+", "6+", "6-", "3-" }, calls)
    end)

    it("leaves a list with nothing collapsed untouched", function()
      currency(1, {})
      _G._currencyList = { { name = "A", isHeader = true, isHeaderExpanded = true, children = { { currencyID = 1 } } } }
      currencies:List()
      assert.are.same({}, _G._currencyListCalls)
    end)

    it("reads Mists Classic's legacy list, its currency ID the twelfth value, and opens headings with 1 and 0", function()
      local rows = {
        { "Dungeon and Raid", true, true },
        { "Valor", false, false, false, true, 1234, 101, 3000, 0, 0, false, 396 },
        { "Player vs. Player", true, false },
      }
      local hidden = { "Honor", false, false, false, false, 50, 102, 4000, 0, 0, false, 1901 }
      local calls = {}
      local function shown()
        local out = { rows[1], rows[2], rows[3] }
        if rows[3][3] then table.insert(out, hidden) end
        return out
      end
      override(_G, "C_CurrencyInfo", {})
      override(_G, "GetCurrencyListSize", function() return #shown() end)
      override(_G, "GetCurrencyListInfo", function(i)
        local r = shown()[i]
        if r == nil then return nil end
        return unpack(r, 1, 12)
      end)
      override(_G, "ExpandCurrencyList", function(i, open)
        table.insert(calls, { i, open })
        if i == 3 then rows[3][3] = open == 1 end
      end)
      local list = currencies:List()
      assert.are.equal(4, #list)
      assert.are.equal(396, list[2].id)
      assert.is_true(list[2].isShowInBackpack)
      assert.are.equal(1234, list[2].quantity)
      assert.are.equal(3000, list[2].maxQuantity)
      assert.are.equal(1901, list[4].id)
      assert.is_nil(list[1].id)
      assert.are.same({ 0, 1, 0, 1 }, { list[1].depth, list[2].depth, list[3].depth, list[4].depth })
      assert.are.same({ { 3, 1 }, { 3, 0 } }, calls)
    end)

    it("is empty on a client without currencies", function()
      override(_G, "C_CurrencyInfo", {})
      override(_G, "GetCurrencyListSize", nil)
      override(_G, "GetCurrencyListInfo", nil)
      assert.are.same({}, currencies:List())
    end)
  end)
end)
