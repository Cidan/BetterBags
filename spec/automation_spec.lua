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
local database = StubBetterBagsModule("Database")
local events = StubBetterBagsModule("Events")
ResetModuleStub("Automation", "data/automation.lua")
LoadBetterBagsModule("data/automation.lua")
local automation = addon:GetModule("Automation")

local BACKPACK = 0

describe("Automation", function()
  local saved, slots, actions, ofCategory, timers, printed, used, picked, deleted, cursor, shift, combat
  local buys, refundable, limit, registered, asked, messages

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  -- put puts an item in a backpack slot, committed and live: its category, its price and what it is.
  local function put(bag, slot, id, category, extra)
    extra = extra or {}
    local key = bag .. "_" .. slot
    local data = {
      bagid = bag, slotid = slot, slotkey = key, kind = BACKPACK, isItemEmpty = false,
      harvestIncomplete = extra.cold,
      itemInfo = { itemID = id, itemGUID = "guid-" .. key, itemLink = "[Item " .. id .. "]", sellPrice = 5,
        traits = { sellPrice = extra.price or 100 }, equipmentSets = extra.sets },
      containerInfo = { hasNoValue = extra.noValue == true, stackCount = extra.count or 1 },
    }
    slots[key] = { data = data, live = { stackCount = extra.count or 1, hasNoValue = extra.noValue == true,
      isLocked = false }, guid = "guid-" .. key }
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
    cursor, shift, combat, buys, refundable, limit, registered = false, false, false, true, {}, true, {}
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
    override(database, "GetAutoSellLimit", function() return limit end)
    override(events, "RegisterEvent", function(_, name, fn) registered[name] = fn end)
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

    it("leaves out slots outside the backpack's bags", function()
      put(0, 1, 11, "Junk")
      put(6, 1, 12, "Junk")
      local list = automation:Entries(ctx())
      assert.are.equal(1, #list)
      assert.are.equal("0_1", list[1].data.slotkey)
    end)

    it("says why it leaves an item alone", function()
      put(0, 1, 11, "Junk", { sets = { "Tank" } })
      put(0, 2, 12, "Junk")
      refundable["0_2"] = true
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

    -- An item a category destroys is sold instead when a merchant buys it, as Vendor does.
    it("sells what sell and destroy categories hold, and destroys only what destroy categories hold", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      put(0, 3, 13, "Trash", { noValue = true })
      put(0, 4, 14, "Junk", { sets = { "Tank" } })
      put(0, 5, 15, "Trash", { sets = { "Tank" } })
      local function keysOf(list)
        local keys = {}
        for i, e in ipairs(list) do keys[i] = e.data.slotkey end
        return keys
      end
      assert.are.same({ "0_1", "0_2" }, keysOf(automation:SellList(ctx())))
      assert.are.same({ "0_2", "0_3" }, keysOf(automation:DestroyList(ctx())), "never what it leaves alone")
    end)
  end)

  describe("selling at a merchant", function()
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

    -- In bulk, as a backpack section dragged onto BetterBags Next's vendor sells (asked).
    it("sells everything at once, the frame after the merchant opens, then says what it sold for", function()
      put(0, 1, 11, "Junk", { count = 3, price = 100 })
      put(0, 2, 12, "Trash", { price = 50 })
      put(0, 3, 13, "Mats")
      assert.are.equal("selling", automation:OnMerchantShow(ctx()))
      assert.are.same({}, used, "nothing in the frame the merchant opens")
      assert.are.equal(1, run())
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({ "BetterBags: Sold 2 items for 350c." }, printed)
      assert.is_nil(automation.sale)
      assert.are.same({}, timers, "done in one go")
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

    it("says nothing of the rest when the limit sold everything", function()
      for slot = 1, 12 do put(1, slot, 100 + slot, "Junk") end
      sell()
      assert.are.equal(12, #used)
      assert.are.equal(1, #printed)
    end)

    it("never acts on an item without a GUID", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      for _, key in ipairs({ "0_1", "0_2" }) do
        slots[key].data.itemInfo.itemGUID = ""
        slots[key].guid = ""
      end
      sell()
      assert.are.same({}, used)
      assert.are.equal("nothing", automation:DestroyNext(ctx()))
      assert.are.equal(0, deleted)
    end)

    it("stops at what buyback keeps, and says how to sell the rest", function()
      for slot = 1, 14 do put(1, slot, 100 + slot, "Junk") end
      sell()
      assert.are.equal(12, #used)
      assert.are.equal(2, #printed)
      assert.truthy(printed[2]:find("12", 1, true))
      used, printed, limit = {}, {}, false
      sell()
      assert.are.equal(2, #used, "the limit turned off sells the rest")
      assert.are.equal(1, #printed)
    end)

    it("sells nothing when the merchant closed before the sale", function()
      put(0, 1, 11, "Junk")
      automation:OnMerchantShow(ctx())
      automation:OnMerchantClosed(ctx())
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
      assert.are.same({}, used)
      assert.is_true(timers[1].delay > 0, "checks again a moment later")
      cursor = false
      run()
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
      run()
      assert.are.same({ "0_4" }, used)
    end)

    it("sells once when the merchant reopened before the sale", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Junk")
      automation:OnMerchantShow(ctx())
      automation:OnMerchantShow(ctx())
      run()
      assert.are.same({ "0_1", "0_2" }, used)
      assert.are.same({ "BetterBags: Sold 2 items for 200c." }, printed)
    end)
  end)

  -- What BetterBags Next's vendor shows on its destroy card (automation.md §4), and what a click
  -- destroys: never an item a sale holds.
  describe("the destroy queue", function()
    local function keysOf(list)
      local keys = {}
      for i, e in ipairs(list) do keys[i] = e.data.slotkey end
      return keys
    end

    it("lists what destroy categories hold that is still in its slot", function()
      put(0, 1, 11, "Trash", { noValue = true })
      put(0, 2, 12, "Trash", { noValue = true })
      put(0, 3, 13, "Junk", { noValue = true })
      slots["0_2"].guid = "another item"
      assert.are.same({ "0_1" }, keysOf(automation:DestroyQueue(ctx())))
    end)

    it("leaves out what a sale holds, until the sale is done with it", function()
      put(0, 1, 11, "Trash")
      put(0, 2, 12, "Trash", { noValue = true })
      automation:OnMerchantShow(ctx())
      assert.are.same({ "0_2" }, keysOf(automation:DestroyQueue(ctx())), "to be sold the next frame")
      assert.are.equal("destroyed", automation:DestroyNext(ctx()))
      assert.are.same({ "0_2" }, picked, "the click never destroys what the merchant buys")
    end)

    it("gives back what a sale left unsold", function()
      for slot = 1, 13 do put(1, slot, 100 + slot, "Trash") end
      automation:OnMerchantShow(ctx())
      run()
      assert.are.equal(12, #used)
      assert.are.same({ "1_13" }, keysOf(automation:DestroyQueue(ctx())), "past the limit")
    end)

    it("keeps what a sale sold out of it while the bags catch up", function()
      put(0, 1, 11, "Trash")
      C_Container.UseContainerItem = function(bag, slot) table.insert(used, bag .. "_" .. slot) end
      automation:OnMerchantShow(ctx())
      run()
      assert.are.same({ "0_1" }, used)
      assert.are.same({}, keysOf(automation:DestroyQueue(ctx())), "sold, though the client still shows it")
    end)

    it("starts again at each merchant", function()
      put(0, 1, 11, "Trash")
      C_Container.UseContainerItem = function(bag, slot) table.insert(used, bag .. "_" .. slot) end
      automation:OnMerchantShow(ctx())
      run()
      buys = false
      automation:OnMerchantShow(ctx())
      assert.are.same({ "0_1" }, keysOf(automation:DestroyQueue(ctx())))
    end)

    it("says when it may have changed: a sale starting and ending, and an item destroyed", function()
      put(0, 1, 11, "Trash")
      put(0, 2, 12, "Trash", { noValue = true })
      automation:OnMerchantShow(ctx())
      assert.are.same({ "automation/Changed" }, messages)
      run()
      assert.are.same({ "automation/Changed", "automation/Changed" }, messages)
      automation:DestroyNext(ctx())
      assert.are.equal(3, #messages)
      automation:DestroyNext(ctx())
      assert.are.equal(3, #messages, "nothing destroyed")
    end)
  end)

  describe("destroying", function()
    it("destroys the next item a destroy category holds, one a press", function()
      put(0, 1, 11, "Junk")
      put(0, 2, 12, "Trash")
      put(0, 3, 13, "Trash")
      assert.are.equal("destroyed", automation:DestroyNext(ctx()))
      assert.are.same({ "0_2" }, picked)
      assert.are.equal(1, deleted)
      assert.are.same({ "BetterBags: Destroyed [Item 12]." }, printed)
    end)

    it("does nothing while the cursor holds an item, in combat, or with nothing to destroy", function()
      put(0, 1, 11, "Trash")
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
      put(0, 1, 11, "Trash")
      put(0, 2, 12, "Trash")
      slots["0_1"].guid = "another item"
      automation:DestroyNext(ctx())
      assert.are.same({ "0_2" }, picked)
    end)

    it("destroys nothing it could not pick up", function()
      put(0, 1, 11, "Trash")
      _G.C_Container.PickupContainerItem = function() end
      assert.are.equal("not picked up", automation:DestroyNext(ctx()))
      assert.are.equal(0, deleted)
    end)

    it("is what the Destroy Next Item key does", function()
      put(0, 1, 11, "Trash")
      BetterBags_DestroyNextItem()
      assert.are.equal(1, deleted)
    end)
  end)
end)
