-- bagcategories_spec.lua -- NextSettingsBagCategories (next/settings/bagcategories.lua): a bag's categories
-- on its Categories tab (next-settings.md §5, category-lifecycle.md §6). Categories are defined once on
-- the Categories page; a bag arranges them: which it uses, their order (pinned first, then the rest),
-- and leftovers it can remove. A category's name opens it on the Categories page.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_KIND.GUILD = const.BAG_KIND.GUILD or 2
const.BAG_VIEW = const.BAG_VIEW or { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }

LoadBetterBagsModule("core/context.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local db = StubBetterBagsModule("Database")
local categories = StubBetterBagsModule("Categories")
local items = StubBetterBagsModule("Items")
local settings = StubBetterBagsModule("NextSettings")
local editor = StubBetterBagsModule("NextSettingsCategories")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextListReorder", "next/settings/reorder.lua" },
  { "NextSettingsBagCategories", "next/settings/bagcategories.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local bagCategories = addon:GetModule("NextSettingsBagCategories")
local nextDialog = addon:GetModule("NextDialog")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local BANK = 1

describe("NextSettingsBagCategories", function()
  local block, owner, filters, sorts, view, committed, sent, handlers, calls, saved

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function ctx()
    return context:New("spec")
  end

  local function click(b)
    b.frame:GetScript("OnClick")(b.frame, "LeftButton")
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

  -- listed returns the list as it shows: "# heading", or the name and what is on its right.
  local function listed()
    local list = {}
    for i, entry in ipairs(block.entries) do
      local row = block.rows[i]
      if entry.header then
        table.insert(list, "# " .. entry.title)
      elseif row.toggle and row.toggle.frame:IsShown() then
        table.insert(list, entry.name .. (row.toggle:GetChecked() and " [on]" or " [off]"))
      elseif row.remove.frame:IsShown() then
        table.insert(list, entry.name .. " [remove]")
      else
        table.insert(list, entry.name .. " | " .. row.note:GetText())
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
    saved, sent, handlers, calls = {}, {}, {}, {}
    filters = {
      Mats = { name = "Mats", save = true, itemList = {}, enabled = { [0] = true, [1] = false, [2] = true } },
      Potions = { name = "Potions", save = true, itemList = {}, enabled = { [0] = true, [1] = true, [2] = true } },
      Tokens = { name = "Tokens", dynamic = true, itemList = {}, enabled = { [0] = true, [1] = true, [2] = true } },
      ["Potions - Flask"] = { name = "Potions - Flask", isGroupBySubcategory = true, groupByParent = "Potions",
        dynamic = true, itemList = {}, enabled = { [1] = true } },
    }
    sorts = { [BANK] = { Potions = 1, Mats = 2, Ghost = 3 } }
    view = const.BAG_VIEW.SECTION_GRID
    committed = {
      ["6_1"] = { itemInfo = { category = "Armor" } },
      ["6_2"] = { itemInfo = { category = "Recent Items" } },
      ["6_3"] = { itemInfo = { category = "Free Space" } },
      ["6_4"] = { isItemEmpty = true, itemInfo = { category = "Bags" } },
      ["6_5"] = { itemInfo = { category = "Potions - Flask" } },
    }
    override(_G, "UISpecialFrames", {})
    controls.escape = {}
    _G._isShiftKeyDown = false
    override(events, "SendMessage", function(_, _, message, ...) table.insert(sent, { message, ... }) end)
    override(events, "RegisterMessage", function(_, message, fn) handlers[message] = fn end)
    override(db, "GetCustomSectionSort", function(_, kind) return sorts[kind] end)
    override(db, "ClearCustomSectionSort", function(_, kind) sorts[kind] = {} end)
    override(db, "SetCustomSectionSort", function(_, kind, name, index) sorts[kind][name] = index end)
    override(db, "GetBagView", function() return view end)
    override(categories, "GetAllCategories", function()
      local all = {}
      for name, f in pairs(filters) do all[name] = f end
      return all
    end)
    override(categories, "GetCategoryByName", function(_, name) return filters[name] end)
    override(categories, "UpdateCategory", function(_, _, name, fields)
      table.insert(calls, { "UpdateCategory", name, fields })
      for k, v in pairs(fields.enabled or {}) do filters[name].enabled[k] = v end
      return true
    end)
    override(categories, "DeleteCategory", function(_, _, name)
      table.insert(calls, { "DeleteCategory", name })
      filters[name] = nil
      sorts[BANK][name] = nil
    end)
    override(items, "slotInfo", { [BANK] = { itemsBySlotKey = committed } })
    override(editor, "Show", function(_, name) table.insert(calls, { "Show", name }) end)
    override(settings, "Open", function(_, page) table.insert(calls, { "Open", page }) end)

    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:Show()
    block = bagCategories:Create(CreateFrame("Frame"), owner, { name = "Bank", kind = BANK })
    block:Refresh(ctx())
    block:Place(0, 0, 700, style.Theme.Settings.BagCategories.Height)
  end)

  after_each(function()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  it("lists the pinned categories in their order, then the rest by name: a switch for each defined one", function()
    assert.are.same({
      "# Pinned", "Potions [on]", "Mats [off]", "Ghost [remove]",
      "# Other Categories", "Armor | Automatic", "Potions - Flask | Grouped by Potions", "Tokens [on]",
    }, listed(), "the bag's sections from its items too; a leftover can be removed")
  end)

  it("lists no bag names in Show Bags", function()
    view = const.BAG_VIEW.SECTION_ALL_BAGS
    block:Refresh(ctx())
    assert.are.same({ "# Pinned", "Potions [on]", "Mats [off]", "Ghost [remove]", "# Other Categories",
      "Potions - Flask | Grouped by Potions", "Tokens [on]" }, listed(), "the categories defined, not Armor")
  end)

  it("is a wide row Height tall", function()
    assert.is_true(block.wide)
    assert.are.equal(style.Theme.Settings.BagCategories.Height, block:Measure(700))
  end)

  it("keeps only the categories whose name has what is typed in its filter", function()
    block.filter.frame:SetText("pot")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.are.same({ "# Pinned", "Potions [on]", "# Other Categories", "Potions - Flask | Grouped by Potions" },
      listed())
  end)

  it("uses a category in this bag or not with its switch", function()
    local row = block:RowFor("Mats")
    click(row.toggle)
    assert.are.same({ "UpdateCategory", "Mats", { enabled = { [BANK] = true } } }, calls[#calls])
  end)

  it("opens a defined category on the Categories page when its name is clicked", function()
    rowClick("Mats")
    assert.are.same({ { "Show", "Mats" }, { "Open", "categories" } }, calls)
    calls = {}
    rowClick("Potions - Flask")
    assert.are.same({ { "Show", "Potions" }, { "Open", "categories" } }, calls, "a group's, its category")
    calls = {}
    rowClick("Armor")
    assert.are.same({}, calls, "an automatic one has nothing to open")
  end)

  it("removes a leftover after asking: what it left in every bag goes", function()
    click(block:RowFor("Ghost").remove)
    answer("Cancel")
    assert.are.same({}, calls)
    click(block:RowFor("Ghost").remove)
    answer("Remove")
    assert.are.same({ "DeleteCategory", "Ghost" }, calls[#calls])
    assert.is_nil(block:RowFor("Ghost"))
  end)

  it("pins a category at the top on a Shift-click, and unpins a pinned one", function()
    rowClick("Armor", true)
    assert.are.same({ "Armor", "Potions", "Mats", "Ghost" }, pinned())
    assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
    rowClick("Potions", true)
    assert.are.same({ "Armor", "Mats", "Ghost" }, pinned())
    assert.are.equal(0, #calls, "a Shift-click opens nothing")
  end)

  it("keeps the order of the pins its filter hides, after the ones it shows", function()
    block.filter.frame:SetText("pot")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    rowClick("Potions - Flask", true)
    assert.are.same({ "Potions - Flask", "Potions", "Mats", "Ghost" }, pinned())
  end)

  it("moves a dragged row where it is let go: pinned at that place, or unpinned below the heading", function()
    block:Drop("Tokens", 2)
    assert.are.same({ "Potions", "Tokens", "Mats", "Ghost" }, pinned())
    block:Drop("Potions", 6)
    assert.are.same({ "Tokens", "Mats", "Ghost" }, pinned())
    block:Drop("Ghost", 1)
    assert.are.same({ "Ghost", "Tokens", "Mats" }, pinned(), "a pinned one moved up")
  end)

  it("drags a row with the mouse, marking where it would land", function()
    local K = style.Theme.Settings.BagCategories
    local I = controls:Theme("Input")
    block.listBox:_SetRect(0, 0, 300, 300)
    local row = block:RowFor("Tokens")
    -- A quarter of the way down the first pinned row: in its top half, so before it.
    _G._cursorX, _G._cursorY = 20, 300 - (K.GroupHeight + 0.25 * K.RowHeight)
    _G._mouseButtonsDown = { LeftButton = true }
    row.frame:GetScript("OnDragStart")(row.frame)
    block.listBox:GetScript("OnUpdate")(block.listBox, 0.016)
    assert.is_true(block.drag.marker:IsShown())
    _G._mouseButtonsDown = {}
    block.listBox:GetScript("OnUpdate")(block.listBox, 0.016)
    assert.is_false(block.drag.marker:IsShown())
    assert.are.same({ "Tokens", "Potions", "Mats", "Ghost" }, pinned())
    _G._cursorX, _G._cursorY = 0, 0
    local _ = I
  end)

  it("lists the bag's sections again when its items are read, and the categories when they change", function()
    committed["6_6"] = { itemInfo = { category = "Weapons" } }
    handlers["items/RefreshBank/Done"](ctx())
    assert.is_not_nil(block:RowFor("Weapons"))
    filters.Gems = { name = "Gems", save = true, itemList = {}, enabled = { [1] = true } }
    handlers["categories/Changed"](ctx())
    assert.is_not_nil(block:RowFor("Gems"))
  end)
end)
