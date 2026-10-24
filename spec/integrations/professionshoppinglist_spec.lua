-- professionshoppinglist_spec.lua -- the Profession Shopping List integration
-- (integrations/professionshoppinglist.lua): what its list still needs, and buying it from the open
-- merchant, only while Profession Shopping List has both functions BetterBags calls.
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

ResetModuleStub("ProfessionShoppingList", "integrations/professionshoppinglist.lua")
LoadBetterBagsModule("integrations/professionshoppinglist.lua")
local shoppingList = addon:GetModule("ProfessionShoppingList")

local CHANGED = "ProfessionShoppingList.OnTrackedRecipesChanged"

describe("Profession Shopping List integration", function()
  local list, bought, registered, sent

  -- psl stands in for Profession Shopping List's API (its API.lua): its functions must be called with a
  -- colon, as its own asserts require.
  local function psl(opts)
    opts = opts or {}
    local api = {}
    if opts.list ~= false then
      function api.GetShoppingList(self)
        assert(self == api, "Call ProfessionShoppingList:GetShoppingList(), not ProfessionShoppingList.GetShoppingList()")
        return list
      end
    end
    if opts.buy ~= false then
      function api.BuyFromMerchant(self)
        assert(self == api, "Call ProfessionShoppingList:BuyFromMerchant(), not ProfessionShoppingList.BuyFromMerchant()")
        bought = bought + 1
      end
    end
    override(_G, "ProfessionShoppingList", api)
    return api
  end

  before_each(function()
    list, bought, registered, sent = {}, 0, {}, {}
    override(_G, "ProfessionShoppingList", nil)
    override(events, "RegisterEvent", function(_, name, fn) registered[name] = fn end)
    override(events, "SendMessage", function(_, _, name) table.insert(sent, name) end)
    override(_G, "print", function() end)
    shoppingList._watching = nil
  end)

  after_each(function()
    EventRegistry:UnregisterCallback(CHANGED, shoppingList)
    for i = #replaced, 1, -1 do replaced[i][1][replaced[i][2]] = replaced[i][3] end
    replaced = {}
  end)

  teardown(function()
    ResetModuleStub("ProfessionShoppingList", "integrations/professionshoppinglist.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("without the functions it calls", function()
    it("is not there without Profession Shopping List", function()
      assert.is_false(shoppingList:Available())
      assert.are.same({}, shoppingList:Needs())
      assert.is_false(shoppingList:Buy())
    end)

    -- Asked: "if PSL (and this function, because it's new) isn't available, don't show this
    -- integration/don't try to call this."
    it("is not there with a Profession Shopping List that has no GetShoppingList", function()
      psl({ list = false })
      assert.is_false(shoppingList:Available())
      assert.are.same({}, shoppingList:Needs())
      assert.is_false(shoppingList:Buy())
      assert.equal(0, bought)
    end)

    it("is not there with a Profession Shopping List that has no BuyFromMerchant", function()
      psl({ buy = false })
      list = { [101] = { required = 5, owned = 0 } }
      assert.is_false(shoppingList:Available())
      assert.are.same({}, shoppingList:Needs())
    end)
  end)

  describe("with Profession Shopping List", function()
    it("is there", function()
      psl()
      assert.is_true(shoppingList:Available())
    end)

    it("needs what each reagent still misses, and nothing it has enough of", function()
      psl()
      list = {
        [101] = { required = 20, owned = 5 },
        [102] = { required = 3, owned = 3 },
        [103] = { required = 2, owned = 7 },
        [104] = { required = 1, owned = 0 },
      }
      assert.are.same({ [101] = 15, [104] = 1 }, shoppingList:Needs())
    end)

    it("buys through Profession Shopping List", function()
      psl()
      assert.is_true(shoppingList:Buy())
      assert.equal(1, bought)
    end)
  end)

  describe("watching the list", function()
    it("says when the tracked recipes change", function()
      psl()
      shoppingList:OnEnable()
      EventRegistry:TriggerEvent(CHANGED, 101, 2)
      assert.are.same({ "shoppingList/Changed" }, sent)
    end)

    it("listens once, however often it is enabled, and says so once", function()
      psl()
      local said = 0
      override(_G, "print", function() said = said + 1 end)
      shoppingList:OnEnable()
      shoppingList:OnEnable()
      EventRegistry:TriggerEvent(CHANGED, 101, 2)
      assert.are.same({ "shoppingList/Changed" }, sent)
      assert.are.equal(1, said)
    end)

    -- Profession Shopping List can load after BetterBags enables its modules.
    it("starts once Profession Shopping List loads after it, and says the list is there", function()
      shoppingList:OnEnable()
      assert.is_function(registered.ADDON_LOADED)
      registered.ADDON_LOADED(nil, "ADDON_LOADED", "SomethingElse")
      assert.are.same({}, sent)
      psl()
      registered.ADDON_LOADED(nil, "ADDON_LOADED", "ProfessionShoppingList")
      assert.are.same({ "shoppingList/Changed" }, sent)
      registered.ADDON_LOADED(nil, "ADDON_LOADED", "Another")
      assert.are.same({ "shoppingList/Changed" }, sent, "once")
      EventRegistry:TriggerEvent(CHANGED, nil, nil)
      assert.are.same({ "shoppingList/Changed", "shoppingList/Changed" }, sent)
    end)

    it("waits for nothing when it is there already", function()
      psl()
      shoppingList:OnEnable()
      assert.is_nil(registered.ADDON_LOADED)
    end)
  end)
end)
