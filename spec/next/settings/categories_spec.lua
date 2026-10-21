-- categories_spec.lua -- NextSettingsCategories (next/settings/categories.lua): the category manager on a
-- bag's Categories tab (next-settings.md §5), keeping everything the classic window's category pane did
-- (category-lifecycle.md): the list (pinned first, then the rest), pinning and
-- reordering, new item list and search categories, a search category's query and group by kept in step,
-- priority, color, Show Section, the items added to it, Save, Rename, Delete, and Remove for a built-in or
-- leftover category.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_KIND.GUILD = const.BAG_KIND.GUILD or 2
const.BAG_VIEW = const.BAG_VIEW or { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
const.SEARCH_CATEGORY_GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY or { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local db = StubBetterBagsModule("Database")
local categories = StubBetterBagsModule("Categories")
local items = StubBetterBagsModule("Items")
local itemRowFrame = StubBetterBagsModule("ItemRowFrame")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDropdown", "next/controls/dropdown.lua" }, { "NextSwatch", "next/controls/swatch.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextSettingsCategories", "next/settings/categories.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local manager = addon:GetModule("NextSettingsCategories")
local nextDialog = addon:GetModule("NextDialog")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local BANK = 1
local GOLD = { 1, 0.82, 0 }

describe("NextSettingsCategories", function()
  local block, owner, filters, sorts, view, committed, sent, handlers, calls, shownState, saved

  -- override replaces a field for one test; after_each puts every one back, so no later spec file
  -- sees these fakes in the shared modules.
  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  local function click(b, mouse)
    b.frame:GetScript("OnClick")(b.frame, mouse or "LeftButton")
  end

  local function answer(text)
    assert.is_true(nextDialog:IsShown(), "a dialog is shown")
    for i, spec in ipairs(nextDialog.opts.buttons) do
      if spec.text == text then
        click(nextDialog.buttons[i])
        return
      end
    end
    error("the dialog has no button " .. text)
  end

  -- listed returns the list as it shows: "# heading" or "name" (and "name P:n" with a priority).
  local function listed()
    local list = {}
    for _, entry in ipairs(block.entries) do
      if entry.header then
        table.insert(list, "# " .. entry.title)
      else
        local row = block:RowFor(entry.name)
        local note = row.note:GetText()
        table.insert(list, entry.name .. (note ~= "" and (" " .. note) or ""))
      end
    end
    return list
  end

  local function rowClick(name, shift)
    _G._isShiftKeyDown = shift == true
    local row = block:RowFor(name)
    row.frame:GetScript("OnClick")(row.frame, "LeftButton")
    _G._isShiftKeyDown = false
  end

  local function pinned()
    local list = {}
    for name, index in pairs(sorts[BANK]) do
      list[index] = name
    end
    return list
  end

  before_each(function()
    filters = {
      Mats = { name = "Mats", priority = 5, save = true, itemList = { [11] = true, [12] = true } },
      Potions = { name = "Potions", priority = 10, save = true, itemList = {}, color = { 0.2, 0.4, 0.6 },
        searchCategory = { query = "type = consumable", groupBy = const.SEARCH_CATEGORY_GROUP_BY.TYPE } },
      Tokens = { name = "Tokens", priority = 10, save = false, dynamic = true, itemList = {} },
      ["Potions - Flask"] = { name = "Potions - Flask", priority = 10, save = false, isGroupBySubcategory = true, itemList = {} },
    }
    sorts = { [BANK] = { Potions = 1, Mats = 2 } }
    view = const.BAG_VIEW.SECTION_GRID
    committed = {
      ["6_1"] = { itemInfo = { category = "Armor" } },
      ["6_2"] = { itemInfo = { category = "Recent Items" } },
      ["6_3"] = { itemInfo = { category = "Free Space" } },
      ["6_4"] = { isItemEmpty = true, itemInfo = { category = "Bags" } },
      ["6_5"] = { itemInfo = { category = "Mats" } },
    }
    sent, handlers, calls, shownState, saved = {}, {}, {}, { Mats = true, Potions = false }, {}
    override(_G, "UISpecialFrames", {})
    controls.escape = {}
    ColorPickerFrame:Hide()
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false

    override(events, "SendMessage", function(_, _, message, ...) table.insert(sent, { message, ... }) end)
    override(events, "RegisterMessage", function(_, message, fn) handlers[message] = fn end)
    override(db, "GetCustomSectionSort", function(_, kind) return sorts[kind] end)
    override(db, "ClearCustomSectionSort", function(_, kind) sorts[kind] = {} end)
    override(db, "SetCustomSectionSort", function(_, kind, name, index) sorts[kind][name] = index end)
    override(db, "DeleteItemFromCategory", function(_, id, name)
      table.insert(calls, { "DeleteItemFromCategory", id, name })
      filters[name].itemList[id] = nil
    end)
    override(db, "GetBagView", function() return view end)
    override(categories, "GetAllCategories", function()
      local all = {}
      for name, f in pairs(filters) do all[name] = f end
      return all
    end)
    override(categories, "GetCategoryByName", function(_, name) return filters[name] end)
    override(categories, "IsCategoryShown", function(_, name) return shownState[name] ~= false end)
    override(categories, "ToggleCategoryShown", function(_, _, name)
      table.insert(calls, { "ToggleCategoryShown", name })
      shownState[name] = shownState[name] == false
    end)
    override(categories, "IsDynamicCategory", function(_, name) return filters[name] ~= nil and filters[name].dynamic == true end)
    override(categories, "IsGroupBySubcategory", function(_, name)
      return filters[name] ~= nil and filters[name].isGroupBySubcategory == true
    end)
    override(categories, "DoesCategoryExist", function(_, name) return filters[name] ~= nil end)
    override(categories, "CreateCategory", function(_, _, filter)
      table.insert(calls, { "CreateCategory", filter })
      filters[filter.name] = filter
    end)
    override(categories, "DeleteCategory", function(_, _, name)
      table.insert(calls, { "DeleteCategory", name })
      filters[name] = nil
    end)
    override(categories, "RenameCategory", function(_, _, old, new)
      table.insert(calls, { "RenameCategory", old, new })
      if filters[new] then return false end
      filters[new], filters[old] = filters[old], nil
      filters[new].name = new
      return true
    end)
    override(categories, "AddPermanentItemToCategory", function(_, _, id, name)
      table.insert(calls, { "AddPermanentItemToCategory", id, name })
      filters[name].itemList[id] = true
    end)
    override(categories, "GetMergedCategory", function(_, name)
      local f = filters[name]
      local list = {}
      for id in pairs(f and f.itemList or {}) do list[id] = true end
      return { name = name, itemList = list }
    end)
    override(items, "slotInfo", { [BANK] = { itemsBySlotKey = committed } })
    override(items, "GetItemData", function(_, c, ids, cb)
      local list = {}
      for i, id in ipairs(ids) do list[i] = { itemInfo = { itemID = id } } end
      cb(c, list)
    end)
    override(itemRowFrame, "Create", function()
      local row = { frame = CreateFrame("Frame"), rowButton = CreateFrame("Button") }
      row.frame:Hide()
      function row:SetStaticItemFromData(_, data) self.data = data self.frame:Show() end
      function row:Release() self.released = true self.frame:Hide() end
      return row
    end)

    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:Show()
    block = manager:Create(CreateFrame("Frame"), owner, { name = "Bank", kind = BANK })
    block:Refresh(ctx())
  end)

  after_each(function()
    nextMenu:Close()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  describe("its list", function()
    it("lists the pinned categories in their order, then every other one by name, with priorities", function()
      assert.are.same({ "# Pinned", "Potions P:10", "Mats P:5", "# Other Categories", "Armor",
        "Potions - Flask P:10", "Tokens P:10" }, listed())
    end)

    it("lists the bag's sections from its committed items, but not the bag names of Show Bags", function()
      view = const.BAG_VIEW.SECTION_ALL_BAGS
      block:Refresh(ctx())
      assert.are.same({ "# Pinned", "Potions P:10", "Mats P:5", "# Other Categories", "Potions - Flask P:10",
        "Tokens P:10" }, listed())
    end)

    it("is a wide row Height tall, its list ListWidth wide", function()
      assert.is_true(block.wide)
      local K = style.Theme.Settings.Categories
      assert.are.equal(K.Height, block:Measure(700))
      block:Place(0, 0, 700, K.Height)
      assert.are.equal(K.ListWidth, block.list:GetWidth())
    end)

    it("shows a category's settings when its row is clicked, marking it", function()
      rowClick("Mats")
      assert.are.equal("Mats", block.selected)
      assert.is_true(block:RowFor("Mats").indicator:IsShown())
      assert.is_false(block:RowFor("Potions").indicator:IsShown())
      assert.are.equal("items", block.detail)
    end)

    it("pins a category at the top on a Shift-click, and unpins a pinned one", function()
      rowClick("Armor", true)
      assert.are.same({ "Armor", "Potions", "Mats" }, pinned())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.equal("# Pinned", listed()[1])
      assert.are.equal("Armor", listed()[2])
      rowClick("Potions", true)
      assert.are.same({ "Armor", "Mats" }, pinned())
      assert.is_nil(block.selected, "a Shift-click does not select")
    end)

    it("moves a dragged row where it is let go: pinned at that place, or unpinned below the heading", function()
      block:Drop("Tokens", 2)
      assert.are.same({ "Potions", "Tokens", "Mats" }, pinned())
      block:Drop("Potions", 5)
      assert.are.same({ "Tokens", "Mats" }, pinned())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
    end)

    it("moves a pinned category down among the pinned ones", function()
      block:Drop("Potions", 3)
      assert.are.same({ "Mats", "Potions" }, pinned())
    end)

    it("drags a row with the mouse, marking where it would land", function()
      local K = style.Theme.Settings.Categories
      block:Place(0, 0, 700, K.Height)
      block.listBox:_SetRect(0, 0, K.ListWidth, 300)
      local row = block:RowFor("Tokens")
      -- A quarter of the way down the first pinned row: in its top half, so before it.
      _G._cursorX, _G._cursorY = 20, 300 - (K.GroupHeight + 0.25 * K.RowHeight)
      _G._mouseButtonsDown = { LeftButton = true }
      row.frame:GetScript("OnDragStart")(row.frame)
      block.listBox:GetScript("OnUpdate")(block.listBox, 0.016)
      assert.is_true(block.marker:IsShown())
      _G._mouseButtonsDown = {}
      block.listBox:GetScript("OnUpdate")(block.listBox, 0.016)
      assert.is_false(block.marker:IsShown())
      assert.are.same({ "Tokens", "Potions", "Mats" }, pinned())
      _G._cursorX, _G._cursorY = 0, 0
    end)

    it("lists the bag's sections again when its items are read while it shows", function()
      block:Place(0, 0, 700, style.Theme.Settings.Categories.Height)
      committed["6_6"] = { itemInfo = { category = "Weapons" } }
      handlers["items/RefreshBank/Done"](ctx())
      assert.are.equal("Weapons", listed()[#listed()])
    end)

    it("makes a new item list category, selected; asking again for a name taken or none", function()
      click(block.newCategory)
      nextDialog.input.frame:SetText("  ")
      answer("Create")
      assert.is_true(nextDialog:IsShown())
      nextDialog.input.frame:SetText("Mats")
      answer("Create")
      assert.are.equal("A category named 'Mats' already exists.", nextDialog.text:GetText())
      nextDialog.input.frame:SetText("Trash")
      answer("Create")
      assert.are.same({ "CreateCategory", { name = "Trash", itemList = {}, save = true } }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.equal("Trash", block.selected)
      assert.are.equal("items", block.detail)
    end)

    it("makes a new search category once it has a query", function()
      click(block.newSearch)
      nextDialog.input.frame:SetText("Gear")
      answer("Create")
      assert.are.equal("draft", block.detail)
      assert.is_nil(filters.Gear, "not made before it has a query")
      click(block.save)
      assert.are.equal("Write a search query first.", block.warning:GetText())
      block.query:SetText("type = armor")
      click(block.save)
      local filter = calls[#calls][2]
      assert.are.same({ name = "Gear", priority = 10, save = true, itemList = {},
        searchCategory = { query = "type = armor", groupBy = const.SEARCH_CATEGORY_GROUP_BY.NONE } }, filter)
      assert.are.equal("search", block.detail)
    end)
  end)

  describe("a search category", function()
    before_each(function()
      rowClick("Potions")
    end)

    it("shows its query with its group by, its priority, group by, color and Show Section", function()
      assert.are.equal("search", block.detail)
      assert.are.equal("Potions", block.title:GetText())
      assert.are.equal("type = consumable group by type", block.query:GetText())
      assert.are.equal("10", block.priority:GetText())
      assert.are.equal("Type", block.groupBy.text:GetText())
      assert.are.same({ 0.2, 0.4, 0.6, 1 }, block.swatch:GetColor())
      assert.is_false(block.shown:GetChecked())
    end)

    it("keeps its group by and its query in step, either way", function()
      block.query.editBox:SetText("type = consumable group by expansion")
      block.query.editBox:GetScript("OnTextChanged")(block.query.editBox, true)
      assert.are.equal("Expansion", block.groupBy.text:GetText())
      block.query.editBox:SetText("type = consumable")
      block.query.editBox:GetScript("OnTextChanged")(block.query.editBox, true)
      assert.are.equal("None", block.groupBy.text:GetText())
      click(block.groupBy)
      nextMenu:Rows()[3].frame:GetScript("OnClick")(nextMenu:Rows()[3].frame, "LeftButton")
      assert.are.equal("type = consumable group by subtype", block.query:GetText())
    end)

    it("saves its query without the group by clause, its group by, priority and color", function()
      block.query:SetText("type = potion group by subtype")
      block.query.editBox:GetScript("OnTextChanged")(block.query.editBox, true)
      block.priority:SetText("3")
      click(block.save)
      assert.are.same({ name = "Potions", priority = 3, save = true, itemList = {}, color = { 0.2, 0.4, 0.6 },
        searchCategory = { query = "type = potion", groupBy = const.SEARCH_CATEGORY_GROUP_BY.SUBTYPE } }, calls[#calls][2])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
    end)

    it("saves Warcraft gold, the default, as no color, and a priority it cannot read as 10", function()
      click(block.resetColor)
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, block.swatch:GetColor())
      block.priority:SetText("")
      click(block.save)
      assert.is_nil(calls[#calls][2].color)
      assert.are.equal(10, calls[#calls][2].priority)
    end)

    it("shows or hides its section at once", function()
      click(block.shown)
      assert.are.same({ "ToggleCategoryShown", "Potions" }, calls[#calls])
    end)

    it("renames it, keeping it selected, or says why it cannot", function()
      click(block.rename)
      assert.are.equal("Potions", nextDialog.input:GetText())
      nextDialog.input.frame:SetText("Mats")
      answer("Rename")
      assert.are.equal("A category named 'Mats' may already exist.", nextDialog.text:GetText())
      answer("Cancel")
      click(block.rename)
      nextDialog.input.frame:SetText("Elixirs")
      answer("Rename")
      assert.are.equal("Elixirs", block.selected)
      assert.are.equal("Elixirs", block.title:GetText())
    end)

    it("says so when the rename fails for another reason", function()
      override(categories, "RenameCategory", function() return false end)
      click(block.rename)
      nextDialog.input.frame:SetText("Elixirs")
      answer("Rename")
      assert.are.equal("A category named 'Elixirs' may already exist.", nextDialog.text:GetText())
      answer("OK")
      assert.are.equal("Potions", block.selected)
    end)

    it("deletes it after asking", function()
      click(block.delete)
      answer("Cancel")
      assert.is_not_nil(filters.Potions)
      click(block.delete)
      answer("Delete")
      assert.are.same({ "DeleteCategory", "Potions" }, calls[#calls])
      assert.is_nil(block.selected)
      assert.are.equal("empty", block.detail)
    end)
  end)

  describe("an item list category", function()
    before_each(function()
      rowClick("Mats")
    end)

    it("shows its color (gold for none), priority, Show Section and its items", function()
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, block.swatch:GetColor())
      assert.are.equal("5", block.priority:GetText())
      assert.is_true(block.shown:GetChecked())
      assert.is_false(block.query.frame:IsShown())
      local ids = {}
      for _, row in ipairs(block.itemRows) do
        table.insert(ids, row.data.itemInfo.itemID)
      end
      table.sort(ids)
      assert.are.same({ 11, 12 }, ids)
    end)

    it("saves its color and priority, keeping its items and how it is saved", function()
      block.priority:SetText("7")
      click(block.save)
      assert.are.same({ name = "Mats", save = true, itemList = { [11] = true, [12] = true }, priority = 7 },
        calls[#calls][2])
    end)

    it("takes an item dropped on its items, and gives one back on a right click", function()
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 99, true
      block.itemDrop:GetScript("OnReceiveDrag")(block.itemDrop)
      assert.are.same({ "AddPermanentItemToCategory", 99, "Mats" }, calls[#calls])
      assert.is_false(CursorHasItem(), "the item is let go of")
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.equal(3, #block.itemRows)
      local row
      for _, r in ipairs(block.itemRows) do
        if r.data.itemInfo.itemID == 11 then row = r end
      end
      row.rowButton:GetScript("OnMouseDown")(row.rowButton, "RightButton")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.same({ "DeleteItemFromCategory", 11, "Mats" }, calls[#calls])
      assert.are.equal(2, #block.itemRows)
    end)

    it("takes nothing that is not an item", function()
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "money", 5, true
      block.itemDrop:GetScript("OnReceiveDrag")(block.itemDrop)
      assert.are.equal(0, #calls)
    end)
  end)

  describe("the rules kept", function()
    it("cannot rename a dynamic category, but can delete it", function()
      rowClick("Tokens")
      assert.is_false(block.rename.frame:IsEnabled())
      assert.are.equal("Cannot Rename", block.rename.label:GetText())
      assert.is_true(block.delete.frame:IsEnabled())
    end)

    it("saves a category that is not saved (a dynamic one) as it is", function()
      rowClick("Tokens")
      click(block.save)
      assert.is_false(calls[#calls][2].save)
    end)

    it("cannot delete a group by sub-category", function()
      rowClick("Potions - Flask")
      assert.is_false(block.delete.frame:IsEnabled())
      assert.are.equal("Cannot Delete", block.delete.label:GetText())
    end)

    it("says what a built-in or leftover category is, and removes it after asking", function()
      rowClick("Armor")
      assert.are.equal("builtin", block.detail)
      assert.is_true(block.info:IsShown())
      click(block.remove)
      answer("Remove")
      assert.are.same({ "DeleteCategory", "Armor" }, calls[#calls])
    end)

    it("says to pick one while none is chosen", function()
      assert.are.equal("empty", block.detail)
      assert.is_true(block.info:IsShown())
      assert.is_false(block.save.frame:IsShown())
    end)
  end)
end)
