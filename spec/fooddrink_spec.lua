-- fooddrink_spec.lua -- FoodDrink (data/fooddrink.lua): what BetterBags Next's Food & Drink bar eats and drinks
-- (food-drink.md §1, §2): which items are food, drink or both, by the spell they cast in the client's language; which
-- the player's rule picks (the highest item level or the lowest), its count, and when the pick is read: on every read of
-- the bags, never in combat, once more when combat ends.
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
local items = trackStub("Items")
local async = trackStub("Async")
local const = trackStub("Constants")

ResetModuleStub("FoodDrink", "data/fooddrink.lua")
LoadBetterBagsModule("data/fooddrink.lua")
local foodDrink = addon:GetModule("FoodDrink")
local context = addon:GetModule("Context")

describe("FoodDrink", function()
  local replaced, sent, messages, options, bags, spells, combat, afterCombat

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  local function sentOf(name)
    local n = 0
    for _, m in ipairs(sent) do
      if m == name then n = n + 1 end
    end
    return n
  end

  -- put puts an item in a bag slot as the bags' read has it (data/items.lua), its use spell as GetItemSpell answers
  -- for its link (ItemDocumentation.lua: its name and spell ID).
  local function put(bag, slot, id, fields)
    fields = fields or {}
    local link = "item:" .. id
    local data = {
      slotkey = bag .. "_" .. slot, bagid = bag, slotid = slot, isItemEmpty = false,
      itemInfo = {
        itemID = id, itemLink = link, classID = fields.classID or 0, itemLevel = fields.itemLevel or 1,
        currentItemCount = fields.count or 1, itemIcon = 1000 + id, traits = not fields.cold and {} or nil,
      },
    }
    bags[data.slotkey] = data
    if fields.spell then
      spells[link] = fields.spell
    end
    return data
  end

  local function empty(bag, slot)
    bags[bag .. "_" .. slot] = { slotkey = bag .. "_" .. slot, bagid = bag, slotid = slot, isItemEmpty = true,
      itemInfo = { itemID = 0, currentItemCount = 0 } }
  end

  local FOOD, DRINK, BOTH = { "Food", 433 }, { "Drink", 430 }, { "Food & Drink", 369166 }

  local function read()
    for _, fn in ipairs(messages["items/RefreshBackpack/Done"] or {}) do fn(ctx()) end
  end

  local function slotOf(pick)
    return pick and pick.data.slotkey
  end

  before_each(function()
    replaced, sent, messages, bags, spells, afterCombat = {}, {}, {}, {}, {}, {}
    combat = false
    options = { pick = "highest" }
    override(const, "BAG_KIND", { BACKPACK = 0, BANK = 1 })
    override(database, "GetNextFoodDrinkOption", function(_, name) return options[name] end)
    override(items, "GetAllSlotInfo", function() return { [0] = { itemsBySlotKey = bags } } end)
    override(events, "SendMessage", function(_, _, name) table.insert(sent, name) end)
    override(events, "RegisterMessage", function(_, name, fn)
      messages[name] = messages[name] or {}
      table.insert(messages[name], fn)
    end)
    override(async, "AfterCombat", function(_, actx, cb)
      if combat then
        table.insert(afterCombat, cb)
      else
        cb(actx)
      end
    end)
    override(_G, "InCombatLockdown", function() return combat end)
    override(C_Item, "GetItemSpell", function(link)
      local s = spells[link]
      if s then return s[1], s[2] end
    end)
    -- The names the client gives the reference spells, in its language (433 Food, 430 Drink, 369166 Food & Drink).
    override(_G, "_spellNames", { [433] = "Food", [430] = "Drink", [369166] = "Food & Drink" })
    foodDrink:Init()
    foodDrink:OnEnable()
  end)

  after_each(function()
    for i = #replaced, 1, -1 do
      local r = replaced[i]
      r[1][r[2]] = r[3]
    end
  end)

  teardown(function()
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("what counts", function()
    it("knows food, drink and both by the name of the spell they cast", function()
      assert.are.equal("food", foodDrink:Kind(put(0, 1, 117, { spell = FOOD })))
      assert.are.equal("drink", foodDrink:Kind(put(0, 2, 159, { spell = DRINK })))
      -- Another Food spell than the reference: every Food item has its own spell, all named Food.
      assert.are.equal("food", foodDrink:Kind(put(0, 3, 194686, { spell = { "Food", 369159 } })))
      assert.are.equal("both", foodDrink:Kind(put(0, 4, 194680, { spell = BOTH })))
    end)

    it("reads the names in the client's language", function()
      override(_G, "_spellNames", { [433] = "Essen", [430] = "Trinken" })
      foodDrink:Init()
      assert.are.equal("food", foodDrink:Kind(put(0, 1, 117, { spell = { "Essen", 433 } })))
      assert.are.equal("drink", foodDrink:Kind(put(0, 2, 159, { spell = { "Trinken", 430 } })))
      assert.is_nil(foodDrink:Kind(put(0, 3, 160, { spell = { "Food", 433 } })))
    end)

    it("knows a mage's conjured food by its spell: it is named Refreshment, like buff food, and restores both", function()
      assert.are.equal("both", foodDrink:Kind(put(0, 1, 113509, { spell = { "Refreshment", 167152 } })))
      assert.are.equal("both", foodDrink:Kind(put(0, 2, 34062, { spell = { "Refreshment", 44166 } })))
      assert.are.equal("both", foodDrink:Kind(put(0, 3, 80610, { spell = { "Refreshment", 128701 } })))
    end)

    it("never counts buff food, alcohol or a client's spell it has no name for", function()
      assert.is_nil(foodDrink:Kind(put(0, 1, 197774, { spell = { "Refreshment", 382237 } })))
      assert.is_nil(foodDrink:Kind(put(0, 2, 268679, { spell = { "Hearty Refreshment", 1233767 } })))
      assert.is_nil(foodDrink:Kind(put(0, 3, 2594, { spell = { "Strong Alcohol", 11009 } })))
      -- A client with no Food & Drink spell (the classic clients) names nothing by it.
      override(_G, "_spellNames", { [433] = "Food", [430] = "Drink" })
      foodDrink:Init()
      assert.is_nil(foodDrink:Kind(put(0, 4, 194680, { spell = { "", 369166 } })))
    end)

    it("counts only consumables: not a tankard to equip, a quest item or raw fish", function()
      assert.is_nil(foodDrink:Kind(put(0, 1, 4696, { classID = 4, spell = DRINK })))
      assert.is_nil(foodDrink:Kind(put(0, 2, 8683, { classID = 12, spell = FOOD })))
      assert.is_nil(foodDrink:Kind(put(0, 3, 6289, { classID = 7, spell = FOOD })))
    end)

    it("skips an empty slot, an item with no use spell and an item read cold", function()
      empty(0, 1)
      assert.is_nil(foodDrink:Kind(bags["0_1"]))
      assert.is_nil(foodDrink:Kind(put(0, 2, 2589)))
      assert.is_nil(foodDrink:Kind(put(0, 3, 117, { spell = FOOD, cold = true })))
    end)
  end)

  describe("the pick", function()
    it("picks the highest item level of each, with the count of every stack of it", function()
      put(0, 1, 117, { spell = FOOD, itemLevel = 5, count = 20 })
      put(0, 2, 2287, { spell = FOOD, itemLevel = 15, count = 3 })
      put(1, 4, 2287, { spell = FOOD, itemLevel = 15, count = 7 })
      put(0, 3, 159, { spell = DRINK, itemLevel = 5, count = 10 })
      read()
      local picks = foodDrink:Picks()
      assert.are.equal(2287, picks.food.data.itemInfo.itemID)
      assert.are.equal(10, picks.food.count)
      assert.are.equal(159, picks.drink.data.itemInfo.itemID)
      assert.are.equal(10, picks.drink.count)
    end)

    it("eats a partial stack first: the smallest, then the first bag and slot", function()
      put(1, 4, 2287, { spell = FOOD, itemLevel = 15, count = 7 })
      put(0, 9, 2287, { spell = FOOD, itemLevel = 15, count = 3 })
      put(0, 2, 2287, { spell = FOOD, itemLevel = 15, count = 3 })
      read()
      assert.are.equal("0_2", slotOf(foodDrink:Picks().food))
    end)

    it("picks the lowest item level when the rule says so", function()
      options.pick = "lowest"
      put(0, 1, 117, { spell = FOOD, itemLevel = 5 })
      put(0, 2, 2287, { spell = FOOD, itemLevel = 15 })
      read()
      assert.are.equal(117, foodDrink:Picks().food.data.itemInfo.itemID)
    end)

    it("picks the lower item ID of two at the same item level, either rule", function()
      put(0, 1, 4599, { spell = FOOD, itemLevel = 35 })
      put(0, 2, 3770, { spell = FOOD, itemLevel = 35 })
      read()
      assert.are.equal(3770, foodDrink:Picks().food.data.itemInfo.itemID)
      options.pick = "lowest"
      for _, fn in ipairs(messages["fooddrink/OptionsChanged"]) do fn(ctx()) end
      assert.are.equal(3770, foodDrink:Picks().food.data.itemInfo.itemID)
    end)

    it("offers what restores both as food and as drink", function()
      put(0, 1, 113509, { spell = { "Refreshment", 167152 }, itemLevel = 40, count = 20 })
      read()
      local picks = foodDrink:Picks()
      assert.are.equal("0_1", slotOf(picks.food))
      assert.are.equal("0_1", slotOf(picks.drink))
    end)

    it("picks nothing of a kind there is none of", function()
      put(0, 1, 117, { spell = FOOD })
      read()
      assert.is_not_nil(foodDrink:Picks().food)
      assert.is_nil(foodDrink:Picks().drink)
    end)

    it("moves to the next one as the last of it is eaten", function()
      put(0, 1, 2287, { spell = FOOD, itemLevel = 15, count = 1 })
      put(0, 2, 117, { spell = FOOD, itemLevel = 5, count = 20 })
      read()
      assert.are.equal("0_1", slotOf(foodDrink:Picks().food))
      empty(0, 1)
      read()
      assert.are.equal("0_2", slotOf(foodDrink:Picks().food))
    end)
  end)

  describe("when it is read", function()
    it("tells the bar only when a pick's slot, item or count changed", function()
      put(0, 1, 117, { spell = FOOD, count = 20 })
      read()
      assert.are.equal(1, sentOf("fooddrink/Changed"))
      read()
      assert.are.equal(1, sentOf("fooddrink/Changed"))
      bags["0_1"].itemInfo.currentItemCount = 19
      read()
      assert.are.equal(2, sentOf("fooddrink/Changed"))
      put(0, 2, 159, { spell = DRINK })
      read()
      assert.are.equal(3, sentOf("fooddrink/Changed"))
    end)

    it("changes nothing in combat, and reads the bags as they are once combat ends", function()
      put(0, 1, 117, { spell = FOOD, count = 20 })
      read()
      assert.are.equal(1, sentOf("fooddrink/Changed"))
      combat = true
      put(0, 2, 2287, { spell = FOOD, itemLevel = 15 })
      read()
      read()
      assert.are.equal(1, sentOf("fooddrink/Changed"))
      assert.are.equal("0_1", slotOf(foodDrink:Picks().food))
      assert.are.equal(1, #afterCombat, "one read queued for after combat")
      -- What the bags hold when combat ends is what counts.
      put(0, 3, 4599, { spell = FOOD, itemLevel = 35 })
      combat = false
      afterCombat[1](ctx())
      assert.are.equal(2, sentOf("fooddrink/Changed"))
      assert.are.equal("0_3", slotOf(foodDrink:Picks().food))
    end)

    it("reads again in combat's wake for a rule changed in combat", function()
      put(0, 1, 117, { spell = FOOD, itemLevel = 5 })
      put(0, 2, 2287, { spell = FOOD, itemLevel = 15 })
      read()
      combat = true
      options.pick = "lowest"
      for _, fn in ipairs(messages["fooddrink/OptionsChanged"]) do fn(ctx()) end
      assert.are.equal("0_2", slotOf(foodDrink:Picks().food))
      combat = false
      afterCombat[1](ctx())
      assert.are.equal("0_1", slotOf(foodDrink:Picks().food))
    end)
  end)
end)
