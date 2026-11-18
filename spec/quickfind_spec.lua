local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load the real Context module (do NOT stub it: Context is a shared core module
-- and overriding context.New here would clobber it for every other spec).
LoadBetterBagsModule("core/context.lua")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BANK_TAB = { BANK = -1, ACCOUNT_BANK_1 = 12 }
const.ACCOUNT_BANK_BAGS = {}
-- What data/search.lua reads from Constants.
const.BRIEF_EXPANSION_MAP = { [0] = "classic" }
const.BINDING_MAP = { [0] = "" }
const.ITEM_QUALITY_TO_ENUM = { poor = 0, common = 1 }

local items = StubBetterBagsModule("Items")
items.GetAllSlotInfo = function() return {} end

local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end
local events = StubBetterBagsModule("Events")
events.RegisterMessage = function() end
events.RegisterEvent = function() end
events.SendMessage = function() end
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end
StubBetterBagsModule("MoneyFrame")
StubBetterBagsModule("Tabs")
StubBetterBagsModule("ContextMenu")
-- What frames/bankslots.lua draws with: the tab slots panel's SelectTab uses none of them.
for _, name in ipairs({ "Grid", "Render", "Texels", "Drawable", "Window", "SonataApply" }) do
  StubBetterBagsModule(name)
end

-- The bank's groups as the database keeps them (core/database.lua): each by ID, and the categories assigned to one,
-- by bank type on retail (DB:GetCategoryGroup), else by name alone.
local database = StubBetterBagsModule("Database")
local dbGroups, dbAssigned, dbActive = {}, {}, {}
database.GetGroup = function(_, kind, id) return dbGroups[kind] and dbGroups[kind][id] end
database.GetAllGroups = function(_, kind) return dbGroups[kind] or {} end
database.GetCategoryGroup = function(_, kind, category, bankType)
  local map = dbAssigned[kind] or {}
  if addon.isRetail and kind == const.BAG_KIND.BANK then
    return map[bankType] and map[bankType][category]
  end
  return map[category]
end
database.GetActiveGroup = function(_, kind) return dbActive[kind] end
database.SetActiveGroup = function(_, kind, id) dbActive[kind] = id end

LoadBetterBagsModule("data/groups.lua")
LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("frames/bankslots.lua")
ResetModuleStub("BankBehavior", "bags/bank.lua")
LoadBetterBagsModule("bags/bank.lua")
LoadBetterBagsModule("integrations/quickfind.lua")
local quickfind = addon:GetModule("QuickFind")
local search = addon:GetModule("Search")
local bankBehavior = addon:GetModule("BankBehavior")
local bankSlots = addon:GetModule("BankSlots")

local BANK = const.BAG_KIND.BANK
local CHAR, ACCOUNT = Enum.BankType.Character, Enum.BankType.Account

-- Every value a test replaces, put back after it.
local saved = {}
local function override(tbl, key, value)
  table.insert(saved, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #saved, 1, -1 do
    saved[i][1][saved[i][2]] = saved[i][3]
  end
  saved = {}
end

-- client sets the flags and bank bags BetterBags reads on each game client: live retail (character tabs 6 to 11,
-- Warbank tabs 12 to 16), WoW: Forever (nine character tabs, no Warbank), and Classic (no bank tabs, no Warbank).
local function client(name)
  override(addon, "isRetail", name ~= "classic")
  override(addon, "isForever", name == "forever")
  override(addon, "hasWarbank", name == "retail")
  local account = {}
  if name == "retail" then
    for id = 12, 16 do account[id] = id end
  end
  override(const, "ACCOUNT_BANK_BAGS", account)
end

-- The bank's groups on each client (core/database.lua seeds the defaults: the Bank, and the Warbank only on a client
-- with one), a group of each bank type made by the player, and a category assigned to each.
local function bankGroups(warbank)
  dbGroups[BANK] = {
    [2] = { id = 2, name = "Bank", bankType = CHAR, isDefault = true },
    [4] = { id = 4, name = "Herbs", bankType = CHAR },
  }
  if warbank then
    dbGroups[BANK][3] = { id = 3, name = "Warbank", bankType = ACCOUNT, isDefault = true }
    dbGroups[BANK][5] = { id = 5, name = "Gems", bankType = ACCOUNT }
  end
  if addon.isRetail then
    dbAssigned[BANK] = { [CHAR] = { Herbs = 4 }, [ACCOUNT] = { Gems = 5 } }
  else
    dbAssigned[BANK] = { Herbs = 4 }
  end
  dbActive[BANK] = 2
end

describe("QuickFind showing a bank item", function()
  local db, calls, shown

  -- The banks QuickFind opens, each with the methods its real one has: BetterBags Next's (next/bank.lua: a tab rail,
  -- SwitchToGroup and SwitchToBlizzardTab on its behavior), the classic retail bank's (bags/bank.lua: a tab bar, the
  -- same two behavior methods, and the tab slots panel whose SelectTab shows a Blizzard tab), and the classic Classic
  -- bank's (bags/classic/bank.lua, bags/era/bank.lua: no tabs, so the inherited SwitchToGroup cannot run).
  local function bankOf(design)
    local bag = { Show = function() shown = shown + 1 end, behavior = {} }
    function bag.behavior:SwitchToGroup(_, id) table.insert(calls, { "group", id }) end
    function bag.behavior:SwitchToBlizzardTab(_, id) table.insert(calls, { "blizzard tab", id }) end
    if design == "next" then
      bag.tabs = { Select = function() end }
    elseif design == "classic" then
      bag.tabs = { SetTabByID = function() end }
      bag.slots = { SelectTab = function(_, _, id) table.insert(calls, { "tab slot", id }) end }
    elseif design == "no tabs" then
      function bag.behavior:SwitchToGroup() error("the bank has no tabs to switch") end
    end
    return bag
  end

  -- pick presses Enter on a bank item in QuickFind, with the bank open in a design.
  local function pick(design, bagid, category)
    override(items, "GetItemDataFromSlotKey", function(_, slotkey)
      return { slotkey = slotkey, bagid = bagid, itemInfo = { itemName = "Item", category = category } }
    end)
    override(addon, "Bags", { Bank = bankOf(design) })
    quickfind:ShowInBag("bank:" .. bagid .. "_1")
    return calls
  end

  before_each(function()
    calls, shown = {}, 0
    db = { groupsEnabled = true, showBankTabs = false }
    client("retail")
    bankGroups(true)
    override(database, "GetGroupsEnabled", function() return db.groupsEnabled end)
    override(database, "GetShowBankTabs", function() return db.showBankTabs end)
    override(database, "GetInBagSearch", function() return false end)
    override(_G, "print", function() end)
  end)

  after_each(restore)

  describe("in the bank's groups", function()
    it("shows the Warbank group for a Warbank item, its category assigned nowhere", function()
      assert.are.same({ { "group", 3 } }, pick("next", 12, "Ore"))
    end)

    it("shows the Bank group for a character bank item, its category assigned nowhere", function()
      assert.are.same({ { "group", 2 } }, pick("next", 7, "Ore"))
    end)

    it("shows the group a character bank item's category is assigned to", function()
      assert.are.same({ { "group", 4 } }, pick("next", 6, "Herbs"))
    end)

    it("shows the group a Warbank item's category is assigned to", function()
      assert.are.same({ { "group", 5 } }, pick("next", 16, "Gems"))
    end)

    -- A category is assigned to a group for one bank type (DB:SetCategoryGroup): the Warbank's items of a category
    -- assigned only for the character bank show in the Warbank group (data/items.lua, ItemBelongsToTab).
    it("shows the Warbank group for a Warbank item whose category is assigned only in the character bank", function()
      assert.are.same({ { "group", 3 } }, pick("next", 13, "Herbs"))
    end)

    it("shows the bank type's default group for an item without a category", function()
      assert.are.same({ { "group", 3 } }, pick("next", 14, nil))
    end)

    it("switches the classic retail bank's groups through its behavior", function()
      assert.are.same({ { "group", 3 } }, pick("classic", 12, "Ore"))
    end)

    it("opens the bank before it switches", function()
      local bank = bankOf("next")
      function bank.behavior:SwitchToGroup() table.insert(calls, { "group after show", shown }) end
      override(items, "GetItemDataFromSlotKey", function(_, slotkey)
        return { slotkey = slotkey, bagid = 12, itemInfo = { itemName = "Item", category = "Ore" } }
      end)
      override(addon, "Bags", { Bank = bank })
      quickfind:ShowInBag("bank:12_1")
      assert.are.same({ { "group after show", 1 } }, calls)
    end)

    it("switches nothing while the bank's groups are off", function()
      db.groupsEnabled = false
      assert.are.same({}, pick("next", 12, "Ore"))
    end)

    describe("on WoW: Forever, without a Warbank", function()
      before_each(function()
        client("forever")
        bankGroups(false)
      end)

      it("shows the Bank group for an item in the ninth character tab", function()
        assert.are.same({ { "group", 2 } }, pick("next", 14, "Ore"))
      end)

      it("shows the group an item's category is assigned to", function()
        assert.are.same({ { "group", 4 } }, pick("classic", 14, "Herbs"))
      end)
    end)

    describe("on Classic, without bank tabs or a Warbank", function()
      before_each(function()
        client("classic")
        bankGroups(false)
      end)

      it("shows the group an item's category is assigned to in BetterBags Next", function()
        assert.are.same({ { "group", 4 } }, pick("next", 5, "Herbs"))
      end)

      it("shows the Bank group for an item whose category is assigned nowhere", function()
        assert.are.same({ { "group", 2 } }, pick("next", -1, "Ore"))
      end)

      it("switches nothing in the classic design, whose bank has no tabs", function()
        assert.has_no.errors(function() pick("no tabs", 5, "Herbs") end)
        assert.are.same({}, calls)
      end)

      -- Show Bank Tabs is retail's: a setting left on splits the bank's data by bag, never by group (data/items.lua).
      it("switches nothing with Show Bank Tabs left on", function()
        db.showBankTabs = true
        assert.are.same({}, pick("next", 5, "Herbs"))
      end)
    end)
  end)

  describe("in Blizzard's bank tabs (Show Bank Tabs, or the classic bank's Show Bags)", function()
    before_each(function()
      db.showBankTabs = true
    end)

    it("shows the tab holding the item in BetterBags Next", function()
      assert.are.same({ { "blizzard tab", 12 } }, pick("next", 12, "Ore"))
      calls = {}
      assert.are.same({ { "blizzard tab", 7 } }, pick("next", 7, "Herbs"))
    end)

    it("selects the tab holding the item in the classic bank's tab slots panel, which shows it", function()
      assert.are.same({ { "tab slot", 14 } }, pick("classic", 14, "Ore"))
    end)

    -- The groups do not apply here: a tab is one bag.
    it("shows the item's tab whatever group its category is assigned to, groups on or off", function()
      assert.are.same({ { "blizzard tab", 16 } }, pick("next", 16, "Gems"))
      db.groupsEnabled = false
      calls = {}
      assert.are.same({ { "blizzard tab", 9 } }, pick("next", 9, "Herbs"))
    end)

    it("shows a ninth character tab on WoW: Forever", function()
      client("forever")
      bankGroups(false)
      assert.are.same({ { "blizzard tab", 14 } }, pick("next", 14, "Ore"))
    end)
  end)
end)

-- The classic retail bank (bags/bank.lua) answers what QuickFind asks of it: these use its real behavior.
describe("QuickFind with the classic retail bank's behavior", function()
  local bag, drawn, bankTypes

  -- slotButton is one of the tab slots panel's buttons (frames/bankslots.lua): its tab, and whether it shows selected.
  local function slotButton(bagIndex)
    return { bagIndex = bagIndex, SetSelected = function(self, on) self.selected = on end }
  end

  before_each(function()
    drawn, bankTypes = {}, {}
    client("retail")
    bankGroups(true)
    override(database, "GetGroupsEnabled", function() return true end)
    override(database, "GetShowBankTabs", function() return false end)
    override(database, "GetInBagSearch", function() return false end)
    override(addon, "atBank", true)
    -- Blizzard's bank panel (Blizzard_UIPanels_Game/Mainline/BankFrame.lua), which the bank's behavior checks for
    -- before it sets the bank type through addon.SetBlizzardBankType (core/hooks.lua).
    override(_G, "BankPanel", { SetBankType = function() end })
    -- Live retail's Enum.BagIndex (vscode-wow-api Annotations/Core/Data/Enum.lua): character tabs from 6, Warbank tabs
    -- from 12; the bank's behavior tells the two apart by the first Warbank tab.
    override(Enum.BagIndex, "CharacterBankTab_1", 6)
    override(Enum.BagIndex, "AccountBankTab_1", 12)
    override(addon, "SetBlizzardBankType", function(bankType) table.insert(bankTypes, bankType) end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(_G, "print", function() end)
    bag = {
      kind = BANK,
      purchaseBankButton = CreateFrame("Button"),
      Show = function() end,
      Hide = function() end,
      SetTitle = function(self, title) self.title = title end,
      Draw = function() table.insert(drawn, true) end,
      tabs = { SetTabByID = function(self, _, id) self.selected = id end },
    }
    bag.behavior = bankBehavior:Create(bag)
    -- The real tab slots panel's methods, over three of its buttons.
    bag.slots = setmetatable({ buttons = { slotButton(6), slotButton(7), slotButton(12) } },
      { __index = bankSlots.bankSlotsPanelProto })
    override(addon, "Bags", { Bank = bag })
  end)

  after_each(restore)

  local function pick(bagid, category)
    override(items, "GetItemDataFromSlotKey", function(_, slotkey)
      return { slotkey = slotkey, bagid = bagid, itemInfo = { itemName = "Item", category = category } }
    end)
    quickfind:ShowInBag("bank:" .. bagid .. "_1")
  end

  it("shows the Warbank group for a Warbank item while the Bank group is shown", function()
    pick(12, "Ore")
    assert.are.equal(3, dbActive[BANK])
    assert.are.equal(3, bag.tabs.selected)
    assert.are.equal("Warbank", bag.title)
    assert.are.same({ ACCOUNT }, bankTypes)
    assert.are.equal(1, #drawn)
  end)

  it("shows the group a character bank item's category is assigned to", function()
    pick(7, "Herbs")
    assert.are.equal(4, dbActive[BANK])
    assert.are.equal("Herbs", bag.title)
    assert.are.same({ CHAR }, bankTypes)
  end)

  it("selects and shows the Blizzard tab holding the item with Show Bags on", function()
    override(database, "GetShowBankTabs", function() return true end)
    pick(12, "Ore")
    assert.are.same({ false, false, true }, { bag.slots.buttons[1].selected, bag.slots.buttons[2].selected,
      bag.slots.buttons[3].selected })
    assert.are.equal(12, bag.slots.selectedBagIndex)
    assert.are.equal(12, bag.blizzardBankTab)
    assert.are.equal(12, bag.bankTab)
    assert.are.same({ ACCOUNT }, bankTypes)
    assert.are.equal(2, dbActive[BANK], "the group shown is left as it was")
  end)
end)

-- In-Bag Search: the item picked is searched for by its whole name, as one quoted text (#1344). Unquoted, the query
-- language reads a name's words as terms and operators (util/query.lua): "Ruby Ring" searched for "Ruby" alone.
describe("QuickFind's search for the item picked", function()
  local box

  local function index(list)
    search:Init()
    for i, entry in ipairs(list) do
      search:Add(MockData.ItemData({ slotkey = "0_" .. i, name = entry[1], tooltipText = entry[2] }))
    end
  end

  -- pick presses Enter on the backpack item named name, In-Bag Search on, and returns what the bag's search box then
  -- finds, by slot key, sorted.
  local function pick(name)
    override(items, "GetItemDataFromSlotKey", function(_, slotkey)
      return { slotkey = slotkey, bagid = 0, itemInfo = { itemName = name } }
    end)
    quickfind:ShowInBag("backpack:0_1")
    local found = {}
    for slotkey in pairs(search:Search(box.text)) do table.insert(found, slotkey) end
    table.sort(found)
    return found
  end

  before_each(function()
    box = {
      SetText = function(self, text) self.text = text end,
      SetFocus = function(self) self.focused = true end,
      HighlightText = function(self) self.highlighted = true end,
    }
    override(database, "GetInBagSearch", function() return true end)
    override(database, "GetGroupsEnabled", function() return false end)
    override(addon, "Bags", { Backpack = { Show = function() end, searchBox = { textBox = box } } })
    index({
      { "Ruby Ring" },
      { "Ruby" },
      { "Ruby Ring of the Tides" },
      { "Recipe: Ruby Ring", "Teaches you how to make a Ruby Ring." },
      { "Ruby Ring" },
      { "Salt and Pepper Shank" },
      { "Salt" },
      { "Rings Not Included" },
      { "Rings" },
      { "Hearthstone of the Forsaken" },
      { 'The "Lucky" Coin' },
    })
  end)

  after_each(restore)

  it("finds the items of that exact name, every stack, and nothing whose name or tooltip only holds it", function()
    assert.are.same({ "0_1", "0_5" }, pick("Ruby Ring"))
  end)

  it("reads and, or and not in a name as words of the name", function()
    assert.are.same({ "0_6" }, pick("Salt and Pepper Shank"))
    assert.are.same({ "0_8" }, pick("Rings Not Included"))
    assert.are.same({ "0_10" }, pick("Hearthstone of the Forsaken"))
  end)

  it("finds a name holding a quotation mark", function()
    assert.are.same({ "0_11" }, pick('The "Lucky" Coin'))
  end)

  it("finds a one-word name exactly", function()
    assert.are.same({ "0_2" }, pick("Ruby"))
  end)

  it("focuses the search box and selects the text, so typing replaces it", function()
    pick("Ruby Ring")
    assert.is_true(box.focused)
    assert.is_true(box.highlighted)
  end)
end)

-- Enable QuickFind Integration (#1262, quickfind.md): BetterBags' items are a QuickFind source whenever QuickFind is
-- loaded, since QuickFind has no way to take a source back (its API.lua: RegisterSource only), and the source is
-- empty while the integration is off, so the switch takes effect at once.
describe("QuickFind integration switch", function()
  local on, registered, printed

  before_each(function()
    on, registered, printed = true, {}, {}
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

  after_each(restore)

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
