-- automation_spec.lua -- What a category does with its items on its own (data/automation.lua,
-- .claude/rules/automation.md): sell them when a merchant opens, or destroy them one at a time.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local context = addon:GetModule("Context")
ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")

ResetModuleStub("Items")
ResetModuleStub("Categories")
local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
local items = StubBetterBagsModule("Items")
local categories = StubBetterBagsModule("Categories")
local events = StubBetterBagsModule("Events")
-- Every sale goes through the seller (data/seller.lua), one item at a time.
ResetModuleStub("Seller", "data/seller.lua")
LoadBetterBagsModule("data/seller.lua")
local seller = addon:GetModule("Seller")
ResetModuleStub("Automation", "data/automation.lua")
LoadBetterBagsModule("data/automation.lua")
local automation = addon:GetModule("Automation")

local BACKPACK = 0

describe("Automation", function()
  local saved, slots, actions, ofCategory, timers, printed, used, picked, deleted, cursor, shift, combat
  local buys, refundable, registered, asked, messages, confirms

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  -- put puts an item in a backpack slot, as the bags last read it (data) and as the client has it now
  -- (live, guid): its category, its price and what it is.
  local function put(bag, slot, id, category, extra)
    extra = extra or {}
    local key = bag .. "_" .. slot
    local data = {
      bagid = bag, slotid = slot, slotkey = key, kind = BACKPACK, isItemEmpty = false,
      harvestIncomplete = extra.cold,
      itemInfo = { itemID = id, itemGUID = "guid-" .. key, itemLink = "[Item " .. id .. "]", sellPrice = 5,
        traits = { sellPrice = extra.price or 100 }, equipmentSets = extra.sets, refundable = extra.refundable == true },
      containerInfo = { hasNoValue = extra.noValue == true, stackCount = extra.count or 1 },
    }
    slots[key] = { data = data, live = { stackCount = extra.count or 1, hasNoValue = extra.noValue == true,
      isLocked = false }, guid = "guid-" .. key }
    refundable[key] = extra.refundable == true
    ofCategory[key] = category
    return data
  end

  -- run runs the timers due now (one frame of the sale), returning how many ran.
  local function run()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do t.fn() end
    return #due
  end

  local function sell()
    local status = automation:OnMerchantShow(ctx())
    for _ = 1, 100 do
      if run() == 0 then break end
    end
    return status
  end

  before_each(function()
    saved, slots, ofCategory, timers, printed, used, picked, deleted, asked = {}, {}, {}, {}, {}, {}, {}, 0, {}
    actions = { Junk = "sell", Trash = "destroy", Mats = nil }
    -- Which categories confirm their sale in BetterBags Next's dock: none here, so a sale sells at once.
    confirms = {}
    cursor, shift, combat, buys, refundable, registered = false, false, false, true, {}, {}
    messages = {}
    automation:Init()
    -- The committed items: rebuilt from the slots each time they are read.
    override(items, "slotInfo", setmetatable({}, { __index = function(_, kind)
      if kind ~= BACKPACK then return nil end
      local committed = {}
      for k, s in pairs(slots) do committed[k] = s.data end
      return { itemsBySlotKey = committed }
    end }))
    override(items, "GetCategory", function(_, _, data, own, ignoreRecent)
      table.insert(asked, { own = own, ignoreRecent = ignoreRecent })
      return ofCategory[data.slotkey]
    end)
    override(categories, "AutomationOf", function(_, name) return actions[name] end)
    override(categories, "ConfirmsSaleOf", function(_, name) return confirms[name] == true end)
    -- Both Automation and the seller listen to merchants: registered fires every listener.
    local listeners = {}
    override(events, "RegisterEvent", function(_, name, fn)
      listeners[name] = listeners[name] or {}
      table.insert(listeners[name], fn)
      registered[name] = function(...) for _, f in ipairs(listeners[name]) do f(...) end end
    end)
    override(_G, "GetNetStats", function() return 0, 0, 40, 60 end)
    override(_G, "UnitGUID", function(unit) return unit == "npc" and "Creature-7" or nil end)
    override(_G, "ERR_VENDOR_NOT_INTERESTED", "The merchant doesn't want that item.")
    override(_G, "ERR_VENDOR_DOESNT_BUY", "You cannot sell items to this merchant")
    override(events, "SendMessage", function(_, _, name) table.insert(messages, name) end)
    override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1, [2] = 2 })
    override(_G, "C_Timer", { After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end })
    override(_G, "C_Container", {
      GetContainerItemInfo = function(bag, slot)
        local s = slots[bag .. "_" .. slot]
        return s and s.live
      end,
      UseContainerItem = function(bag, slot)
        table.insert(used, bag .. "_" .. slot)
        slots[bag .. "_" .. slot] = nil
      end,
      PickupContainerItem = function(bag, slot)
        table.insert(picked, bag .. "_" .. slot)
        cursor = true
      end,
    })
    -- An item is in a slot while the client reports it (live); the bags' last read (data) can lag.
    local function exists(location)
      local bag, slot = location:GetBagAndSlot()
      local s = slots[bag .. "_" .. slot]
      return s ~= nil and s.live ~= nil
    end
    override(_G, "C_Item", {
      GetItemGUID = function(location)
        local bag, slot = location:GetBagAndSlot()
        local s = slots[bag .. "_" .. slot]
        return s and s.guid
      end,
      -- As the client: an empty slot is an error (a capture: "bad argument #1 to '?' (Usage: local
      -- canBeRefunded = C_Item.CanBeRefunded(itemLocation))").
      CanBeRefunded = function(location)
        if not exists(location) then
          error("bad argument #1 to '?' (Usage: local canBeRefunded = C_Item.CanBeRefunded(itemLocation))")
        end
        local bag, slot = location:GetBagAndSlot()
        return refundable[bag .. "_" .. slot] == true
      end,
    })
    override(_G, "C_MerchantFrame", { IsSellAllJunkEnabled = function() return buys end })
    override(_G, "C_CurrencyInfo", { GetCoinTextureString = function(copper) return copper .. "c" end })
    override(_G, "CursorHasItem", function() return cursor end)
    -- The item on the cursor is gone, and so is what its slot held.
    override(_G, "DeleteCursorItem", function()
      deleted = deleted + 1
      cursor = false
      slots[picked[#picked]] = nil
    end)
    override(_G, "IsShiftKeyDown", function() return shift end)
    override(_G, "InCombatLockdown", function() return combat end)
    override(_G, "print", function(text) table.insert(printed, text) end)
    -- The seller hears the merchant open, as the client tells it.
    seller:Init()
    seller:OnEnable()
    registered.MERCHANT_SHOW(ctx())
  end)

  after_each(function()
    for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
  end)

  describe("which items", function()
    it("lists the backpack's items whose category has an action, by bag and slot", function()
      put(1, 2, 11, "Junk")
      put(0, 3, 12, "Trash")
      put(0, 1, 13, "Mats")
      put(1, 1, 14, "Junk")
      local list = automation:Entries(ctx())
      local keys = {}
      for i, e in ipairs(list) do keys[i] = e.data.slotkey .. ":" .. e.category .. ":" .. e.action end
      assert.are.same({ "0_3:Trash:destroy", "1_1:Junk:sell", "1_2:Junk:sell" }, keys)
      assert.is_true(asked[1].ignoreRecent, "a recent item is acted on by its own category")
      assert.is_falsy(asked[1].own, "search categories count")
    end)

    -- What a docked section holds to sell and to destroy (BetterBags Next's vendor, automation.md §4):
    -- the same rules, over the items given.
    it("lists only the items given, when given", function()
      local a = put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      local c = put(0, 3, 13, "Trash", { noValue = true })
      local d = put(0, 4, 14, "Junk", { sets = { "Tank" } })
      local function keysOf(list)
        local keys = {}
        for i, e in ipairs(list) do keys[i] = e.data.slotkey end
        return keys
      end
      assert.are.same({ "0_1", "0_3", "0_4" }, keysOf(automation:Entries(ctx(), { d, c, a })))
      assert.are.same({ "0_1" }, keysOf(automation:SellList(ctx(), { a, c, d })), "never one left alone")
      assert.are.same({ "0_3" }, keysOf(automation:DestroyQueue(ctx(), { a, c })))
      assert.are.same({}, keysOf(automation:DestroyQueue(ctx(), { a })))
    end)

    -- What BetterBags Next's vendor offers in its dock for a section (automation.md §4).
    it("offers to sell, of the items given, what a confirming category holds that is still there", function()
      local a = put(0, 1, 11, "Junk")
      local b = put(0, 2, 12, "Junk")
      local c = put(0, 3, 13, "Trash")
      local d = put(0, 4, 14, "Trash", { noValue = true })
      confirms.Junk = true
      local function keysOf(list)
        local keys = {}
        for i, e in ipairs(list) do keys[i] = e.data.slotkey end
        return keys
      end
      assert.are.same({ "0_1", "0_2" }, keysOf(automation:SaleOffer(ctx(), { a, b, c, d })), "Trash sells at once")
      slots["0_2"].live.isLocked = true
      assert.are.same({ "0_1" }, keysOf(automation:SaleOffer(ctx(), { a, b })), "one selling is not offered again")
      confirms.Trash = true
      assert.are.same({ "0_3" }, keysOf(automation:SaleOffer(ctx(), { c, d })), "never one merchants do not buy")
      assert.are.same({ "0_4" }, keysOf(automation:DestroyLeft(ctx(), { a, c, d })))
      slots["0_4"] = nil
      assert.are.same({}, keysOf(automation:DestroyLeft(ctx(), { a, c, d })), "destroyed: no longer there")
    end)

    it("leaves out slots outside the backpack's bags", function()
      put(0, 1, 11, "Junk")
      put(6, 1, 12, "Junk")
      local list = automation:Entries(ctx())
      assert.are.equal(1, #list)
      assert.are.equal("0_1", list[1].data.slotkey)
    end)

    it("says why it leaves an item alone", function()
      put(0, 1, 11, "Junk", { sets = { "Tank" } })
      put(0, 2, 12, "Junk", { refundable = true })
      put(0, 3, 13, "Junk", { noValue = true })
      put(0, 4, 14, "Trash", { noValue = true })
      put(0, 5, 15, "Junk", { cold = true })
      put(0, 6, 16, "Junk")
      local reasons = {}
      for _, e in ipairs(automation:Entries(ctx())) do reasons[e.data.slotkey] = e.blocked or "none" end
      assert.truthy(reasons["0_1"]:find("equipment set", 1, true))
      assert.truthy(reasons["0_2"]:find("refunded", 1, true))
      assert.truthy(reasons["0_3"]:find("do not buy", 1, true))
      assert.are.equal("none", reasons["0_4"], "an item merchants do not buy can still be destroyed")
      assert.truthy(reasons["0_5"]:find("not loaded", 1, true))
      assert.are.equal("none", reasons["0_6"])
    end)

    -- Reported: 58 errors from CanBeRefunded on an emptied slot. A sale empties slots before the bags
    -- are read again, and BetterBags Next's vendor drew on PLAYER_MONEY and BAG_UPDATE_DELAYED in
    -- between, asking the client about the slots the last read had. What automation decides comes from
    -- that read alone; only acting asks the client, once it shows the item is still there.
    it("decides from the bags' last read, asking the client nothing, and acts only on what is still there", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash", { noValue = true })
      put(0, 3, 13, "Trash", { refundable = true, noValue = true })
      for _, key in ipairs({ "0_1", "0_2", "0_3" }) do
        slots[key].live, slots[key].guid = nil, nil
      end
      local reasons = {}
      assert.has_no.errors(function()
        for _, e in ipairs(automation:Entries(ctx())) do reasons[e.data.slotkey] = e.blocked or "none" end
      end)
      assert.are.equal("none", reasons["0_1"])
      assert.truthy(reasons["0_3"]:find("refunded", 1, true), "as the read had it")
      sell()
      assert.are.same({}, used)
      assert.are.equal("nothing", automation:DestroyNext(ctx()))
      assert.are.same({}, picked)
    end)

    -- Asked: Auto Sell, and Destroy What Can't Be Sold, which needs Auto Sell ("destroy" is both).
    it("sells what either action holds that merchants buy, and destroys only what cannot be sold", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      put(0, 3, 13, "Trash", { noValue = true })
      put(0, 4, 14, "Junk", { sets = { "Tank" } })
      put(0, 5, 15, "Trash", { sets = { "Tank" }, noValue = true })
      put(0, 6, 16, "Junk", { noValue = true })
      local function keysOf(list)
        local keys = {}
        for i, e in ipairs(list) do keys[i] = e.data.slotkey end
        return keys
      end
      assert.are.same({ "0_1", "0_2" }, keysOf(automation:SellList(ctx())))
      assert.are.same({ "0_3" }, keysOf(automation:DestroyQueue(ctx())),
        "never what a merchant buys, what it leaves alone, or what a sell-only category holds")
    end)
  end)

  describe("selling at a merchant", function()
    -- close closes the merchant, as the client does: Automation and the seller hear it.
    local function close()
      registered.MERCHANT_CLOSED(ctx())
      automation:OnMerchantClosed(ctx())
    end

    local function refuse(name)
      registered.UI_ERROR_MESSAGE(ctx(), "UI_ERROR_MESSAGE", 1, _G[name])
    end

    it("listens to the merchant opening and closing", function()
      automation:OnEnable()
      assert.is_function(registered.MERCHANT_SHOW)
      assert.is_function(registered.MERCHANT_CLOSED)
      put(0, 1, 11, "Junk")
      registered.MERCHANT_SHOW(ctx())
      registered.MERCHANT_CLOSED(ctx())
      run()
      assert.are.same({}, used, "closed before the first sale")
    end)

    -- Through the seller (asked: "dejunk's works fine"): one item at a time, the next one an interval
    -- later, after selling all at once made the client answer "That object is busy."
    it("sells one item at a time from the frame after the merchant opens, then says what it sold", function()
      put(0, 1, 11, "Junk", { count = 3, price = 100 })
      put(0, 2, 12, "Trash", { price = 50 })
      put(0, 3, 13, "Mats")
      assert.are.equal("selling", automation:OnMerchantShow(ctx()))
      assert.are.same({}, used, "nothing in the frame the merchant opens")
      run()
      assert.are.same({ "0_1" }, used)
      assert.are.same({ seller:Interval() }, { timers[1].delay })
      run()
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({}, printed, "nothing said mid-sale")
      run()
      assert.are.same({ "BetterBags: Sold 2 items for 350c." }, printed)
      assert.is_nil(automation.sale)
      assert.are.same({}, timers)
    end)

    -- Asked: "our yolo sell only sells 10 items, then stops".
    it("sells every item, however many", function()
      for slot = 1, 30 do put(1 + math.floor((slot - 1) / 20), (slot - 1) % 20 + 1, 100 + slot, "Junk") end
      sell()
      assert.are.equal(30, #used)
      assert.are.same({ "BetterBags: Sold 30 items for 3000c." }, printed)
    end)

    -- Asked: "refused items go back to the backpack until we find a merchant that buys it".
    it("leaves what this merchant refused out of what it sold, and out of the next sale here", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      C_Container.UseContainerItem = function(bag, slot)
        table.insert(used, bag .. "_" .. slot)
        if slot == 2 then slots["0_2"] = nil end
      end
      automation:OnMerchantShow(ctx())
      run()
      refuse("ERR_VENDOR_NOT_INTERESTED")
      for _ = 1, 10 do run() end
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({ "BetterBags: This merchant would not buy 1 item.", "BetterBags: Sold 1 item for 100c." },
        printed)
      used = {}
      assert.are.equal("nothing", sell(), "not offered here again")
      assert.are.same({}, used)
    end)

    it("sells nothing again at a merchant that buys nothing", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      automation:OnMerchantShow(ctx())
      run()
      refuse("ERR_VENDOR_DOESNT_BUY")
      for _ = 1, 10 do run() end
      assert.are.same({ "0_1" }, used)
      assert.is_false(automation:MerchantBuys())
      assert.are.equal("not buying", sell())
    end)

    -- Asked: "Confirm autosell", on by default; turned off, the category sells at once (automation.md §3).
    it("sells at once only the categories that do not confirm their sale", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      confirms.Junk = true
      sell()
      assert.are.same({ "0_2" }, used)
      confirms.Trash = true
      used = {}
      assert.are.equal("nothing", sell(), "every one confirms")
      assert.are.same({}, used)
    end)

    it("sells nothing while Shift is held, at a merchant that does not buy, or with nothing to sell", function()
      put(0, 1, 11, "Junk")
      shift = true
      assert.are.equal("shift", sell())
      shift, buys = false, false
      assert.are.equal("not buying", sell())
      assert.are.same({}, used)
      buys = true
      slots = {}
      assert.are.equal("nothing", sell())
      assert.are.same({}, printed)
    end)

    it("asks a Classic merchant whether it sells anything", function()
      _G.C_MerchantFrame = {}
      local n = 0
      override(_G, "GetMerchantNumItems", function() return n end)
      put(0, 1, 11, "Junk")
      assert.are.equal("not buying", sell())
      n = 4
      assert.are.equal("selling", sell())
      assert.are.same({ "0_1" }, used)
    end)

    it("never acts on an item without a GUID", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      for _, key in ipairs({ "0_1", "0_2" }) do
        slots[key].data.itemInfo.itemGUID = ""
        slots[key].guid = ""
      end
      slots["0_2"].data.containerInfo.hasNoValue = true
      sell()
      assert.are.same({}, used)
      assert.are.equal("nothing", automation:DestroyNext(ctx()))
      assert.are.equal(0, deleted)
    end)

    it("stops when the merchant closes, saying only what it sold", function()
      for slot = 1, 14 do put(1, slot, 100 + slot, "Junk") end
      automation:OnMerchantShow(ctx())
      run()
      run()
      close()
      for _ = 1, 10 do run() end
      assert.are.equal(2, #used)
      assert.are.same({ "BetterBags: Sold 2 items for 200c." }, printed)
      assert.are.same({}, timers)
    end)

    it("sells nothing when the merchant closed before the sale", function()
      put(0, 1, 11, "Junk")
      automation:OnMerchantShow(ctx())
      close()
      run()
      assert.are.same({}, used)
      assert.are.same({}, printed)
    end)

    it("waits while the cursor holds an item", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      automation:OnMerchantShow(ctx())
      cursor = true
      run()
      run()
      assert.are.same({}, used)
      assert.is_true(timers[1].delay > 0, "checks again a moment later")
      cursor = false
      for _ = 1, 10 do run() end
      assert.are.same({ "0_1", "0_2" }, used)
    end)

    it("skips an item that moved, locked, or can now be refunded", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      put(0, 3, 13, "Junk")
      put(0, 4, 14, "Junk")
      automation:OnMerchantShow(ctx())
      slots["0_1"].guid = "another item"
      slots["0_2"].live.isLocked = true
      refundable["0_3"] = true
      for _ = 1, 10 do run() end
      assert.are.same({ "0_4" }, used)
    end)

    it("says each sale once when the merchant reopens mid-sale, the new one selling what is left", function()
      for slot = 1, 14 do put(1, slot, 100 + slot, "Junk") end
      automation:OnMerchantShow(ctx())
      run()
      run()
      automation:OnMerchantShow(ctx())
      assert.are.same({ "BetterBags: Sold 2 items for 200c." }, printed, "the first sale ends")
      for _ = 1, 40 do run() end
      assert.are.equal(14, #used, "each item once")
      assert.are.same({ "BetterBags: Sold 2 items for 200c.", "BetterBags: Sold 12 items for 1200c." }, printed)
    end)

    it("sells once when the merchant reopened before the sale", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      automation:OnMerchantShow(ctx())
      automation:OnMerchantShow(ctx())
      for _ = 1, 10 do run() end
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({ "BetterBags: Sold 2 items for 200c." }, printed)
      assert.are.same({}, timers)
    end)
  end)

  -- What BetterBags Next's vendor shows on its destroy card (automation.md §4), and what a click
  -- destroys: what destroy categories hold that cannot be sold.
  describe("the destroy queue", function()
    local function keysOf(list)
      local keys = {}
      for i, e in ipairs(list) do keys[i] = e.data.slotkey end
      return keys
    end

    it("lists what destroy categories hold that cannot be sold, as the bags were last read", function()
      put(0, 1, 11, "Trash", { noValue = true })
      put(0, 2, 12, "Trash", { noValue = true })
      put(0, 3, 13, "Junk", { noValue = true })
      put(0, 4, 14, "Trash")
      slots["0_2"].guid = "another item"
      assert.are.same({ "0_1", "0_2" }, keysOf(automation:DestroyQueue(ctx())))
    end)

    it("never shares an item with a sale", function()
      put(0, 1, 11, "Trash")
      put(0, 2, 12, "Trash", { noValue = true })
      automation:OnMerchantShow(ctx())
      assert.are.same({ "0_2" }, keysOf(automation:DestroyQueue(ctx())))
      assert.are.equal("destroyed", automation:DestroyNext(ctx()))
      assert.are.same({ "0_2" }, picked)
      run()
      assert.are.same({ "0_1" }, used)
    end)

    it("says when it may have changed: an item destroyed", function()
      put(0, 1, 11, "Trash")
      put(0, 2, 12, "Trash", { noValue = true })
      automation:OnMerchantShow(ctx())
      run()
      assert.are.same({}, messages, "a sale changes nothing it holds")
      automation:DestroyNext(ctx())
      assert.are.same({ "automation/Changed" }, messages)
      automation:DestroyNext(ctx())
      assert.are.equal(1, #messages, "nothing destroyed")
    end)
  end)

  describe("destroying", function()
    it("destroys the next item a destroy category holds that cannot be sold, one a press", function()
      put(0, 1, 11, "Junk", { noValue = true })
      put(0, 2, 12, "Trash", { noValue = true })
      put(0, 3, 13, "Trash", { noValue = true })
      assert.are.equal("destroyed", automation:DestroyNext(ctx()))
      assert.are.same({ "0_2" }, picked)
      assert.are.equal(1, deleted)
      assert.are.same({ "BetterBags: Destroyed [Item 12]." }, printed)
    end)

    it("does nothing while the cursor holds an item, in combat, or with nothing to destroy", function()
      put(0, 1, 11, "Trash", { noValue = true })
      cursor = true
      assert.are.equal("cursor", automation:DestroyNext(ctx()))
      cursor, combat = false, true
      assert.are.equal("combat", automation:DestroyNext(ctx()))
      combat = false
      actions.Trash = nil
      assert.are.equal("nothing", automation:DestroyNext(ctx()))
      assert.are.same({}, picked)
      assert.are.equal(0, deleted)
      assert.are.equal(3, #printed)
    end)

    it("skips an item that moved, and destroys the next one", function()
      put(0, 1, 11, "Trash", { noValue = true })
      put(0, 2, 12, "Trash", { noValue = true })
      slots["0_1"].guid = "another item"
      automation:DestroyNext(ctx())
      assert.are.same({ "0_2" }, picked)
    end)

    it("never destroys what a merchant would buy, even away from one", function()
      put(0, 1, 11, "Trash")
      assert.are.equal("nothing", automation:DestroyNext(ctx()))
      assert.are.equal(0, deleted)
    end)

    it("destroys the next item of the items given, when given", function()
      put(0, 1, 11, "Trash", { noValue = true })
      local b = put(0, 2, 12, "Trash", { noValue = true })
      assert.are.equal("destroyed", automation:DestroyNext(ctx(), { b }))
      assert.are.same({ "0_2" }, picked)
      assert.are.equal("nothing", automation:DestroyNext(ctx(), { b }), "nothing left of them")
    end)

    it("destroys nothing it could not pick up", function()
      put(0, 1, 11, "Trash", { noValue = true })
      _G.C_Container.PickupContainerItem = function() end
      assert.are.equal("not picked up", automation:DestroyNext(ctx()))
      assert.are.equal(0, deleted)
    end)

    it("is what the Destroy Next Item key does", function()
      put(0, 1, 11, "Trash", { noValue = true })
      BetterBags_DestroyNextItem()
      assert.are.equal(1, deleted)
    end)
  end)
end)
