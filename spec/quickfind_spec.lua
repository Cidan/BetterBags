local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load the real Context module (do NOT stub it: Context is a shared core module
-- and overriding context.New here would clobber it for every other spec).
LoadBetterBagsModule("core/context.lua")

-- Constants stub with Camelot-shaped bank tab tables: 9 character tabs and 9
-- account tabs. The extra tabs (values beyond retail's 6/5 cap) are the ones the
-- old hard-coded range bounds in quickfind.lua would have misrouted.
local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BANK_ONLY_BAGS = {}
for _, id in ipairs({ 6, 7, 8, 9, 10, 11, 12, 13, 14 }) do const.BANK_ONLY_BAGS[id] = id end
const.ACCOUNT_BANK_BAGS = {}
for _, id in ipairs({ 15, 16, 17, 18, 19, 20, 21, 22, 23 }) do const.ACCOUNT_BANK_BAGS[id] = id end

local items = StubBetterBagsModule("Items")
StubBetterBagsModule("Groups")

local database = StubBetterBagsModule("Database")
-- Short-circuit ShowInBag right after the tab dispatch so the search-box code
-- (the bag's in-bag search box) is never reached.
database.GetInBagSearch = function() return false end


LoadBetterBagsModule("integrations/quickfind.lua")
local quickfind = addon:GetModule("QuickFind")

describe("QuickFind bank tab classification", function()
  local switched

  ---Drives quickfind:ShowInBag for a bank item whose bagid is `tabID`, returning
  ---which bank-behavior method the dispatch selected.
  local function showBankItem(tabID)
    switched = {}
    items.GetItemDataFromSlotKey = function()
      return { bagid = tabID, itemInfo = { itemName = "Test Item" } }
    end
    addon.Bags = {
      Bank = {
        Show = function() end,
        behavior = {
          SwitchToCharacterBankTab = function() switched.character = true end,
          SwitchToAccountBank = function() switched.account = true end,
        },
        tabs = { SetTabByID = function() switched.fallback = true end },
      },
    }
    quickfind:ShowInBag("bank:" .. tabID .. "_1")
  end

  it("routes a 9th character bank tab (Camelot) to SwitchToCharacterBankTab", function()
    showBankItem(14) -- CharacterBankTab_9 on Camelot; beyond retail's _6
    assert.is_true(switched.character)
    assert.is_nil(switched.account)
    assert.is_nil(switched.fallback)
  end)

  it("routes a 9th account bank tab (Camelot) to SwitchToAccountBank", function()
    showBankItem(23) -- AccountBankTab_9 on Camelot; beyond retail's _5
    assert.is_true(switched.account)
    assert.is_nil(switched.character)
    assert.is_nil(switched.fallback)
  end)

  it("still routes the first character/account tabs correctly", function()
    showBankItem(6) -- CharacterBankTab_1
    assert.is_true(switched.character)
    showBankItem(15) -- AccountBankTab_1
    assert.is_true(switched.account)
  end)

  it("falls back to a visual tab switch for an unknown tab id", function()
    showBankItem(999)
    assert.is_true(switched.fallback)
    assert.is_nil(switched.character)
    assert.is_nil(switched.account)
  end)

  -- A BetterBags Next bank's tab rail has no visual-only switch (next.md §6).
  it("skips the visual tab switch for a bank whose tabs have none", function()
    items.GetItemDataFromSlotKey = function()
      return { bagid = -1, itemInfo = { itemName = "Test Item" } }
    end
    addon.Bags = { Bank = { Show = function() end, behavior = {}, tabs = { frame = {} } } }
    assert.has_no.errors(function() quickfind:ShowInBag("bank:-1_1") end)
  end)
end)

-- Enable QuickFind Integration (#1262, quickfind.md): BetterBags' items are a QuickFind source whenever QuickFind is
-- loaded, since QuickFind has no way to take a source back (its API.lua: RegisterSource only), and the source is
-- empty while the integration is off, so the switch takes effect at once.
describe("QuickFind integration switch", function()
  local saved, on, registered, printed

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved, on, registered, printed = {}, true, {}, {}
    override(database, "GetQuickFindEnabled", function() return on end)
    -- QuickFind's public table (QuickFind/init.lua, API.lua): its lookup types and RegisterSource.
    override(_G, "QuickFind", {
      LOOKUP_TYPE = { SPELL = "SPELL", TOY = "TOY", ITEM = "ITEM", MOUNT = "MOUNT", LUA = "LUA" },
      RegisterSource = function(_, source)
        table.insert(registered, source)
        return true
      end,
    })
    override(_G, "print", function(...) table.insert(printed, table.concat({ ... }, " ")) end)
    override(items, "GetAllSlotInfo", function()
      return {
        [const.BAG_KIND.BACKPACK] = { itemsBySlotKey = {
          ["0_1"] = { slotkey = "0_1", bagid = 0, slotid = 1, itemInfo = { itemName = "Ore", itemIcon = 1 } },
        } },
        [const.BAG_KIND.BANK] = { itemsBySlotKey = {
          ["6_1"] = { slotkey = "6_1", bagid = 6, slotid = 1, itemInfo = { itemName = "Gems", itemIcon = 2 } },
        } },
      }
    end)
  end)

  after_each(function()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  it("registers BetterBags' items as a source while the integration is off too, to follow it being turned on", function()
    on = false
    quickfind:OnEnable()
    assert.are.equal(1, #registered)
    assert.are.equal("BetterBags Items", registered[1].name)
  end)

  it("gives QuickFind the bags' items while on, and none while off", function()
    quickfind:OnEnable()
    local names = {}
    for _, entry in ipairs(registered[1].get()) do table.insert(names, entry.name) end
    table.sort(names)
    assert.are.same({ "Gems", "Ore" }, names)
    on = false
    assert.are.same({}, registered[1].get())
    assert.are.same({}, quickfind:GetItemResults())
    on = true
    assert.are.equal(2, #registered[1].get())
  end)

  it("says at login that the integration is enabled only while it is on", function()
    quickfind:OnEnable()
    assert.are.same({ "BetterBags: QuickFind integration enabled." }, printed)
    on = false
    quickfind:OnEnable()
    assert.are.same({ "BetterBags: QuickFind integration enabled." }, printed, "nothing more")
  end)
end)
