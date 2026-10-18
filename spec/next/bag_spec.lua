-- bag_spec.lua -- NextBag (next/bag.lua): BetterBagsNext's backpack. A full-height panel that slides
-- in from the right, with a feathered left edge, the title and its sparkles, a search box, the
-- group tabs down its left side and the content in one column; it stands in for the backpack
-- everywhere the addon talks to it (next.md §1, §3).
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
local BACKPACK = const.BAG_KIND.BACKPACK

local stubs = {
  L = trackStub("Localization"),
  itemFrame = trackStub("ItemFrame"),
  items = trackStub("Items"),
  database = trackStub("Database"),
  groups = trackStub("Groups"),
  events = trackStub("Events"),
  searchBox = trackStub("SearchBox"),
  sonata = trackStub("Sonata"),
  money = trackStub("MoneyFrame"),
  cursorPlacement = trackStub("CursorPlacement"),
  backpackBehavior = trackStub("BackpackBehavior"),
  sectionFrame = trackStub("SectionFrame"),
  bagSystem = trackStub("BagSystem"),
}

-- Every function this spec replaces on a module, put back after each test and the file.
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
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextSparkles", "next/sparkles.lua" }, { "NextTabs", "next/tabs.lua" }, { "NextContent", "next/content.lua" },
  { "NextDrag", "next/drag.lua" }, { "NextPanel", "next/panel.lua" }, { "NextBag", "next/bag.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local nextBag = addon:GetModule("NextBag")
local style = addon:GetModule("NextStyle")
local tween = addon:GetModule("NextTween")
local render = addon:GetModule("Render")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

describe("NextBag", function()
  local buttons, sent, messages, buckets, groupsEnabled, activeGroup, allGroups, expired, inBagSearch
  local box, helper, placed, slotInfo

  -- fakeButton stands in for an item button, recording what is done to it.
  local function fakeButton(slotkey)
    local b = { slotkey = slotkey, frame = CreateFrame("Frame"), searched = {}, cooldowns = 0, released = 0 }
    b.frame:SetSize(37, 37)
    function b:SetItemFromData(_, data) self.data = data self.isFreeSlot = false end
    function b:SetFreeSlots(_, data) self.data = data self.isFreeSlot = true end
    function b:SetSize(_, w, h) self.frame:SetSize(w, h) end
    function b:GetItemData() return self.data end
    function b:UpdateSearch(_, found)
      self.searches = (self.searches or 0) + 1
      table.insert(self.searched, found)
    end
    function b:UpdateCooldown() self.cooldowns = self.cooldowns + 1 return "start" end
    function b:Release() self.released = self.released + 1 end
    return b
  end

  local function item(slotkey, category)
    return { slotkey = slotkey, itemInfo = { category = category } }
  end

  -- tabData builds slot info with tab 1 holding a Weapons category and tab 2 a Herbs category.
  local function data(tab1Items, tab2Items, free)
    return {
      sortedItems = {},
      tabs = {
        [1] = { categories = { { name = "Weapons" } }, items = tab1Items or { item("0_1", "Weapons") }, freeSpace = free },
        [2] = { categories = { { name = "Herbs" } }, items = tab2Items or { item("0_7", "Herbs") } },
      },
    }
  end

  before_each(function()
    render:Init()
    tween:Init()
    motion:Init()
    buttons, sent, messages, buckets = {}, {}, {}, {}
    groupsEnabled, activeGroup, expired, inBagSearch = true, 1, false, true
    allGroups = { [1] = { id = 1, name = "Backpack" }, [2] = { id = 2, name = "Herbs" } }
    placed = {}
    slotInfo = data()
    override(stubs.L, "G", function(_, key) return key end)
    override(stubs.itemFrame, "GetButton", function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or fakeButton(slotkey)
      return buttons[slotkey]
    end)
    override(stubs.items, "GetAllSlotInfo", function() return { [BACKPACK] = slotInfo } end)
    override(stubs.items, "ExpireRecentItems", function() return expired end)
    override(stubs.database, "GetGroupsEnabled", function() return groupsEnabled end)
    override(stubs.database, "GetActiveGroup", function() return activeGroup end)
    override(stubs.database, "SetActiveGroup", function(_, _, id) activeGroup = id end)
    override(stubs.database, "GetInBagSearch", function() return inBagSearch end)
    override(stubs.groups, "GetAllGroups", function() return allGroups end)
    override(stubs.groups, "GetGroup", function(_, _, id) return allGroups[id] end)
    override(stubs.events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    override(stubs.events, "RegisterMessage", function(_, name, fn) messages[name] = fn end)
    override(stubs.events, "BucketEvent", function(_, name, fn, filter) buckets[name] = { fn, filter } end)
    override(stubs.searchBox, "CreateBox", function(_, kind, parent)
      box = { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      box.textBox = CreateFrame("EditBox", nil, box.frame)
      return box
    end)
    override(stubs.sonata, "UnregisterElement", function(_, kind, element)
      table.insert(sent, { "unregistered", kind, element })
    end)
    override(stubs.money, "Create", function() return { frame = CreateFrame("Frame") } end)
    override(stubs.cursorPlacement, "PlaceCursorItem", function(_, kind) table.insert(placed, kind) return "placed" end)
    helper = { menus = {}, created = 0 }
    function helper:ShowGroupContextMenu(_, id) table.insert(self.menus, id) end
    function helper:ShowCreateGroupDialog() self.created = self.created + 1 end
    override(stubs.backpackBehavior, "Create", function(_, bag) helper.bag = bag return helper end)
    override(_G, "PlaySound", function() end)
    override(addon, "TriggerItemContextChanged", function() end)
    override(addon, "ForceHideBlizzardBags", function() end)
  end)

  after_each(function()
    restore()
  end)

  teardown(function()
    for _, m in ipairs({ "NextBag", "NextPanel", "NextDrag", "NextContent", "NextTabs", "NextSparkles", "NextTween", "NextStyle" }) do
      ResetModuleStub(m)
    end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  local function ctx() return context:New("spec") end

  local function finishTweens()
    for _ = 1, 400 do
      local update = tween.driver and tween.driver:GetScript("OnUpdate")
      if update == nil then return end
      update(tween.driver, 0.05)
    end
  end

  local function offset(bag)
    local _, _, _, x = bag.frame:GetPoint(1)
    return x
  end

  local function sentNamed(name)
    local out = {}
    for _, m in ipairs(sent) do
      if m[1] == name then table.insert(out, m) end
    end
    return out
  end

  local function opened()
    local bag = nextBag:Create(ctx())
    bag:Draw(ctx(), slotInfo, function() end)
    bag:Show(ctx())
    finishTweens()
    return bag
  end

  describe("the panel", function()
    it("is a hidden, named, full-height panel on the right edge of the screen", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(BACKPACK, bag.kind)
      assert.are.equal("BetterBagsNextBackpack", bag:GetName())
      assert.is_false(bag:IsShown())
      assert.are.same({ "TOPRIGHT", UIParent, "TOPRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 }, { bag.frame:GetPoint(2) })
      assert.are.equal(style.WIDTH, bag.frame:GetWidth())
    end)

    -- Above every other part of the UI (MEDIUM panels, LOW bars, addon frames up to HIGH), below
    -- what must cover it: Blizzard's popups and game menu (DIALOG), menus (FULLSCREEN_DIALOG),
    -- tooltips, and the toplevel HIGH boxes that raise themselves when shown (the stack split).
    it("sits in the HIGH strata, raising itself when shown or clicked", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal("HIGH", bag.frame:GetFrameStrata())
      assert.is_true(bag.frame:IsToplevel())
    end)

    it("feathers its left edge out to nothing and takes no clicks there", function()
      local bag = nextBag:Create(ctx())
      local g = bag.feather._gradient
      assert.are.equal("HORIZONTAL", g.orientation)
      assert.are.equal(0, g.min.a)
      assert.are.equal(style.Color.Body[4], g.max.a)
      assert.are.equal(style.FEATHER, bag.feather:GetWidth())
      assert.are.same({ style.FEATHER, 0, 0, 0 }, { bag.frame:GetHitRectInsets() })
    end)

    it("titles itself in its title", function()
      local bag = nextBag:Create(ctx())
      bag:SetTitle("Backpack")
      assert.are.equal("Backpack", bag.title:GetText())
      assert.are.equal(style:Font("Title"), bag.title:GetFontObject())
    end)

    it("uses the backpack's in-bag search box, drawn by Next instead of the theme", function()
      local bag = nextBag:Create(ctx())
      assert.are.equal(BACKPACK, box.kind)
      assert.are.equal(box, bag.searchBox)
      assert.are.same({ "unregistered", "SearchBox", box.textBox }, sent[1])
      assert.is_true(box.frame:IsShown())
    end)

    it("hides the search box while in-bag search is off, and recalculates when it changes", function()
      inBagSearch = false
      local bag = nextBag:Create(ctx())
      assert.is_false(box.frame:IsShown())
      inBagSearch = true
      messages["search/SetInFrame"](ctx())
      assert.is_true(box.frame:IsShown())
      assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sentNamed("bags/Rederive"))
      local _ = bag
    end)
  end)

  describe("opening and closing", function()
    it("keeps a draw for when it opens, and draws it as it opens", function()
      local bag = nextBag:Create(ctx())
      local called = 0
      bag:Draw(ctx(), slotInfo, function() called = called + 1 end)
      assert.are.equal(1, called, "calls back at once")
      assert.is_nil(buttons["0_1"], "draws nothing while hidden")
      assert.is_true(bag:Show(ctx()))
      assert.is_not_nil(buttons["0_1"])
      assert.is_false(bag:Show(ctx()), "already open")
    end)

    it("leaves an open panel alone when asked to open again", function()
      local bag = opened()
      bag:Show(ctx())
      assert.are.equal(1, bag.content.order[1].frame:GetAlpha(), "no new cascade")
      assert.is_false(tween:IsPlaying(bag), "no new slide")
    end)

    it("closes once when asked to close while it is closing", function()
      local bag = opened()
      local sounds = 0
      override(_G, "PlaySound", function() sounds = sounds + 1 end)
      bag:Hide(ctx())
      tween:Step(0.1)
      bag:Hide(ctx())
      assert.are.equal(1, sounds)
      finishTweens()
      assert.is_false(bag:IsShown())
    end)

    it("slides in from the right, past its place a little and back", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      assert.is_true(bag:IsShown())
      assert.are.equal(style.WIDTH + style.OVERREACH, offset(bag))
      local past = false
      for _ = 1, 40 do
        tween:Step(0.0125)
        if offset(bag) < 0 then past = true end
      end
      assert.is_true(past, "overshoots")
      assert.are.equal(0, offset(bag))
    end)

    it("fades its sections in one after the other as it opens", function()
      local bag = nextBag:Create(ctx())
      bag:Draw(ctx(), slotInfo, function() end)
      bag:Show(ctx())
      assert.are.equal(0, bag.content.order[1].frame:GetAlpha())
      finishTweens()
      assert.are.equal(1, bag.content.order[1].frame:GetAlpha())
    end)

    it("starts its sparkles while open, and stops them when it hides", function()
      local bag = nextBag:Create(ctx())
      bag:Show(ctx())
      assert.is_not_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      assert.is_not_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"))
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.is_nil(bag.sparkles.frame:GetScript("OnUpdate"))
      assert.is_nil(bag.edgeSparkles.frame:GetScript("OnUpdate"))
    end)

    it("slides out to the right, then hides", function()
      local bag = opened()
      bag:Hide(ctx())
      assert.is_true(bag:IsShown(), "still sliding")
      finishTweens()
      assert.is_false(bag:IsShown())
      assert.are.equal(style.WIDTH + style.OVERREACH, offset(bag))
    end)

    it("toggles open and closed", function()
      local bag = nextBag:Create(ctx())
      bag:Toggle(ctx())
      finishTweens()
      assert.is_true(bag:IsShown())
      bag:Toggle(ctx())
      finishTweens()
      assert.is_false(bag:IsShown())
    end)

    -- Escape hides the frame directly (UISpecialFrames); every way it hides runs this.
    it("expires Recent Items when it hides, and recalculates when any expired or gaps are held", function()
      local bag = opened()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({}, sentNamed("bags/Rederive"))
      expired = true
      bag.frame:Show()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({ { "bags/Rederive", { backpack = true, bank = false } } }, sentNamed("bags/Rederive"))
      expired = false
      bag.drawOnClose = true
      bag.frame:Show()
      bag.frame:Hide()
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.equal(2, #sentNamed("bags/Rederive"))
      assert.is_false(bag.drawOnClose)
    end)

    it("does nothing on a hide while it is still shown (a parent hid)", function()
      local bag = opened()
      expired = true
      bag.frame:GetScript("OnHide")(bag.frame)
      assert.are.same({}, sentNamed("bags/Rederive"))
    end)
  end)

  -- Switching between the classic design and BetterBags Next without a reload (next.md §11).
  describe("switching designs (Deactivate, Activate)", function()
    it("hides at once and lets go of every button it drew", function()
      local bag = opened()
      bag:Deactivate(ctx())
      assert.is_false(bag.frame:IsShown())
      assert.is_false(bag.closing, "not through the slide")
      for slotkey, b in pairs(buttons) do
        assert.are.equal(1, b.released, slotkey)
      end
      assert.are.same({}, bag.drawnButtons)
    end)

    it("catches up on its search box, its tabs and its money", function()
      local bag = nextBag:Create(ctx())
      local updates = 0
      bag.moneyFrame.Update = function() updates = updates + 1 end
      inBagSearch = false
      allGroups[3] = { id = 3, name = "Ore" }
      bag:Activate(ctx())
      assert.is_false(bag.searchBox.frame:IsShown())
      assert.is_not_nil(bag.tabs:Tab(3), "Ore listed")
      assert.are.equal(1, updates)
    end)
  end)

  describe("drawing", function()
    it("releases the buttons it drew last time and did not draw again", function()
      local bag = opened()
      local sword = buttons["0_1"]
      slotInfo = data({ item("0_2", "Weapons") })
      bag:Draw(ctx(), slotInfo, function() end)
      assert.are.equal(1, sword.released)
      assert.are.equal(0, buttons["0_2"].released)
    end)

    it("says so when the tab it shows holds nothing", function()
      local bag = opened()
      assert.is_false(bag.emptyText:IsShown())
      slotInfo = data({})
      bag:Draw(ctx(), slotInfo, function() end)
      assert.is_true(bag.emptyText:IsShown())
      assert.are.equal("Nothing here yet", bag.emptyText:GetText())
    end)

    it("shows its free slots in the footer", function()
      slotInfo = data(nil, nil, { showAll = false, buttons = { { slotkey = "1_5", count = 12 } } })
      local bag = opened()
      assert.are.equal("12 free slots", bag.freeText:GetText())
    end)

    it("searches the buttons it shows, leaving free slots alone", function()
      slotInfo = data(nil, nil, { showAll = false, buttons = { { slotkey = "1_5", count = 12 } } })
      local bag = opened()
      bag:Search(ctx(), { ["0_1"] = false })
      assert.are.same({ false }, buttons["0_1"].searched)
      assert.is_nil(buttons["1_5"].searches)
      bag:ResetSearch(ctx())
      assert.are.same({ false, true }, buttons["0_1"].searched)
    end)

    it("refreshes its buttons' cooldowns while shown, from the bucketed event and as it opens", function()
      local bag = nextBag:Create(ctx())
      local bucket = buckets["BAG_UPDATE_COOLDOWN"]
      assert.is_false(bucket[2](), "fires are dropped while hidden")
      bag:Draw(ctx(), slotInfo, function() end)
      bag:Show(ctx())
      assert.is_true(bucket[2]())
      local before = buttons["0_1"].cooldowns
      bucket[1](ctx())
      assert.are.equal(before + 1, buttons["0_1"].cooldowns)
    end)

    it("is a drop target for the backpack", function()
      local bag = opened()
      bag.frame:GetScript("OnReceiveDrag")(bag.frame)
      assert.are.same({ BACKPACK }, placed)
    end)
  end)

  describe("tabs", function()
    it("lists the groups as tabs, with one to make a group, and selects the active one", function()
      local bag = opened()
      local ids = {}
      for _, tab in ipairs(bag.tabs.tabs) do table.insert(ids, tab.id) end
      assert.are.same({ 1, 2, 0 }, ids)
      assert.are.equal(1, bag.tabs.selected)
      assert.is_true(bag.tabs.frame:IsShown())
    end)

    it("hides the tabs while groups are off", function()
      groupsEnabled = false
      local bag = opened()
      assert.is_false(bag.tabs.frame:IsShown())
      assert.are.equal(1, bag:GetCurrentTabID())
    end)

    it("switches group on a click: the tab's items, fading in", function()
      local bag = opened()
      local herbs = bag.tabs.tabs[2].button
      herbs:GetScript("OnClick")(herbs, "LeftButton")
      assert.are.equal(2, activeGroup)
      assert.are.equal(2, bag.tabs.selected)
      assert.are.equal("Herbs", bag.content.order[1].name)
      assert.are.equal(1, buttons["0_1"].released)
      assert.are.equal(0, bag.content.order[1].frame:GetAlpha())
    end)

    it("fades in a section it shows again when the tab changes", function()
      slotInfo = data(nil, { item("0_9", "Weapons") })
      slotInfo.tabs[2].categories = { { name = "Weapons" } }
      local bag = opened()
      local weapons = bag.content.order[1]
      bag:SwitchToGroup(ctx(), 2)
      assert.are.equal(weapons, bag.content.order[1], "the same section")
      assert.are.equal(0, weapons.frame:GetAlpha())
    end)

    it("switches group for Quick Find and the group dialogs through its behavior", function()
      local bag = opened()
      bag.behavior:SwitchToGroup(ctx(), 2)
      assert.are.equal(2, activeGroup)
    end)

    it("opens a group's menu on a right click, and the new group dialog from its last tab", function()
      local bag = opened()
      local herbs, backpack, plus = bag.tabs.tabs[2].button, bag.tabs.tabs[1].button, bag.tabs.tabs[3].button
      herbs:GetScript("OnClick")(herbs, "RightButton")
      backpack:GetScript("OnClick")(backpack, "RightButton")
      assert.are.same({ 2 }, helper.menus, "the Backpack group has no menu")
      plus:GetScript("OnClick")(plus, "LeftButton")
      assert.are.equal(1, helper.created)
      assert.are.equal(1, activeGroup)
    end)

    it("lists the groups again when they change, and goes back to Backpack when its group goes", function()
      local bag = opened()
      bag:SwitchToGroup(ctx(), 2)
      allGroups[2] = nil
      messages["groups/Deleted"](ctx(), 2, nil, BACKPACK)
      assert.are.equal(1, activeGroup)
      assert.are.equal(2, #bag.tabs.tabs)
      allGroups[3] = { id = 3, name = "Ore" }
      messages["groups/Created"](ctx(), { kind = BACKPACK })
      assert.are.equal(3, #bag.tabs.tabs)
    end)
  end)

  describe("buttons and search", function()
    -- Both atlases are in the atlas table of retail, WoW: Forever, Classic Era, Mists and
    -- Anniversary; GM-icon-settings, the first settings icon, is missing on Classic Era and Mists.
    it("draws its header icons with atlases every client has, settings at the screen edge", function()
      local bag = opened()
      assert.are.equal("uitools-icon-settings", bag.settingsButton.icon:GetAtlas())
      assert.are.equal("bags-button-autosort-up", bag.sortButton.icon:GetAtlas())
      assert.are.same({ "TOPRIGHT", bag.body, "TOPRIGHT", -style.PAD, -(style.TITLE_TOP + 3) },
        { bag.settingsButton:GetPoint(1) })
      assert.are.same({ "RIGHT", bag.settingsButton, "LEFT", -8, 0 }, { bag.sortButton:GetPoint(1) })
    end)

    -- The way back from BetterBags Next without a reload (next.md §11): the backpack's own icon,
    -- Blizzard's backpack button's art on each client (bag-main on retail and WoW: Forever,
    -- MainMenuBarBagButtons.lua; Button-Backpack-Up on Classic, MainMenuBarBagButtons.xml).
    it("switches the bags to the classic design from a backpack button in its header", function()
      local switched = {}
      override(stubs.bagSystem, "Switch", function(_, c, design)
        assert.is_not_nil(c)
        table.insert(switched, design)
        return true
      end)
      override(addon, "isRetail", true)
      local bag = opened()
      assert.are.equal("bag-main", bag.classicButton.icon:GetAtlas())
      assert.are.same({ "RIGHT", bag.sortButton, "LEFT", -8, 0 }, { bag.classicButton:GetPoint(1) })
      bag.classicButton:GetScript("OnClick")(bag.classicButton, "LeftButton")
      assert.are.same({ "classic" }, switched)
      bag.classicButton:GetScript("OnEnter")(bag.classicButton)
      assert.are.equal("Switch to Classic Bags", GameTooltip:GetText())
      override(addon, "isRetail", false)
      local classicClient = nextBag:Create(ctx())
      assert.are.equal("Interface\\Buttons\\Button-Backpack-Up", classicClient.classicButton.icon:GetTexture())
    end)

    it("sorts the backpack and opens the settings from its header", function()
      local bag = opened()
      bag.sortButton:GetScript("OnClick")(bag.sortButton, "LeftButton")
      bag.settingsButton:GetScript("OnClick")(bag.settingsButton, "LeftButton")
      assert.are.equal(1, #sentNamed("bags/SortBackpack"))
      assert.are.equal(1, #sentNamed("config/Open"))
    end)

    it("opens and focuses its search box from the search keybinding", function()
      local bag = nextBag:Create(ctx())
      bag:ToggleSearch(ctx())
      assert.is_true(bag:IsShown())
      assert.is_true(box.textBox:HasFocus())
      bag:ToggleSearch(ctx())
      assert.is_false(box.textBox:HasFocus(), "a second press lets go of the box")
    end)
  end)
end)
