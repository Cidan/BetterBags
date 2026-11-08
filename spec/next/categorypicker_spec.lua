-- categorypicker_spec.lua -- NextCategoryPicker (next/categorypicker.lua): what an item dropped on a BetterBags Next bag's
-- title (or, in a theme with one, its bag button: Header.ItemDrop) opens, to put the item in a category or in a new one
-- (issue #1270). Asked: "drag an item to the bag name ... to have a (pretty) popup appear that lets you put an item in an
-- existing category, or into a new category ... i don't just want to open the config screen".
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
local L = trackStub("Localization")
local categories = trackStub("Categories")
local items = trackStub("Items")
local database = trackStub("Database")
local events = trackStub("Events")

local modules = { { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextInput", "next/controls/input.lua" },
  { "NextMenu", "next/controls/menu.lua" }, { "NextCategoryPicker", "next/categorypicker.lua" } }
for _, m in ipairs(modules) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local picker = addon:GetModule("NextCategoryPicker")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local BACKPACK, BANK = 0, 1
local LINK = "|cff0070dd|Hitem:6948::::::::80:::::|h[Hearthstone]|h|r"
local GOLD = { 1, 0.82, 0 }

describe("NextCategoryPicker", function()
  local replaced, calls, sent, filters, home, slots, anchor, saved

  local function override(tbl, key, value)
    table.insert(replaced, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx() return context:New("spec") end

  local function bagItem(itemID, category)
    return { itemInfo = { itemID = itemID, category = category, itemIcon = 134414, itemQuality = 3 } }
  end

  -- held is what the panel read of the item dropped (NextPanel:PickCategory): its ID and link, what the bags hold of it,
  -- and where it lands without the category it was added to by hand.
  local function held(extra)
    local item = { itemID = 6948, link = LINK, data = bagItem(6948, "Travel"), natural = "Travel" }
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
  end

  local function open(item)
    picker:Open(ctx(), anchor, item or held())
  end

  local function rows()
    local out = {}
    for _, row in ipairs(nextMenu:Rows()) do
      table.insert(out, row.label:GetText())
    end
    return out
  end

  local function row(text)
    for _, r in ipairs(nextMenu:Rows()) do
      if r.label:GetText() == text then return r end
    end
  end

  local function lit()
    for i, r in ipairs(nextMenu:Rows()) do
      if r.hover:IsShown() then return i end
    end
  end

  local function typeText(text)
    local field = nextMenu.field.frame
    field:SetText(text)
    field:GetScript("OnTextChanged")(field, true)
  end

  local function enter()
    nextMenu.field.frame:GetScript("OnEnterPressed")(nextMenu.field.frame)
  end

  local function click(text)
    local r = row(text)
    r.frame:GetScript("OnClick")(r.frame, "LeftButton")
  end

  before_each(function()
    replaced, calls, sent = {}, {}, {}
    home = nil
    filters = {
      Travel = { name = "Travel", save = true, color = { 0, 1, 0 } },
      Toys = { name = "Toys", save = true },
      Junk = { name = "Junk" },
    }
    slots = {
      [BACKPACK] = { itemsBySlotKey = {
        ["0_1"] = bagItem(6948, "Travel"), ["0_2"] = bagItem(6948, "Travel"), ["0_3"] = bagItem(1111, "Travel"),
        ["0_4"] = bagItem(2222, "Toys - Pets"), ["0_5"] = { isItemEmpty = true },
      } },
      [BANK] = { itemsBySlotKey = { ["6_1"] = bagItem(3333, "Toys") } },
    }
    saved = { _G.UISpecialFrames, C_Timer.After }
    _G.UISpecialFrames = {}
    C_Timer.After = function(_, fn) fn() end
    controls.escape = {}
    override(const, "BAG_KIND", { BACKPACK = BACKPACK, BANK = BANK })
    override(const, "ITEM_QUALITY_COLOR", { [1] = { 1, 1, 1, 1 }, [3] = { 0, 0.44, 0.87, 1 } })
    override(L, "G", function(_, key) return key end)
    override(categories, "GetOrder", function()
      local names = {}
      for _, name in ipairs({ "Travel", "Toys", "Junk" }) do
        if filters[name] then table.insert(names, name) end
      end
      for name in pairs(filters) do
        if name ~= "Travel" and name ~= "Toys" and name ~= "Junk" then table.insert(names, name) end
      end
      return names
    end)
    override(categories, "GetCategoryByName", function(_, name) return filters[name] end)
    override(categories, "DoesCategoryExist", function(_, name) return filters[name] ~= nil or name == "Toys - Pets" end)
    override(categories, "FileItem", function(_, c, itemID, name, natural)
      assert.is_not_nil(c)
      table.insert(calls, { "file", itemID, name, natural })
      return "added"
    end)
    override(categories, "CreateCategory", function(_, c, filter)
      assert.is_not_nil(c)
      table.insert(calls, { "create", filter })
      filters[filter.name] = filter
    end)
    override(categories, "RemoveItemFromCategory", function(_, itemID, name)
      table.insert(calls, { "remove", itemID, name })
    end)
    override(database, "GetItemCategoryByItemID", function() return home and { name = home } or {} end)
    override(items, "GetAllSlotInfo", function() return slots end)
    override(events, "SendMessage", function(_, _, name, opts) table.insert(sent, { name, opts }) end)
    anchor = CreateFrame("Button", nil, CreateFrame("Frame"))
    anchor:SetSize(120, 26)
    anchor:Show()
  end)

  after_each(function()
    nextMenu:Close()
    _G.UISpecialFrames, C_Timer.After = saved[1], saved[2]
    for i = #replaced, 1, -1 do
      replaced[i][1][replaced[i][2]] = replaced[i][3]
    end
    UseNextTheme(nil)
  end)

  teardown(function()
    for i = #modules, 1, -1 do ResetModuleStub(modules[i][1]) end
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("opens a menu under what the item was dropped on, headed by the item: its icon, its name, where it is now", function()
    open()
    assert.is_true(nextMenu:IsOpenFor(anchor))
    assert.are.equal(134414, nextMenu.headIcon:GetTexture())
    assert.are.equal("|cff0070dd|Hitem:6948::::::::80:::::|hHearthstone|h|r", nextMenu.headText:GetText(),
      "its link, in its quality's color, without the brackets")
    assert.are.equal("In Travel", nextMenu.headNote:GetText())
    local edge = nextMenu.headEdge.Top._colorTexture
    assert.are.same({ 0, 0.44, 0.87 }, { edge.r, edge.g, edge.b }, "its quality round its icon")
    assert.are.equal("Find or name a category", nextMenu.field.help:GetText())
    assert.is_true(nextMenu.field.frame:HasFocus())
  end)

  it("lists every category in their order, the item's own checked, a plugin's not to be picked, each with its count", function()
    open()
    assert.are.same({ "Travel", "Toys", "Junk" }, rows())
    local travel, toys, junk = row("Travel"), row("Toys"), row("Junk")
    assert.is_true(travel.item.selected)
    assert.is_falsy(toys.item.selected)
    assert.are.equal("2 items", travel.item.note, "each item once")
    assert.are.equal("2 items", toys.item.note, "a group by's sections and the bank's items count for it")
    assert.is_true(junk.item.disabled)
    assert.are.equal("Made by a plugin", junk.item.note)
    assert.are.same({ 0, 1, 0 }, travel.item.color)
    assert.are.same(GOLD, { toys.item.color[1], toys.item.color[2], toys.item.color[3] }, "gold without a color")
    assert.is_nil(lit(), "nothing lit before anything is typed")
  end)

  it("offers a new category named what is typed when no category has that name, lit when nothing else matches", function()
    open()
    typeText("Hearth")
    assert.are.same({ 'New category "Hearth"' }, rows())
    assert.are.equal(1, lit())
    assert.is_table(row('New category "Hearth"').item.glyph)
    assert.are.same(style.Theme.Controls.Menu.Picker.NewIcon, row('New category "Hearth"').item.glyph)
    typeText("to")
    assert.are.same({ 'New category "to"', "Toys" }, rows())
    assert.are.equal(2, lit(), "the first category that matches")
    typeText("TOYS")
    assert.are.same({ "Toys" }, rows(), "a category of that name, in any case, is offered in place of a new one")
    assert.are.equal(1, lit())
    typeText("   ")
    assert.are.same({ "Travel", "Toys", "Junk" }, rows(), "spaces are nothing typed")
    assert.is_nil(lit())
  end)

  -- Found in review: a group by's section ("Toys - Pets") is no category GetOrder lists, but its name is taken; made
  -- again as a category, it shadowed the section. The settings refuse a name taken (askName, DoesCategoryExist).
  it("offers no new category of a name already taken, a group by's section's too", function()
    open()
    typeText("Toys - Pets")
    assert.are.same({}, rows())
    assert.is_nil(lit())
    enter()
    assert.are.same({}, calls, "Enter makes nothing")
  end)

  it("files the item in the category picked, as a header drop does, and recalculates the bags", function()
    open()
    click("Toys")
    assert.are.same({ { "file", 6948, "Toys", "Travel" } }, calls)
    assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
    assert.is_false(nextMenu.frame:IsShown())
    open()
    typeText("trav")
    enter()
    assert.are.same({ "file", 6948, "Travel", "Travel" }, calls[2])
  end)

  it("files nothing in a plugin's category", function()
    open()
    click("Junk")
    assert.are.same({}, calls)
    assert.is_true(nextMenu.frame:IsShown())
  end)

  it("makes the new category, saved, empty, then files the item in it", function()
    open()
    typeText("  Hearth  ")
    enter()
    assert.are.same({ { "create", { name = "Hearth", itemList = {}, save = true } },
      { "file", 6948, "Hearth", "Travel" } }, calls)
    assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
  end)

  it("offers to take an item added to a category by hand back to where it belongs", function()
    home = "Toys"
    open()
    assert.are.same({ "Back to Travel", "Travel", "Toys", "Junk" }, rows())
    assert.is_nil(lit())
    assert.is_table(row("Back to Travel").item.glyph)
    assert.are.same(style.Theme.Controls.Menu.Picker.BackIcon, row("Back to Travel").item.glyph)
    click("Back to Travel")
    assert.are.same({ { "remove", 6948, "Toys" } }, calls)
    assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
    open()
    typeText("t")
    assert.is_nil(row("Back to Travel"), "only while nothing is typed")
  end)

  it("offers no way back where the item would land in the category it was added to anyway", function()
    home = "Toys"
    open(held({ natural = "Toys - Pets" }))
    assert.is_nil(row("Back to Toys - Pets"))
    local unknown = held()
    unknown.natural = nil
    open(unknown)
    assert.are.same({ "Travel", "Toys", "Junk" }, rows(), "nor where it is not known")
  end)

  it("heads an item the bags do not hold (an equipped one) by its ID's icon, saying nothing of where it is", function()
    override(C_Item, "GetItemInfoInstant", function(id) return id, "Armor", "Cloth", "INVTYPE_HEAD", 133136 end)
    local worn = held()
    worn.data, worn.natural = nil, nil
    open(worn)
    assert.are.equal(133136, nextMenu.headIcon:GetTexture())
    assert.is_false(nextMenu.headNote:IsShown())
    assert.is_falsy(row("Travel").item.selected)
  end)

  it("says, under the pointer, what dropping the item there does", function()
    local owner = CreateFrame("Button")
    picker:Hint(owner, "ANCHOR_LEFT")
    assert.are.equal(owner, GameTooltip._owner)
    assert.are.equal("ANCHOR_LEFT", GameTooltip._anchor)
    assert.are.equal("Add to a Category", GameTooltip._text)
    assert.are.equal("Drop the item here to put it in a category, or in a new one.", GameTooltip.lines[1].text)
  end)
end)
