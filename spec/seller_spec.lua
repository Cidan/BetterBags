-- seller_spec.lua -- Seller (data/seller.lua): every sale to a merchant, one item at a time at Dejunk's
-- pace (asked: "dejunk's works fine"), after selling a sale's items all at once hit the client's "That
-- object is busy." A merchant's refusals send items back to the bags "until we find a merchant that buys
-- it" (asked). automation.md §3.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local context = addon:GetModule("Context")
ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")
local events = StubBetterBagsModule("Events")
ResetModuleStub("Seller", "data/seller.lua")
LoadBetterBagsModule("data/seller.lua")
local seller = addon:GetModule("Seller")

describe("Seller", function()
  local saved, slots, timers, used, cursor, printed, registered, npc, latency, refundable

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx() return context:New("spec") end

  -- put puts an item in a slot as the client has it, returning it as the bags last read it.
  local function put(bag, slot, extra)
    extra = extra or {}
    local key = bag .. "_" .. slot
    slots[key] = { live = { stackCount = extra.count or 1, hasNoValue = extra.noValue == true, isLocked = false },
      guid = "guid-" .. key }
    refundable[key] = extra.refundable == true
    return { bagid = bag, slotid = slot, slotkey = key, itemInfo = { itemGUID = "guid-" .. key,
      traits = { sellPrice = extra.price or 10 } } }
  end

  -- step runs the timers due now (one beat of the pace), returning their delays.
  local function step()
    local due = timers
    timers = {}
    local delays = {}
    for _, t in ipairs(due) do
      table.insert(delays, t.delay)
      t.fn()
    end
    return delays
  end

  local function drain()
    for _ = 1, 200 do
      if #timers == 0 then return end
      step()
    end
  end

  local function fail(name)
    registered.UI_ERROR_MESSAGE(ctx(), "UI_ERROR_MESSAGE", 1, _G[name])
  end

  before_each(function()
    saved, slots, timers, used, printed, registered, refundable = {}, {}, {}, {}, {}, {}, {}
    cursor, npc, latency = false, "Creature-1", { 50, 80 }
    override(events, "RegisterEvent", function(_, name, fn) registered[name] = fn end)
    override(_G, "C_Timer", { After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end })
    override(_G, "GetNetStats", function() return 0, 0, latency[1], latency[2] end)
    override(_G, "UnitGUID", function(unit) return unit == "npc" and npc or nil end)
    override(_G, "CursorHasItem", function() return cursor end)
    override(_G, "print", function(text) table.insert(printed, text) end)
    override(_G, "C_Container", {
      GetContainerItemInfo = function(bag, slot)
        local s = slots[bag .. "_" .. slot]
        return s and s.live
      end,
      UseContainerItem = function(bag, slot)
        table.insert(used, bag .. "_" .. slot)
      end,
    })
    override(_G, "C_Item", {
      GetItemGUID = function(location)
        local bag, slot = location:GetBagAndSlot()
        local s = slots[bag .. "_" .. slot]
        return s and s.guid
      end,
      CanBeRefunded = function(location)
        local bag, slot = location:GetBagAndSlot()
        return refundable[bag .. "_" .. slot] == true
      end,
    })
    for name, text in pairs({ ERR_OBJECT_IS_BUSY = "That object is busy.",
      ERR_VENDOR_NOT_INTERESTED = "The merchant doesn't want that item.",
      ERR_VENDOR_REFUSE_SCRAPPABLE_AZERITE = "The merchant doesn't want that item. Bring it to the Scrapper.",
      ERR_VENDOR_DOESNT_BUY = "You cannot sell items to this merchant",
      ERR_VENDOR_HATES_YOU = "That merchant doesn't like you.",
      ERR_VENDOR_TOO_FAR = "You are too far away." }) do
      override(_G, name, text)
    end
    seller:Init()
    seller:OnEnable()
    registered.MERCHANT_SHOW(ctx())
  end)

  after_each(function()
    for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
  end)

  describe("the pace", function()
    -- Dejunk's Addon:GetLatency: the larger of the home and world latency, at least 0.2 s.
    it("waits the larger of the home and world latency between items, at least 0.2 seconds", function()
      assert.are.equal(0.2, seller:Interval())
      latency = { 50, 350 }
      assert.are.equal(0.35, seller:Interval())
      latency = { 400, 120 }
      assert.are.equal(0.4, seller:Interval())
    end)

    it("sends one item at once, then the next one interval later, never two in a beat", function()
      local a, b, c = put(0, 1), put(0, 2), put(0, 3)
      seller:Sell({ a, b, c })
      assert.are.same({ "0_1" }, used, "the first at once")
      assert.are.same({ { 0.2 } }, { step() })
      assert.are.same({ "0_1", "0_2" }, used)
      step()
      assert.are.same({ "0_1", "0_2", "0_3" }, used)
    end)

    it("sells sales one after another on the one pace", function()
      local a, b, c = put(0, 1), put(0, 2), put(1, 1)
      seller:Sell({ a, b })
      seller:Sell({ c })
      assert.are.same({ "0_1" }, used)
      drain()
      assert.are.same({ "0_1", "0_2", "1_1" }, used)
    end)

    it("waits while the cursor holds an item", function()
      local a, b = put(0, 1), put(0, 2)
      seller:Sell({ a, b })
      cursor = true
      step()
      assert.are.same({ "0_1" }, used)
      assert.are.equal(1, #timers, "it looks again")
      cursor = false
      step()
      assert.are.same({ "0_1", "0_2" }, used)
    end)

    it("skips an item no longer there, moved, locked, refundable now, or that merchants do not buy", function()
      local list = { put(0, 1), put(0, 2), put(0, 3), put(0, 4), put(0, 5), put(0, 6) }
      slots["0_1"] = nil
      slots["0_2"].guid = "another"
      slots["0_3"].live.isLocked = true
      refundable["0_4"] = true
      slots["0_5"].live.hasNoValue = true
      seller:Sell(list)
      drain()
      assert.are.same({ "0_6" }, used)
    end)

    it("sells slots it was given without an item, as they hold now (Classic's junk)", function()
      put(0, 1)
      seller:Sell({ { bag = 0, slot = 1 } })
      assert.are.same({ "0_1" }, used)
    end)
  end)

  describe("what the merchant answers", function()
    -- Asked: "gracefully back off".
    it("tries an item the client was too busy for again later, skipping a beat first", function()
      local a, b = put(0, 1), put(0, 2)
      local job = seller:Sell({ a, b })
      fail("ERR_OBJECT_IS_BUSY")
      step()
      assert.are.same({ "0_1" }, used, "a beat with nothing sent")
      drain()
      assert.are.same({ "0_1", "0_2", "0_1" }, used)
      assert.are.equal(2, #job.sold)
    end)

    it("gives an item up after three busy tries", function()
      local a = put(0, 1)
      local job = seller:Sell({ a })
      for _ = 1, 5 do
        fail("ERR_OBJECT_IS_BUSY")
        step()
        step()
      end
      assert.are.same({ "0_1", "0_1", "0_1" }, used)
      assert.are.same({}, job.sold)
      assert.are.equal(1, job.unsold)
    end)

    -- Asked: "refused items go back to the backpack until we find a merchant that buys it".
    it("remembers an item this merchant does not want, and tries it at another merchant", function()
      local a, b = put(0, 1), put(0, 2)
      local job = seller:Sell({ a, b })
      fail("ERR_VENDOR_NOT_INTERESTED")
      drain()
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({ b }, (function()
        local out = {}
        for _, item in ipairs(job.sold) do table.insert(out, item.data) end
        return out
      end)())
      assert.are.equal(1, job.unsold)
      assert.is_true(seller:Refuses(a))
      assert.is_false(seller:Refuses(b))
      seller:Sell({ a })
      drain()
      assert.are.same({ "0_1", "0_2" }, used, "not tried again here")
      registered.MERCHANT_CLOSED(ctx())
      npc = "Creature-2"
      registered.MERCHANT_SHOW(ctx())
      assert.is_false(seller:Refuses(a), "another merchant")
      seller:Sell({ a })
      assert.are.same({ "0_1", "0_2", "0_1" }, used)
      registered.MERCHANT_CLOSED(ctx())
      npc = "Creature-1"
      registered.MERCHANT_SHOW(ctx())
      assert.is_true(seller:Refuses(a), "the first merchant still does not want it")
    end)

    it("takes the Azerite refusal as a refusal too", function()
      local a = put(0, 1)
      seller:Sell({ a })
      fail("ERR_VENDOR_REFUSE_SCRAPPABLE_AZERITE")
      drain()
      assert.is_true(seller:Refuses(a))
    end)

    it("stops every sale when the merchant buys nothing, and remembers it", function()
      local a, b, c = put(0, 1), put(0, 2), put(1, 1)
      local reasons = {}
      local first = seller:Sell({ a, b }, { onDone = function(_, why) table.insert(reasons, why) end })
      seller:Sell({ c }, { onDone = function(_, why) table.insert(reasons, why) end })
      fail("ERR_VENDOR_DOESNT_BUY")
      assert.are.same({ "refused", "refused" }, reasons, "at once")
      drain()
      assert.are.same({ "0_1" }, used)
      assert.are.same({ "refused", "refused" }, reasons)
      assert.are.equal(2, first.unsold)
      assert.is_true(seller:BuysNothing())
      assert.are.same({ "BetterBags: This merchant buys nothing." }, printed)
      seller:Sell({ b })
      assert.are.same({ "0_1" }, used, "nothing sold here again")
    end)

    it("stops when the merchant does not like the player", function()
      local a, b = put(0, 1), put(0, 2)
      seller:Sell({ a, b })
      fail("ERR_VENDOR_HATES_YOU")
      drain()
      assert.are.same({ "0_1" }, used)
      assert.is_true(seller:BuysNothing())
    end)

    it("stops when the player walked too far", function()
      local a, b = put(0, 1), put(0, 2)
      local reason
      seller:Sell({ a, b }, { onDone = function(_, why) reason = why end })
      fail("ERR_VENDOR_TOO_FAR")
      drain()
      assert.are.same({ "0_1" }, used)
      assert.are.equal("closed", reason)
      assert.is_false(seller:BuysNothing())
    end)

    it("pays no attention to errors while nothing waits for an answer, or to other errors", function()
      local a, b = put(0, 1), put(0, 2)
      fail("ERR_VENDOR_NOT_INTERESTED")
      local job = seller:Sell({ a, b })
      registered.UI_ERROR_MESSAGE(ctx(), "UI_ERROR_MESSAGE", 1, "You can't do that right now.")
      drain()
      assert.are.equal(2, #job.sold)
      assert.is_false(seller:Refuses(a))
    end)

    it("takes one answer per item", function()
      local a, b = put(0, 1), put(0, 2)
      local job = seller:Sell({ a, b })
      fail("ERR_VENDOR_NOT_INTERESTED")
      fail("ERR_OBJECT_IS_BUSY")
      drain()
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.equal(1, job.unsold)
      assert.are.equal(1, #job.sold)
    end)

    it("says only that the merchant buys nothing when it refused an item first", function()
      local a, b = put(0, 1), put(0, 2)
      seller:Sell({ a, b })
      fail("ERR_VENDOR_NOT_INTERESTED")
      step()
      fail("ERR_VENDOR_DOESNT_BUY")
      drain()
      assert.are.same({ "BetterBags: This merchant buys nothing." }, printed)
    end)

    it("says once what this merchant would not buy", function()
      local a, b, c = put(0, 1), put(0, 2), put(0, 3)
      seller:Sell({ a, b, c })
      fail("ERR_VENDOR_NOT_INTERESTED")
      step()
      fail("ERR_VENDOR_NOT_INTERESTED")
      drain()
      assert.are.same({ "BetterBags: This merchant would not buy 2 items." }, printed)
    end)
  end)

  describe("a sale", function()
    it("counts what it sold, with what each slot held, once the last one had its time to answer", function()
      local a, b = put(0, 1, { count = 3 }), put(0, 2)
      local done
      local job = seller:Sell({ a, b }, { onDone = function(j, why) done = { j, why } end })
      step()
      assert.is_nil(done, "the last one still has its interval to answer")
      step()
      assert.are.same({ job, "done" }, done)
      assert.are.same({ 3, 1 }, { job.sold[1].count, job.sold[2].count })
      assert.are.equal(0, job.unsold)
      assert.are.same({}, timers, "the pace stops with nothing to sell")
    end)

    it("says what is left after each item", function()
      local a, b = put(0, 1), put(0, 2)
      local left = {}
      seller:Sell({ a, b }, { onProgress = function(j) table.insert(left, seller:Left(j)) end })
      drain()
      assert.are.same({ 1, 0 }, left)
    end)

    it("stops when the merchant closes, what it did not send left unsold", function()
      local a, b = put(0, 1), put(0, 2)
      local reason
      local job = seller:Sell({ a, b }, { onDone = function(_, why) reason = why end })
      registered.MERCHANT_CLOSED(ctx())
      assert.are.equal("closed", reason, "at once")
      drain()
      assert.are.same({ "0_1" }, used)
      assert.are.equal("closed", reason)
      assert.are.equal(1, job.unsold)
    end)

    it("sells nothing away from a merchant", function()
      registered.MERCHANT_CLOSED(ctx())
      local reason
      seller:Sell({ put(0, 1) }, { onDone = function(_, why) reason = why end })
      assert.are.same({}, used)
      assert.are.equal("closed", reason)
    end)

    it("stops a sale its owner no longer wants (stillOpen), and one cancelled, without calling back", function()
      local a, b, c = put(0, 1), put(0, 2), put(1, 1)
      local open, calls = true, 0
      seller:Sell({ a, b }, { stillOpen = function() return open end })
      open = false
      step()
      assert.are.same({ "0_1" }, used)
      local job = seller:Sell({ c }, { onDone = function() calls = calls + 1 end })
      seller:Cancel(job)
      drain()
      assert.are.same({ "0_1", "1_1" }, used, "it was sent before the cancel")
      assert.are.equal(0, calls)
      assert.is_false(seller:IsSelling())
    end)
  end)
end)
