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
-- (themes:GetInBagSearchBox etc.) is never reached.
database.GetInBagSearch = function() return false end

StubBetterBagsModule("Themes")

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
end)
