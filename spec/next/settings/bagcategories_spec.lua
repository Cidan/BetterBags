-- bagcategories_spec.lua -- NextSettingsBagCategories (next/settings/bagcategories.lua): a bag's categories
-- on its Order tab (next-settings.md §5, category-lifecycle.md §6). Categories are defined once on the
-- Categories page, which says which bags use them; a bag orders them (pinned first, then the rest) and can
-- remove leftovers. A category's name opens it on the Categories page.
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
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" }, { "NextScrollBar", "next/controls/scrollbar.lua" },
  { "NextButton", "next/controls/button.lua" }, { "NextToggle", "next/controls/toggle.lua" },
  { "NextInput", "next/controls/input.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextLift", "next/lift.lua" }, { "NextListReorder", "next/settings/reorder.lua" },
  { "NextSettingsBagCategories", "next/settings/bagcategories.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local bagCategories = addon:GetModule("NextSettingsBagCategories")
local nextDialog = addon:GetModule("NextDialog")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")
local lift = addon:GetModule("NextLift")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")

local BANK = 1

describe("NextSettingsBagCategories", function()
  local block, owner, filters, sorts, view, committed, sent, handlers, calls, saved, relayouts

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
      elseif row.remove.frame:IsShown() then
        table.insert(list, entry.name .. " [remove]")
      elseif row.note:GetText() ~= "" then
        table.insert(list, entry.name .. " | " .. row.note:GetText())
      else
        table.insert(list, entry.name)
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
    local _, _, _, _, y = block:RowFor(name).frame:GetPoint(1)
    return -y
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
    relayouts = 0
    override(settings, "Relayout", function() relayouts = relayouts + 1 end)
    override(settings, "scroll", { scrollBox = CreateFrame("Frame", nil, UIParent, "WowScrollBox") })

    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:Show()
    block = bagCategories:Create(CreateFrame("Frame"), owner, { name = "Bank", kind = BANK })
    block:Refresh(ctx())
    block:Place(0, 0, 700, 420)
  end)

  after_each(function()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  it("lists the pinned categories in their order, then the rest by name", function()
    assert.are.same({
      "# Pinned", "Potions", "Mats | Not used in this bag", "Ghost [remove]",
      "# Other Categories", "Armor | Automatic", "Potions - Flask | Grouped by Potions", "Tokens",
    }, listed(), "the bag's sections from its items too; a leftover can be removed")
  end)

  it("lists no bag names in Show Bags", function()
    view = const.BAG_VIEW.SECTION_ALL_BAGS
    block:Refresh(ctx())
    assert.are.same({ "# Pinned", "Potions", "Mats | Not used in this bag", "Ghost [remove]", "# Other Categories",
      "Potions - Flask | Grouped by Potions", "Tokens" }, listed(), "the categories defined, not Armor")
  end)

  -- Asked: "no scrollbox within tabs, just make the whole list scroll the tab content itself".
  it("is a wide row as tall as its filter and every row, scrolling with its tab's content", function()
    local K, I = style.Theme.Settings.BagCategories, controls:Theme("Input")
    assert.is_true(block.wide)
    assert.are.equal(3 * K.Pad + I.Height + 2 * K.GroupHeight + 6 * K.RowHeight, block:Measure(700))
    assert.are.equal(2 * K.GroupHeight + 6 * K.RowHeight, block.listContent:GetHeight())
    assert.is_nil(block.listBox)
    assert.are.equal(settings.scroll.scrollBox, block.drag.opts.box, "a drag scrolls the tab's content")
  end)

  it("hangs its rows under its filter", function()
    local K, I = style.Theme.Settings.BagCategories, controls:Theme("Input")
    local point, relativeTo, relativePoint, x, y = block.listContent:GetPoint(1)
    assert.are.same({ "TOPLEFT", block.frame, "TOPLEFT", K.Pad, -(2 * K.Pad + I.Height) },
      { point, relativeTo, relativePoint, x, y })
    assert.are.equal(700 - 2 * K.Pad, block.listContent:GetWidth())
  end)

  -- Typing lays the list out again; restyling the box being typed in could move its caret.
  it("restyles its filter when it is made wider or a theme applies, not for what is typed", function()
    local styled = 0
    local real = block.filter.Style
    block.filter.Style = function(...)
      styled = styled + 1
      return real(...)
    end
    block:Place(0, 0, 700, 300)
    assert.are.equal(0, styled, "only shorter")
    block:Place(0, 0, 500, 300)
    assert.are.equal(1, styled, "narrower")
    block:Style()
    assert.are.equal(2, styled, "a theme")
    block.filter.Style = nil
  end)

  it("asks its tab to lay out again when its height changes, and only then", function()
    local before = block:Measure(700)
    relayouts = 0
    block:Refresh(ctx())
    assert.are.equal(0, relayouts, "nothing changed")
    block.filter.frame:SetText("pot")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.are.equal(1, relayouts)
    assert.is_true(block:Measure(700) < before)
    block.filter.frame:SetText("")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.are.equal(2, relayouts)
    assert.are.equal(before, block:Measure(700))
  end)

  it("keeps only the categories whose name has what is typed in its filter", function()
    block.filter.frame:SetText("pot")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.are.same({ "# Pinned", "Potions", "# Other Categories", "Potions - Flask | Grouped by Potions" },
      listed())
  end)

  -- Asked: "we set that in the categories page already (no duplicate controls here)".
  it("has no switch for whether the bag uses a category: the Categories page says", function()
    local row = block:RowFor("Mats")
    assert.is_nil(row.toggle)
    local shown = {}
    for _, child in ipairs({ row.frame:GetChildren() }) do
      if child:IsShown() then
        table.insert(shown, child)
      end
    end
    assert.are.same({}, shown, "nothing to press in the row")
    assert.is_false(categories.UpdateCategory ~= nil and #calls > 0)
  end)

  it("says when a bag does not use a category, and stops saying once it does", function()
    assert.are.equal("Not used in this bag", block:RowFor("Mats").note:GetText())
    filters.Mats.enabled[BANK] = true
    handlers["categories/Changed"](ctx())
    assert.are.equal("", block:RowFor("Mats").note:GetText())
    filters.Tokens.enabled = nil
    block:Refresh(ctx())
    assert.are.equal("", block:RowFor("Tokens").note:GetText(), "used in every bag when it names none")
    filters.Tokens.enabled = { [0] = true }
    block:Refresh(ctx())
    assert.are.equal("", block:RowFor("Tokens").note:GetText(), "used in a bag it does not name")
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

  -- Asked: "instead of a line on drag, let's animate the move like we do categories" (NextListReorder).
  it("drags a row as the bags drag a section: lifted, the others making room, landing where let go", function()
    local K = style.Theme.Settings.BagCategories
    block.listContent.GetLeft, block.listContent.GetTop = function() return 0 end, function() return 300 end
    local row = block:RowFor("Tokens")
    row.frame:_SetRect(0, 300 - yOf("Tokens") - K.RowHeight, 300, K.RowHeight)
    -- A quarter of the way down the first pinned row: in its top half, so before it.
    _G._cursorX, _G._cursorY = 20, 300 - (K.GroupHeight + 0.25 * K.RowHeight)
    _G._mouseButtonsDown = { LeftButton = true }
    row.frame:GetScript("OnDragStart")(row.frame)
    assert.are.equal(lift.layer, row.frame:GetParent(), "lifted")
    block.drag:Update(0.016)
    assert.are.equal(K.GroupHeight + K.RowHeight, yOf("Potions"), "Potions makes room above it")
    _G._mouseButtonsDown = {}
    block.drag:Update(0.016)
    finishTweens()
    _G._cursorX, _G._cursorY = 0, 0
    assert.are.same({ "Tokens", "Potions", "Mats", "Ghost" }, pinned())
    assert.are.equal(block.listContent, row.frame:GetParent())
    assert.are.equal(row, block:RowFor("Tokens"), "its own row, in its new place")
    assert.are.equal(K.GroupHeight, yOf("Tokens"))
  end)

  it("never drops a row above the Pinned heading", function()
    local K = style.Theme.Settings.BagCategories
    block.listContent.GetLeft, block.listContent.GetTop = function() return 0 end, function() return 300 end
    local row = block:RowFor("Mats")
    row.frame:_SetRect(0, 300 - yOf("Mats") - K.RowHeight, 300, K.RowHeight)
    _G._cursorX, _G._cursorY = 20, 299
    _G._mouseButtonsDown = { LeftButton = true }
    row.frame:GetScript("OnDragStart")(row.frame)
    block.drag:Update(0.016)
    motion:Step(1)
    local _, _, _, _, headingY = block.rows[1].frame:GetPoint(1)
    assert.are.equal(0, headingY, "the Pinned heading stays on top")
    assert.are.equal(0, yOf("Potions") - K.GroupHeight - K.RowHeight, "the room is under the heading")
    _G._mouseButtonsDown = {}
    block.drag:Update(0.016)
    finishTweens()
    _G._cursorX, _G._cursorY = 0, 0
    assert.are.same({ "Mats", "Potions", "Ghost" }, pinned())
  end)

  it("gives a category named like a heading a row of its own", function()
    filters["# Pinned"] = { name = "# Pinned", save = true, itemList = {}, enabled = { [1] = true } }
    filters["Pinned"] = { name = "Pinned", save = true, itemList = {}, enabled = { [1] = true } }
    block:Refresh(ctx())
    assert.are.equal("# Pinned", block:RowFor("# Pinned").label:GetText())
    assert.are.equal("Pinned", block:RowFor("Pinned").label:GetText())
    assert.are.equal("PINNED", block.rows[1].label:GetText(), "the heading keeps its own")
  end)

  -- Rows belong to their categories, so one moved in the order slides to its new place (Motion).
  it("keeps each category's row its own, as wide as the list, hiding a row it no longer lists", function()
    local K = style.Theme.Settings.BagCategories
    local armor, potions = block:RowFor("Armor"), block:RowFor("Potions")
    rowClick("Armor", true)
    assert.are.equal(armor, block:RowFor("Armor"))
    assert.are.equal(potions, block:RowFor("Potions"))
    assert.are.equal("Armor", armor.label:GetText())
    assert.are.equal(K.GroupHeight, yOf("Armor"))
    assert.are.equal(700 - 2 * K.Pad, potions.frame:GetWidth())
    block.filter.frame:SetText("pot")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.is_nil(block:RowFor("Armor"))
    assert.is_false(armor.frame:IsShown())
    local free = #block.free
    block.filter.frame:SetText("")
    block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
    assert.are.equal(0, #block.free, "the rows put away are used again: " .. free)
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
