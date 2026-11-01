-- pawn_spec.lua -- The Pawn integration (integrations/pawn.lua, caches.md §2a): the budgeted question, the queue of links
-- waiting to be asked, and what Pawn's signal does to it. Reported (issue #1209): every loot froze the game for about 150 ms,
-- since each one reset every answer and the next refresh asked Pawn about the whole bag again.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local context = LoadFreshBetterBagsModule("Context", "core/context.lua")
local events = LoadFreshBetterBagsModule("Events", "core/events.lua")

local createdStubs = {}
local function stubModule(name)
  local mod, created = StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end

local const = stubModule("Constants")
local savedBagKind = const.BAG_KIND
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1, GUILD = 2 }
local debug = stubModule("Debug")
debug.Log = debug.Log or function() end
local items = stubModule("Items")

local BACKPACK, BANK, GUILD = 0, 1, 2

-- The time a question costs in Pawn, from the capture on issue #1209.
local ASK = 0.00087

describe("Pawn integration", function()
  local pawn, now, timers, asked, verdicts, registered, sent, inCombat, provider, slotInfo, generation, ready
  local saved = {}

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  -- Pawn's BudgetThrottle (Pawn 2.14 Pawn.lua), line for line: past its budget it answers nil without asking.
  local function budgetThrottle(func, budget, period)
    local periodEndsAt = 0
    local remaining = 0
    return function(...)
      local at = _G.GetTimePreciseSec()
      if at >= periodEndsAt then
        periodEndsAt = at + period
        remaining = budget
      elseif remaining <= 0 then
        return nil
      end
      local returns = { func(...) }
      local elapsed = _G.GetTimePreciseSec() - at
      remaining = remaining - elapsed
      return unpack(returns)
    end
  end

  -- advance moves the clock on by seconds, running each timer when it comes due.
  local function advance(seconds)
    local target = now + seconds
    while true do
      local nextTimer, index
      for i, t in ipairs(timers) do
        if t.at <= target and (nextTimer == nil or t.at < nextTimer.at) then
          nextTimer, index = t, i
        end
      end
      if nextTimer == nil then
        break
      end
      table.remove(timers, index)
      now = math.max(now, nextTimer.at)
      nextTimer.fn()
    end
    now = math.max(now, target)
  end

  -- turns runs n turns of asking, a quarter second apart.
  local function turns(n)
    for _ = 1, n or 1 do
      advance(0.25)
    end
  end

  -- settle runs the queue until nothing more is waiting on a timer.
  local function settle()
    local guard = 0
    while #timers > 0 do
      advance(0.25)
      guard = guard + 1
      assert(guard < 2000, "the queue never settled")
    end
  end

  local function link(id)
    return "|cffffffff|Hitem:" .. id .. "::::::::|h[Item " .. id .. "]|h|r"
  end

  local function item(id, kind)
    return { itemInfo = { itemLink = link(id) }, kind = kind or BACKPACK }
  end

  -- hold puts items in a kind's committed items, as a read would.
  local function hold(kind, ids)
    local held = {}
    for i, id in ipairs(ids) do
      held[kind .. "_" .. i] = item(id, kind)
    end
    held[kind .. "_empty"] = { isItemEmpty = true, itemInfo = {} }
    slotInfo[kind] = { itemsBySlotKey = held }
  end

  -- sweep asks about every item held in a kind, as a read's Phase 6 does.
  local function sweep(kind)
    local answers = {}
    for _, data in pairs(slotInfo[kind].itemsBySlotKey) do
      if not data.isItemEmpty then
        answers[data.itemInfo.itemLink] = pawn:Answer(data)
      end
    end
    return answers
  end

  local function count(list, value)
    local n = 0
    for _, v in ipairs(list) do
      if v == value then
        n = n + 1
      end
    end
    return n
  end

  local function ids(from, to)
    local list = {}
    for i = from, to do
      table.insert(list, i)
    end
    return list
  end

  -- signal is Pawn calling us back (PawnResetBags calls each third-party bag's RefreshAll).
  local function signal()
    return registered[1].overrides.RefreshAll()
  end

  before_each(function()
    now, timers, asked, verdicts, registered, sent, inCombat = 100, {}, {}, {}, {}, {}, false
    provider, slotInfo, generation, ready = "Pawn", {}, 1, true
    override(_G, "PawnIsReady", function() return ready end)
    override(_G, "GetTime", function() return now end)
    override(_G, "GetTimePreciseSec", function() return now end)
    override(_G, "InCombatLockdown", function() return inCombat end)
    override(_G.C_Timer, "After", function(delay, fn) table.insert(timers, { at = now + delay, fn = fn }) end)
    override(_G, "PawnShouldItemLinkHaveUpgradeArrow", budgetThrottle(function(askedLink, checkLevel)
      assert(checkLevel == true, "Pawn is asked to check the player's level")
      table.insert(asked, askedLink)
      now = now + ASK
      local v = verdicts[askedLink]
      if type(v) == "function" then
        return v()
      elseif v == "not sure" then
        return nil
      end
      return v == true
    end, 2 / 60 / 4, 1 / 4))
    override(_G, "PawnRegisterThirdPartyBag", function(name, overrides)
      table.insert(registered, { name = name, overrides = overrides })
    end)
    override(items, "RegisterUpgradeProvider", function(_, name, func, options)
      items.registeredProvider = { name = name, func = func, options = options }
    end)
    override(items, "GetActiveUpgradeProvider", function() return provider end)
    override(items, "GetUpgradeGeneration", function() return generation end)
    override(items, "InvalidateUpgrades", function(_, refresh)
      assert(refresh == false, "Pawn's signal asks for no refresh")
      generation = generation + 1
    end)
    override(items, "GetAllSlotInfo", function() return slotInfo end)
    override(events, "SendMessage", function(_, _, message, ...)
      table.insert(sent, { message = message, options = (...) })
    end)
    addon.atBank, addon.atGuildBank = false, false
    pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
    override(_G, "print", function() end)
    assert.is_true(pawn:Register())
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
    saved = {}
    addon.atBank, addon.atGuildBank = nil, nil
  end)

  teardown(function()
    const.BAG_KIND = savedBagKind
    ResetModuleStub("Pawn", "integrations/pawn.lua")
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  describe("registering", function()
    it("registers as a third-party bag, with a callback, once", function()
      assert.are.equal(1, #registered)
      assert.are.equal("BetterBags", registered[1].name)
      assert.is_function(registered[1].overrides.RefreshAll)
      assert.is_true(pawn:Register())
      assert.are.equal(1, #registered, "Pawn prints a failure for a bag registered twice")
    end)

    it("hooks nothing of Pawn's", function()
      local hooked = false
      override(_G, "hooksecurefunc", function() hooked = true end)
      pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
      pawn:Register()
      assert.is_false(hooked)
    end)

    it("registers its provider without per-item verdicts: it keeps answers by link itself", function()
      assert.are.equal("Pawn", items.registeredProvider.name)
      assert.is_true(items.registeredProvider.options == nil or items.registeredProvider.options.cacheable ~= true)
      local data = item(1)
      verdicts[link(1)] = true
      assert.is_true(items.registeredProvider.func(data))
    end)

    for _, missing in ipairs({ "PawnShouldItemLinkHaveUpgradeArrow", "PawnRegisterThirdPartyBag" }) do
      it("waits while Pawn does not have " .. missing, function()
        items.registeredProvider, registered = nil, {}
        override(_G, missing, nil)
        pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
        assert.is_false(pawn:Register())
        assert.is_nil(items.registeredProvider)
        assert.are.equal(0, #registered)
      end)
    end

    -- PawnRegisterThirdPartyBag came with Pawn 2.13.1 (its Version history.md): an older Pawn would lose its arrows in silence.
    it("says so, once, when Pawn is too old to work with", function()
      local said = {}
      override(_G, "print", function(message) table.insert(said, message) end)
      override(_G, "PawnVersion", 2.13)
      override(_G, "PawnRegisterThirdPartyBag", nil)
      pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
      assert.is_false(pawn:Register())
      assert.is_false(pawn:Register())
      assert.are.equal(1, #said)
      assert.is_truthy(said[1]:find("Pawn", 1, true))
      assert.is_truthy(said[1]:find("too old", 1, true))
    end)

    it("says nothing while Pawn is not loaded at all", function()
      local said = {}
      override(_G, "print", function(message) table.insert(said, message) end)
      override(_G, "PawnShouldItemLinkHaveUpgradeArrow", nil)
      override(_G, "PawnRegisterThirdPartyBag", nil)
      pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
      assert.is_false(pawn:Register())
      assert.are.equal(0, #said)
    end)

    it("registers once Pawn loads after it, and asks for one recalculation that keeps categories", function()
      items.registeredProvider, registered = nil, {}
      local pawnAsk, pawnRegister = _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnRegisterThirdPartyBag
      override(_G, "PawnShouldItemLinkHaveUpgradeArrow", nil)
      override(_G, "PawnRegisterThirdPartyBag", nil)
      local onLoaded
      override(events, "RegisterEvent", function(_, name, fn)
        if name == "ADDON_LOADED" then onLoaded = fn end
      end)
      pawn = LoadFreshBetterBagsModule("Pawn", "integrations/pawn.lua")
      pawn:OnEnable()
      onLoaded(context:New("test"))
      assert.is_nil(items.registeredProvider, "not yet")
      assert.are.equal(0, #sent)
      _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnRegisterThirdPartyBag = pawnAsk, pawnRegister
      onLoaded(context:New("test"))
      assert.is_not_nil(items.registeredProvider)
      assert.are.same({ { message = "bags/Rederive", options = { categoriesUnchanged = true } } }, sent)
      onLoaded(context:New("test"))
      assert.are.equal(1, #sent, "once")
      assert.are.equal(1, #registered)
    end)
  end)

  describe("answering a read", function()
    it("gives no arrow to nothing, and asks Pawn nothing", function()
      assert.is_false(pawn:Answer(nil))
      assert.is_false(pawn:Answer({ isItemEmpty = true }))
      assert.is_false(pawn:Answer({ itemInfo = {} }))
      assert.are.equal(0, #asked)
      assert.are.equal(0, #timers)
    end)

    -- Pawn reads only item links (PawnGetItemData); asked about a caged pet it could only say it is not sure, for good.
    it("gives a caged pet no arrow, and asks Pawn nothing, whatever its custom name", function()
      assert.is_false(pawn:Answer({ itemInfo = { itemLink = "|cff0070dd|Hbattlepet:635:1:3:152:13:12:0|h[item:5]|h|r" } }))
      assert.are.equal(0, #asked)
    end)

    it("gives a caged pet no arrow, and asks Pawn nothing", function()
      local cage = { itemInfo = { itemLink = "|cff0070dd|Hbattlepet:635:1:3:152:13:12:0|h[Adder]|h|r" } }
      assert.is_false(pawn:Answer(cage))
      assert.are.equal(0, #asked)
      assert.are.equal(0, #timers)
    end)

    it("asks about an item it has not seen at once, so a looted item has its arrow on the read that found it", function()
      verdicts[link(1)] = true
      assert.is_true(pawn:Answer(item(1)))
      assert.are.same({ link(1) }, asked)
      assert.are.equal(0, #timers, "nothing is left waiting")
      assert.are.equal(0, #sent, "the read itself shows it")
    end)

    it("says it is not sure while Pawn is", function()
      verdicts[link(1)] = "not sure"
      assert.is_nil(pawn:Answer(item(1)))
    end)

    it("keeps the answer by link: another stack or the same item in a new slot asks nothing", function()
      verdicts[link(1)] = true
      pawn:Answer(item(1))
      assert.is_true(pawn:Answer(item(1)), "a stack, or the new object a sort reads")
      assert.is_true(pawn:Answer(item(1, BANK)), "the same link in another bag")
      assert.are.equal(1, #asked)
    end)

    it("draws no arrow and has it wait when Pawn is out of budget, then shows it", function()
      hold(BACKPACK, ids(1, 40))
      verdicts[link(40)] = true
      sweep(BACKPACK)
      local inTheRead = #asked
      assert.is_true(inTheRead > 0 and inTheRead < 40, "the budget stops the read: " .. inTheRead)
      settle()
      assert.are.equal(40, #asked, "each once")
      assert.is_true(pawn:Answer(item(40)))
    end)

    it("stays well inside a frame however many items the first read holds", function()
      hold(BACKPACK, ids(1, 163))
      local start = now
      sweep(BACKPACK)
      assert.is_true(now - start < 0.012, "the read cost " .. (now - start))
    end)
  end)

  describe("Pawn's signal", function()
    before_each(function()
      hold(BACKPACK, ids(1, 5))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    it("starts one timer and asks nothing in the frame it fires in", function()
      signal()
      assert.are.equal(0, #asked)
      assert.are.equal(1, #timers)
    end)

    -- The first attempt refreshed on Pawn's signal, which it sends on every item picked up (caches.md §2).
    it("asks for no refresh and no redraw", function()
      signal()
      assert.are.equal(0, #sent)
    end)

    it("starts a new generation, so the rest of the addon's kept verdicts follow", function()
      local before = generation
      signal()
      assert.are.equal(before + 1, generation)
    end)

    it("keeps showing the old answers while they wait, asking nothing in a read", function()
      verdicts[link(1)] = true
      pawn:Forget()
      pawn:Answer(item(1))
      asked = {}
      verdicts[link(1)] = false
      signal()
      assert.is_true(pawn:Answer(item(1)), "the old arrow stays")
      assert.are.equal(0, #asked)
    end)

    it("asks about every item held, once, then stops", function()
      signal()
      settle()
      assert.are.equal(5, #asked)
      for i = 1, 5 do
        assert.are.equal(1, count(asked, link(i)), "item " .. i)
      end
      assert.are.equal(0, #timers)
    end)

    it("asks nothing when it fires with no items", function()
      slotInfo = {}
      signal()
      assert.are.equal(0, #timers)
      assert.are.equal(0, #asked)
    end)

    it("asks about items in every bag read, each link once", function()
      hold(BANK, { 1, 2, 90 })
      addon.atBank = true
      signal()
      settle()
      assert.are.equal(6, #asked)
      assert.are.equal(1, count(asked, link(1)))
      assert.are.equal(1, count(asked, link(90)))
    end)

    it("asks first about what shows no answer yet", function()
      hold(BACKPACK, ids(1, 40))
      sweep(BACKPACK)
      settle()
      asked = {}
      local held = slotInfo[BACKPACK].itemsBySlotKey
      local new = {}
      for i = 101, 105 do
        held["new" .. i] = item(i)
        new[link(i)] = true
      end
      signal()
      turns(1)
      for i = 1, 5 do
        assert.is_true(new[asked[i]] == true, "question " .. i .. " was about an item that shows an answer")
      end
    end)

    it("does not ask about a caged pet", function()
      slotInfo[BACKPACK].itemsBySlotKey.cage = { itemInfo = { itemLink = "|Hbattlepet:635:1:3:152:13:12:0|h[item:5]|h" } }
      signal()
      settle()
      assert.are.equal(5, #asked)
    end)
  end)

  -- Asked: "let's consider what happens when we have multiple callbacks fire (do we clear the queue if there is one/if there
  -- are items waiting on the timer?)". It is not cleared: what waits keeps its turn, what was answered goes behind it.
  describe("several signals", function()
    before_each(function()
      hold(BACKPACK, ids(1, 40))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    it("leaves one timer however many fire while it waits", function()
      signal()
      signal()
      signal()
      assert.are.equal(1, #timers)
    end)

    it("puts each link in the queue once, so a burst costs one round", function()
      for _ = 1, 10 do
        signal()
      end
      settle()
      assert.are.equal(40, #asked)
      for i = 1, 40 do
        assert.are.equal(1, count(asked, link(i)), "item " .. i)
      end
    end)

    it("asks again what was answered before the latest signal, and only that", function()
      signal()
      turns(1)
      local first = #asked
      assert.is_true(first > 0 and first < 40, "part of the way: " .. first)
      signal()
      settle()
      assert.are.equal(40 + first, #asked)
      for i = 1, 40 do
        local times = count(asked, link(i))
        assert.is_true(times == 1 or times == 2, "item " .. i .. " asked " .. times)
      end
    end)

    it("ends with every answer from after the latest signal", function()
      signal()
      turns(1)
      for i = 1, 40 do
        verdicts[link(i)] = true
      end
      signal()
      settle()
      for i = 1, 40 do
        assert.is_true(pawn:Answer(item(i)), "item " .. i)
      end
      assert.are.equal(0, #timers, "looking at them asks nothing more")
    end)

    it("keeps the turn of what was waiting: it goes before what is asked again", function()
      signal()
      turns(1)
      local first = #asked
      local notYet = link(40)
      assert.are.equal(0, count(asked, notYet))
      signal()
      asked = {}
      turns(1)
      assert.is_true(#asked > 0)
      local waitedBefore = {}
      for i = first + 1, 40 do
        waitedBefore[link(i)] = true
      end
      for _, l in ipairs(asked) do
        assert.is_true(waitedBefore[l] == true, "an item answered before was asked ahead of one still waiting")
      end
    end)

    -- Looting fast: Pawn signals every quarter second, for as long as it goes on.
    it("starves nothing under a signal every turn", function()
      local seen = {}
      for _ = 1, 60 do
        signal()
        turns(1)
        for _, l in ipairs(asked) do
          seen[l] = true
        end
      end
      for i = 1, 40 do
        assert.is_true(seen[link(i)] == true, "item " .. i .. " was never asked")
      end
    end)

    it("stays within Pawn's budget each turn, under a signal every turn", function()
      for _ = 1, 20 do
        signal()
        local before, at = #asked, now
        turns(1)
        local spent = (#asked - before) * ASK
        assert.is_true(spent <= 2 / 60 / 4 + ASK, "a turn spent " .. spent .. " at " .. at)
      end
    end)

    it("settles once the signals stop", function()
      for _ = 1, 10 do
        signal()
        turns(1)
      end
      settle()
      assert.are.equal(0, #timers)
      local total = #asked
      turns(20)
      assert.are.equal(total, #asked, "nothing more")
    end)

    it("does not grow the queue under a signal every turn", function()
      for _ = 1, 50 do
        signal()
        turns(1)
      end
      assert.is_true(pawn:Waiting() <= 40, "waiting: " .. pawn:Waiting())
    end)

    it("survives Pawn signalling from inside its own answer", function()
      local fired = false
      verdicts[link(1)] = function()
        if not fired then
          fired = true
          signal()
        end
        return false
      end
      signal()
      settle()
      assert.are.equal(0, #timers)
      assert.are.equal(2, count(asked, link(1)), "asked again: the signal came after it was asked")
    end)
  end)

  describe("what is waiting on a read", function()
    it("does not ask again what a read answered while it waited", function()
      verdicts[link(1)] = "not sure"
      pawn:Answer(item(1))
      asked = {}
      verdicts[link(1)] = false
      assert.is_false(pawn:Answer(item(1)))
      assert.are.equal(1, #asked)
      settle()
      assert.are.equal(1, #asked)
    end)

    it("puts an item it has never seen before what is only being checked again", function()
      hold(BACKPACK, ids(1, 40))
      sweep(BACKPACK)
      settle()
      asked = {}
      signal()
      turns(1)
      local new = link(99)
      -- Spend the budget, as a read of a full bag does.
      verdicts[new] = "not sure"
      pawn:Answer(item(99))
      local tries = count(asked, new)
      verdicts[new] = false
      asked = {}
      turns(1)
      assert.are.equal(new, asked[1], "first of its turn, tried " .. tries .. " times in the read")
    end)

    it("shows an answer a read found to the other bag that waited on it", function()
      hold(BANK, { 7 })
      addon.atBank = true
      verdicts[link(7)] = "not sure"
      sweep(BANK)
      verdicts[link(7)] = true
      assert.is_true(pawn:Answer(item(7, BACKPACK)), "a read of the backpack found it")
      settle()
      assert.are.equal(1, #sent)
      assert.is_true(sent[1].options.bank)
    end)

    -- Gear, level, skills and spec also start a generation (caches.md §2), and a read follows it.
    it("checks again what a generation made stale, on the next read, keeping its arrow", function()
      verdicts[link(1)] = true
      pawn:Answer(item(1))
      asked = {}
      generation = generation + 1
      verdicts[link(1)] = false
      assert.is_true(pawn:Answer(item(1)), "the old arrow, for now")
      assert.are.equal(0, #asked, "not in the read")
      settle()
      assert.are.equal(1, #asked)
      assert.is_false(pawn:Answer(item(1)))
    end)

    it("asks nothing when nothing is stale", function()
      verdicts[link(1)] = true
      pawn:Answer(item(1))
      asked = {}
      for _ = 1, 5 do
        pawn:Answer(item(1))
      end
      assert.are.equal(0, #asked)
      assert.are.equal(0, #timers)
    end)
  end)

  -- Every bag item's link carries the player's level and spec (spec/fixtures/dump_retail_12_1_5.lua: |Hitem:6948::::::::90:66:...),
  -- so a level-up or a respec changes every link in the bags. Found by an adversarial review: answers kept by the whole link took
  -- every arrow away for seconds, and the links nothing held any more stayed in the queue.
  describe("a link that follows the player's level and spec", function()
    local function levelled(id, level, spec, enchant)
      return "|cnIQ1:|Hitem:" .. id .. ":" .. (enchant or "") .. ":::::::" .. level .. ":" .. spec .. ":::::::::|h[Item " .. id .. "]|h|r"
    end

    local function holding(linkOf)
      local held = {}
      for i = 1, 5 do
        held[i] = { itemInfo = { itemLink = linkOf(i) }, kind = BACKPACK }
      end
      slotInfo[BACKPACK] = { itemsBySlotKey = held }
    end

    it("keeps its arrow through the change, asks nothing in the read, then checks the link the bags hold", function()
      local before, after = levelled(1, 90, 66), levelled(1, 91, 66)
      verdicts[before] = true
      assert.is_true(pawn:Answer({ itemInfo = { itemLink = before } }))
      asked = {}
      generation = generation + 1
      verdicts[after] = false
      assert.is_true(pawn:Answer({ itemInfo = { itemLink = after } }), "the old arrow, for now")
      assert.are.equal(0, #asked, "not in the read")
      settle()
      assert.are.same({ after }, asked)
      assert.is_false(pawn:Answer({ itemInfo = { itemLink = after } }))
    end)

    it("follows a change of spec the same way", function()
      local before, after = levelled(1, 90, 66), levelled(1, 90, 65)
      verdicts[before] = true
      pawn:Answer({ itemInfo = { itemLink = before } })
      asked = {}
      assert.is_true(pawn:Answer({ itemInfo = { itemLink = after } }))
      assert.are.equal(0, #asked)
    end)

    it("asks only about the links the bags hold now, each once, when the signal came before the read", function()
      holding(function(i) return levelled(i, 90, 66) end)
      sweep(BACKPACK)
      settle()
      asked = {}
      signal()
      holding(function(i) return levelled(i, 90, 65) end)
      sweep(BACKPACK)
      settle()
      table.sort(asked)
      local want = {}
      for i = 1, 5 do want[i] = levelled(i, 90, 65) end
      table.sort(want)
      assert.are.same(want, asked)
    end)

    it("recalculates the bag holding the new link when its answer changes", function()
      local before, after = levelled(1, 90, 66), levelled(1, 91, 66)
      verdicts[before] = true
      pawn:Answer({ itemInfo = { itemLink = before } })
      sent = {}
      slotInfo[BACKPACK] = { itemsBySlotKey = { a = { itemInfo = { itemLink = after } } } }
      verdicts[after] = false
      signal()
      settle()
      assert.are.same({ backpack = true, bank = false, guild = false, categoriesUnchanged = true }, sent[1].options)
    end)

    -- From spec/fixtures/dump_retail_12_1_5.lua: the name can hold colons and a texture of its own, and bonus IDs come after both fields.
    for name, parts in pairs({
      plain = { "|cnIQ1:|Hitem:6948::::::::", ":::::::::|h[Hearthstone]|h|r" },
      ["bonus IDs and a quality in its name"] = { "|cnIQ3:|Hitem:243984::::::::",
        "::::2:38:13:40:3814:::::|h[Enchant Ring - Nature's Wrath |A:Professions-ChatIcon-Quality-12-Tier1:17:15::1|a]|h|r" },
      ["no color of its kind"] = { "|cffffffff|Hitem:6948::::::::", ":::::::::|h[Hearthstone]|h|r" },
    }) do
      it("keeps one answer for a real link, " .. name, function()
        verdicts[parts[1] .. "90:66" .. parts[2]] = true
        assert.is_true(pawn:Answer({ itemInfo = { itemLink = parts[1] .. "90:66" .. parts[2] } }))
        asked = {}
        assert.is_true(pawn:Answer({ itemInfo = { itemLink = parts[1] .. "91:65" .. parts[2] } }))
        assert.are.equal(0, #asked)
      end)
    end

    it("tells apart real links that differ past those two fields", function()
      local one = "|cnIQ3:|Hitem:243984::::::::90:66::::2:38:13:40:3814:::::|h[Enchant]|h|r"
      local other = "|cnIQ3:|Hitem:243984::::::::90:66::::2:38:13:40:2590:::::|h[Enchant]|h|r"
      local gem = "|cnIQ3:|Hitem:243984::999:::::::90:66::::2:38:13:40:3814:::::|h[Enchant]|h|r"
      local unique = "|cnIQ3:|Hitem:243984:::::::77:90:66::::2:38:13:40:3814:::::|h[Enchant]|h|r"
      for _, itemLink in ipairs({ one, other, gem, unique }) do
        pawn:Answer({ itemInfo = { itemLink = itemLink } })
      end
      assert.are.equal(4, #asked)
    end)

    it("is another item with another enchant, or another item ID", function()
      verdicts[levelled(1, 90, 66)] = true
      pawn:Answer({ itemInfo = { itemLink = levelled(1, 90, 66) } })
      asked = {}
      assert.is_false(pawn:Answer({ itemInfo = { itemLink = levelled(1, 90, 66, 7000) } }))
      assert.is_false(pawn:Answer({ itemInfo = { itemLink = levelled(11, 90, 66) } }))
      assert.are.equal(2, #asked)
    end)

    it("keeps one answer however many levels pass", function()
      for level = 80, 90 do
        pawn:Answer({ itemInfo = { itemLink = levelled(1, level, 66) } })
      end
      local kept = 0
      for _ in pairs(pawn.answers) do kept = kept + 1 end
      assert.are.equal(1, kept)
    end)
  end)

  -- Pawn answers nil both past its budget and when it has no data for an item, and the two look the same.
  describe("a link Pawn is not sure about", function()
    before_each(function()
      hold(BACKPACK, ids(1, 3))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    it("does not hold up the links behind it", function()
      verdicts[link(1)] = "not sure"
      verdicts[link(2)] = true
      verdicts[link(3)] = true
      signal()
      turns(3)
      assert.are.equal(1, count(asked, link(2)))
      assert.are.equal(1, count(asked, link(3)))
    end)

    it("stops asking for the turn: nil may mean the budget is gone", function()
      for i = 1, 3 do
        verdicts[link(i)] = "not sure"
      end
      signal()
      turns(1)
      assert.are.equal(1, #asked, "the first ask of the turn said nil")
    end)

    it("is asked again, and its answer shown when it comes", function()
      verdicts[link(1)] = "not sure"
      signal()
      turns(4)
      verdicts[link(1)] = true
      settle()
      assert.is_true(pawn:Answer(item(1)))
      assert.are.equal(1, #sent)
    end)

    it("gives up after a while, so the timer stops", function()
      verdicts[link(1)] = "not sure"
      signal()
      settle()
      assert.are.equal(0, #timers)
      assert.is_true(count(asked, link(1)) <= 21, "asked " .. count(asked, link(1)))
    end)

    it("goes on with what waits behind it when it gives up", function()
      verdicts[link(1)] = "not sure"
      signal()
      -- Until it has one try left, alone in the queue, then a signal puts the others behind it.
      turns(19)
      local tries = count(asked, link(1))
      assert.are.equal(19, tries)
      asked = {}
      signal()
      settle()
      assert.are.equal(1, count(asked, link(2)))
      assert.are.equal(1, count(asked, link(3)))
      assert.are.equal(0, #timers)
    end)

    -- Found by an adversarial review: it was told to no bag, since nothing waited on the link any more.
    it("tells the other bag when a read answers a link it gave up on", function()
      hold(BANK, { 7 })
      addon.atBank = true
      verdicts[link(7)] = "not sure"
      sweep(BANK)
      settle()
      assert.are.equal(0, #timers, "given up")
      verdicts[link(7)] = true
      assert.is_true(pawn:Answer(item(7, BACKPACK)))
      settle()
      assert.are.equal(1, #sent)
      assert.is_true(sent[1].options.bank)
    end)

    it("tells it in combat too: nothing asks Pawn there, and the bags can be recalculated", function()
      hold(BANK, { 7 })
      addon.atBank = true
      verdicts[link(7)] = "not sure"
      sweep(BANK)
      settle()
      inCombat = true
      verdicts[link(7)] = true
      pawn:Answer(item(7, BACKPACK))
      settle()
      assert.are.equal(1, #sent)
    end)

    it("keeps its old answer when it gives up", function()
      verdicts[link(1)] = true
      pawn:Forget()
      pawn:Answer(item(1))
      verdicts[link(1)] = "not sure"
      signal()
      settle()
      assert.is_true(pawn:Answer(item(1)))
    end)

    it("is tried again on the next read after giving up, from no tries", function()
      verdicts[link(1)] = "not sure"
      signal()
      settle()
      local before = count(asked, link(1))
      pawn:Answer(item(1))
      settle()
      assert.is_true(count(asked, link(1)) > before + 1, "tried again")
      verdicts[link(1)] = false
      pawn:Answer(item(1))
      settle()
      assert.are.equal(0, #timers)
    end)

    it("forgets its tries once it answers", function()
      verdicts[link(1)] = "not sure"
      signal()
      turns(5)
      verdicts[link(1)] = false
      settle()
      asked = {}
      verdicts[link(1)] = "not sure"
      signal()
      settle()
      assert.is_true(count(asked, link(1)) >= 19, "a full set of tries, not what was left: " .. count(asked, link(1)))
    end)
  end)

  -- Asked: "let's take care not to trigger full redraws".
  describe("when an answer changes", function()
    before_each(function()
      hold(BACKPACK, ids(1, 3))
      verdicts[link(1)] = true
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    -- The reported case: a loot, every answer the same as it was.
    it("recalculates nothing when no answer changed", function()
      signal()
      settle()
      assert.are.equal(3, #asked)
      assert.are.equal(0, #sent)
    end)

    it("shows a change once: the round after it recalculates nothing", function()
      verdicts[link(1)] = false
      signal()
      settle()
      assert.are.equal(1, #sent)
      sent = {}
      signal()
      settle()
      assert.are.equal(0, #sent)
    end)

    it("does not look through the bags when no answer changed", function()
      signal()
      local looked = 0
      local slots = items.GetAllSlotInfo
      items.GetAllSlotInfo = function(...)
        looked = looked + 1
        return slots(...)
      end
      settle()
      items.GetAllSlotInfo = slots
      assert.are.equal(0, looked)
    end)

    -- No arrow moves, so nothing is worth a recalculation a second, as a first read of a big bag would ask for. But the item has no
    -- upgrade field and Automation leaves it alone until it has an answer (caches.md §2a), so the answer has to reach it.
    it("shows first answers that are no upgrade once, when the round is done", function()
      hold(BACKPACK, ids(1, 80))
      sweep(BACKPACK)
      turns(1)
      assert.is_true(pawn:Waiting() > 0, "still going")
      assert.are.equal(0, #sent, "no arrow moved")
      settle()
      assert.are.equal(1, #sent)
    end)

    -- The spent budget leaves them waiting in this order, the last asked at the front.
    it("recalculates for an arrow in the turn it changes, then leaves first answers for the end", function()
      pawn:Forget()
      hold(BACKPACK, ids(1, 60))
      for i = 60, 1, -1 do
        verdicts[link(i)] = "not sure"
        pawn:Answer(item(i))
      end
      for i = 1, 60 do
        verdicts[link(i)] = i == 1
      end
      sent = {}
      turns(1)
      assert.is_true(pawn:Waiting() > 0, "still going")
      assert.are.equal(1, #sent, "the arrow, though a first answer that moves none came after it")
      settle()
      assert.is_true(now > 101, "past a second of recalculating for arrows")
      assert.are.equal(2, #sent, "and once more at the end")
    end)

    -- Found by an adversarial review: a round that never ends, at the bank with something moved every few seconds, kept them for minutes.
    it("does not keep them past five seconds in a round that goes on", function()
      pawn:Forget()
      hold(BACKPACK, ids(1, 300))
      sweep(BACKPACK)
      sent = {}
      turns(19)
      assert.are.equal(0, #sent, "under five seconds")
      turns(2)
      assert.is_true(pawn:Waiting() > 0, "still going")
      assert.are.equal(1, #sent)
    end)

    it("counts those five seconds again after it shows them", function()
      pawn:Forget()
      hold(BACKPACK, ids(1, 800))
      sweep(BACKPACK)
      sent = {}
      turns(21)
      assert.are.equal(1, #sent)
      turns(18)
      assert.are.equal(1, #sent, "under five more")
      turns(3)
      assert.is_true(pawn:Waiting() > 0, "still going")
      assert.are.equal(2, #sent)
    end)

    it("takes them along with a recalculation for an arrow, and has nothing left to show after it", function()
      hold(BACKPACK, ids(1, 15))
      for i = 4, 15 do
        verdicts[link(i)] = i % 2 == 0
      end
      sweep(BACKPACK)
      settle()
      local first = #sent
      assert.is_true(first >= 1)
      sent = {}
      signal()
      settle()
      assert.are.equal(0, #sent)
    end)

    it("reaches the bag holding a first answer", function()
      hold(BANK, { 50 })
      addon.atBank = true
      signal()
      settle()
      assert.are.same({ backpack = false, bank = true, guild = false, categoriesUnchanged = true }, sent[1].options)
    end)

    it("recalculates when an arrow goes away", function()
      verdicts[link(1)] = false
      signal()
      settle()
      assert.are.equal(1, #sent)
    end)

    it("recalculates when an arrow appears", function()
      verdicts[link(2)] = true
      signal()
      settle()
      assert.are.equal(1, #sent)
    end)

    it("asks for a recalculation that keeps categories and draws no button in full", function()
      verdicts[link(1)] = false
      signal()
      settle()
      assert.are.same({
        message = "bags/Rederive",
        options = { backpack = true, bank = false, guild = false, categoriesUnchanged = true },
      }, sent[1])
      assert.is_nil(sent[1].options.buttons)
      assert.is_nil(sent[1].options.resetLayout)
    end)

    it("recalculates only the bag holding it", function()
      hold(BANK, { 50 })
      addon.atBank = true
      signal()
      verdicts[link(50)] = true
      settle()
      assert.are.same({ backpack = false, bank = true, guild = false, categoriesUnchanged = true }, sent[1].options)
    end)

    it("recalculates every open bag holding it", function()
      hold(BANK, { 1 })
      hold(GUILD, { 1 })
      addon.atBank, addon.atGuildBank = true, true
      verdicts[link(1)] = false
      signal()
      settle()
      assert.are.same({ backpack = true, bank = true, guild = true, categoriesUnchanged = true }, sent[1].options)
    end)

    it("does not recalculate a closed bank or guild bank", function()
      hold(BANK, { 1 })
      hold(GUILD, { 1 })
      verdicts[link(1)] = false
      signal()
      settle()
      assert.are.same({ backpack = true, bank = false, guild = false, categoriesUnchanged = true }, sent[1].options)
    end)

    it("recalculates nothing for an item no bag holds any more", function()
      verdicts[link(1)] = false
      signal()
      hold(BACKPACK, { 2, 3 })
      settle()
      assert.are.equal(0, #sent)
    end)

    it("recalculates at most once a second while others wait, and once more when they are done", function()
      hold(BACKPACK, ids(1, 120))
      sweep(BACKPACK)
      settle()
      sent = {}
      for i = 1, 120 do
        verdicts[link(i)] = i % 2 == 0
      end
      signal()
      local start = now
      settle()
      local took = now - start
      assert.is_true(took > 2, "took " .. took)
      assert.is_true(#sent >= math.floor(took), "shown as they came: " .. #sent .. " in " .. took .. " seconds")
      assert.is_true(#sent <= math.ceil(took) + 1, #sent .. " recalculations in " .. took .. " seconds")
    end)

    it("loses no change when the last answers come inside that second", function()
      verdicts[link(1)] = false
      signal()
      settle()
      sent = {}
      verdicts[link(2)] = true
      signal()
      settle()
      assert.are.equal(1, #sent, "the queue is done: nothing is left to carry it")
    end)
  end)

  -- Pawn's own start-up can fail, and it answers nothing then, printing a failure each time. Found by an adversarial review: every item
  -- stayed "not known", which stopped Auto Sell for good. PawnIsReady is Pawn's API for this.
  describe("while Pawn is not ready", function()
    it("gives no arrow, says it knows that, and asks Pawn nothing", function()
      ready = false
      assert.is_false(pawn:Answer(item(1)))
      assert.are.equal(0, #asked)
      assert.are.equal(0, #timers)
    end)

    it("leaves nothing waiting, and asks Pawn nothing", function()
      hold(BACKPACK, { 1, 2 })
      ready = false
      signal()
      settle()
      assert.are.equal(0, #asked)
      assert.are.equal(0, pawn:Waiting())
    end)

    it("asks once Pawn is ready", function()
      ready = false
      pawn:Answer(item(1))
      ready = true
      verdicts[link(1)] = true
      assert.is_true(pawn:Answer(item(1)))
    end)
  end)

  describe("forgetting", function()
    it("drops what it had yet to show", function()
      verdicts[link(1)] = true
      hold(BACKPACK, { 1 })
      signal()
      turns(1)
      pawn.changed[link(1)], pawn.arrowChanged = true, true
      pawn:Forget()
      assert.is_nil(next(pawn.changed))
      assert.is_false(pawn.arrowChanged)
    end)
  end)

  describe("in combat", function()
    before_each(function()
      hold(BACKPACK, ids(1, 5))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    it("asks nothing, and goes on once it is over", function()
      inCombat = true
      signal()
      turns(10)
      assert.are.equal(0, #asked)
      assert.are.equal(1, #timers, "one timer still")
      inCombat = false
      settle()
      assert.are.equal(5, #asked)
    end)

    it("leaves nothing on the timer when nothing waits", function()
      signal()
      pawn:Forget()
      inCombat = true
      turns(1)
      assert.are.equal(0, #timers)
    end)

    it("keeps the old answers meanwhile", function()
      verdicts[link(1)] = true
      pawn:Forget()
      pawn:Answer(item(1))
      inCombat = true
      verdicts[link(1)] = false
      signal()
      turns(4)
      assert.is_true(pawn:Answer(item(1)))
    end)

    it("still answers about an item it has never seen, within Pawn's budget", function()
      inCombat = true
      verdicts[link(50)] = true
      assert.is_true(pawn:Answer(item(50)))
    end)
  end)

  describe("when Pawn is not the provider in use", function()
    before_each(function()
      hold(BACKPACK, ids(1, 5))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    it("does nothing with the signal: no generation, no timer, no question", function()
      provider = "BetterBags"
      local before = generation
      signal()
      assert.are.equal(before, generation, "the built-in provider's kept verdicts stand")
      assert.are.equal(0, #timers)
      assert.are.equal(0, #asked)
    end)

    it("drops what waits, and stops, when the player switches away mid-round", function()
      signal()
      turns(0)
      provider = "None"
      settle()
      assert.are.equal(0, #asked)
      assert.are.equal(0, #timers)
      assert.are.equal(0, pawn:Waiting())
    end)

    -- It missed Pawn's signals meanwhile, so what it knew may be out of date.
    it("asks afresh after being switched back", function()
      provider = "None"
      signal()
      provider = "Pawn"
      verdicts[link(1)] = true
      assert.is_true(pawn:Answer(item(1)))
      assert.are.same({ link(1) }, asked)
    end)
  end)

  describe("an error from Pawn", function()
    it("does not leave the queue stuck: the next signal goes on", function()
      hold(BACKPACK, ids(1, 5))
      sweep(BACKPACK)
      settle()
      asked = {}
      verdicts[link(1)] = function() error("Pawn broke") end
      signal()
      local ok = pcall(turns, 1)
      assert.is_false(ok)
      verdicts[link(1)] = false
      signal()
      settle()
      for i = 1, 5 do
        assert.is_true(count(asked, link(i)) >= 1, "item " .. i)
      end
      assert.are.equal(0, #timers)
    end)
  end)

  -- The capture on issue #1209: 163 items, Pawn 0.87 ms a question, two loots a third of a second apart, every answer
  -- unchanged. Each cost about 141 ms in Pawn, in one frame, while the bags were closed.
  describe("the reported loot", function()
    before_each(function()
      hold(BACKPACK, ids(1, 163))
      sweep(BACKPACK)
      settle()
      asked = {}
      sent = {}
    end)

    local function loot(id)
      local start = now
      signal()
      local held = slotInfo[BACKPACK].itemsBySlotKey
      held["loot" .. id] = item(id)
      sweep(BACKPACK)
      return now - start
    end

    it("costs one question, for the item looted, in the frame it happens", function()
      local spent = loot(200)
      assert.are.same({ link(200) }, asked)
      assert.is_true(spent < 0.002, "spent " .. spent)
    end)

    it("checks the rest a few at a time, never more than Pawn's budget in a turn", function()
      loot(200)
      local most = 0
      while #timers > 0 do
        local before = #asked
        advance(0.25)
        most = math.max(most, #asked - before)
      end
      assert.is_true(most * ASK <= 2 / 60 / 4 + ASK, "most in a turn: " .. most)
    end)

    it("finishes in a few seconds, asks each item once, and recalculates nothing", function()
      local start = now
      loot(200)
      settle()
      assert.are.equal(164, #asked)
      assert.are.equal(0, #sent)
      assert.is_true(now - start < 6, "took " .. (now - start))
    end)

    -- The second loot finds Pawn's budget spent on the first one's round, so its first answer has to reach it: one recalculation.
    it("two loots a third of a second apart ask each item at most twice, and recalculate at most once", function()
      loot(200)
      advance(0.33)
      loot(201)
      settle()
      for i = 1, 163 do
        assert.is_true(count(asked, link(i)) <= 2, "item " .. i)
      end
      assert.is_true(#sent <= 1, "recalculated " .. #sent)
    end)
  end)
end)
