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
  categories = trackStub("Categories"),
  groups = trackStub("Groups"),
  merchant = trackStub("NextMerchant"),
  itemFrame = trackStub("ItemFrame"),
  question = trackStub("Question"),
  automation = trackStub("Automation"),
  seller = trackStub("Seller"),
  shoppingList = trackStub("ProfessionShoppingList"),
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
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextLift", "next/lift.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDockCard", "next/dockcard.lua" }, { "NextDock", "next/dock.lua" }, { "NextDrag", "next/drag.lua" }, { "NextChain", "next/chain.lua" }, { "NextOrnaments", "next/ornaments.lua" }, { "NextPanel", "next/panel.lua" }, { "NextVendorButton", "next/vendorbutton.lua" },
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
local nextDock = addon:GetModule("NextDock")
local nextContent = addon:GetModule("NextContent")

describe("NextVendor", function()
  local eventsRegistered, buckets, timers, calls, data, asked, messages

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

  -- slotsOfSale returns the slot keys a sale was handed.
  local function slotsOfSale(job)
    local out = {}
    for _, d in ipairs(job.list) do table.insert(out, d.slotkey or (d.bag .. "_" .. d.slot)) end
    return out
  end

  -- finishSale ends a sale as the seller does, unsold of its items left in the bags.
  local function finishSale(job, reason, unsold)
    job.unsold, job.left = unsold or 0, 0
    if job.opts.onDone then job.opts.onDone(job, reason or "done") end
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
    nextDock:Init()
    nextDrag:Init()
    vendorButton:Init()
    ResetMockMerchant()
    ResetMockGuildBank()
    eventsRegistered, buckets, timers, messages = {}, {}, {}, {}
    calls = { sellAll = 0, sales = {}, cancelled = {}, repairAll = {}, purchase = {} }
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
    override(stubs.database, "GetNextSize", function() return "full" end)
    override(stubs.database, "GetInBagSearch", function() return true end)
    data.tabOrder = {}
    override(stubs.database, "GetNextTabOrder", function(_, key) return data.tabOrder[key] or {} end)
    override(stubs.database, "SetNextTabOrder", function(_, key, ids) data.tabOrder[key] = ids end)
    override(stubs.database, "GetGroupsEnabled", function() return false end)
    override(stubs.events, "SendMessage", function() end)
    override(stubs.events, "RegisterMessage", function(_, name, fn)
      messages[name] = messages[name] or {}
      table.insert(messages[name], fn)
    end)
    -- Automation, stood in for: which categories a sale waits to be confirmed for (sell) and which hold
    -- items to destroy (destroy), over the items given; gone: slots sold or destroyed.
    data.sell, data.destroy, data.gone = {}, {}, {}
    calls.destroyed = {}
    local function entriesOf(items, which)
      local list = {}
      for _, item in ipairs(items) do
        local category = item.itemInfo.category
        if which[category] and not data.gone[item.slotkey] and (which ~= data.sell or not item.noValue)
          and (which ~= data.destroy or item.noValue) then
          table.insert(list, { data = item, category = category, action = "sell" })
        end
      end
      return list
    end
    override(stubs.automation, "SaleOffer", function(_, _, items) return entriesOf(items, data.sell) end)
    override(stubs.automation, "DestroyLeft", function(_, _, items) return entriesOf(items, data.destroy) end)
    override(stubs.automation, "DestroyNext", function(_, _, items)
      local left = entriesOf(items, data.destroy)
      if left[1] == nil then return "nothing" end
      data.gone[left[1].data.slotkey] = true
      table.insert(calls.destroyed, left[1].data.slotkey)
      return "destroyed"
    end)
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
    -- The seller, stood in for: each sale is recorded, and a test ends it (finishSale).
    data.refused = {}
    override(stubs.seller, "Sell", function(_, list, opts)
      local job = { list = list, opts = opts or {}, sold = {}, unsold = 0, left = #list }
      table.insert(calls.sales, job)
      return job
    end)
    override(stubs.seller, "Left", function(_, job) return job.left end)
    override(stubs.seller, "Cancel", function(_, job) table.insert(calls.cancelled, job) end)
    override(stubs.seller, "Refuses", function(_, d) return data.refused[d.slotkey] == true end)
    override(stubs.automation, "MerchantBuys", function() return data.buys ~= false end)
    override(stubs.merchant, "RepairAll", function(_, guild) table.insert(calls.repairAll, guild) end)
    override(stubs.merchant, "Purchase", function(_, frame, i) table.insert(calls.purchase, i) end)
    -- Profession Shopping List (integrations/professionshoppinglist.lua), stood in for: not there unless a
    -- test says so; what its list needs (data.needs, by item ID); its purchases counted.
    data.listAvailable, data.needs, calls.bought = false, {}, 0
    override(stubs.shoppingList, "Available", function() return data.listAvailable end)
    override(stubs.shoppingList, "Needs", function() return data.listAvailable and data.needs or {} end)
    override(stubs.shoppingList, "Buy", function()
      if not data.listAvailable then return false end
      calls.bought = calls.bought + 1
      return true
    end)
    -- NextMerchant's purchases, stood in for as it works them out (spec/next/merchant_spec.lua): the first
    -- item of each needed ID that can be bought; a quantity's price per unit of a purchase.
    override(stubs.merchant, "ToBuy", function(_, list, needs)
      local out, seen = {}, {}
      for _, i in ipairs(list) do
        if needs[i.itemID] and not seen[i.itemID] then
          seen[i.itemID] = true
          if i.isPurchasable then table.insert(out, { item = i, quantity = needs[i.itemID] }) end
        end
      end
      return out
    end)
    override(stubs.merchant, "PriceOf", function(_, i, quantity) return i.price * quantity / i.stackCount, {} end)
    override(stubs.merchant, "TotalOf", function(_, purchases)
      local total = 0
      for _, p in ipairs(purchases) do total = total + p.item.price * p.quantity / p.item.stackCount end
      return total, {}
    end)
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
    UseNextTheme(nil)
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
    it("is a hidden, named panel on the left, its items cards with their names and prices", function()
      local v = nextVendor:Create(ctx())
      assert.are.equal("BetterBagsNextVendor", v:GetName())
      assert.are.equal("LEFT", v.side)
      assert.is_false(v:IsShown())
      assert.are.equal(style.VENDOR_CARD_WIDTH, v.content:CellWidth())
      assert.are.equal(style.ICON, v.content:CellHeight())
      -- A small vendor is never narrower than one of its cards (with one column, a card sets the
      -- narrowest it goes).
      assert.is_true(v:MinWidth() >= 2 * style.PAD + style.GUTTER + v.content:CellWidth())
      UseNextTheme({ Layout = { VendorColumns = 1 } })
      assert.are.equal(2 * style.PAD + style.GUTTER + style.GRID_WIDTH, v:MinWidth())
      UseNextTheme(nil)
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
      for _, b in ipairs(v.headerButtons) do table.insert(out, NextIconName(b)) end
      return out
    end

    it("lines up close, settings, the filter, Sell Junk, Repair All and the guild's repair on retail", function()
      local v = nextVendor:Create(ctx())
      assert.are.same({ "close", "settings", "filter", "selljunk", "repair", "guildrepair" }, icons(v))
    end)

    it("draws the same icons on Classic, which has no filter", function()
      override(addon, "isRetail", false)
      override(C_MerchantFrame, "GetItemInfo", nil)
      override(_G, "SetMerchantFilter", nil)
      local v = nextVendor:Create(ctx())
      assert.are.same({ "close", "settings", "selljunk", "repair", "guildrepair" }, icons(v))
      assert.are.same({ 0, 1, 0, 1 }, v.repairAllButton.icon._texCoords)
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
      assert.are.same({ "TOPLEFT", v.sellJunkButton, "TOPRIGHT", 8, 0 }, { v.repairAllButton:GetPoint(1) })
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

    -- A Next theme's header sizes (next-themes.md): the name fits the room they leave.
    it("fits the vendor's name to a theme's button size, gap and inset", function()
      _G._merchant.canRepair, _G._merchant.canGuildRepair = true, true
      local v = open()
      UseNextTheme({ Layout = { HeaderButton = 30, HeaderButtonGap = 2, TitleInset = 10 } })
      v:ApplyStyle(ctx())
      assert.are.equal(style.BODY_WIDTH - (style.PAD + 10) - (style.PAD + 6 * 30 + 5 * 2) - 12, v.title:GetWidth())
      UseNextTheme(nil)
      v:ApplyStyle(ctx())
    end)

    -- A theme that puts the header buttons down a side rail (Header.Buttons.Rail, docs/next-gw2-theme.md): down the
    -- vendor's right, its inner side, the name taking the whole header row.
    it("puts its buttons down a side rail on its right, its name the whole header row", function()
      _G._merchant.canRepair, _G._merchant.canGuildRepair = true, true
      local v = open()
      UseNextTheme({ Header = { Buttons = { Rail = { Width = 40, Top = 66, Gap = 8 } } } })
      v:ApplyStyle(ctx())
      local y = 66
      for _, button in ipairs(v.headerButtons) do
        if button:IsShown() then
          assert.are.same({ "TOPRIGHT", v.body, "TOPRIGHT", -9, -y }, { button:GetPoint(1) }, button.key)
          y = y + style.HEADER_BUTTON + 8
        end
      end
      assert.are.equal(style.BODY_WIDTH - 40 - (style.PAD + 4) - style.PAD - 12, v.title:GetWidth())
      UseNextTheme(nil)
      v:ApplyStyle(ctx())
    end)

    -- GW2_UI's merchant frame shows its own emblem (Immersive/Skins/merchant.lua), its bags another.
    it("shows GW2_UI's merchant emblem in the Guild Wars 2 theme, not its bag's", function()
      local v = open()
      style:Use(addon:GetModule("SonataNext"):Resolve("GW2"))
      v:ApplyStyle(ctx())
      local shown = {}
      for i = 1, v.ornaments.count do
        local piece = v.ornaments.pieces[i]
        shown[piece.spec.Texture] = piece.texture:IsShown()
      end
      assert.is_true(shown.VendorEmblem)
      assert.is_false(shown.BagEmblem)
      UseNextTheme(nil)
      v:ApplyStyle(ctx())
    end)

    it("hides the filter where a game rule turns it off", function()
      _G._gameRules[Enum.GameRule.MerchantFilterDisabled] = true
      local v = open()
      assert.is_false(v.filterButton:IsShown())
      assert.are.same({ "TOPLEFT", v.settingsButton, "TOPRIGHT", 8, 0 }, { v.sellJunkButton:GetPoint(1) })
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

    -- Asked: tabs reorderable, "make sure it saves" (docs/next-batch-2.md §5).
    it("lists its tabs in the order saved, and saves the order they are moved to", function()
      data.tabOrder.vendor = { 2, 1 }
      local v = open()
      assert.are.same({ 2, 1 }, tabIDs(v))
      assert.is_true(v.tabs:Tab(1).movable)
      v.tabs.onReorder(ctx(), { 1, 2 })
      assert.are.same({ 1, 2 }, data.tabOrder.vendor)
      assert.are.same({ 1, 2 }, tabIDs(v))
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
      -- A glyph does not show desaturation: it fades (Header.Buttons.DisabledAlpha).
      assert.are.equal(style.Theme.Header.Buttons.DisabledAlpha, v.sellJunkButton.icon:GetAlpha())
      data.junk = 1
      eventsRegistered["PLAYER_MONEY"](ctx())
      assert.is_true(v.sellJunkButton:IsEnabled())
      assert.are.equal(1, v.sellJunkButton.icon:GetAlpha())
    end)
  end)

  describe("selling junk", function()
    it("uses Blizzard's own Sell All Junk where the client has it", function()
      local v = open()
      click(v.sellJunkButton)
      assert.are.equal(1, calls.sellAll)
      assert.is_nil(asked)
    end)

    -- One item at a time, as every sale (the seller, data/seller.lua).
    it("asks first on Classic, then sells the junk through the seller while the vendor is open", function()
      data.hasSellAll = false
      local v = open()
      click(v.sellJunkButton)
      assert.are.equal("Sell Junk", asked.title)
      assert.are.equal("Sell 2 junk items? Only the last 12 items sold can be bought back.", asked.text)
      assert.are.same({}, calls.sales, "nothing before the answer")
      asked.yes()
      assert.are.equal(1, #calls.sales)
      assert.are.equal(data.junkSlots, calls.sales[1].list)
      assert.is_true(calls.sales[1].opts.stillOpen())
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      assert.is_false(calls.sales[1].opts.stillOpen(), "not once the vendor has closed")
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
      assert.are.equal(style.Theme.Header.Buttons.DisabledAlpha, v.repairAllButton.icon:GetAlpha())
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

  -- Selling what is on the cursor is NextMerchant's (SellCursorItem, merchant_spec): Blizzard's refund
  -- question first, nothing without an item.
  describe("selling by dropping", function()
    local sales

    before_each(function()
      sales = 0
      override(stubs.merchant, "SellCursorItem", function() sales = sales + 1 return "sold" end)
    end)

    it("sells an item dropped on it or let go over it", function()
      local v = open()
      v.frame:GetScript("OnReceiveDrag")(v.frame)
      v.frame:GetScript("OnMouseUp")(v.frame, "LeftButton")
      assert.are.equal(2, sales)
      v.frame:GetScript("OnMouseUp")(v.frame, "RightButton")
      assert.are.equal(2, sales, "not on a right click")
    end)

    it("sells an item dropped on a section header too", function()
      local v = open()
      local h = v.content.order[1].header
      h:GetScript("OnReceiveDrag")(h)
      assert.are.equal(1, sales)
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
      -- Every slot holds an item here, as its info says (C_Item.DoesItemExist reads the item ID).
      override(C_Container, "GetContainerItemID", function() return 1 end)
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

    it("leaves out what this merchant refused: back in the bags until a merchant buys it", function()
      local v = open()
      data.refused["0_2"] = true
      assert.are.same({ "0_1", "0_3" }, slotsOf(v:SaleOf({ slotData(0, 1), slotData(0, 2), slotData(0, 3) })))
    end)

    -- A dragged section waits in the vendor's dock while it sells (NextDrag docks it with this offer):
    -- the seller sells one item at a time.
    describe("its offer", function()
      local v, section, entry, sectionItems

      before_each(function()
        sectionItems = {}
        override(nextDrag, "SectionItems", function() return sectionItems end)
        v = open()
        section = { name = "Junk", frame = CreateFrame("Frame"), entries = {}, height = 40 }
        section.frame:SetSize(300, 40)
        entry = { docked = true }
        override(nextDock, "Answer", function(_, e, answer) table.insert(calls.answers, { e, answer }) end)
        override(nextDock, "Refresh", function(_, e) calls.refreshed = (calls.refreshed or 0) + 1 end)
        calls.answers = {}
      end)

      local function sellOf(n)
        for i = 1, n do table.insert(sectionItems, slotData(0, i)) end
        return v:SaleOffer(section)
      end

      it("sells at once, as it docks, when buyback can keep it all, saying how far it is", function()
        local o = sellOf(12)
        assert.is_nil(o.confirm and o.confirm(ctx()), "nothing to confirm")
        o.docked(entry)
        assert.are.equal(1, #calls.sales)
        assert.are.same({ "0_1", "0_2", "0_3", "0_4", "0_5", "0_6", "0_7", "0_8", "0_9", "0_10", "0_11", "0_12" },
          slotsOfSale(calls.sales[1]))
        calls.sales[1].left = 9
        calls.sales[1].opts.onProgress(calls.sales[1])
        assert.are.equal(1, calls.refreshed)
        assert.are.same({ "Selling 3 of 12...", "One item at a time, as the merchant takes them.", "Right-click to stop" },
          { o.text() })
        assert.is_nil(o.color())
      end)

      it("flies into the vendor once all sold, and goes back with what the merchant would not take", function()
        local o = sellOf(2)
        o.docked(entry)
        finishSale(calls.sales[1], "done", 0)
        assert.are.same({ { entry, "moved" } }, calls.answers)
        local again = sellOf(0)
        again.docked(entry)
        finishSale(calls.sales[2], "done", 1)
        assert.are.same({ entry, "back" }, calls.answers[2])
        local closed = sellOf(0)
        closed.docked(entry)
        finishSale(calls.sales[3], "closed", 4)
        assert.are.same({ entry, "back" }, calls.answers[3])
      end)

      -- Past 12 the sale is confirmed in the vendor itself: the dialog it asked with blended in.
      it("past 12, the last 12 sold being all buyback keeps, sells only once double-clicked", function()
        local o = sellOf(13)
        o.docked(entry)
        assert.are.same({}, calls.sales)
        assert.are.same({ "Sell 13 items?", "Only the last 12 items sold can be bought back.",
          "Double-click to sell · Right-click to cancel" }, { o.text() })
        assert.is_nil(asked)
        assert.are.equal("stay", o.confirm(ctx()))
        assert.are.equal(13, #calls.sales[1].list)
        assert.is_nil(o.confirm(ctx()), "nothing more while it sells")
        assert.are.equal(1, #calls.sales)
      end)

      it("sends it back when nothing is left to sell at the double click, or the vendor is closing", function()
        local o = sellOf(13)
        v.closing = true
        assert.are.equal("back", o.confirm(ctx()))
        v.closing = false
        sectionItems = {}
        assert.are.equal("back", o.confirm(ctx()))
        assert.are.same({}, calls.sales)
      end)

      it("stops its sale when it leaves the dock, whichever way", function()
        local o = sellOf(3)
        o.docked(entry)
        o.cancel()
        assert.are.same({ calls.sales[1] }, calls.cancelled)
        o.cancel()
        assert.are.equal(1, #calls.cancelled, "once")
      end)

      it("sells only while the vendor is open", function()
        local o = sellOf(3)
        o.docked(entry)
        assert.is_true(calls.sales[1].opts.stillOpen())
        eventsRegistered["MERCHANT_CLOSED"](ctx())
        assert.is_false(calls.sales[1].opts.stillOpen())
      end)
    end)
  end)

  -- What waits for the player at a merchant (automation.md §4): each backpack category whose sale Auto
  -- Sell confirms (Confirm Auto Sell) or which holds items to destroy, its section docked in the vendor
  -- (NextDock), the one interface a dragged section's sale uses too. Asked: "we probably have a list of
  -- categories that move over to the vendor window ... selling (or cancelling) animates the next section
  -- to the position above it"; destroying "should function just like the above, but with a red outline".
  describe("offering categories at a merchant", function()
    local backpack, items

    local function send(name, ...)
      for _, fn in ipairs(messages[name] or {}) do fn(ctx(), ...) end
    end

    local function item(slot, category, noValue)
      local slotkey = "0_" .. slot
      items[slotkey] = { slotkey = slotkey, bagid = 0, slotid = slot, noValue = noValue,
        itemInfo = { category = category } }
      return items[slotkey]
    end

    -- bind gives the backpack its sections, in this order.
    local function bind(list)
      local categories, ordered = {}, {}
      for _, entry in ipairs(list) do
        table.insert(categories, { name = entry[1] })
        for _, it in ipairs(entry[2]) do table.insert(ordered, it) end
      end
      backpack.content:Bind(ctx(), { sortedItems = {}, tabs = { [1] = { categories = categories, items = ordered } } },
        1, {})
      render:NewRenderChain(backpack.content, { ctx = ctx() }, { Width = style.GRID_WIDTH })
    end

    local function docked(v)
      local out = {}
      for _, e in ipairs(nextDock:Entries(v)) do table.insert(out, e.section.name) end
      return out
    end

    local function entry(v, name)
      return nextDock:EntryOf(v, name)
    end

    local function doubleClick(e)
      e.catcher:GetScript("OnDoubleClick")(e.catcher, "LeftButton")
    end

    local function textOf(e)
      return { e.box.title:GetText(), e.box.warning:GetText(), e.box.hint:GetText() }
    end

    local function glowOf(e)
      local r, g, b = e.box.glow[1]:GetVertexColor()
      return { r, g, b }
    end

    before_each(function()
      items = {}
      local frame = CreateFrame("Frame", nil, UIParent)
      frame:Show()
      backpack = { frame = frame, kind = 0, closing = false }
      backpack.content = nextContent:Create(frame)
      backpack.scroll = { frame = CreateFrame("Frame", nil, frame) }
      function backpack:IsShown() return self.frame:IsShown() end
      local buttonsByKey = {}
      backpack.content:SetButtonSource({ GetButton = function(_, _, slotkey)
        if buttonsByKey[slotkey] == nil then
          local b = { frame = CreateFrame("Frame") }
          b.frame:SetSize(37, 37)
          function b:SetItemFromData() end
          function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
          function b:GetItemData() return items[slotkey] end
          buttonsByKey[slotkey] = b
        end
        return buttonsByKey[slotkey]
      end })
      override(addon, "Bags", { Backpack = backpack })
      bind({ { "Junk", { item(1, "Junk"), item(2, "Junk") } }, { "Mats", { item(3, "Mats") } },
        { "Trash", { item(4, "Trash", true) } }, { "Ore", { item(5, "Ore") } } })
      data.sell = { Junk = true, Ore = true }
      data.destroy = { Trash = true }
    end)

    it("docks, once both show, each category that waits, in the backpack's order", function()
      local v = open()
      send("next/PanelShown", v)
      assert.are.same({ "Junk", "Trash", "Ore" }, docked(v))
      for _, name in ipairs({ "Junk", "Trash", "Ore" }) do
        assert.is_true(backpack.content:IsAway(backpack.content.byName[name]), name)
      end
      assert.is_false(backpack.content:IsAway(backpack.content.byName.Mats))
    end)

    it("says what a sale sells and how to answer, in the dock's glow", function()
      local v = open()
      send("next/PanelShown", v)
      assert.are.same({ "Sell 2 items?", "You can buy them back.", "Double-click to sell · Right-click to cancel" },
        textOf(entry(v, "Junk")))
      local r, g, b = style:RGBA(style.Theme.Dock.Glow.Color)
      assert.are.same({ r, g, b }, glowOf(entry(v, "Junk")))
      assert.are.equal("Sell 1 item?", entry(v, "Ore").box.title:GetText())
    end)

    it("warns when buyback cannot keep all of a sale", function()
      local list = {}
      for slot = 1, 13 do table.insert(list, item(slot, "Junk")) end
      bind({ { "Junk", list } })
      local v = open()
      send("next/PanelShown", v)
      assert.are.same({ "Sell 13 items?", "Only the last 12 items sold can be bought back.",
        "Double-click to sell · Right-click to cancel" }, textOf(entry(v, "Junk")))
      doubleClick(entry(v, "Junk"))
      assert.are.equal(13, #calls.sales[1].list, "the double click is the confirmation")
    end)

    -- Asked: "with a red outline like we have now, when it's destroying".
    it("glows in the theme's destroy color for what it destroys, a click destroying the next", function()
      local v = open()
      send("next/PanelShown", v)
      local trash = entry(v, "Trash")
      assert.are.same({ "Destroy 1 item", "No merchant buys these.", "Click to destroy next · Right-click to cancel" },
        textOf(trash))
      local r, g, b = style:RGBA(style.Theme.Dock.DestroyColor)
      assert.are.same({ r, g, b }, glowOf(trash))
    end)

    it("sells on a double click through the seller, waiting while it sells, the next coming up once sold", function()
      local v = open()
      send("next/PanelShown", v)
      doubleClick(entry(v, "Junk"))
      assert.are.same({ "0_1", "0_2" }, slotsOfSale(calls.sales[1]))
      assert.are.same({ "Junk", "Trash", "Ore" }, docked(v), "it waits while it sells")
      assert.are.equal("Selling 0 of 2...", entry(v, "Junk").box.title:GetText())
      data.gone["0_1"], data.gone["0_2"] = true, true
      finishSale(calls.sales[1], "done", 0)
      assert.are.same({ "Trash", "Ore" }, docked(v))
    end)

    -- Asked: "refused items go back to the backpack until we find a merchant that buys it".
    it("goes back to the backpack with what the merchant would not take", function()
      local v = open()
      send("next/PanelShown", v)
      doubleClick(entry(v, "Junk"))
      data.gone["0_1"] = true
      finishSale(calls.sales[1], "done", 1)
      finishTweens()
      assert.are.same({ "Trash", "Ore" }, docked(v))
      assert.is_false(backpack.content:IsAway(backpack.content.byName.Junk))
      assert.is_false(backpack.content:IsLeaving(backpack.content.byName.Junk))
    end)

    it("offers no sale where the merchant buys nothing, only what to destroy", function()
      data.buys = false
      local v = open()
      send("next/PanelShown", v)
      assert.are.same({ "Trash" }, docked(v))
    end)

    it("turns into a destroy, glowing red, when items no merchant buys are left after its sale", function()
      bind({ { "Trash", { item(1, "Trash"), item(2, "Trash", true), item(3, "Trash", true) } } })
      data.sell = { Trash = true }
      local v = open()
      send("next/PanelShown", v)
      local trash = entry(v, "Trash")
      assert.are.equal("Sell 1 item?", trash.box.title:GetText())
      doubleClick(trash)
      assert.are.equal(1, #calls.sales)
      data.gone["0_1"] = true
      finishSale(calls.sales[1], "done", 0)
      assert.are.same({ "Trash" }, docked(v), "it waits on")
      assert.are.equal("Destroy 2 items", trash.box.title:GetText())
      local r, g, b = style:RGBA(style.Theme.Dock.DestroyColor)
      assert.are.same({ r, g, b }, glowOf(trash))
    end)

    -- OnDoubleClick blocks OnClick when it fires (warcraft.wiki.gg UIHANDLER_OnDoubleClick): every click
    -- of a fast pair destroys one, so a double click destroys two.
    it("destroys one item per click, double clicks included, and goes when none is left", function()
      bind({ { "Trash", { item(1, "Trash", true), item(2, "Trash", true), item(3, "Trash", true) } } })
      local v = open()
      send("next/PanelShown", v)
      local trash = entry(v, "Trash")
      click(trash.catcher)
      assert.are.same({ "0_1" }, calls.destroyed)
      assert.are.equal("Destroy 2 items", trash.box.title:GetText())
      doubleClick(trash)
      assert.are.same({ "0_1", "0_2" }, calls.destroyed)
      click(trash.catcher)
      assert.are.same({ "0_1", "0_2", "0_3" }, calls.destroyed)
      assert.are.same({}, docked(v))
    end)

    it("sells nothing on a single click, and waits on", function()
      local v = open()
      send("next/PanelShown", v)
      click(entry(v, "Junk").catcher)
      assert.are.same({}, calls.sales)
      assert.are.same({}, calls.destroyed)
      assert.is_not_nil(entry(v, "Junk"))
    end)

    it("goes back when nothing is left to sell at the double click", function()
      local v = open()
      send("next/PanelShown", v)
      data.gone["0_1"], data.gone["0_2"] = true, true
      doubleClick(entry(v, "Junk"))
      finishTweens()
      assert.are.same({}, calls.sales)
      assert.is_nil(entry(v, "Junk"))
      assert.is_false(backpack.content:IsLeaving(backpack.content.byName.Junk), "back, not moved")
    end)

    it("shows no tooltip while it waits to be sold", function()
      bind({ { "Trash", { item(1, "Trash"), item(2, "Trash", true) } } })
      data.sell = { Trash = true }
      local v = open()
      send("next/PanelShown", v)
      local trash = entry(v, "Trash")
      GameTooltip:Hide()
      trash.catcher:GetScript("OnEnter")(trash.catcher)
      assert.is_false(GameTooltip:IsOwned(trash.catcher))
    end)

    it("shows the next item to destroy in its tooltip, and the one after once it is gone", function()
      bind({ { "Trash", { item(4, "Trash", true), item(5, "Trash", true) } } })
      local v = open()
      send("next/PanelShown", v)
      local trash = entry(v, "Trash")
      trash.catcher:GetScript("OnEnter")(trash.catcher)
      assert.are.same({ bag = 0, slot = 4 }, GameTooltip._bagItem)
      local text = {}
      for _, line in ipairs(GameTooltip.lines) do table.insert(text, line.text) end
      assert.are.same({ "Click to destroy it." }, text)
      click(trash.catcher)
      assert.are.same({ bag = 0, slot = 5 }, GameTooltip._bagItem)
    end)

    it("offers each category once a visit: one sent back stays back until the next visit", function()
      local v = open()
      send("next/PanelShown", v)
      local junk = entry(v, "Junk")
      click(junk.catcher, "RightButton")
      finishTweens()
      send("bags/Draw/Backpack/Done")
      assert.are.same({ "Trash", "Ore" }, docked(v))
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      assert.are.same({}, docked(v), "every one goes back when the merchant closes")
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      send("next/PanelShown", backpack)
      assert.are.same({ "Junk", "Trash", "Ore" }, docked(v))
    end)

    it("offers what starts waiting later in the visit, when the backpack draws or automation changes", function()
      local v = open()
      send("next/PanelShown", v)
      data.sell.Mats = true
      send("automation/Changed")
      assert.are.same({ "Junk", "Trash", "Ore", "Mats" }, docked(v))
    end)

    it("offers nothing away from a merchant, with the backpack hidden or closing, or for a section docked already", function()
      local v = open()
      backpack.frame:Hide()
      send("next/PanelShown", v)
      assert.are.same({}, docked(v))
      backpack.frame:Show()
      backpack.closing = true
      send("bags/Draw/Backpack/Done")
      assert.are.same({}, docked(v))
      backpack.closing = false
      nextDock:Add(v, { section = backpack.content.byName.Junk, source = backpack,
        offer = { text = function() return "Sell 2 items?", "", "" end } })
      send("bags/Draw/Backpack/Done")
      assert.are.same({ "Junk", "Trash", "Ore" }, docked(v), "the dragged one is not docked twice")
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      send("bags/Draw/Backpack/Done")
      assert.are.same({}, docked(v))
    end)

    it("offers no section that is leaving the backpack (sold by a drag) or docked in another panel", function()
      local v = open()
      backpack.content:MarkLeaving("Junk")
      local other = { frame = CreateFrame("Frame"), scroll = { frame = CreateFrame("Frame") } }
      other.content = nextContent:Create(other.frame)
      nextDock:Add(other, { section = backpack.content.byName.Ore, source = backpack,
        offer = { text = function() return "", "", "" end } })
      send("next/PanelShown", v)
      assert.are.same({ "Trash" }, docked(v))
    end)

    it("sends everything back when BetterBags Next is switched off", function()
      local v = open()
      send("next/PanelShown", v)
      v:Deactivate(ctx())
      assert.are.same({}, docked(v))
      assert.is_false(backpack.content:IsAway(backpack.content.byName.Junk))
    end)

    it("leaves the vendor's own content where it was: nothing under it, no room kept", function()
      local v = open()
      send("next/PanelShown", v)
      assert.are.equal(style.FOOTER, v:ContentBottom())
      assert.is_nil(v.destroyCard)
    end)
  end)

  -- Switching between the classic design and BetterBags Next without a reload (next.md §11): the
  -- vendor is switched only away from a vendor, and catches up when the next one opens.
  -- Profession Shopping List (profession-shopping-list.md). Asked: "if a vendor has items the user has on
  -- their list, just like we have the sell or destroy, let's add a 'double click to buy' in the same exact
  -- style, but, with a glowing green outline instead", "with the items in it to buy, and total price to
  -- buy", and nothing of it without Profession Shopping List and its new function.
  describe("the shopping list (Profession Shopping List)", function()
    local backpack

    local function send(name, ...)
      for _, fn in ipairs(messages[name] or {}) do fn(ctx(), ...) end
    end

    local function listEntry(v)
      return nextDock:EntryOf(v, "Shopping List")
    end

    local function namesOf(section)
      local out = {}
      for _, e in ipairs(section.entries) do table.insert(out, e.item.item.index) end
      return out
    end

    local function textOf(e)
      return { e.box.title:GetText(), e.box.warning:GetText(), e.box.hint:GetText() }
    end

    local function doubleClick(e)
      e.catcher:GetScript("OnDoubleClick")(e.catcher, "LeftButton")
    end

    local function rightClick(e)
      e.catcher:GetScript("OnClick")(e.catcher, "RightButton")
    end

    before_each(function()
      local frame = CreateFrame("Frame", nil, UIParent)
      frame:Show()
      backpack = { frame = frame, scroll = { frame = CreateFrame("Frame", nil, frame) }, closing = false }
      function backpack:IsShown() return self.frame:IsShown() end
      override(addon, "Bags", { Backpack = backpack })
      data.items = { forSale(1, "Food", { price = 200, stackCount = 5 }), forSale(2, "Armor"), forSale(3, "Food"),
        forSale(4, "Mats") }
    end)

    it("shows nothing of it without Profession Shopping List", function()
      data.needs = { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      assert.are.same({ "Armor", "Food", "Mats" }, sectionNames(v))
      assert.are.same({}, nextDock:Entries(v))
    end)

    it("puts what the list buys here above the vendor's categories, out of theirs, each with how many", function()
      data.listAvailable, data.needs = true, { [1] = 10, [4] = 3 }
      local v = open()
      assert.are.same({ "Shopping List", "Armor", "Food" }, sectionNames(v))
      assert.are.same({ 1, 4 }, namesOf(v.content.byName["Shopping List"]))
      assert.are.same({ 3 }, namesOf(v.content.byName.Food))
      assert.are.equal("10", v.buttons["vendor:1"].count:GetText())
      assert.are.equal("3", v.buttons["vendor:4"].count:GetText())
    end)

    -- Asked: "make the item frame appear directly in the buy screen at the start when we open it? right
    -- now it's on the list for a split second then slides to the buy frame".
    it("is in its card as the vendor opens, never shown in the vendor's column first", function()
      data.listAvailable, data.needs = true, { [1] = 10, [4] = 3 }
      local placed = {}
      local place = motion.Place
      override(motion, "Place", function(self, frame, relativeTo, ...)
        table.insert(placed, { frame = frame, relativeTo = relativeTo })
        return place(self, frame, relativeTo, ...)
      end)
      local v = open()
      local e = listEntry(v)
      local frame = v.content.byName["Shopping List"].frame
      for _, p in ipairs(placed) do
        assert.is_false(p.frame == frame and p.relativeTo == v.content.frame, "never placed in the column")
      end
      assert.is_not_nil(e)
      assert.is_nil(e.flight, "seated at once, not flown in from a place in the column")
      assert.is_true(e.seated)
      assert.are.equal(e.box.frame, v.content.byName["Shopping List"].frame:GetParent())
      assert.is_true(v.content:IsAway(v.content.byName["Shopping List"]))
    end)

    -- Reported: the card opened as a narrow empty strip, its section laid out at no width.
    it("lays its items out in its card as the vendor's column lays them out", function()
      data.listAvailable, data.needs = true, { [1] = 10, [3] = 3 }
      local v = open()
      local list, armor = v.content.byName["Shopping List"], v.content.byName.Armor
      assert.is_true(armor.frame:GetWidth() > 0)
      -- Laid out on its card's scaled grid (whole pixels there, docs/next-pixel-perfect.md).
      assert.is_true(math.abs(armor.frame:GetWidth() - list.frame:GetWidth()) < 0.5)
      local _, _, _, x1, y1 = v.buttons["vendor:1"].frame:GetPoint(1)
      local _, _, _, x3, y3 = v.buttons["vendor:3"].frame:GetPoint(1)
      assert.are.equal(y1, y3, "side by side, as the vendor's columns put them")
      assert.is_true(x3 > x1)
    end)

    -- Reported: on opening, the card was in place but its items slid in. The vendor keeps its sections
    -- while hidden; closing put the Shopping List back in its column, anchored there, and the next visit
    -- reused it: docked with a place on screen, it flew from there into its card. In the client an
    -- anchored frame has a place on screen; the mock has one only when given (_SetRect).
    it("opens in its card again at the next visit, though its section was left in the vendor's column", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      finishTweens()
      v.frame:GetScript("OnHide")(v.frame)
      local section = v.content.byName["Shopping List"]
      assert.is_false(v.content:IsAway(section), "back in its column while the vendor is away")
      section.frame:_SetRect(40, 500, 394, 120)
      MerchantFrame:Show()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      local e = listEntry(v)
      assert.is_not_nil(e)
      assert.is_nil(e.flight, "seated at once, not flown in from its old place")
      assert.is_true(e.seated)
      finishTweens()
    end)

    it("says in the theme's buy color what it buys and the total", function()
      data.listAvailable, data.needs = true, { [1] = 10, [4] = 3 }
      local v = open()
      local e = listEntry(v)
      assert.are.same({ "Buy 2 items?", "Total: " .. vendorButton:PriceText(700, {}),
        "Double-click to buy · Right-click to cancel" }, textOf(e))
      local r, g, b = e.box.glow[1]:GetVertexColor()
      local er, eg, eb = style:RGBA(style.Theme.Dock.BuyColor)
      assert.are.same({ er, eg, eb }, { r, g, b })
      data.needs = { [4] = 1 }
      eventsRegistered["MERCHANT_UPDATE"](ctx())
      assert.are.equal("Buy 1 item?", e.box.title:GetText())
    end)

    it("buys on a double click through Profession Shopping List, flying into the backpack", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      local e = listEntry(v)
      assert.are.equal(backpack.scroll.frame, e.offer.destination())
      doubleClick(e)
      assert.are.equal(1, calls.bought)
      assert.are.same({}, nextDock:Entries(v))
      finishTweens()
      assert.is_true(v.content:IsLeaving(v.content.byName["Shopping List"]))
      data.needs = {}
      eventsRegistered["BAG_UPDATE_DELAYED"](ctx())
      assert.are.same({ "Armor", "Food", "Mats" }, sectionNames(v))
      assert.are.same({ 1, 3 }, namesOf(v.content.byName.Food), "bought: its items go back to their categories")
    end)

    it("flies nowhere when the backpack is not shown", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      backpack.frame:Hide()
      assert.is_nil(listEntry(v).offer.destination())
    end)

    it("buys nothing, and goes back, once the vendor is closing or the merchant has closed", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      local e = listEntry(v)
      v.closing = true
      assert.are.equal("back", e.offer.confirm(ctx()))
      v.closing = false
      v.atMerchant = false
      assert.are.equal("back", e.offer.confirm(ctx()))
      assert.are.equal(0, calls.bought)
    end)

    -- As at the start: never shown in the vendor's column on the way out.
    it("slides out with the vendor in its card when the merchant closes, going back once the vendor has gone", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      local e = listEntry(v)
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      assert.are.equal(e, listEntry(v))
      assert.is_true(v.content:IsAway(v.content.byName["Shopping List"]))
      finishTweens()
      assert.is_false(v.frame:IsShown())
      v.frame:GetScript("OnHide")(v.frame)
      assert.is_nil(listEntry(v))
    end)

    it("is not offered as the vendor closes, nor once it has", function()
      data.listAvailable = true
      local v = open()
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      assert.is_true(v.closing)
      data.needs = { [1] = 10 }
      eventsRegistered["BAG_UPDATE_DELAYED"](ctx())
      assert.is_nil(listEntry(v), "not while it slides out")
      finishTweens()
      send("next/PanelShown", backpack)
      assert.is_nil(listEntry(v), "not once it has gone")
    end)

    it("goes back to the top of Buy on a right click, and is not offered again this visit", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      rightClick(listEntry(v))
      finishTweens()
      assert.is_false(v.content:IsAway(v.content.byName["Shopping List"]))
      assert.are.equal("Shopping List", sectionNames(v)[1])
      send("next/PanelShown", v)
      eventsRegistered["MERCHANT_UPDATE"](ctx())
      assert.is_nil(listEntry(v))
      eventsRegistered["MERCHANT_CLOSED"](ctx())
      finishTweens()
      eventsRegistered["MERCHANT_SHOW"](ctx())
      finishTweens()
      send("next/PanelShown", v)
      assert.is_not_nil(listEntry(v), "offered again at the next visit")
    end)

    it("waits in the dock on the other tabs, out of their columns", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      local e = listEntry(v)
      data.buyback = {}
      click(v.tabs.tabs[2].button)
      finishTweens()
      assert.are.equal(e, listEntry(v))
      assert.is_true(v.content:IsAway(v.content.byName["Shopping List"]))
      assert.is_true(v.emptyText:IsShown(), "Buyback says nothing was sold")
      click(v.tabs.tabs[1].button)
      finishTweens()
      assert.are.equal(e, listEntry(v))
    end)

    it("goes when the list needs nothing more from this vendor", function()
      data.listAvailable, data.needs = true, { [1] = 10 }
      local v = open()
      send("next/PanelShown", v)
      data.needs = { [99] = 4 }
      eventsRegistered["MERCHANT_UPDATE"](ctx())
      assert.is_nil(listEntry(v))
      assert.are.same({ "Armor", "Food", "Mats" }, sectionNames(v))
    end)

    it("is offered straight into its card when the list changes during a visit", function()
      data.listAvailable = true
      local v = open()
      send("next/PanelShown", v)
      assert.is_nil(listEntry(v))
      data.needs = { [4] = 2 }
      send("shoppingList/Changed")
      assert.is_not_nil(listEntry(v))
      assert.is_nil(listEntry(v).flight)
    end)

    it("dims the Shopping List's buttons as a search dims their items", function()
      data.listAvailable, data.needs = true, { [1] = 10, [4] = 3 }
      local v = open()
      data.search = { ["vendor:4"] = true }
      v.searchBox.textBox:SetText("mats")
      v.searchBox.textBox:GetScript("OnTextChanged")(v.searchBox.textBox, true)
      assert.are.equal(0.25, v.buttons["vendor:1"].frame:GetAlpha())
      assert.are.equal(1, v.buttons["vendor:4"].frame:GetAlpha())
    end)

    it("leaves out what cannot be bought, as Profession Shopping List would", function()
      data.listAvailable, data.needs = true, { [2] = 1 }
      data.items[2].isPurchasable = false
      local v = open()
      send("next/PanelShown", v)
      assert.is_nil(listEntry(v))
      assert.are.same({ "Armor", "Food", "Mats" }, sectionNames(v))
    end)
  end)

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

  -- BetterBags Next, pixel perfect (docs/next-pixel-perfect.md): every view of the vendor, at rest, on
  -- whole screen pixels, full and small, on the reporter's window at 65% and on a common screen.
  describe("on the screen's pixels", function()
    local layout = dofile("spec/helpers/layout.lua")
    local undo

    after_each(function()
      if undo then undo() undo = nil end
    end)

    -- What moves by nature lands on the grid only by chance (spec/next/pixel_perfect_spec.lua).
    local function offGrid(v)
      for _ = 1, 3 do
        finishTweens()
        render:Flush()
        motion:Step(10)
      end
      local skip = { [v.spark] = true, [v.braid.layer] = true }
      for _, key in ipairs({ "sparkles", "edgeSparkles", "cloudSparkles", "knotSparkles" }) do
        if v[key] ~= nil then skip[v[key].frame] = true end
      end
      for _, puff in ipairs(v.cloud.puffs) do skip[puff.texture] = true end
      return layout.PixelCheck(v.frame, { owners = { vendor = v }, skip = skip })
    end

    for _, size in ipairs({ "full", "small" }) do
      for _, screen in ipairs({ { 3396, 1362, 0.65 }, { 1920, 1080, 1 } }) do
        local name = string.format("%s, on %dx%d at %d%%", size, screen[1], screen[2], screen[3] * 100)
        it("draws its buy, buyback and repair views on whole pixels, " .. name, function()
          override(stubs.database, "GetNextSize", function() return size end)
          -- A small vendor's place, size and chain (docs/next-small-mode.md): the defaults.
          override(stubs.database, "GetNextBagScale", function() return 100 end)
          override(stubs.database, "GetNextSmallChain", function() return "apart" end)
          override(stubs.database, "GetNextSmallPlace", function() return nil end)
          override(stubs.database, "GetNextSmallSize", function() return nil end)
          undo = layout.UseScreen(screen[1], screen[2], screen[3])
          _G._merchant.canRepair = true
          local v = open()
          assert.is_true(#v.content.order > 0)
          assert.are.same({}, offGrid(v), "buy")
          click(v.tabs.tabs[2].button)
          assert.are.same({}, offGrid(v), "buyback")
          click(v.tabs.tabs[3].button)
          assert.are.same({}, offGrid(v), "repair")
          data.buyback = {}
          click(v.tabs.tabs[2].button)
          eventsRegistered["MERCHANT_UPDATE"](ctx())
          assert.is_true(v.emptyText:IsShown())
          assert.are.same({}, offGrid(v), "nothing sold")
        end)
      end
    end
  end)
end)
