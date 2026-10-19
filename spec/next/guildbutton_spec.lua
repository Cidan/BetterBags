-- guildbutton_spec.lua -- NextGuildButton (next/guildbutton.lua): a guild bank slot in BetterBags
-- Next's guild bank (guild-bank.md §5). Blizzard's own guild bank item button, made the way Blizzard
-- makes it (the ItemButton intrinsic on retail and WoW: Forever, ItemButtonTemplate on Classic),
-- drawn from the data engine's ItemData as bag buttons are, its clicks Blizzard's guild bank item
-- button's (GuildBankItemButtonMixin) on the item's own tab.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
local context = addon:GetModule("Context")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
local stubs = {
  events = trackStub("Events"),
  L = trackStub("Localization"),
  database = trackStub("Database"),
  color = trackStub("Color"),
  guildBank = trackStub("GuildBank"),
  itemFrame = trackStub("ItemFrame"),
  sonata = trackStub("Sonata"),
  elements = trackStub("SonataElements"),
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

for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextGuildButton", "next/guildbutton.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local guildButton = addon:GetModule("NextGuildButton")

local GUILD = 2

describe("NextGuildButton", function()
  local calls, savedRetail, ctx

  -- item is the ItemData the data engine makes of a guild bank slot (items:AttachGuildBankItemInfo).
  local function item(opts)
    opts = opts or {}
    local d = {
      kind = GUILD, bagid = 1002, slotid = 7, slotkey = "1002_7", guildTab = 2, isItemEmpty = false,
      containerInfo = { isFiltered = opts.isFiltered or false },
      itemInfo = {
        itemID = 2770, itemLink = "|Hitem:2770|h[Copper Ore]|h", itemIcon = 135232, itemQuality = opts.quality or 1,
        currentItemCount = opts.count or 20, isLocked = opts.locked or false, classID = opts.classID or 7,
        currentItemLevel = opts.ilvl or 1,
      },
      isSearchResult = opts.isSearchResult,
      isUpgrade = opts.isUpgrade,
      stackedCount = opts.stackedCount,
    }
    return d
  end

  -- free is a Free Space entry of the data engine (items:Phase10_PartitionIntoTabs): one per tab with
  -- its count in the combined view, one per empty slot when a tab is shown by itself.
  local function free(opts)
    opts = opts or {}
    return { slotkey = opts.slotkey or "1002_9", bagid = 1002, slotid = opts.slotid or 9, count = opts.count or 1,
      isIndividual = opts.individual, key = "Mats", isFreeSlot = opts.individual,
      itemInfo = { emptySlotName = "Mats" } }
  end

  local function script(b, name, ...)
    return b.button:GetScript(name)(b.button, ...)
  end

  before_each(function()
    calls = { messages = {}, quality = {}, glow = {}, registered = {}, pickup = {}, withdraw = {}, split = {},
      place = {}, petTooltip = nil }
    ctx = context:New("test")
    savedRetail = addon.isRetail
    addon.isRetail = true
    ResetMockGuildBank()
    guildButton:Init()
    -- Enum.ItemClass as Blizzard declares it (ItemConstantsDocumentation.lua); other specs replace it.
    override(Enum, "ItemClass", { Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Tradegoods = 7 })
    override(const, "BAG_KIND", { BACKPACK = 0, BANK = 1, GUILD = GUILD })
    override(const, "GUILD_BANK_BAGS", { [1001] = 1, [1002] = 2 })
    override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3 })
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 }, [2] = { 0.12, 1, 0, 1 }, [3] = { 0, 0.44, 0.87, 1 } })
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.events, "SendMessage", function(_, _, name, ...)
      table.insert(calls.messages, { name = name, args = { ... } })
    end)
    override(stubs.database, "GetItemLevelOptions", function(_, kind)
      assert.are.equal(GUILD, kind)
      return { enabled = true, color = false }
    end)
    override(stubs.color, "GetItemLevelColor", function() return 1, 0.5, 0 end)
    override(stubs.guildBank, "TabOf", function(_, container) return const.GUILD_BANK_BAGS[container] end)
    override(stubs.guildBank, "TabInfo", function(_, tab) return { tab = tab, name = tab == 2 and "Mats" or "Gear" } end)
    override(stubs.guildBank, "Pickup", function(_, tab, slot) table.insert(calls.pickup, { tab, slot }) end)
    override(stubs.guildBank, "Withdraw", function(_, tab, slot) table.insert(calls.withdraw, { tab, slot }) end)
    override(stubs.guildBank, "Split", function(_, tab, slot, n) table.insert(calls.split, { tab, slot, n }) end)
    override(stubs.guildBank, "PlaceCursorItem", function(_, tab)
      table.insert(calls.place, tab)
      return "placed"
    end)
    override(stubs.itemFrame, "DrawQualityGlowFor", function(_, kind, button, quality)
      table.insert(calls.glow, { kind = kind, button = button, quality = quality })
    end)
    override(stubs.sonata, "RegisterElement", function(_, kind, element)
      table.insert(calls.registered, { kind = kind, element = element })
    end)
    override(stubs.elements, "DrawItemQuality", function() return false end)
    -- Blizzard's item button helpers (Blizzard_ItemButton ItemButtonTemplate.lua).
    override(_G, "SetItemButtonTexture", function(button, texture) button.icon:SetTexture(texture) end)
    override(_G, "SetItemButtonCount", function(button, count)
      button.count = count
      if count and count > (button.minDisplayCount or 1) then
        button.Count:SetText(count)
        button.Count:Show()
      else
        button.Count:Hide()
      end
    end)
    override(_G, "SetItemButtonDesaturated", function(button, desaturated)
      button.icon:SetDesaturated(desaturated and true or false)
    end)
    override(_G, "SetItemButtonQuality", function(button, quality, link)
      table.insert(calls.quality, { button = button, quality = quality, link = link })
    end)
    override(_G, "BattlePetToolTip_Show", function(...)
      calls.petTooltip = { ... }
    end)
    _G._isShiftKeyDown, _G._isControlKeyDown = false, false
    _G._modifiedClickHandled = false
    ClearCursor()
    _G._cursorHasItem = false
  end)

  after_each(function()
    restore()
    addon.isRetail = savedRetail
    ClearCursor()
    _G._cursorHasItem = false
  end)

  teardown(function()
    for _, name in ipairs(createdStubs) do
      ResetModuleStub(name)
    end
  end)

  describe("the button", function()
    it("is Blizzard's item button: the ItemButton intrinsic on retail and WoW: Forever", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      assert.are.equal("ItemButton", b.button._type)
      assert.are.equal(b.button, b.frame)
    end)

    it("is ItemButtonTemplate on Classic, as Blizzard's TBC guild bank makes it", function()
      addon.isRetail = false
      local b = guildButton:GetButton(ctx, "1002_7")
      assert.are.equal("Button", b.button._type)
      assert.are.equal("ItemButtonTemplate", b.button._template)
    end)

    it("is one button per slot until it is released, then reused for any slot", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      assert.are.equal(b, guildButton:GetButton(ctx, "1002_7"))
      assert.are_not.equal(b, guildButton:GetButton(ctx, "1001_1"))
      b:Release(ctx)
      assert.are.equal(b, guildButton:GetButton(ctx, "1001_5"))
    end)

    it("is announced once, for Masque, and styled by the theme as bag buttons are", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:Release(ctx)
      guildButton:GetButton(ctx, "1001_5")
      local announced = 0
      for _, m in ipairs(calls.messages) do
        if m.name == "guild/NewButton" then
          announced = announced + 1
          assert.are.equal(b, m.args[1])
        end
      end
      assert.are.equal(1, announced)
      assert.are.same({ { kind = "ItemButton", element = b.button } }, calls.registered)
    end)

    it("is hidden and unparented once released", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b.frame:SetParent(UIParent)
      b:SetItemFromData(ctx, item())
      b:Release(ctx)
      assert.is_false(b.frame:IsShown())
      assert.is_nil(b.frame:GetParent())
      assert.is_nil(b:GetItemData())
    end)

    it("sizes its icon and border with itself", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetSize(ctx, 44, 44)
      assert.are.same({ 44, 44 }, { b.button:GetSize() })
      assert.are.same({ 44, 44 }, { b.button.icon:GetSize() })
      assert.are.same({ 44, 44 }, { b.button.IconBorder:GetSize() })
    end)
  end)

  -- Blizzard's guild bank draws a slot with SetItemButtonTexture, SetItemButtonCount,
  -- SetItemButtonDesaturated (locked) and SetItemButtonQuality (GuildBankFrameMixin:Update).
  describe("drawing a guild item", function()
    it("shows its icon, count and quality as Blizzard's guild bank does, and is shown", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      local data = item({ quality = 3 })
      b:SetItemFromData(ctx, data)
      assert.are.equal(135232, b.button.icon:GetTexture())
      assert.are.equal("20", tostring(b.button.Count:GetText()))
      assert.is_true(b.button.Count:IsShown())
      assert.are.same({ { button = b.button, quality = 3, link = data.itemInfo.itemLink } }, calls.quality)
      assert.are.equal(data, b:GetItemData())
      assert.is_true(b.frame:IsShown())
      assert.is_falsy(b.isFreeSlot)
    end)

    it("shows a virtual stack's total", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ count = 20, stackedCount = 45 }))
      assert.are.equal("45", tostring(b.button.Count:GetText()))
    end)

    it("is desaturated while it is locked (another player is moving it)", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ locked = true }))
      assert.is_true(b.button.icon:IsDesaturated())
      b:SetItemFromData(ctx, item())
      assert.is_false(b.button.icon:IsDesaturated())
    end)

    it("glows by the guild bank's own glow setting, as bag buttons do by theirs", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ quality = 3 }))
      assert.are.same({ { kind = GUILD, button = b.button, quality = 3 } }, calls.glow)
    end)

    it("leaves quality to a theme that draws it", function()
      local asked
      override(stubs.elements, "DrawItemQuality", function(_, button, color, quality)
        asked = { button = button, color = color, quality = quality }
        return true
      end)
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ quality = 3 }))
      assert.are.same({}, calls.glow)
      assert.are.same({ button = b.button, color = const.ITEM_QUALITY_COLOR[3], quality = 3 }, asked)
    end)

    it("hands a theme no color for a common item", function()
      local asked
      override(stubs.elements, "DrawItemQuality", function(_, _, color)
        asked = color
        return true
      end)
      guildButton:GetButton(ctx, "1002_7"):SetItemFromData(ctx, item({ quality = 1 }))
      assert.is_nil(asked)
    end)

    it("shows the item level of gear, as the guild bank's settings say", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ classID = Enum.ItemClass.Armor, ilvl = 600 }))
      assert.are.equal("600", b.itemLevel:GetText())
      assert.is_true(b.itemLevel:IsShown())
      b:SetItemFromData(ctx, item({ classID = 7, ilvl = 600 }))
      assert.is_false(b.itemLevel:IsShown())
      override(stubs.database, "GetItemLevelOptions", function() return { enabled = false } end)
      b:SetItemFromData(ctx, item({ classID = Enum.ItemClass.Weapon, ilvl = 600 }))
      assert.is_false(b.itemLevel:IsShown())
    end)

    it("colors the item level when the setting says so", function()
      override(stubs.database, "GetItemLevelOptions", function() return { enabled = true, color = true } end)
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ classID = Enum.ItemClass.Weapon, ilvl = 600 }))
      assert.are.same({ 1, 0.5, 0, 1 }, { b.itemLevel:GetTextColor() })
    end)

    it("shows Blizzard's upgrade arrow for an upgrade", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ isUpgrade = true }))
      assert.is_true(b.upgrade:IsShown())
      assert.are.equal("bags-greenarrow", b.upgrade:GetAtlas())
      b:SetItemFromData(ctx, item())
      assert.is_false(b.upgrade:IsShown())
    end)

    it("dims what the search leaves out, else what the client filters", function()
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ isSearchResult = false }))
      assert.is_false(b.button:GetMatchesSearch())
      b:SetItemFromData(ctx, item({ isFiltered = true }))
      assert.is_false(b.button:GetMatchesSearch())
      b:SetItemFromData(ctx, item({ isSearchResult = true, isFiltered = true }))
      assert.is_true(b.button:GetMatchesSearch())
      b:UpdateSearch(ctx, false)
      assert.is_false(b.button:GetMatchesSearch())
    end)

    it("dims with the template's search overlay on Classic, which has no SetMatchesSearch", function()
      addon.isRetail = false
      local b = guildButton:GetButton(ctx, "1002_7")
      b:SetItemFromData(ctx, item({ isSearchResult = false }))
      assert.is_true(b.button.searchOverlay:IsShown())
      b:UpdateSearch(ctx, true)
      assert.is_false(b.button.searchOverlay:IsShown())
    end)
  end)

  -- GuildBankItemButtonMixin: OnClick, OnDragStart, OnReceiveDrag, OnEnter, OnHide; each on the
  -- item's own tab (GuildBank makes it current: Blizzard's buttons act on the current tab).
  describe("clicks", function()
    local b, data

    before_each(function()
      b = guildButton:GetButton(ctx, "1002_7")
      data = item()
      b:SetItemFromData(ctx, data)
    end)

    it("picks the item up on a left click, withdraws it to the bags on a right click", function()
      script(b, "OnClick", "LeftButton")
      script(b, "OnClick", "RightButton")
      assert.are.same({ { 2, 7 } }, calls.pickup)
      assert.are.same({ { 2, 7 } }, calls.withdraw)
    end)

    it("hands a modified click Blizzard handles (a chat link) to Blizzard alone", function()
      _G._isShiftKeyDown = true
      _G._modifiedClickHandled = true
      script(b, "OnClick", "LeftButton")
      assert.are.same({}, calls.pickup)
      assert.are.same({}, _G._guildBankCalls.splitFrames)
    end)

    it("opens Blizzard's stack split on Shift, and splits from the item's tab", function()
      _G._guildBank.tabs[2] = { name = "Mats", slots = { [7] = { link = data.itemInfo.itemLink, texture = 1, count = 20 } } }
      _G._guildBank.delivered[2] = true
      _G._isShiftKeyDown = true
      script(b, "OnClick", "LeftButton")
      assert.are.same({ { max = 20, owner = b.button, anchor = "BOTTOMLEFT", anchorTo = "TOPLEFT" } },
        _G._guildBankCalls.splitFrames)
      b.button.SplitStack(b.button, 5)
      assert.are.same({ { 2, 7, 5 } }, calls.split)
      assert.are.same({}, calls.pickup)
    end)

    it("splits nothing that is locked, a single item, or with something on the cursor", function()
      _G._guildBank.tabs[2] = { name = "Mats", slots = { [7] = { link = "x", texture = 1, count = 20, locked = true } } }
      _G._guildBank.delivered[2] = true
      _G._isShiftKeyDown = true
      script(b, "OnClick", "LeftButton")
      _G._guildBank.tabs[2].slots[7] = { link = "x", texture = 1, count = 1 }
      script(b, "OnClick", "LeftButton")
      _G._guildBank.tabs[2].slots[7] = { link = "x", texture = 1, count = 20 }
      _G._cursorHasItem = true
      script(b, "OnClick", "LeftButton")
      assert.are.same({}, _G._guildBankCalls.splitFrames)
    end)

    -- Classic's stack split is a global function (Classic/StackSplitFrame.lua); retail's a method of
    -- the frame (StackSplitMixin), and neither client has the other.
    it("uses the global stack split on Classic", function()
      addon.isRetail = false
      local opened
      override(StackSplitFrame, "OpenStackSplitFrame", nil)
      override(_G, "OpenStackSplitFrame", function(maxStack, owner, anchor, anchorTo)
        opened = { max = maxStack, owner = owner, anchor = anchor, anchorTo = anchorTo }
      end)
      _G._guildBank.tabs[2] = { name = "Mats", slots = { [7] = { link = "x", texture = 1, count = 20 } } }
      _G._guildBank.delivered[2] = true
      _G._isShiftKeyDown = true
      script(b, "OnClick", "LeftButton")
      assert.are.same({ max = 20, owner = b.button, anchor = "BOTTOMLEFT", anchorTo = "TOPLEFT" }, opened)
    end)

    it("deposits gold held on the cursor, and puts back gold taken from the guild bank", function()
      _G._cursorType, _G._cursorItemID = "money", 5000
      script(b, "OnClick", "LeftButton")
      assert.are.same({ 5000 }, _G._guildBankCalls.deposits)
      assert.is_nil(GetCursorInfo())
      _G._cursorType = "guildbankmoney"
      script(b, "OnClick", "LeftButton")
      assert.are.equal(1, _G._guildBankCalls.cursorMoneyDropped)
      assert.are.same({}, calls.pickup)
    end)

    it("picks the item up when dragged, and takes a drop", function()
      script(b, "OnDragStart", "LeftButton")
      script(b, "OnReceiveDrag")
      assert.are.same({ { 2, 7 }, { 2, 7 } }, calls.pickup)
    end)

    it("shows Blizzard's tooltip for the slot of its own tab", function()
      script(b, "OnEnter")
      assert.are.same({ { tab = 2, slot = 7 } }, _G._guildBankCalls.tooltips)
    end)

    it("shows a caged battle pet's own tooltip, as Blizzard's guild bank does", function()
      local saved = GameTooltip.SetGuildBankItem
      GameTooltip.SetGuildBankItem = function() return 1234, 25, 3, 1400, 300, 280, "Whelpling" end
      script(b, "OnEnter")
      GameTooltip.SetGuildBankItem = saved
      assert.are.same({ 1234, 25, 3, 1400, 300, 280, "Whelpling" }, calls.petTooltip)
    end)

    it("closes the stack split it opened when it hides", function()
      _G._guildBank.tabs[2] = { name = "Mats", slots = { [7] = { link = "x", texture = 1, count = 20 } } }
      _G._guildBank.delivered[2] = true
      _G._isShiftKeyDown = true
      script(b, "OnClick", "LeftButton")
      b.button.hasStackSplit = 1
      script(b, "OnHide")
      assert.are.equal(1, _G._guildBankCalls.splitHidden)
    end)
  end)

  describe("free slots", function()
    it("shows an empty slot of a tab shown by itself, which takes the item held", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ individual = true }), 1, true)
      assert.is_true(b.isFreeSlot)
      assert.is_false(b.button.Count:IsShown())
      assert.is_nil(b:GetItemData())
      _G._cursorType = "item"
      _G._cursorHasItem = true
      script(b, "OnClick", "LeftButton")
      script(b, "OnReceiveDrag")
      assert.are.same({ { 2, 9 }, { 2, 9 } }, calls.pickup)
      script(b, "OnClick", "RightButton")
      script(b, "OnDragStart", "LeftButton")
      assert.are.equal(2, #calls.pickup)
    end)

    it("does nothing on a click with nothing held", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ individual = true }), 1, true)
      script(b, "OnClick", "LeftButton")
      assert.are.same({}, calls.pickup)
    end)

    it("counts a tab's free slots in the combined view, and puts the item held in that tab", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ count = 96 }), 96)
      assert.are.equal("96", tostring(b.button.Count:GetText()))
      assert.is_true(b.button.Count:IsShown())
      _G._cursorType = "item"
      _G._cursorHasItem = true
      script(b, "OnClick", "LeftButton")
      script(b, "OnReceiveDrag")
      assert.are.same({ 2, 2 }, calls.place)
      assert.are.same({}, calls.pickup)
    end)

    it("draws no item art, count or arrow left from an item drawn before", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetItemFromData(ctx, item({ isUpgrade = true, classID = Enum.ItemClass.Armor, ilvl = 500, locked = true }))
      b:SetFreeSlots(ctx, free({ individual = true }), 1, true)
      assert.is_false(b.upgrade:IsShown())
      assert.is_false(b.itemLevel:IsShown())
      assert.is_false(b.button.icon:IsDesaturated())
      assert.is_false(b.button.IconBorder:IsShown())
    end)

    it("draws the bags' empty slot art: Blizzard's slot background on retail", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ individual = true }), 1, true)
      assert.is_true(b.slotBackground:IsShown())
      assert.are.equal("Interface\\ContainerFrame\\UI-Bag-Components", b.slotBackground:GetTexture())
      b:SetItemFromData(ctx, item())
      assert.is_false(b.slotBackground:IsShown())
    end)

    it("draws the bags' empty slot art: the backpack's empty slot on Classic", function()
      addon.isRetail = false
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ individual = true }), 1, true)
      assert.are.equal("Interface\\PaperDoll\\UI-Backpack-EmptySlot", b.button.icon:GetTexture())
    end)

    it("names its tab and its free slots in its tooltip", function()
      local b = guildButton:GetButton(ctx, "1002_9")
      b:SetFreeSlots(ctx, free({ count = 96 }), 96)
      local lines = {}
      local saved = { GameTooltip.SetText, GameTooltip.AddLine }
      GameTooltip.SetText = function(_, text) table.insert(lines, text) end
      GameTooltip.AddLine = function(_, text) table.insert(lines, text) end
      script(b, "OnEnter")
      GameTooltip.SetText, GameTooltip.AddLine = saved[1], saved[2]
      assert.are.same({ "Mats", "96 free slots", "Drop an item here to put it in this tab" }, lines)
    end)
  end)
end)
