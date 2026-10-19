-- vendor_spec.lua -- NextVendor (next/vendor.lua): BetterBags Next's vendor (next.md §10). A panel on
-- the left, as the bank's, that stands in for Blizzard's merchant frame while BetterBags Next is on:
-- the vendor's items in the backpack's categories, Buy, Buyback and Repair tabs, Sell Junk, Repair All,
-- the guild's repair, the spec filter, selling what is dropped on it, and every way of closing it
-- ending the vendor visit.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 0, BANK = 1 }

local stubs = {
  L = trackStub("Localization"),
  items = trackStub("Items"),
  database = trackStub("Database"),
  events = trackStub("Events"),
  searchBox = trackStub("SearchBox"),
  sonata = trackStub("Sonata"),
  cursorPlacement = trackStub("CursorPlacement"),
  sectionFrame = trackStub("SectionFrame"),
  groups = trackStub("Groups"),
  merchant = trackStub("NextMerchant"),
  itemFrame = trackStub("ItemFrame"),
  question = trackStub("Question"),
}

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
local modules = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextPanel", "next/panel.lua" }, { "NextVendorButton", "next/vendorbutton.lua" },
  { "NextVendor", "next/vendor.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextVendor = addon:GetModule("NextVendor")
local nextDrag = addon:GetModule("NextDrag")
local vendorButton = addon:GetModule("NextVendorButton")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

describe("NextVendor", function()
  local eventsRegistered, buckets, timers, calls, data, asked

  local function ctx() return context:New("spec") end

  local function forSale(index, category, opts)
    local i = { index = index, link = "|Hitem:" .. index .. "|h", itemID = index, name = "Item " .. index,
      texture = index, price = 100, stackCount = 1, numAvailable = -1, maxStack = 20, isPurchasable = true,
      isUsable = true, hasExtendedCost = false, isQuestStartItem = false, canAfford = true, refundable = true,
      isKnownHeirloom = false, quality = 1, costs = {}, category = category, record = { slotkey = "vendor:" .. index } }
    for k, v in pairs(opts or {}) do i[k] = v end
    return i
  end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function runTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
  end

  local function sectionNames(v)
    local out = {}
    for _, s in ipairs(v.content.order) do table.insert(out, s.name) end
    return out
  end

  local function tabIDs(v)
    local ids = {}
    for _, t in ipairs(v.tabs.tabs) do table.insert(ids, t.id) end
    return ids
  end

  local function click(button, mouse)
    button:GetScript("OnClick")(button, mouse or "LeftButton")
  end

  -- open makes the vendor and opens it the way the client does: Blizzard shows its merchant frame,
  -- then MERCHANT_SHOW.
  local function open()
    local v = nextVendor:Create(ctx())
    MerchantFrame:Show()
    eventsRegistered["MERCHANT_SHOW"](ctx())
    finishTweens()
    return v
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    nextDrag:Init()
    vendorButton:Init()
    ResetMockMerchant()
    ResetMockGuildBank()
    eventsRegistered, buckets, timers = {}, {}, {}
    calls = { sellAll = 0, sellSlots = {}, repairAll = {}, purchase = {} }
    asked = nil
    data = {
      items = { forSale(1, "Food"), forSale(2, "Armor"), forSale(3, "Food") },
      buyback = { { index = 2, name = "Sold B", texture = 9, price = 5, quantity = 1, isUsable = true },
        { index = 1, name = "Sold A", texture = 8, price = 4, quantity = 1, isUsable = true } },
      repair = { equipped = { { slot = 1, texture = 7, durability = 10, maxDurability = 100, cost = 2000 } },
        bags = { { bag = 0, slot = 3, texture = 6, durability = 1, maxDurability = 4, cost = 500 } } },
      search = nil, junk = 2, hasSellAll = true, junkSlots = { { bag = 0, slot = 1 } },
    }
    override(addon, "isRetail", true)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
    override(const, "BAG_KIND", { BACKPACK = 0, BANK = 1, UNDEFINED = -1 })
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 } })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2 })
    override(_G, "MerchantFrame", CreateFrame("Frame", "MerchantFrame"))
    MerchantFrame.selectedTab = 1
    MerchantFrame:Hide()
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.items, "ExpireRecentItems", function() return false end)
    override(stubs.database, "GetNextChain", function() return "apart" end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    override(stubs.database, "GetGroupsEnabled", function() return false end)
    override(stubs.events, "SendMessage", function() end)
    override(stubs.events, "RegisterMessage", function() end)
    override(stubs.events, "RegisterEvent", function(_, name, fn) eventsRegistered[name] = fn end)
    override(stubs.events, "BucketEvent", function(_, name, fn, filter) buckets[name] = { fn, filter } end)
    override(stubs.searchBox, "CreateBox", function() error("the vendor makes its own search box") end)
    override(stubs.sonata, "UnregisterElement", function() end)
    override(stubs.merchant, "ReadItems", function() return data.items, false end)
    override(stubs.merchant, "BuildSections", function(_, list)
      local byName, order = {}, {}
      for _, i in ipairs(list) do
        if not byName[i.category] then
          byName[i.category] = { name = i.category, items = {} }
          table.insert(order, byName[i.category])
        end
        table.insert(byName[i.category].items, i)
      end
      table.sort(order, function(a, b) return a.name < b.name end)
      return order
    end)
    override(stubs.merchant, "Search", function() return data.search end)
    override(stubs.merchant, "ReadBuyback", function() return data.buyback end)
    override(stubs.merchant, "ReadRepair", function() return data.repair end)
    override(stubs.merchant, "HasSellAllJunk", function() return data.hasSellAll end)
    override(stubs.merchant, "NumJunk", function() return data.junk end)
    override(stubs.merchant, "JunkSlots", function() return data.junkSlots end)
    override(stubs.merchant, "SellAllJunk", function() calls.sellAll = calls.sellAll + 1 end)
    override(stubs.merchant, "SellSlots", function(_, slots, stillOpen)
      table.insert(calls.sellSlots, { slots = slots, open = stillOpen() })
    end)
    override(stubs.merchant, "RepairAll", function(_, guild) table.insert(calls.repairAll, guild) end)
    override(stubs.merchant, "Purchase", function(_, frame, i) table.insert(calls.purchase, i) end)
    override(stubs.question, "YesNo", function(_, title, text, yes, no) asked = { title = title, text = text, yes = yes, no = no } end)
    override(C_Timer, "After", function(_, fn) table.insert(timers, fn) end)
    override(_G, "PlaySound", function() end)
    override(_G, "UnitName", function(unit) return unit == "npc" and "Mira the Smith" or "Me" end)
    override(_G, "GetMoney", function() return 12345 end)
    _G._cursorHasItem = false
    _G._extendedPriceShown = false
    _G._hiddenPopups = {}
    _G._gameRules = {}
    _G._lastContextMenu = nil
    _G._cursor = "BUY_CURSOR"
  end)

  after_each(function()
    restore()
    ResetMockMerchant()
    ResetMockGuildBank()
    _G._cursorHasItem = false
    _G._extendedPriceShown = false
    _G._lastContextMenu = nil
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  -- Vendors, banks and the backpack chain alike (next.md §12): the vendor is the backpack's
  -- companion, like the bank, and its name chains it.
  describe("chaining", function()
    it("is the backpack's companion, and its name goes to the chain", function()
      local v = nextVendor:Create(ctx())
      local chain = addon:GetModule("NextChain")
      assert.are.equal("companion", v.chainRole)
      local clicked
      override(chain, "Click", function(_, _, panel) clicked = panel return "alone" end)
      v.titleButton:GetScript("OnClick")(v.titleButton, "LeftButton")
      assert.are.equal(v, clicked)
    end)
  end)

  describe("the panel", function()
    it("is a hidden, named panel on the left, its rows tall enough for prices", function()
      local v = nextVendor:Create(ctx())
      assert.are.equal("BetterBagsNextVendor", v:GetName())
      assert.are.equal("LEFT", v.side)
      assert.is_false(v:IsShown())
      assert.are.equal(style.ICON + style.VENDOR_PRICE, v.content.cellHeight)
      assert.are.equal("HIGH", v.frame:GetFrameStrata())
    end)

    it("is no source of section drags, nor a panel they reorder in (it buys them: a seller)", function()
      local v = open()
      for _, panel in ipairs(nextDrag.panels) do assert.are_not.equal(v, panel) end
      local s = v.content.order[1]
      s.header:GetScript("OnDragStart")(s.header)
      assert.is_false(nextDrag:IsActive())
    end)

    -- Its box sets its own OnTextChanged, which replaces the template's, the one that hid the help text
    -- (InputBoxInstructions_OnTextChanged), so "Search Vendor" stayed under what was typed.
    it("hides its help text while something is typed, and shows it again once emptied", function()
      local v = open()
      local t = v.searchBox.textBox
      assert.are.equal("Search Vendor", t.Instructions:GetText())
      t:SetText("plate")
      t:GetScript("OnTextChanged")(t, true)
      assert.is_false(t.Instructions:IsShown())
      t:SetText("")
      t:GetScript("OnTextChanged")(t, true)
      assert.is_true(t.Instructions:IsShown())
    end)

    it("has a search box of its own, always shown, filtering the vendor's items", function()
      local v = open()
      assert.is_true(v.searchBox.frame:IsShown())
      data.search = { ["vendor:2"] = true }
      v.searchBox.textBox:SetText("plate")
      v.searchBox.textBox:GetScript("OnTextChanged")(v.searchBox.textBox, true)
      assert.are.equal(0.25, v.buttons["vendor:1"].frame:GetAlpha())
      assert.are.equal(1, v.buttons["vendor:2"].frame:GetAlpha())
      data.search = nil
      v.searchBox.textBox:SetText("")
      v.searchBox.textBox:GetScript("OnTextChanged")(v.searchBox.textBox, true)
      assert.are.equal(1, v.buttons["vendor:1"].frame:GetAlpha())
    end)
  end)

  describe("its header", function()
    local function icons(v)
      local out = {}
      for _, b in ipairs(v.headerButtons) do table.insert(out, b.icon:GetAtlas() or b.icon:GetTexture()) end
      return out
    end

    it("lines up close, settings, the filter, Sell Junk, Repair All and the guild's repair on retail", function()
      local v = nextVendor:Create(ctx())
      assert.are.same({ "uitools-icon-close", "uitools-icon-settings", "ui-questtrackerbutton-filter",
        "SpellIcon-256x256-SellJunk", "SpellIcon-256x256-RepairAll", "SpellIcon-256x256-RepairAllGuild" }, icons(v))
    end)

    it("uses Classic's repair icons and a coin for Sell Junk, and has no filter there", function()
      override(addon, "isRetail", false)
      override(C_MerchantFrame, "GetItemInfo", nil)
      override(_G, "SetMerchantFilter", nil)
      local v = nextVendor:Create(ctx())
      assert.are.same({ "uitools-icon-close", "uitools-icon-settings", "Interface\\Icons\\INV_Misc_Coin_02",
        "Interface\\MerchantFrame\\UI-Merchant-RepairIcons", "Interface\\MerchantFrame\\UI-Merchant-RepairIcons" },
        icons(v))
      assert.are.same({ 0.28125, 0.5625, 0, 0.5625 }, v.repairAllButton.icon._texCoords)
    end)

    it("shows the repair buttons only at a vendor that repairs, the guild's only when the guild pays", function()
      _G._merchant.canRepair = false
      local v = open()
      assert.is_false(v.repairAllButton:IsShown())
      assert.is_false(v.guildRepairButton:IsShown())
      v:Hide(ctx())
      finishTweens()
      _G._merchant.canRepair, _G._merchant.canGuildRepair = true, false
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      assert.is_true(v.repairAllButton:IsShown())
      assert.is_false(v.guildRepairButton:IsShown())
      assert.are.same({ "LEFT", v.sellJunkButton, "RIGHT", 8, 0 }, { v.repairAllButton:GetPoint(1) })
    end)

    it("keeps the vendor's name to the room right of its shown buttons, on one line", function()
      local function room(n)
        return style.BODY_WIDTH - (style.PAD + 4) - (style.PAD + n * 22 + (n - 1) * 8) - 12
      end
      _G._merchant.canRepair, _G._merchant.canGuildRepair = true, true
      local v = open()
      assert.are.equal(room(6), v.title:GetWidth())
      assert.is_false(v.title:CanWordWrap())
      v:Hide(ctx())
      finishTweens()
      _G._merchant.canRepair = false
      eventsRegistered["MERCHANT_SHOW"](ctx())
      assert.are.equal(room(4), v.title:GetWidth())
    end)

    it("hides the filter where a game rule turns it off", function()
      _G._gameRules[Enum.GameRule.MerchantFilterDisabled] = true
      local v = open()
      assert.is_false(v.filterButton:IsShown())
      assert.are.same({ "LEFT", v.settingsButton, "RIGHT", 8, 0 }, { v.sellJunkButton:GetPoint(1) })
    end)
  end)

  -- Reported, at a vendor in an instance: "next/panel.lua:742: attempt to perform arithmetic on a
  -- secret number value (execution tainted by 'BetterBags')" in CloudSpan, from SetTitle in
  -- OnShowing. UnitName is SecretWhenUnitNameIdentityRestricted (UnitDocumentation.lua), so in a
  -- dungeon or raid the vendor's name is secret; FontString:SetText takes it, and GetStringWidth is
  -- then secret (SecretWhenAnchoringSecret, SimpleFontStringAPIDocumentation.lua).
  describe("with a secret vendor name (an instance)", function()
    local name
    before_each(function()
      override(_G, "issecretvalue", IsMockSecret)
      name = MockSecret("Mira the Smith")
      override(_G, "UnitName", function(unit) if unit == "npc" then return name end return "Me" end)
    end)

    it("opens, still shows the name, and lays its cloud out without measuring it", function()
      local v = open()
      assert.is_true(v:IsShown())
      assert.are.equal(name, v.title:GetText(), "the name still shows")
      assert.are.equal(style.Cloud.SecretTitleWidth + style.PAD + 4 + style.Cloud.Pad, v:CloudSpan())
      for _ = 1, 20 do
        v.cloudSparkles.options.Spawn()
      end
    end)

    it("calls itself Vendor in its title's tooltip, never by the secret name", function()
      local v = open()
      v.titleButton:GetScript("OnEnter")(v.titleButton)
      assert.are.equal("Vendor", GameTooltip._header)
      v.titleButton:GetScript("OnLeave")(v.titleButton)
    end)

    it("measures its name again once the name is no longer secret", function()
      local v = open()
      v:Hide(ctx())
      finishTweens()
      name = "Mira the Smith"
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      assert.are.equal(#"Mira the Smith" * 6 + style.PAD + 4 + style.Cloud.Pad, v:CloudSpan())
    end)
  end)

  describe("opening", function()
    it("shows the vendor's name, resets the filter and draws what it sells in categories", function()
      local v = open()
      assert.is_true(v:IsShown())
      assert.are.equal("Mira the Smith", v.title:GetText())
      assert.are.equal(1, _G._merchantCalls.filterReset)
      assert.are.same({ "Armor", "Food" }, sectionNames(v))
      assert.are.equal("Item 3", v.content.order[2].entries[2].item.item.name)
    end)

    it("lists Buy and Buyback, and Repair at a vendor that repairs", function()
      local v = open()
      assert.are.same({ 1, 2 }, tabIDs(v))
      assert.are.equal(1, v.tabs.selected)
      v:Hide(ctx())
      finishTweens()
      _G._merchant.canRepair = true
      eventsRegistered["MERCHANT_SHOW"](ctx())
      assert.are.same({ 1, 2, 3 }, tabIDs(v))
    end)

    it("opens on Buy whatever tab it last showed", function()
      local v = open()
      click(v.tabs.tabs[2].button)
      v:Hide(ctx())
      finishTweens()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      assert.are.equal(1, v.tabs.selected)
    end)
  end)

  describe("its tabs", function()
    it("keeps a button for each item across redraws, and lets go of the ones gone", function()
      local v = open()
      local b2 = v.buttons["vendor:2"]
      local b3 = v.buttons["vendor:3"]
      data.items = { forSale(2, "Armor") }
      eventsRegistered["MERCHANT_UPDATE"](ctx())
      assert.are.equal(b2, v.buttons["vendor:2"])
      assert.is_nil(v.buttons["vendor:3"])
      assert.is_false(b3.frame:IsShown())
    end)

    it("shows what was sold on Buyback, newest first, and says when nothing was", function()
      local v = open()
      click(v.tabs.tabs[2].button)
      assert.are.same({ "Sold" }, sectionNames(v))
      assert.are.same({ "Sold B", "Sold A" }, { v.content.order[1].entries[1].item.buyback.name,
        v.content.order[1].entries[2].item.buyback.name })
      data.buyback = {}
      eventsRegistered["MERCHANT_UPDATE"](ctx())
      assert.is_true(v.emptyText:IsShown())
      assert.are.equal("Nothing sold yet", v.emptyText:GetText())
    end)

    it("shows what needs repair, worn and in the bags, and what repairing it all costs", function()
      _G._merchant.canRepair = true
      local v = open()
      click(v.tabs.tabs[3].button)
      assert.are.same({ "Equipped", "In your bags" }, sectionNames(v))
      assert.are.equal("Repair all: 25s", v.freeText:GetText())
      data.repair = { equipped = {}, bags = {} }
      eventsRegistered["UPDATE_INVENTORY_DURABILITY"](ctx())
      assert.are.equal("Nothing needs repair", v.emptyText:GetText())
      assert.is_true(v.emptyText:IsShown())
    end)

    it("shows the player's gold and the vendor's currencies in its footer on Buy", function()
      _G._merchant.currencies = { 42 }
      _G._currencies[42] = { name = "Valor", iconFileID = 77, quantity = 1200 }
      local v = open()
      assert.are.equal("1g 23s 45c   |T77:0|t 1200", v.freeText:GetText())
    end)
  end)

  describe("keeping up", function()
    it("redraws on the merchant's updates and on new item data while shown", function()
      local v = open()
      data.items = { forSale(5, "Gems") }
      eventsRegistered["MERCHANT_FILTER_ITEM_UPDATE"](ctx())
      assert.are.same({ "Gems" }, sectionNames(v))
      data.items = { forSale(6, "Ore") }
      assert.is_true(buckets["GET_ITEM_INFO_RECEIVED"][2]())
      buckets["GET_ITEM_INFO_RECEIVED"][1](ctx())
      assert.are.same({ "Ore" }, sectionNames(v))
      v:Hide(ctx())
      finishTweens()
      assert.is_false(buckets["GET_ITEM_INFO_RECEIVED"][2](), "not while hidden")
    end)

    it("updates what it can afford and the junk on bag and money changes", function()
      local v = open()
      data.junk = 0
      eventsRegistered["BAG_UPDATE_DELAYED"](ctx())
      assert.is_false(v.sellJunkButton:IsEnabled())
      assert.is_true(v.sellJunkButton.icon:IsDesaturated())
      data.junk = 1
      eventsRegistered["PLAYER_MONEY"](ctx())
      assert.is_true(v.sellJunkButton:IsEnabled())
    end)
  end)

  describe("selling junk", function()
    it("uses Blizzard's own Sell All Junk where the client has it", function()
      local v = open()
      click(v.sellJunkButton)
      assert.are.equal(1, calls.sellAll)
      assert.is_nil(asked)
    end)

    it("asks first on Classic, then sells the junk, again a moment later while junk is left", function()
      data.hasSellAll = false
      local v = open()
      click(v.sellJunkButton)
      assert.are.equal("Sell Junk", asked.title)
      assert.are.equal("Sell 2 junk items? Only the last 12 items sold can be bought back.", asked.text)
      asked.yes()
      assert.are.same({ { slots = data.junkSlots, open = true } }, calls.sellSlots)
      runTimers()
      assert.are.equal(2, #calls.sellSlots)
      data.junkSlots = {}
      runTimers()
      assert.are.equal(2, #calls.sellSlots, "stops once none is left")
      assert.are.same({}, timers)
    end)

    it("sells at most three rounds", function()
      data.hasSellAll = false
      local v = open()
      click(v.sellJunkButton)
      asked.yes()
      runTimers()
      runTimers()
      runTimers()
      assert.are.equal(3, #calls.sellSlots)
      assert.are.same({}, timers)
    end)

    it("stops selling once the vendor has closed", function()
      data.hasSellAll = false
      local v = open()
      click(v.sellJunkButton)
      asked.yes()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      runTimers()
      assert.are.equal(1, #calls.sellSlots)
    end)
  end)

  describe("repairing", function()
    it("repairs everything from the player's gold or the guild's, telling what it costs", function()
      _G._merchant.canRepair, _G._merchant.canGuildRepair = true, true
      _G._merchant.repairCost = 20000
      _G._guildBank.withdrawMoney, _G._guildBank.money = 5000, 900000
      local v = open()
      v.repairAllButton:GetScript("OnEnter")(v.repairAllButton)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ "Repair all: 2g", "You do not have enough money" }, text)
      v.guildRepairButton:GetScript("OnEnter")(v.guildRepairButton)
      text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ "Repair all: 2g", "The guild pays up to 50s" }, text)
      click(v.repairAllButton)
      click(v.guildRepairButton)
      assert.are.same({ false, true }, calls.repairAll)
      _G._merchant.canGuildRepair = false
      click(v.guildRepairButton)
      assert.are.same({ false, true }, calls.repairAll, "not once the guild stops paying")
    end)

    it("tells a guild leader the guild bank's whole balance, anyone else what they may withdraw of it", function()
      _G._merchant.canRepair, _G._merchant.canGuildRepair, _G._merchant.repairCost = true, true, 20000
      local v = open()
      local function said()
        v.guildRepairButton:GetScript("OnEnter")(v.guildRepairButton)
        return GameTooltip.lines[2].text
      end
      _G._guildBank.withdrawMoney, _G._guildBank.money = -1, 900000
      assert.are.equal("The guild pays up to 90g", said())
      _G._guildBank.withdrawMoney, _G._guildBank.money = 500000, 300
      assert.are.equal("The guild pays up to 3s", said())
    end)

    it("cannot repair when nothing needs it", function()
      _G._merchant.canRepair, _G._merchant.repairCost = true, 0
      local v = open()
      assert.is_false(v.repairAllButton:IsEnabled())
    end)
  end)

  describe("the filter", function()
    it("offers Blizzard's filters: each spec, the class, Bind on Equip and everything", function()
      local v = open()
      click(v.filterButton)
      local menu = _G._lastContextMenu.root
      local radios = {}
      for _, e in ipairs(menu.entries) do
        if e.kind == "radio" then table.insert(radios, { e.text, e.data }) end
      end
      assert.are.same({ { "Spec 1", LE_LOOT_FILTER_SPEC1 }, { "Spec 2", LE_LOOT_FILTER_SPEC1 + 1 },
        { "All Specializations", LE_LOOT_FILTER_CLASS }, { "Bind on Equip", LE_LOOT_FILTER_BOE },
        { "All", LE_LOOT_FILTER_ALL } }, radios)
      menu.entries[5].setSelected(LE_LOOT_FILTER_BOE)
      assert.are.same({ LE_LOOT_FILTER_BOE }, _G._merchantCalls.filters)
      assert.is_true(menu.entries[5].isSelected(LE_LOOT_FILTER_BOE))
    end)
  end)

  describe("selling by dropping", function()
    it("sells an item dropped on it or let go over it", function()
      local v = open()
      _G._cursorHasItem = true
      v.frame:GetScript("OnReceiveDrag")(v.frame)
      v.frame:GetScript("OnMouseUp")(v.frame, "LeftButton")
      assert.are.same({ 0, 0 }, _G._merchantCalls.pickup)
      _G._cursorHasItem = false
      v.frame:GetScript("OnReceiveDrag")(v.frame)
      assert.are.equal(2, #_G._merchantCalls.pickup)
    end)

    it("lets Blizzard ask first about selling a refundable item, as its merchant frame does", function()
      local v = open()
      _G._cursorHasItem = true
      MerchantFrame.refundItem = "bag button"
      MerchantFrame.refundItemEquipped = false
      _G._extendedPriceShown = true
      v.frame:GetScript("OnReceiveDrag")(v.frame)
      assert.are.same({}, _G._merchantCalls.pickup)
      assert.are.equal("bag button", _G._extendedPriceAsked.button)
    end)

    it("sells an item dropped on a section header too", function()
      local v = open()
      _G._cursorHasItem = true
      local h = v.content.order[1].header
      h:GetScript("OnReceiveDrag")(h)
      assert.are.same({ 0 }, _G._merchantCalls.pickup)
    end)
  end)

  -- A backpack section dragged onto the vendor is sold (NextDrag's seller, next.md §10).
  describe("selling a section", function()
    local infos

    local function slotData(bag, slot)
      return { bagid = bag, slotid = slot, slotkey = bag .. "_" .. slot }
    end

    local function slotsOf(list)
      local out = {}
      for _, d in ipairs(list) do table.insert(out, d.slotkey) end
      return out
    end

    before_each(function()
      infos = {}
      _G._refundableLocations = {}
      override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
      override(stubs.sectionFrame, "WithStacks", function(_, list)
        local all = {}
        for _, d in ipairs(list) do
          table.insert(all, d)
          if d.hides then
            for _, h in ipairs(d.hides) do table.insert(all, h) end
          end
        end
        return all
      end)
      override(C_Container, "GetContainerItemInfo", function(bag, slot)
        return infos[bag .. "_" .. slot] or { hasNoValue = false }
      end)
    end)

    after_each(function()
      _G._refundableLocations = {}
    end)

    it("is a seller for section drags", function()
      local v = nextVendor:Create(ctx())
      assert.are.same({ v }, nextDrag.sellers)
    end)

    it("sells every item and hidden pile of the backpack's bags the vendor buys, refunds aside, once each", function()
      local v = open()
      local stacked = slotData(0, 2)
      stacked.hides = { slotData(1, 7), slotData(0, 2) }
      infos["0_3"] = { hasNoValue = true }
      _G._refundableLocations["1:1"] = true
      local sale = v:SaleOf({ slotData(0, 1), stacked, slotData(0, 3), slotData(1, 1), slotData(6, 1) })
      assert.are.same({ "0_1", "0_2", "1_7" }, slotsOf(sale))
    end)

    it("sells up to 12 at once, while the vendor is open", function()
      local v = open()
      local sale = {}
      for i = 1, 12 do table.insert(sale, slotData(0, i)) end
      assert.are.equal("sold", v:Sell(ctx(), sale))
      assert.is_nil(asked)
      assert.are.equal(12, #calls.sellSlots[1].slots)
      assert.are.same({ bag = 0, slot = 3 }, calls.sellSlots[1].slots[3])
      assert.is_true(calls.sellSlots[1].open)
    end)

    it("asks first past 12, the last 12 sold being all buyback keeps", function()
      local v = open()
      local sale = {}
      for i = 1, 13 do table.insert(sale, slotData(0, i)) end
      assert.are.equal("asked", v:Sell(ctx(), sale))
      assert.are.same({}, calls.sellSlots)
      assert.are.equal("Sell Items", asked.title)
      assert.are.equal("Sell 13 items? Only the last 12 items sold can be bought back.", asked.text)
      asked.no()
      assert.are.same({}, calls.sellSlots)
      asked.yes()
      assert.are.equal(13, #calls.sellSlots[1].slots)
    end)

    it("sells nothing once the vendor has closed", function()
      local v = open()
      local sale = {}
      for i = 1, 13 do table.insert(sale, slotData(0, i)) end
      v:Sell(ctx(), sale)
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      asked.yes()
      assert.is_false(calls.sellSlots[1].open)
    end)
  end)

  -- Switching between the classic design and BetterBags Next without a reload (next.md §11): the
  -- vendor is switched only away from a vendor, and catches up when the next one opens.
  describe("switching designs (Deactivate, Activate)", function()
    it("hides at once and lets go of every button", function()
      local v = open()
      local b = v.buttons["vendor:1"]
      v:Deactivate(ctx())
      assert.is_false(v.frame:IsShown())
      assert.are.same({}, v.buttons)
      assert.is_false(b.frame:IsShown())
    end)

    it("has nothing to catch up on: the next vendor that opens draws everything", function()
      local v = nextVendor:Create(ctx())
      assert.has_no.errors(function() v:Activate(ctx()) end)
      assert.is_false(v.frame:IsShown())
    end)
  end)

  describe("closing", function()
    it("ends the visit at once from its close button, once", function()
      local v = open()
      click(v.closeButton)
      click(v.closeButton)
      assert.are.equal(1, _G._merchantCalls.closed)
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      finishTweens()
      assert.is_false(v:IsShown())
      assert.are.equal(1, _G._merchantCalls.closed)
    end)

    it("hides when the vendor closes, ending nothing itself", function()
      local v = open()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      finishTweens()
      assert.is_false(v:IsShown())
      assert.are.equal(0, _G._merchantCalls.closed)
    end)

    it("ends the visit a frame later when Escape hides it, outside Blizzard's own code", function()
      local v = open()
      v.frame:Hide()
      v.frame:GetScript("OnHide")(v.frame)
      assert.are.equal(0, _G._merchantCalls.closed)
      runTimers()
      assert.are.equal(1, _G._merchantCalls.closed)
    end)

    it("ends it once when Escape hides both it and Blizzard's merchant frame", function()
      local sneaky = CreateFrame("Frame")
      sneaky:Hide()
      local v = nextVendor:Create(ctx())
      nextVendor:TakeOver(sneaky)
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      v.frame:Hide()
      v.frame:GetScript("OnHide")(v.frame)
      MerchantFrame:Hide()
      runTimers()
      assert.are.equal(1, _G._merchantCalls.closed)
    end)

    it("ends nothing when the vendor closed before the frame passed", function()
      local sneaky = CreateFrame("Frame")
      sneaky:Hide()
      nextVendor:Create(ctx())
      nextVendor:TakeOver(sneaky)
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      -- Blizzard's MerchantFrame_MerchantClosed hides its frame, then MERCHANT_CLOSED arrives.
      MerchantFrame:Hide()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      runTimers()
      assert.are.equal(0, _G._merchantCalls.closed)
    end)

    it("puts the cursor back and closes Blizzard's purchase prompts when the vendor closes", function()
      open()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      assert.is_nil(_G._cursor)
      assert.are.same({ "CONFIRM_PURCHASE_TOKEN_ITEM", "CONFIRM_PURCHASE_ITEM_DELAYED", "CONFIRM_REFUND_TOKEN_ITEM",
        "CONFIRM_REFUND_MAX_HONOR", "CONFIRM_REFUND_MAX_ARENA_POINTS" }, _G._hiddenPopups)
    end)
  end)

  -- With BetterBags Next on, Blizzard's merchant frame stays shown but is never seen: Blizzard's
  -- bag code sells while MerchantFrame:IsShown(), and MerchantFrame_OnHide would end the visit.
  describe("Blizzard's merchant frame", function()
    it("is put under the hidden frame, and its hide by the panel manager ends the visit a frame later", function()
      local sneaky = CreateFrame("Frame")
      sneaky:Hide()
      local v = nextVendor:Create(ctx())
      nextVendor:TakeOver(sneaky)
      assert.are.equal(sneaky, MerchantFrame:GetParent())
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      MerchantFrame:Hide()
      assert.are.equal(0, _G._merchantCalls.closed)
      runTimers()
      assert.are.equal(1, _G._merchantCalls.closed)
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      finishTweens()
      assert.is_false(v:IsShown())
      MerchantFrame:Hide()
      assert.are.same({}, timers, "nothing to end once closed")
      runTimers()
      assert.are.equal(1, _G._merchantCalls.closed)
    end)

    -- Switching designs (next.md §11): the classic design shows Blizzard's merchant frame again.
    it("is given back to UIParent when BetterBags Next is switched off, and taken again, hooked once", function()
      local sneaky = CreateFrame("Frame")
      sneaky:Hide()
      nextVendor:Create(ctx())
      nextVendor:TakeOver(sneaky)
      nextVendor:GiveBack()
      assert.are.equal(UIParent, MerchantFrame:GetParent())
      nextVendor:TakeOver(sneaky)
      assert.are.equal(sneaky, MerchantFrame:GetParent())
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      local before = #timers
      MerchantFrame:Hide()
      assert.are.equal(before + 1, #timers, "one hook")
    end)
  end)
end)
