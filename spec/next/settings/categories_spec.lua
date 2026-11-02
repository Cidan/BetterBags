-- categories_spec.lua -- NextSettingsCategories (next/settings/categories.lua): the Categories page
-- (next-settings.md §5, category-lifecycle.md §6), where every category is defined once: one kind of
-- category (a rule, items added by hand, or both). Its list goes in the window's sidebar, the chosen
-- category's name and Rename/Delete in the header, and three tabs show it: Settings, Rule, Added Items.
-- The window (NextSettings) is stood in for: its Reselect is recorded and its content height given.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_KIND.GUILD = const.BAG_KIND.GUILD or 2
const.SEARCH_CATEGORY_GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY or { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local categories = StubBetterBagsModule("Categories")
local items = StubBetterBagsModule("Items")
local search = StubBetterBagsModule("Search")
local settings = StubBetterBagsModule("NextSettings")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDropdown", "next/controls/dropdown.lua" }, { "NextSwatch", "next/controls/swatch.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextItemGrid", "next/controls/itemgrid.lua" },
  { "NextLift", "next/lift.lua" }, { "NextListReorder", "next/settings/reorder.lua" },
  { "NextSettingsItemsTab", "next/settings/itemstab.lua" }, { "NextSettingsCategories", "next/settings/categories.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local editor = addon:GetModule("NextSettingsCategories")
local lift = addon:GetModule("NextLift")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")
local nextDialog = addon:GetModule("NextDialog")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local BACKPACK, BANK, GUILD = 0, 1, 2
local GOLD = { 1, 0.82, 0 }
local CONTENT_HEIGHT = 530

describe("NextSettingsCategories", function()
  local owner, filters, committed, sent, handlers, calls, saved, bags, matches, reselected, itemNames, refreshed

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

  local function updates()
    local list = {}
    for _, call in ipairs(calls) do
      if call[1] == "UpdateCategory" then table.insert(list, call) end
    end
    return list
  end

  -- ids returns the item IDs of a grid's entries, in order.
  local function ids(grid)
    local list = {}
    for _, e in ipairs(grid.entries) do table.insert(list, e.itemID) end
    return list
  end

  local function entryOf(grid, itemID)
    for _, e in ipairs(grid.entries) do
      if e.itemID == itemID then return e end
    end
  end

  local function bagsFn()
    return bags
  end

  local function place(tab)
    tab:Refresh(ctx())
    tab:Place(0, 0, 720, tab:Measure(720))
    return tab
  end

  before_each(function()
    saved, sent, handlers, calls, reselected = {}, {}, {}, {}, 0
    filters = {
      Mats = { name = "Mats", save = true, priority = 5, itemList = { [11] = true, [12] = true },
        enabled = { [BACKPACK] = true, [BANK] = false, [GUILD] = true } },
      Potions = { name = "Potions", save = true, priority = 10, itemList = {}, color = { 0.2, 0.4, 0.6 },
        groupBy = 1, searchCategory = { query = "type = consumable" },
        enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } },
      Midnight = { name = "Midnight", save = true, priority = 2, itemList = { [7] = true },
        searchCategory = { query = "exp = mid" }, enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } },
      Empty = { name = "Empty", save = true, itemList = {}, enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } },
      Openable = { name = "Openable", priority = 1, itemList = { [99] = true }, dynamic = true,
        enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } },
      Ores = { name = "Ores", priority = 3, itemList = {}, searchCategory = { query = "ore" },
        enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } },
      ["Potions - Flask"] = { name = "Potions - Flask", isGroupBySubcategory = true, dynamic = true, itemList = {},
        enabled = { [BACKPACK] = true } },
    }
    local function item(itemID, category, extra)
      local info = { itemID = itemID, category = category, itemIcon = itemID * 10, itemName = "Item " .. itemID,
        itemLink = "|Hitem:" .. itemID .. "|h", itemQuality = 1, currentItemCount = 1 }
      for k, v in pairs(extra or {}) do info[k] = v end
      return { itemInfo = info }
    end
    committed = {
      [BACKPACK] = {
        ["0_1"] = item(50, "Potions - Flask", { itemName = "Flask" }),
        ["0_2"] = item(51, "Potions", { itemName = "Bandage", currentItemCount = 5 }),
        ["0_3"] = item(52, "Recent Items", { itemName = "Crab" }),
        ["0_4"] = item(11, "Junk", { itemName = "Ore" }),
        ["0_5"] = { isItemEmpty = true, itemInfo = {} },
        ["0_6"] = item(51, "Potions", { itemName = "Bandage", currentItemCount = 3 }),
      },
      [BANK] = {
        ["6_1"] = item(53, "Potions", { itemName = "Antidote" }),
        ["6_2"] = item(54, "Elixirs", { itemName = "Elixir" }),
      },
    }
    for key, data in pairs(committed[BACKPACK]) do data.slotkey = key end
    for key, data in pairs(committed[BANK]) do data.slotkey = key end
    -- What the rule "type = consumable" matches: three show in Potions, two elsewhere.
    matches = { ["0_1"] = true, ["0_2"] = true, ["0_3"] = true, ["6_1"] = true, ["6_2"] = true }
    itemNames = { [11] = "Copper Ore", [12] = "Arcane Dust", [99] = "Lockbox" }
    bags = { { name = "Backpack", kind = BACKPACK }, { name = "Bank", kind = BANK }, { name = "Guild Bank", kind = GUILD } }
    override(_G, "UISpecialFrames", {})
    -- core/constants.lua's quality colors.
    override(const, "ITEM_QUALITY_COLOR", { [0] = { 0.62, 0.62, 0.62, 1 }, [1] = { 1, 1, 1, 1 },
      [2] = { 0.12, 1, 0, 1 }, [3] = { 0, 0.44, 0.87, 1 }, [4] = { 0.64, 0.21, 0.93, 1 } })
    controls.escape = {}
    override(events, "SendMessage", function(_, _, message, ...) table.insert(sent, { message, ... }) end)
    override(events, "RegisterMessage", function(_, message, fn)
      handlers[message] = handlers[message] or {}
      table.insert(handlers[message], fn)
    end)
    override(settings, "Reselect", function() reselected = reselected + 1 end)
    refreshed = 0
    override(settings, "Refresh", function() refreshed = refreshed + 1 end)
    override(settings, "ContentHeight", function() return CONTENT_HEIGHT end)
    override(categories, "GetAllCategories", function()
      local all = {}
      for name, f in pairs(filters) do all[name] = f end
      return all
    end)
    override(categories, "GetCategoryByName", function(_, name) return filters[name] end)
    -- As the real one: every category but a group by's sections, by priority, then by name.
    override(categories, "GetOrder", function()
      local list = {}
      for _, f in pairs(filters) do
        if not f.isGroupBySubcategory then table.insert(list, f) end
      end
      table.sort(list, function(a, b)
        if (a.priority or 10) ~= (b.priority or 10) then return (a.priority or 10) < (b.priority or 10) end
        return a.name:lower() < b.name:lower()
      end)
      local names = {}
      for i, f in ipairs(list) do names[i] = f.name end
      return names
    end)
    override(categories, "MoveCategory", function(_, _, name, after)
      table.insert(calls, { "MoveCategory", name, after })
      return true
    end)
    override(categories, "DoesCategoryExist", function(_, name) return filters[name] ~= nil end)
    override(categories, "RuleOf", function(_, f)
      local q = f and f.searchCategory and f.searchCategory.query
      return q ~= nil and strtrim(q) ~= "" and strtrim(q) or nil
    end)
    override(categories, "CreateCategory", function(_, _, filter)
      table.insert(calls, { "CreateCategory", filter })
      filters[filter.name] = filter
    end)
    override(categories, "UpdateCategory", function(_, _, name, fields)
      table.insert(calls, { "UpdateCategory", name, fields })
      local f = filters[name]
      if fields.priority then f.priority = fields.priority end
      if fields.groupBy then f.groupBy = fields.groupBy end
      if fields.color ~= nil then f.color = fields.color or nil end
      if fields.rule ~= nil then f.searchCategory = fields.rule ~= "" and { query = fields.rule } or nil end
      if fields.automation ~= nil then f.automation = fields.automation or nil end
      if fields.confirmSale == false then
        f.confirmSale = false
      elseif fields.confirmSale ~= nil then
        f.confirmSale = nil
      end
      if fields.skipRecent ~= nil then f.skipRecent = fields.skipRecent == true or nil end
      for k, v in pairs(fields.enabled or {}) do f.enabled[k] = v end
      for k, v in pairs(fields.hidden or {}) do
        f.hidden = f.hidden or {}
        f.hidden[k] = v == true or nil
      end
      return true
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
    override(categories, "RemoveItemFromCategory", function(_, id, name)
      table.insert(calls, { "RemoveItemFromCategory", id, name })
      filters[name].itemList[id] = nil
    end)
    override(categories, "WipeCategory", function(_, _, name)
      table.insert(calls, { "WipeCategory", name })
      filters[name].itemList = {}
    end)
    -- Ignored Items, as the real ones: kept on the category.
    override(categories, "IgnoresItem", function(_, name, id)
      local f = filters[name]
      return f ~= nil and f.ignoredItems ~= nil and f.ignoredItems[id] == true
    end)
    override(categories, "GetIgnoredItems", function(_, name)
      local list = {}
      for id in pairs(filters[name] and filters[name].ignoredItems or {}) do list[id] = true end
      return list
    end)
    override(categories, "IgnoreItem", function(_, _, id, name)
      table.insert(calls, { "IgnoreItem", id, name })
      filters[name].ignoredItems = filters[name].ignoredItems or {}
      filters[name].ignoredItems[id] = true
      return true
    end)
    override(categories, "UnignoreItem", function(_, _, id, name)
      table.insert(calls, { "UnignoreItem", id, name })
      filters[name].ignoredItems[id] = nil
      return true
    end)
    override(categories, "ClearIgnoredItems", function(_, _, name)
      table.insert(calls, { "ClearIgnoredItems", name })
      filters[name].ignoredItems = nil
      return true
    end)
    override(categories, "GetMergedCategory", function(_, name)
      local list = {}
      for id in pairs(filters[name] and filters[name].itemList or {}) do list[id] = true end
      return { name = name, itemList = list }
    end)
    override(items, "slotInfo", { [BACKPACK] = { itemsBySlotKey = committed[BACKPACK] },
      [BANK] = { itemsBySlotKey = committed[BANK] } })
    override(search, "Search", function(_, query)
      if query == "broken (" then error("unexpected end") end
      if query == "type = consumable" then return matches end
      if query == "ore" then return { ["0_4"] = true } end
      -- As the bags' search box: nothing typed filters nothing.
      if query == "" then return { ["0_1"] = true, ["0_2"] = true } end
      return {}
    end)
    override(C_Item, "GetItemNameByID", function(id) return itemNames[id] end)
    override(C_Item, "GetItemQualityByID", function(id) return id == 11 and 3 or 1 end)
    override(C_Item, "GetItemInfoInstant", function(id) return id, "", "", "", id * 100 end)
    ColorPickerFrame:Hide()
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    editor:Init()
    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:Show()
  end)

  after_each(function()
    nextMenu:Close()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  describe("its list", function()
    local list

    local function listed()
      local out = {}
      for i, entry in ipairs(list.entries) do
        if entry.header then
          table.insert(out, "# " .. entry.title)
        else
          table.insert(out, entry.name .. " | " .. list.rows[i].detail:GetText())
        end
      end
      return out
    end

    before_each(function()
      list = editor:CreateList(CreateFrame("Frame"), owner, bagsFn)
      list:Place(232, 648)
      list:Refresh(ctx())
    end)

    local function finishTweens()
      for _ = 1, 400 do
        local update = tween.driver and tween.driver:GetScript("OnUpdate")
        if update == nil then return end
        update(tween.driver, 0.05)
      end
    end

    -- yOf returns where a row is in the list once its slide (Motion) has ended.
    local function yOf(name)
      motion:Step(1)
      local _, _, _, _, y = list:RowFor(name).frame:GetPoint(1)
      return -y
    end

    -- Reported: with a long list, pressing on the scroll bar's thumb grabbed the category row under it (the rows reach
    -- under the bar, deeper in the box than the bar was). The bar and its thumb are above every row.
    it("keeps its scroll bar above its rows, so the thumb takes the mouse", function()
      list:Place(232, 120)
      list:RefreshRows()
      list.box._extent = 1000
      list.box:FullUpdate(true)
      assert.is_true(list.bar.frame:IsShown(), "it scrolls")
      for _, row in ipairs(list.rows) do
        assert.is_true(list.bar.thumb:GetFrameLevel() > row.frame:GetFrameLevel(), row.name or "a row")
        for _, child in ipairs({ row.frame:GetChildren() }) do
          assert.is_true(list.bar.thumb:GetFrameLevel() > child:GetFrameLevel(), "in a row")
        end
      end
    end)

    -- Asked: priority is the order of one list, yours and the plugins' together; then: "can you just
    -- have the subtext to categories say 'x items matching' please?"
    it("lists every category in their order, each saying how many of your items it holds", function()
      assert.are.same({
        "Openable | 0 items matching",
        "Midnight | 0 items matching",
        "Ores | 0 items matching",
        "Mats | 0 items matching",
        "Empty | 0 items matching",
        "Potions | 3 items matching",
      }, listed(), "a group by's sub-categories are not listed")
    end)

    -- The count is the Settings tab's Current Items in this Group: each item once (two Bandage stacks
    -- are one), its group by's sections with it (the Flask in "Potions - Flask"), in the bags the
    -- settings show.
    it("counts what its Settings tab shows as Current Items in this Group, one item singular", function()
      local tab = editor:CreateSettingsTab(CreateFrame("Frame"), owner, bagsFn)
      editor.selected = "Potions"
      place(tab)
      assert.are.equal(3, #tab.grid.entries)
      committed[BACKPACK]["0_7"] = { slotkey = "0_7", itemInfo = { itemID = 12, category = "Mats" } }
      committed[BACKPACK]["0_8"] = { slotkey = "0_8", itemInfo = { itemID = 12, category = "Mats - Gems" } }
      list:RefreshRows()
      assert.are.equal("1 item matching", list:RowFor("Mats").detail:GetText())
      bags = { bags[2] }
      list:RefreshRows()
      assert.are.equal("1 item matching", list:RowFor("Potions").detail:GetText(), "the bank's only")
      assert.are.equal("0 items matching", list:RowFor("Mats").detail:GetText())
    end)

    it("counts again when a bag's items are read while it shows", function()
      list.frame:GetParent():Show()
      list.frame:Show()
      committed[BANK]["6_3"] = { slotkey = "6_3", itemInfo = { itemID = 55, category = "Potions" } }
      handlers["items/RefreshBank/Done"][1](ctx())
      assert.are.equal("4 items matching", list:RowFor("Potions").detail:GetText())
      list.frame:Hide()
      committed[BANK]["6_4"] = { slotkey = "6_4", itemInfo = { itemID = 56, category = "Potions" } }
      handlers["items/RefreshBackpack/Done"][1](ctx())
      assert.are.equal("4 items matching", list:RowFor("Potions").detail:GetText(), "not while hidden")
    end)

    -- Asked: "instead of a line on drag, let's animate the move like we do categories" (NextListReorder).
    it("drags a category as the bags drag a section, moving it after the one above where it lands", function()
      local K = style.Theme.Settings.Categories
      list.box:_SetRect(0, 0, 232, 600)
      list.content.GetLeft, list.content.GetTop = function() return 0 end, function() return 600 end
      local row = list:RowFor("Potions")
      row.frame:_SetRect(0, 600 - yOf("Potions") - K.RowHeight, 232, K.RowHeight)
      -- A quarter of the way down the second row: in its top half, so after the first.
      _G._cursorX, _G._cursorY = 20, 600 - (K.RowHeight + 0.25 * K.RowHeight)
      _G._mouseButtonsDown = { LeftButton = true }
      row.frame:GetScript("OnDragStart")(row.frame)
      assert.are.equal(lift.layer, row.frame:GetParent(), "lifted")
      list.drag:Update(0.016)
      assert.are.equal(2 * K.RowHeight, yOf("Midnight"), "Midnight makes room under Openable")
      _G._mouseButtonsDown = {}
      list.drag:Update(0.016)
      finishTweens()
      _G._cursorX, _G._cursorY = 0, 0
      assert.are.same({ "MoveCategory", "Potions", "Openable" }, calls[#calls])
      assert.are.equal(list.content, row.frame:GetParent())
      assert.are.equal(K.RowHeight, yOf("Potions"), "in its new place")
      list:Drop("Potions", 0)
      list:Drop("Openable", 2)
      local moves = {}
      for _, call in ipairs(calls) do
        if call[1] == "MoveCategory" then table.insert(moves, call) end
      end
      -- The stand-in MoveCategory draws nothing again, so the list shows the order the drag left:
      -- Openable, Potions, Midnight...
      assert.are.same({ { "MoveCategory", "Potions", "Openable" }, { "MoveCategory", "Potions", nil },
        { "MoveCategory", "Openable", "Potions" } }, moves)
    end)

    -- Rows belong to their categories, so one moved in the order slides to its new place (Motion).
    it("keeps each category's row its own, as wide as the list, hiding a row it no longer lists", function()
      local K = style.Theme.Settings.Categories
      local potions, mats = list:RowFor("Potions"), list:RowFor("Mats")
      filters.Potions.priority = 0
      list:RefreshRows()
      assert.are.equal(potions, list:RowFor("Potions"))
      assert.are.equal(mats, list:RowFor("Mats"))
      assert.are.equal("Potions", potions.label:GetText())
      assert.are.equal(0, yOf("Potions"))
      assert.are.equal(232, mats.frame:GetWidth())
      list.filter.frame:SetText("pot")
      list.filter.frame:GetScript("OnTextChanged")(list.filter.frame, true)
      assert.is_nil(list:RowFor("Mats"))
      assert.is_false(mats.frame:IsShown())
      local free = #list.free
      list.filter.frame:SetText("")
      list.filter.frame:GetScript("OnTextChanged")(list.filter.frame, true)
      assert.are.equal(0, #list.free, "the rows put away are used again: " .. free)
      local _ = K
    end)

    -- A filter shows some of the order: a category dropped among them lands next to them in the whole
    -- order, the others keeping theirs.
    it("drops among the categories a filter shows next to them in the whole order", function()
      list.filter.frame:SetText("s")
      list.filter.frame:GetScript("OnTextChanged")(list.filter.frame, true)
      assert.are.same({ "Ores | 0 items matching", "Mats | 0 items matching", "Potions | 3 items matching" },
        listed())
      list:Drop("Potions", 0)
      list:Drop("Ores", 2)
      assert.are.same({ "MoveCategory", "Potions", "Midnight" }, calls[#calls - 1], "before Ores: after Midnight")
      assert.are.same({ "MoveCategory", "Ores", "Mats" }, calls[#calls])
    end)

    it("puts its filter where the window's search box is, and New Category at the bottom", function()
      local T = style.Theme.Settings
      assert.are.same({ "TOPLEFT", list.frame, "TOPLEFT", T.Sidebar.Pad, -T.Search.Gap }, { list.filter.frame:GetPoint(1) })
      assert.are.same({ "BOTTOMLEFT", list.frame, "BOTTOMLEFT", T.Sidebar.Pad, T.Version.Bottom },
        { list.newCategory.frame:GetPoint(1) })
      assert.are.equal(232 - 2 * T.Sidebar.Pad, list.newCategory.frame:GetWidth())
    end)

    it("keeps only the categories whose name has what is typed in its filter", function()
      list.filter.frame:SetText("MID")
      list.filter.frame:GetScript("OnTextChanged")(list.filter.frame, true)
      assert.are.same({ "Midnight | 0 items matching" }, listed())
    end)

    it("chooses the first category when none is, and the one clicked, marking it", function()
      assert.are.equal("Openable", editor.selected)
      local row = list:RowFor("Mats")
      row.frame:GetScript("OnClick")(row.frame, "LeftButton")
      assert.are.equal("Mats", editor.selected)
      assert.are.equal(1, reselected, "the page shows it")
      list:RefreshRows()
      assert.is_true(list:RowFor("Mats").indicator:IsShown())
      assert.is_false(list:RowFor("Openable").indicator:IsShown())
    end)

    -- The Plain theme (docs/next-plain-theme.md): Blizzard's lists mark the chosen row with its fill, no bar.
    it("marks the chosen category with no bar for a theme without one", function()
      UseNextTheme({ Settings = { Categories = { Indicator = false } } })
      list:RefreshRows()
      for _, row in ipairs(list.rows) do
        assert.is_false(row.indicator:IsShown())
      end
      UseNextTheme(nil)
      list:RefreshRows()
      assert.is_true(list:RowFor(editor.selected).indicator:IsShown())
    end)

    it("keeps a category chosen from elsewhere (a bag's tab opening it here)", function()
      editor:Show("Midnight")
      list:Refresh(ctx())
      assert.are.equal("Midnight", editor.selected)
    end)

    it("makes a new category, saved and used in every bag, chosen, asking again for a name taken or none", function()
      click(list.newCategory)
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
      assert.are.equal("Trash", editor.selected)
      assert.is_true(reselected > 0)
    end)

    -- The search box's Enter to Make Category (frames/search.lua, through Config).
    it("asks for a new category's name, its rule a search waiting for it, once", function()
      editor:NewFromSearch("rarity = epic")
      list:Refresh(ctx())
      nextDialog.input.frame:SetText("Epics")
      answer("Create")
      assert.are.same({ name = "Epics", itemList = {}, save = true, searchCategory = { query = "rarity = epic" } },
        calls[#calls][2])
      assert.are.equal("Epics", editor.selected)
      list:Refresh(ctx())
      assert.is_false(nextDialog:IsShown())
    end)

    it("shows the page again when a category changes while it shows, another one chosen for one gone", function()
      list.frame:GetParent():Show()
      list.frame:Show()
      editor.selected = "Mats"
      filters.Mats = nil
      handlers["categories/Changed"][1](ctx())
      assert.are.equal("Openable", editor.selected)
      assert.are.equal(1, reselected)
    end)
  end)

  describe("its heading and buttons", function()
    it("names the chosen category and says what is in it, or asks for one", function()
      assert.are.same({ "Categories", "Make a category to sort your items your way." }, { editor:Heading() })
      editor.selected = "Midnight"
      assert.are.same({ "Midnight", "Search Rule and 1 added item" }, { editor:Heading() })
      editor.selected = "Openable"
      assert.are.same({ "Openable", "Made by a plugin · 1 added item" }, { editor:Heading() })
    end)

    it("says what a category does on its own", function()
      filters.Mats.automation = "sell"
      editor.selected = "Mats"
      assert.are.same({ "Mats", "2 added items · Sells at merchants" }, { editor:Heading() })
      filters.Mats.automation = "destroy"
      assert.are.same({ "Mats", "2 added items · Sells, destroys the rest" }, { editor:Heading() })
    end)

    it("says which tabs show: Rule for yours and a plugin's with a rule; Added Items while one is chosen", function()
      assert.is_false(editor:RuleTabShown())
      assert.is_false(editor:ItemsTabShown())
      assert.is_false(editor:AutomationTabShown())
      editor.selected = "Openable"
      assert.is_true(editor:AutomationTabShown(), "a plugin's category too: what it does is yours to choose")
      editor.selected = nil
      editor.selected = "Mats"
      assert.is_true(editor:RuleTabShown())
      assert.is_true(editor:ItemsTabShown())
      editor.selected = "Openable"
      assert.is_false(editor:RuleTabShown())
      editor.selected = "Ores"
      assert.is_true(editor:RuleTabShown())
    end)

    it("has Rename and Delete for your categories only", function()
      local actions = editor:CreateActions(CreateFrame("Frame"), owner)
      editor.selected = "Mats"
      actions:Refresh(ctx())
      assert.is_true(actions.rename.frame:IsShown() and actions.delete.frame:IsShown())
      assert.is_true(actions.frame:GetWidth() > 1)
      editor.selected = "Openable"
      actions:Refresh(ctx())
      assert.is_false(actions.rename.frame:IsShown() or actions.delete.frame:IsShown())
      assert.are.equal(1, actions.frame:GetWidth(), "the title takes the room")
    end)

    it("renames, keeping it chosen, or says why it cannot", function()
      local actions = editor:CreateActions(CreateFrame("Frame"), owner)
      editor.selected = "Mats"
      actions:Refresh(ctx())
      click(actions.rename)
      assert.are.equal("Mats", nextDialog.input:GetText())
      nextDialog.input.frame:SetText("Potions")
      answer("Rename")
      assert.are.equal("A category named 'Potions' already exists.", nextDialog.text:GetText())
      nextDialog.input.frame:SetText("Metals")
      answer("Rename")
      assert.are.same({ "RenameCategory", "Mats", "Metals" }, calls[#calls])
      assert.are.equal("Metals", editor.selected)
      assert.are.equal(1, reselected)
    end)

    it("deletes after asking, choosing the first category left", function()
      local actions = editor:CreateActions(CreateFrame("Frame"), owner)
      editor.selected = "Mats"
      click(actions.delete)
      answer("Cancel")
      assert.is_not_nil(filters.Mats)
      click(actions.delete)
      answer("Delete")
      assert.are.same({ "DeleteCategory", "Mats" }, calls[#calls])
      assert.are.equal("Openable", editor.selected, "the first in the order")
      assert.are.equal(1, reselected)
    end)
  end)

  describe("the Settings tab", function()
    local tab

    before_each(function()
      tab = editor:CreateSettingsTab(CreateFrame("Frame"), owner, bagsFn)
    end)

    it("fills the page's content without scrolling, as a wide row", function()
      local C = style.Theme.Settings.Content
      assert.is_true(tab.wide)
      assert.are.equal(CONTENT_HEIGHT - C.Top - C.Bottom, tab:Measure(700))
    end)

    it("says to make a category while there is none", function()
      place(tab)
      assert.is_true(tab.none:IsShown())
      assert.is_false(tab.toggles[BACKPACK].frame:IsShown())
      assert.is_false(tab.groupBy.frame:IsShown())
      assert.is_false(tab.grid.frame:IsShown())
    end)

    -- Asked: no priority as a number; the order of the list is it.
    it("shows the bags it is used in (the guild bank like any), group by and color, and no priority", function()
      editor.selected = "Potions"
      place(tab)
      assert.is_false(tab.none:IsShown())
      assert.is_nil(tab.priority)
      assert.is_nil(tab.labels.priority)
      assert.are.equal("Type", tab.groupBy.text:GetText())
      assert.are.same({ 0.2, 0.4, 0.6, 1 }, tab.swatch:GetColor())
      editor.selected = "Mats"
      tab:Refresh(ctx())
      assert.is_true(tab.toggles[BACKPACK]:GetChecked())
      assert.is_false(tab.toggles[BANK]:GetChecked())
      assert.is_true(tab.toggles[GUILD]:GetChecked())
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, tab.swatch:GetColor())
      bags = { bags[1], bags[2] }
      tab:Refresh(ctx())
      assert.is_false(tab.toggles[GUILD].frame:IsShown(), "only the bags the settings show")
    end)

    it("puts its four rows of settings, then the box of what shows in it under them", function()
      editor.selected = "Mats"
      place(tab)
      local K = style.Theme.Settings.Categories
      local B = controls:Theme("Button")
      -- Each by its top left, centered on its row by whole pixels (docs/next-pixel-perfect.md).
      local function topOf(i) return K.Pad + (i - 1) * (B.Height + K.FieldGap) end
      local point, _, _, _, colorY = tab.swatch.frame:GetPoint(1)
      assert.are.equal("TOPLEFT", point)
      assert.are.equal(-(topOf(4) + math.floor((B.Height - tab.swatch.frame:GetHeight()) / 2)), colorY,
        "color is the fourth row")
      local _, _, _, _, hideY = tab.hideToggles[BACKPACK].frame:GetPoint(1)
      assert.are.equal(-(topOf(2) + math.floor((B.Height - tab.hideToggles[BACKPACK].frame:GetHeight()) / 2)), hideY,
        "hiding is the row under the bags it is used in")
      local box = K.Pad + 4 * (B.Height + K.FieldGap) + K.FieldGap + B.Height + K.FieldGap
      local _, _, _, _, gridY = tab.grid.frame:GetPoint(1)
      assert.are.equal(-box, gridY)
    end)

    -- Asked (issue #1222): a switch per bag beside Used In, asking first, since the old hide confused players.
    describe("hiding it in a bag", function()
      before_each(function()
        editor.selected = "Mats"
        place(tab)
      end)

      it("has a switch per bag the settings show, showing what is saved", function()
        filters.Mats.hidden = { [BANK] = true }
        tab:Refresh(ctx())
        assert.are.equal("Hide In", tab.labels.hide:GetText())
        assert.is_false(tab.hideToggles[BACKPACK]:GetChecked())
        assert.is_true(tab.hideToggles[BANK]:GetChecked())
        bags = { bags[1], bags[2] }
        tab:Refresh(ctx())
        assert.is_false(tab.hideToggles[GUILD].frame:IsShown(), "only the bags the settings show")
      end)

      it("asks before hiding, naming the category and the bag, and hides on Hide", function()
        click(tab.hideToggles[BACKPACK])
        assert.are.same({}, updates(), "nothing yet")
        assert.is_true(nextDialog:IsShown())
        assert.are.equal("Hide Mats?", nextDialog.title:GetText())
        assert.is_truthy(nextDialog.text:GetText():find("Backpack", 1, true))
        answer("Hide")
        local list = updates()
        assert.are.equal(1, #list)
        assert.are.same({ hidden = { [BACKPACK] = true } }, list[1][3])
      end)

      it("puts the switch back and hides nothing on Cancel", function()
        click(tab.hideToggles[BACKPACK])
        answer("Cancel")
        assert.are.same({}, updates())
        assert.is_false(tab.hideToggles[BACKPACK]:GetChecked())
      end)

      it("puts the switch back when the question is closed another way", function()
        click(tab.hideToggles[BACKPACK])
        nextDialog:Hide()
        assert.are.same({}, updates())
        assert.is_false(tab.hideToggles[BACKPACK]:GetChecked())
      end)

      it("shows a hidden category again without asking", function()
        filters.Mats.hidden = { [BACKPACK] = true }
        tab:Refresh(ctx())
        click(tab.hideToggles[BACKPACK])
        assert.is_false(nextDialog:IsShown())
        assert.are.same({ hidden = { [BACKPACK] = false } }, updates()[1][3])
      end)

      it("cannot hide it in a bag it is not used in", function()
        assert.is_false(tab.toggles[BANK]:GetChecked())
        assert.is_false(tab.hideToggles[BANK].frame:IsEnabled())
        assert.is_true(tab.hideToggles[BACKPACK].frame:IsEnabled())
      end)

      it("hides a plugin's category too", function()
        editor.selected = "Openable"
        tab:Refresh(ctx())
        assert.is_true(tab.hideToggles[BACKPACK].frame:IsShown())
      end)

      it("hides its row while no category is chosen", function()
        editor.selected = nil
        tab:Refresh(ctx())
        assert.is_false(tab.hideToggles[BACKPACK].frame:IsShown())
        assert.is_false(tab.labels.hide:IsShown())
      end)
    end)

    it("saves each setting at once: bags, group by, color and its reset", function()
      editor.selected = "Mats"
      place(tab)
      click(tab.toggles[BANK])
      click(tab.groupBy)
      nextMenu:Rows()[3].frame:GetScript("OnClick")(nextMenu:Rows()[3].frame, "LeftButton")
      tab.swatch:SetColor({ 0.5, 0.5, 0.5, 1 })
      tab.swatch.opts.onChange(ctx(), { 0.5, 0.5, 0.5, 1 })
      click(tab.resetColor)
      assert.are.same({
        { "UpdateCategory", "Mats", { enabled = { [BANK] = true } } },
        { "UpdateCategory", "Mats", { groupBy = 2 } },
        { "UpdateCategory", "Mats", { color = { 0.5, 0.5, 0.5 } } },
        { "UpdateCategory", "Mats", { color = false } },
      }, updates())
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, tab.swatch:GetColor())
    end)

    it("has no group by for a plugin's category", function()
      editor.selected = "Openable"
      place(tab)
      assert.is_false(tab.groupBy.frame:IsShown())
      assert.is_true(tab.swatch.frame:IsShown())
    end)

    it("shows what of your bags shows in it now (its group by's sections too), an item a cell", function()
      editor.selected = "Potions"
      place(tab)
      assert.are.equal("Current Items in this Group", tab.labels.inBags:GetText())
      assert.are.equal("There are no current items in your inventory that match this category",
        tab.grid.empty:GetText())
      assert.are.equal("Backpack: 2 items · Bank: 1 item", tab.inBags:GetText())
      assert.are.same({ 53, 51, 50 }, ids(tab.grid), "by name: Antidote, Bandage, Flask")
      assert.are.equal(8, entryOf(tab.grid, 51).count, "both of its stacks")
      editor.selected = "Mats"
      tab:Refresh(ctx())
      assert.are.equal("", tab.inBags:GetText())
      assert.are.same({}, ids(tab.grid))
    end)

    it("shows what the bags hold again when they are read", function()
      editor.selected = "Potions"
      place(tab)
      tab.frame:GetParent():Show()
      tab.frame:Show()
      committed[BANK]["6_3"] = { slotkey = "6_3", itemInfo = { itemID = 60, category = "Potions", itemIcon = 600,
        itemName = "Zest", currentItemCount = 1 } }
      for _, fn in ipairs(handlers["items/RefreshBank/Done"]) do fn(ctx()) end
      assert.are.equal("Backpack: 2 items · Bank: 2 items", tab.inBags:GetText())
    end)
  end)

  describe("the Rule tab", function()
    local tab

    local function typed(text)
      tab.rule.editBox:SetText(text)
      tab.rule.editBox:GetScript("OnTextChanged")(tab.rule.editBox, true)
    end

    before_each(function()
      tab = editor:CreateRuleTab(CreateFrame("Frame"), owner, bagsFn)
      editor.selected = "Potions"
      place(tab)
    end)

    it("is the Search Rule, its matches the Search Results, counted beside their name as it is typed", function()
      assert.are.equal("Search Rule", tab.labels.rule:GetText())
      assert.are.equal("Apply Search Rule", tab.apply.label:GetText())
      assert.are.equal("type = consumable", tab.rule:GetText())
      assert.are.equal("Search Results (5 results)", tab.results:GetText())
      typed("ore")
      assert.are.equal("Search Results (1 result)", tab.results:GetText())
      typed("broken (")
      assert.are.equal("Search Results (invalid search)", tab.results:GetText())
      assert.are.same({}, ids(tab.grid))
      typed("")
      assert.are.equal("Search Results (0 results)", tab.results:GetText(), "no search rule matches nothing")
      assert.are.same({}, ids(tab.grid))
    end)

    -- Asked: the two item boxes slightly apart made switching between the tabs messy.
    it("keeps its results box exactly where the Settings tab keeps its own, and its name level with that one's", function()
      local settingsTab = place(editor:CreateSettingsTab(CreateFrame("Frame"), owner, bagsFn))
      -- Where a region sits in its tab: its point, the tab's point, and the offsets.
      local function at(region)
        local point, _, relativePoint, x, y = region:GetPoint(1)
        return { point, relativePoint, x, y }
      end
      assert.are.same(at(settingsTab.grid.frame), at(tab.grid.frame))
      assert.are.same({ settingsTab.grid.frame:GetSize() }, { tab.grid.frame:GetSize() })
      assert.are.same(at(settingsTab.labels.inBags), at(tab.results))
      local B = controls:Theme("Button")
      local _, _, _, _, colorMiddle = settingsTab.labels.color:GetPoint(1)
      local _, _, _, _, nameMiddle = settingsTab.labels.inBags:GetPoint(1)
      assert.is_true(-nameMiddle - B.Height / 2 >= -colorMiddle + B.Height / 2, "the box's name under the Color row")
      editor.selected = "Openable"
      settingsTab:Refresh(ctx())
      assert.are.same(at(tab.grid.frame), at(settingsTab.grid.frame), "without group by too")
    end)

    -- Asked: the results in full color; their tooltip still says where one shows.
    it("shows the items it matches in full color, those in it first, saying where the others show", function()
      assert.are.same({ 53, 51, 50, 52, 54 }, ids(tab.grid), "Antidote, Bandage, Flask; then Crab, Elixir")
      assert.is_nil(entryOf(tab.grid, 50).note, "a group by's section is the category's")
      local crab = entryOf(tab.grid, 52)
      assert.is_falsy(crab.dim)
      assert.are.equal("Shows in Recent Items.", crab.note)
    end)

    it("saves it with Apply Rule, on only when it changed and has no mistake", function()
      assert.is_false(tab.apply.frame:IsEnabled())
      typed("broken (")
      assert.is_false(tab.apply.frame:IsEnabled())
      click(tab.apply)
      assert.are.equal(0, #updates())
      typed("type = trade goods")
      assert.is_true(tab.apply.frame:IsEnabled())
      click(tab.apply)
      assert.are.same({ "UpdateCategory", "Potions", { rule = "type = trade goods" } }, updates()[1])
      assert.is_false(tab.apply.frame:IsEnabled())
      typed("  ")
      click(tab.apply)
      assert.are.same({ "UpdateCategory", "Potions", { rule = "" } }, updates()[2])
    end)

    it("keeps what is typed while the same category shows, and shows another's rule", function()
      typed("ore")
      tab:Refresh(ctx())
      assert.are.equal("ore", tab.rule:GetText())
      editor.selected = "Midnight"
      tab:Refresh(ctx())
      assert.are.equal("exp = mid", tab.rule:GetText())
    end)

    it("shows a plugin's rule read-only", function()
      editor.selected = "Ores"
      tab:Refresh(ctx())
      assert.are.equal("ore", tab.rule:GetText())
      assert.is_false(tab.rule.editBox:IsEnabled())
      assert.is_false(tab.apply.frame:IsShown())
      assert.are.same({ 11 }, ids(tab.grid))
      editor.selected = "Potions"
      tab:Refresh(ctx())
      assert.is_true(tab.rule.editBox:IsEnabled())
      assert.is_true(tab.apply.frame:IsShown())
    end)
  end)

  -- What a category does with its items on its own (automation.md §5): Auto Sell, and Destroy What Can't
  -- Be Sold, which needs Auto Sell on ("sell"; "destroy" is both). Asked: drawn as every other page's
  -- settings, rows of a section (the window's rows, next/settings/rows.lua), not controls of its own.
  describe("the Automation tab's settings", function()
    local sellOption, confirmOption, destroyOption

    before_each(function()
      sellOption, confirmOption, destroyOption = unpack(editor:AutomationOptions())
    end)

    it("are three switches, named and described", function()
      assert.are.same({ "toggle", "toggle", "toggle" }, { sellOption.kind, confirmOption.kind, destroyOption.kind })
      assert.are.equal("Auto Sell", sellOption.title)
      assert.are.equal("Confirm Auto Sell", confirmOption.title)
      assert.are.equal("Destroy What Can't Be Sold", destroyOption.title)
      for _, option in ipairs({ sellOption, confirmOption, destroyOption }) do
        assert.truthy(option.description:find("merchant", 1, true) or option.description:find("vendor", 1, true))
        assert.truthy(#option.keywords > 0)
      end
    end)

    it("show what the chosen category does, the other two only with Auto Sell", function()
      editor.selected = "Mats"
      assert.is_false(sellOption.get())
      assert.is_true(confirmOption.get(), "on by default")
      assert.is_false(destroyOption.get())
      assert.is_true(confirmOption.disabled())
      assert.is_true(destroyOption.disabled())
      filters.Mats.automation = "sell"
      assert.is_true(sellOption.get())
      assert.is_false(destroyOption.get())
      assert.is_false(confirmOption.disabled())
      assert.is_false(destroyOption.disabled())
      filters.Mats.automation = "destroy"
      filters.Mats.confirmSale = false
      assert.is_true(sellOption.get())
      assert.is_false(confirmOption.get())
      assert.is_true(destroyOption.get())
    end)

    it("save at once, Auto Sell turned off taking Destroy with it, and show the page's rows again", function()
      editor.selected = "Mats"
      sellOption.set(ctx(), true)
      destroyOption.set(ctx(), true)
      destroyOption.set(ctx(), false)
      destroyOption.set(ctx(), true)
      sellOption.set(ctx(), false)
      confirmOption.set(ctx(), false)
      confirmOption.set(ctx(), true)
      assert.are.same({
        { "UpdateCategory", "Mats", { automation = "sell" } },
        { "UpdateCategory", "Mats", { automation = "destroy" } },
        { "UpdateCategory", "Mats", { automation = "sell" } },
        { "UpdateCategory", "Mats", { automation = "destroy" } },
        { "UpdateCategory", "Mats", { automation = false } },
        { "UpdateCategory", "Mats", { confirmSale = false } },
        { "UpdateCategory", "Mats", { confirmSale = true } },
      }, updates())
      assert.are.equal(7, refreshed, "the other switches' state follows")
      assert.is_true(destroyOption.disabled())
    end)

    it("work for a plugin's category too", function()
      editor.selected = "Openable"
      sellOption.set(ctx(), true)
      assert.are.same({ { "UpdateCategory", "Openable", { automation = "sell" } } }, updates())
    end)

    it("change nothing with no category chosen", function()
      editor.selected = nil
      assert.is_false(sellOption.get())
      sellOption.set(ctx(), true)
      confirmOption.set(ctx(), false)
      assert.are.same({}, updates())
    end)
  end)

  -- Asked: "'Skip Recent Items' ... 100% independent of autosell, etc. can apply to any category".
  describe("the Skip Recent Items setting", function()
    local option

    before_each(function()
      option = editor:RecentOptions()[1]
    end)

    it("is a switch, named and described, on with the category's setting", function()
      assert.are.equal("toggle", option.kind)
      assert.are.equal("Skip Recent Items", option.title)
      assert.truthy(option.description:find("Recent Items", 1, true))
      assert.truthy(#option.keywords > 0)
      editor.selected = "Mats"
      assert.is_false(option.get())
      filters.Mats.skipRecent = true
      assert.is_true(option.get())
      assert.is_nil(option.disabled, "never needs Auto Sell")
    end)

    it("saves at once and shows the page's rows again, for a plugin's category too", function()
      editor.selected = "Mats"
      option.set(ctx(), true)
      editor.selected = "Openable"
      option.set(ctx(), true)
      option.set(ctx(), false)
      assert.are.same({
        { "UpdateCategory", "Mats", { skipRecent = true } },
        { "UpdateCategory", "Openable", { skipRecent = true } },
        { "UpdateCategory", "Openable", { skipRecent = false } },
      }, updates())
      assert.are.equal(3, refreshed)
    end)

    it("changes nothing with no category chosen", function()
      editor.selected = nil
      assert.is_false(option.get())
      option.set(ctx(), true)
      assert.are.same({}, updates())
    end)
  end)

  describe("the Added Items tab", function()
    local tab

    before_each(function()
      tab = editor:CreateItemsTab(CreateFrame("Frame"), owner, bagsFn)
      editor.selected = "Mats"
      place(tab)
    end)

    it("shows the items added, by name, with their icons and qualities, and how many there are", function()
      assert.are.equal("2 added items", tab.count:GetText())
      assert.are.same({ 12, 11 }, ids(tab.grid), "Arcane Dust, Copper Ore")
      local ore = entryOf(tab.grid, 11)
      assert.are.equal(1100, ore.icon)
      assert.are.equal(3, ore.quality)
      assert.is_true(tab.grid.frame:IsShown())
      assert.is_false(tab.readOnly.frame:IsShown())
    end)

    it("fades an added item in your bags that shows in another category, saying where", function()
      local ore = entryOf(tab.grid, 11)
      assert.is_true(ore.dim)
      assert.are.equal("Shows in Junk instead.", ore.note)
      assert.is_falsy(entryOf(tab.grid, 12).dim)
    end)

    it("is shown again when a bag is read while it shows, not while it is hidden", function()
      tab.frame:GetParent():Show()
      tab.frame:Show()
      committed[BACKPACK]["0_4"].itemInfo.category = "Mats"
      for _, fn in ipairs(handlers["items/RefreshBackpack/Done"]) do fn(ctx()) end
      assert.is_falsy(entryOf(tab.grid, 11).dim, "it shows in Mats now")
      tab.frame:Hide()
      committed[BACKPACK]["0_4"].itemInfo.category = "Junk"
      for _, fn in ipairs(handlers["items/RefreshBackpack/Done"]) do fn(ctx()) end
      assert.is_falsy(entryOf(tab.grid, 11).dim, "hidden: read again when shown")
    end)

    it("keeps only the items whose name has what is typed in its filter", function()
      tab.filter.frame:SetText("ore")
      tab.filter.frame:GetScript("OnTextChanged")(tab.filter.frame, true)
      assert.are.same({ 11 }, ids(tab.grid))
      assert.are.equal("1 of 2 added items", tab.count:GetText())
    end)

    it("asks for the names it does not know yet, once, and shows the items again when they arrive", function()
      local loads, finish = 0, nil
      override(ContinuableContainer, "Create", function()
        loads = loads + 1
        local c = { added = {} }
        function c:AddContinuable(i) table.insert(self.added, i) end
        function c:ContinueOnLoad(fn) finish = fn end
        return c
      end)
      itemNames[11] = nil
      tab.frame:GetParent():Show()
      tab.frame:Show()
      tab:ShowItems()
      tab:ShowItems()
      assert.are.equal(1, loads)
      assert.are.same({ 12, 11 }, ids(tab.grid), "a name not known yet last")
      itemNames[11] = "Aardvark Ore"
      finish()
      assert.are.same({ 11, 12 }, ids(tab.grid))
    end)

    it("adds an item dropped anywhere on its items, and nothing that is not an item", function()
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "money", 5, true
      tab.grid.frame:GetScript("OnReceiveDrag")(tab.grid.frame)
      assert.are.equal(0, #calls)
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 13, true
      itemNames[13] = "Bolt"
      local cell = tab.grid.cells[1]
      cell.frame:GetScript("OnReceiveDrag")(cell.frame)
      assert.are.same({ "AddPermanentItemToCategory", 13, "Mats" }, calls[#calls])
      assert.is_false(CursorHasItem())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({ 12, 13, 11 }, ids(tab.grid))
    end)

    it("removes an item from a right click on it", function()
      local cell = tab.grid.cells[2]
      assert.are.equal(11, cell.entry.itemID)
      cell.frame:GetScript("OnClick")(cell.frame, "RightButton")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.same({ "RemoveItemFromCategory", 11, "Mats" }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({ 12 }, ids(tab.grid))
    end)

    it("removes every item after asking, with Remove All, off while there is none", function()
      click(tab.removeAll)
      assert.are.equal("Remove all 2 added items from 'Mats'? This cannot be undone.", nextDialog.text:GetText())
      answer("Cancel")
      assert.are.equal(0, #calls)
      click(tab.removeAll)
      answer("Remove All")
      assert.are.same({ "WipeCategory", "Mats" }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({}, ids(tab.grid))
      assert.is_false(tab.removeAll.frame:IsEnabled())
    end)

    it("shows a plugin's items read-only: no drop, no removing", function()
      editor.selected = "Openable"
      tab:Refresh(ctx())
      assert.is_false(tab.grid.frame:IsShown())
      assert.is_true(tab.readOnly.frame:IsShown())
      assert.are.same({ 99 }, ids(tab.readOnly))
      assert.is_false(tab.removeAll.frame:IsShown())
      assert.is_nil(tab.readOnly.frame:GetScript("OnReceiveDrag"))
      assert.are.equal("The plugin that made this category adds these items.", tab.help:GetText())
    end)

    it("says, simply, how to add an item", function()
      assert.are.equal("Drag an item here to manually add it to this category.", tab.help:GetText())
      assert.are.equal("No items added yet.", tab.grid.empty:GetText())
    end)

    -- An item added and ignored lands elsewhere: ignoring wins (asked: "no matter if it's added in Added
    -- Items").
    it("fades an added item the category ignores, saying so", function()
      filters.Mats.ignoredItems = { [12] = true }
      tab:Refresh(ctx())
      local dust = entryOf(tab.grid, 12)
      assert.is_true(dust.dim)
      assert.are.equal("Ignored in this category.", dust.note)
    end)
  end)

  -- Asked: "a new tab next to 'Added Items' called 'Ignored Items', same interface/layout as Added Items,
  -- but items in this are *ignored* from the category" (docs/next-batch-2.md §2).
  describe("the Ignored Items tab", function()
    local tab

    before_each(function()
      filters.Mats.ignoredItems = { [11] = true }
      tab = editor:CreateItemsTab(CreateFrame("Frame"), owner, bagsFn, "ignored")
      editor.selected = "Mats"
      place(tab)
    end)

    it("shows the items ignored, how many, and where one in your bags shows", function()
      assert.are.equal("1 ignored item", tab.count:GetText())
      assert.are.same({ 11 }, ids(tab.grid))
      local ore = entryOf(tab.grid, 11)
      assert.are.equal(1100, ore.icon)
      assert.is_falsy(ore.dim)
      assert.are.equal("Shows in Junk.", ore.note)
    end)

    it("says how to ignore an item", function()
      assert.are.equal("Drag an item here so it never shows in this category.", tab.help:GetText())
      assert.are.equal("No items ignored.", tab.grid.empty:GetText())
    end)

    it("keeps only the items whose name has what is typed in its filter", function()
      filters.Mats.ignoredItems[12] = true
      tab:ShowItems()
      tab.filter.frame:SetText("dust")
      tab.filter.frame:GetScript("OnTextChanged")(tab.filter.frame, true)
      assert.are.same({ 12 }, ids(tab.grid))
      assert.are.equal("1 of 2 ignored items", tab.count:GetText())
    end)

    it("ignores an item dropped on it, for a plugin's category too", function()
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 13, true
      itemNames[13] = "Bolt"
      tab.grid.frame:GetScript("OnReceiveDrag")(tab.grid.frame)
      assert.are.same({ "IgnoreItem", 13, "Mats" }, calls[#calls])
      assert.is_false(CursorHasItem())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({ 13, 11 }, ids(tab.grid))
      editor.selected = "Openable"
      tab:Refresh(ctx())
      assert.is_true(tab.grid.frame:IsShown(), "editable")
      assert.is_false(tab.readOnly.frame:IsShown())
      assert.is_true(tab.removeAll.frame:IsShown())
      assert.are.equal("Drag an item here so it never shows in this category.", tab.help:GetText())
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 14, true
      itemNames[14] = "Gear"
      tab.grid.frame:GetScript("OnReceiveDrag")(tab.grid.frame)
      assert.are.same({ "IgnoreItem", 14, "Openable" }, calls[#calls])
    end)

    it("stops ignoring an item from a right click on it", function()
      local cell = tab.grid.cells[1]
      cell.frame:GetScript("OnClick")(cell.frame, "RightButton")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.same({ "UnignoreItem", 11, "Mats" }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({}, ids(tab.grid))
    end)

    it("stops ignoring every item after asking, with Remove All", function()
      click(tab.removeAll)
      assert.are.equal("Remove all 1 ignored item from 'Mats'? This cannot be undone.", nextDialog.text:GetText())
      answer("Remove All")
      assert.are.same({ "ClearIgnoredItems", "Mats" }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.same({}, ids(tab.grid))
      assert.is_false(tab.removeAll.frame:IsEnabled())
    end)
  end)
end)
