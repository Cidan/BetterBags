-- categories_spec.lua -- NextSettingsCategories (next/settings/categories.lua): the Categories page
-- (next-settings.md §5, category-lifecycle.md §6), where every category is defined once: one kind of
-- category (a rule, items placed by hand, or both), the bags it is used in, its priority, group by and
-- color, what it holds in the bags now, and the plugins' categories.
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

local editor = addon:GetModule("NextSettingsCategories")
local nextDialog = addon:GetModule("NextDialog")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local context = addon:GetModule("Context")
local style = addon:GetModule("NextStyle")

local BACKPACK, BANK, GUILD = 0, 1, 2
local GOLD = { 1, 0.82, 0 }

describe("NextSettingsCategories", function()
  local block, owner, filters, committed, sent, handlers, calls, saved, bags, matches

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

  -- listed returns the list as it shows: "# heading", or "name | details".
  local function listed()
    local list = {}
    for i, entry in ipairs(block.entries) do
      if entry.header then
        table.insert(list, "# " .. entry.title)
      else
        table.insert(list, entry.name .. " | " .. block.rows[i].detail:GetText())
      end
    end
    return list
  end

  local function choose(name)
    local row = block:RowFor(name)
    row.frame:GetScript("OnClick")(row.frame, "LeftButton")
  end

  local function updates()
    local list = {}
    for _, call in ipairs(calls) do
      if call[1] == "UpdateCategory" then table.insert(list, call) end
    end
    return list
  end

  before_each(function()
    saved, sent, handlers, calls = {}, {}, {}, {}
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
      ["Potions - Flask"] = { name = "Potions - Flask", isGroupBySubcategory = true, dynamic = true, itemList = {},
        enabled = { [BACKPACK] = true } },
    }
    committed = {
      [BACKPACK] = {
        ["0_1"] = { itemInfo = { itemID = 50, category = "Potions - Flask", itemIcon = 501 } },
        ["0_2"] = { itemInfo = { itemID = 51, category = "Potions", itemIcon = 502 } },
        ["0_3"] = { itemInfo = { itemID = 52, category = "Recent Items", itemIcon = 503 } },
        ["0_4"] = { itemInfo = { itemID = 11, category = "Junk", itemIcon = 504 } },
        ["0_5"] = { isItemEmpty = true, itemInfo = {} },
      },
      [BANK] = {
        ["6_1"] = { itemInfo = { itemID = 53, category = "Potions", itemIcon = 505 } },
        ["6_2"] = { itemInfo = { itemID = 54, category = "Elixirs", itemIcon = 506 } },
      },
    }
    -- What the rule "type = consumable" matches: three shown in Potions, the others elsewhere.
    matches = { ["0_1"] = true, ["0_2"] = true, ["0_3"] = true, ["6_1"] = true, ["6_2"] = true }
    bags = { { name = "Backpack", kind = BACKPACK }, { name = "Bank", kind = BANK }, { name = "Guild Bank", kind = GUILD } }
    override(_G, "UISpecialFrames", {})
    controls.escape = {}
    override(events, "SendMessage", function(_, _, message, ...) table.insert(sent, { message, ... }) end)
    override(events, "RegisterMessage", function(_, message, fn) handlers[message] = fn end)
    override(categories, "GetAllCategories", function()
      local all = {}
      for name, f in pairs(filters) do all[name] = f end
      return all
    end)
    override(categories, "GetCategoryByName", function(_, name) return filters[name] end)
    override(categories, "DoesCategoryExist", function(_, name) return filters[name] ~= nil end)
    override(categories, "IsDynamicCategory", function(_, name) return filters[name] ~= nil and filters[name].dynamic == true end)
    override(categories, "IsGroupBySubcategory", function(_, name)
      return filters[name] ~= nil and filters[name].isGroupBySubcategory == true
    end)
    override(categories, "RuleOf", function(_, f)
      local q = f and f.searchCategory and f.searchCategory.query
      return q ~= nil and strtrim(q) ~= "" and strtrim(q) or nil
    end)
    override(categories, "CreateCategory", function(_, _, filter)
      table.insert(calls, { "CreateCategory", filter })
      filter.enabled = filter.enabled or { [BACKPACK] = true, [BANK] = true, [GUILD] = true }
      filters[filter.name] = filter
    end)
    override(categories, "UpdateCategory", function(_, _, name, fields)
      table.insert(calls, { "UpdateCategory", name, fields })
      local f = filters[name]
      if fields.priority then f.priority = fields.priority end
      if fields.groupBy then f.groupBy = fields.groupBy end
      if fields.color ~= nil then f.color = fields.color or nil end
      if fields.rule ~= nil then f.searchCategory = fields.rule ~= "" and { query = fields.rule } or nil end
      for k, v in pairs(fields.enabled or {}) do f.enabled[k] = v end
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
    override(categories, "GetMergedCategory", function(_, name)
      local list = {}
      for id in pairs(filters[name] and filters[name].itemList or {}) do list[id] = true end
      return { name = name, itemList = list }
    end)
    override(items, "slotInfo", { [BACKPACK] = { itemsBySlotKey = committed[BACKPACK] },
      [BANK] = { itemsBySlotKey = committed[BANK] } })
    override(items, "GetItemData", function(_, c, ids, cb)
      local list = {}
      for i, id in ipairs(ids) do list[i] = { itemInfo = { itemID = id } } end
      cb(c, list)
    end)
    override(search, "Search", function(_, query)
      if query == "broken (" then error("unexpected end") end
      if query == "type = consumable" then return matches end
      if query == "exp = mid" then return {} end
      return { ["0_1"] = true }
    end)
    override(itemRowFrame, "Create", function()
      local row = { frame = CreateFrame("Frame"), rowButton = CreateFrame("Button") }
      row.frame:Hide()
      function row:SetStaticItemFromData(_, data) self.data = data self.frame:Show() end
      function row:Release() self.released = true self.frame:Hide() end
      return row
    end)
    ColorPickerFrame:Hide()
    _G._cursorType, _G._cursorItemID, _G._cursorHasItem = nil, nil, false
    editor:Init()

    owner = CreateFrame("Frame", "SpecSettingsWindow", UIParent)
    owner:Show()
    block = editor:Create(CreateFrame("Frame"), owner, function() return bags end)
    block:Refresh(ctx())
    block:Place(0, 0, 700, style.Theme.Settings.Categories.Height)
  end)

  after_each(function()
    nextMenu:Close()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  describe("its list", function()
    it("lists your categories, then the plugins', each by name, with what is in it and its priority", function()
      assert.are.same({
        "# Your Categories",
        "Empty | Nothing in it yet · Priority 10",
        "Mats | 2 items · Priority 5",
        "Midnight | Rule and 1 item · Priority 2",
        "Potions | Rule · Priority 10",
        "# From Plugins",
        "Openable | 1 item · Priority 1",
      }, listed(), "a group by's sub-categories are not listed")
    end)

    it("is a wide row filling the page, its list ListWidth wide", function()
      local K = style.Theme.Settings.Categories
      assert.is_true(block.wide)
      assert.are.equal(K.Height, block:Measure(700))
      assert.are.equal(K.ListWidth, block.list:GetWidth())
    end)

    it("keeps only the categories whose name has what is typed in its filter", function()
      block.filter.frame:SetText("MID")
      block.filter.frame:GetScript("OnTextChanged")(block.filter.frame, true)
      assert.are.same({ "# Your Categories", "Midnight | Rule and 1 item · Priority 2" }, listed())
    end)

    it("chooses the first category when none is chosen, and marks the one chosen", function()
      assert.are.equal("Empty", block.selected)
      choose("Mats")
      assert.are.equal("Mats", block.selected)
      assert.is_true(block:RowFor("Mats").indicator:IsShown())
      assert.is_false(block:RowFor("Empty").indicator:IsShown())
    end)

    it("makes a new category, chosen, asking again for a name taken or none", function()
      click(block.newCategory)
      nextDialog.input.frame:SetText("  ")
      answer("Create")
      assert.is_true(nextDialog:IsShown())
      nextDialog.input.frame:SetText("Mats")
      answer("Create")
      assert.are.equal("A category named 'Mats' already exists.", nextDialog.text:GetText())
      nextDialog.input.frame:SetText("Trash")
      answer("Create")
      assert.are.same({ "CreateCategory", { name = "Trash", itemList = {}, save = true,
        enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } } }, calls[#calls])
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.equal("Trash", block.selected)
    end)

    it("lists the categories again when they change while it shows", function()
      filters.Gems = { name = "Gems", save = true, itemList = {}, enabled = {} }
      handlers["categories/Changed"](ctx())
      assert.is_not_nil(block:RowFor("Gems"))
    end)
  end)

  describe("a category", function()
    it("shows its name, color (gold for none), the bags it is used in, priority and group by", function()
      choose("Potions")
      assert.are.equal("Potions", block.title:GetText())
      assert.are.same({ 0.2, 0.4, 0.6, 1 }, block.swatch:GetColor())
      assert.are.equal("10", block.priority:GetText())
      assert.are.equal("Type", block.groupBy.text:GetText())
      choose("Mats")
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, block.swatch:GetColor())
      assert.is_true(block.bagToggles[BACKPACK]:GetChecked())
      assert.is_false(block.bagToggles[BANK]:GetChecked())
      assert.is_true(block.bagToggles[GUILD]:GetChecked())
      assert.are.equal("None", block.groupBy.text:GetText())
    end)

    it("has a switch for each bag the settings show, the guild bank like any other", function()
      bags = { { name = "Backpack", kind = BACKPACK }, { name = "Bank", kind = BANK } }
      block:Refresh(ctx())
      choose("Mats")
      assert.is_true(block.bagToggles[BACKPACK].frame:IsShown())
      assert.is_false(block.bagToggles[GUILD] ~= nil and block.bagToggles[GUILD].frame:IsShown())
    end)

    it("uses it in a bag or not at once", function()
      choose("Mats")
      click(block.bagToggles[BANK])
      assert.are.same({ "UpdateCategory", "Mats", { enabled = { [BANK] = true } } }, updates()[1])
    end)

    it("saves its priority when it is entered, 0 to 99, and shows it again for something else", function()
      choose("Mats")
      block.priority:SetText("3")
      block.priority:Commit(ctx())
      assert.are.same({ "UpdateCategory", "Mats", { priority = 3 } }, updates()[1])
      block.priority:SetText("")
      block.priority:Commit(ctx())
      assert.are.equal(1, #updates(), "nothing saved for nothing")
      assert.are.equal("3", block.priority:GetText())
    end)

    it("saves its group by when one is picked", function()
      choose("Mats")
      click(block.groupBy)
      nextMenu:Rows()[3].frame:GetScript("OnClick")(nextMenu:Rows()[3].frame, "LeftButton")
      assert.are.same({ "UpdateCategory", "Mats", { groupBy = 2 } }, updates()[1])
    end)

    it("saves its color, or none for gold", function()
      choose("Mats")
      -- As the picker does: the swatch takes the color, then says so.
      block.swatch:SetColor({ 0.5, 0.5, 0.5, 1 })
      block.swatch.opts.onChange(ctx(), { 0.5, 0.5, 0.5, 1 })
      assert.are.same({ "UpdateCategory", "Mats", { color = { 0.5, 0.5, 0.5 } } }, updates()[1])
      click(block.resetColor)
      assert.are.same({ "UpdateCategory", "Mats", { color = false } }, updates()[2])
      assert.are.same({ GOLD[1], GOLD[2], GOLD[3], 1 }, block.swatch:GetColor())
    end)
  end)

  describe("its rule", function()
    local function typed(text)
      block.rule.editBox:SetText(text)
      block.rule.editBox:GetScript("OnTextChanged")(block.rule.editBox, true)
    end

    it("shows its search and how many items in the bags it matches, as it is typed", function()
      choose("Potions")
      assert.are.equal("type = consumable", block.rule:GetText())
      assert.are.equal("Matches 5 items in your bags.", block.ruleCount:GetText())
      typed("anything")
      assert.are.equal("Matches 1 item in your bags.", block.ruleCount:GetText())
      typed("broken (")
      assert.are.equal("This search has a mistake.", block.ruleCount:GetText())
      typed("")
      assert.are.equal("No rule: only the items placed here.", block.ruleCount:GetText())
    end)

    it("saves it with Apply Rule, which is off until it is changed", function()
      choose("Potions")
      assert.is_false(block.applyRule.frame:IsEnabled())
      typed("type = trade goods")
      assert.is_true(block.applyRule.frame:IsEnabled())
      click(block.applyRule)
      assert.are.same({ "UpdateCategory", "Potions", { rule = "type = trade goods" } }, updates()[1])
      assert.is_false(block.applyRule.frame:IsEnabled())
    end)

    it("saves no rule for an empty one, and refuses a search with a mistake", function()
      choose("Potions")
      typed("broken (")
      assert.is_false(block.applyRule.frame:IsEnabled())
      click(block.applyRule)
      assert.are.equal(0, #updates())
      typed("  ")
      click(block.applyRule)
      assert.are.same({ "UpdateCategory", "Potions", { rule = "" } }, updates()[1])
    end)
  end)

  describe("its items", function()
    it("lists the items placed in it by hand", function()
      choose("Mats")
      local ids = {}
      for _, row in ipairs(block.itemRows) do table.insert(ids, row.data.itemInfo.itemID) end
      table.sort(ids)
      assert.are.same({ 11, 12 }, ids)
    end)

    it("takes an item dropped on its items, and gives one back on a right click", function()
      choose("Mats")
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "item", 13, true
      block.itemDrop:GetScript("OnReceiveDrag")(block.itemDrop)
      assert.are.same({ "AddPermanentItemToCategory", 13, "Mats" }, calls[#calls])
      assert.is_false(CursorHasItem())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true } }, sent[#sent])
      assert.are.equal(3, #block.itemRows)
      local row
      for _, r in ipairs(block.itemRows) do
        if r.data.itemInfo.itemID == 11 then row = r end
      end
      sent = {}
      row.rowButton:GetScript("OnMouseDown")(row.rowButton, "RightButton")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.same({ "RemoveItemFromCategory", 11, "Mats" }, calls[#calls])
      assert.are.same({ { "bags/Rederive", { resetLayout = true, buttons = true } } }, sent)
      assert.are.equal(2, #block.itemRows)
    end)

    it("takes nothing that is not an item", function()
      choose("Mats")
      _G._cursorType, _G._cursorItemID, _G._cursorHasItem = "money", 5, true
      block.itemDrop:GetScript("OnReceiveDrag")(block.itemDrop)
      assert.are.equal(0, #calls)
    end)
  end)

  describe("what it holds in the bags now", function()
    local function icons()
      local list = {}
      for _, icon in ipairs(block.icons) do
        if icon:IsShown() then table.insert(list, icon:GetTexture()) end
      end
      table.sort(list)
      return list
    end

    it("counts what shows in it (its sub-categories too) by bag, and says where the rest shows", function()
      choose("Potions")
      assert.are.equal("In your bags now: 3 (Backpack 2, Bank 1).", block.inBags:GetText())
      assert.are.same({ 501, 502, 505 }, icons())
      assert.are.equal("Shown elsewhere: 1 in Elixirs, 1 in Recent Items.", block.elsewhere:GetText())
    end)

    it("counts the items placed in it by hand that show elsewhere too", function()
      choose("Potions")
      choose("Mats")
      assert.are.equal("In your bags now: none.", block.inBags:GetText())
      assert.are.same({}, icons())
      assert.are.equal("Shown elsewhere: 1 in Junk.", block.elsewhere:GetText())
    end)

    it("shows what the bags hold again when they are read", function()
      choose("Potions")
      committed[BACKPACK]["0_6"] = { itemInfo = { itemID = 60, category = "Potions", itemIcon = 600 } }
      handlers["items/RefreshBackpack/Done"](ctx())
      assert.are.equal("In your bags now: 4 (Backpack 3, Bank 1).", block.inBags:GetText())
    end)
  end)

  describe("renaming and deleting", function()
    it("renames it, keeping it chosen, or says why it cannot", function()
      choose("Mats")
      click(block.rename)
      assert.are.equal("Mats", nextDialog.input:GetText())
      nextDialog.input.frame:SetText("Potions")
      answer("Rename")
      assert.are.equal("A category named 'Potions' already exists.", nextDialog.text:GetText())
      nextDialog.input.frame:SetText("Metals")
      answer("Rename")
      assert.are.same({ "RenameCategory", "Mats", "Metals" }, calls[#calls])
      assert.are.equal("Metals", block.selected)
    end)

    it("deletes it after asking, choosing the first category", function()
      choose("Mats")
      click(block.delete)
      answer("Cancel")
      assert.is_not_nil(filters.Mats)
      click(block.delete)
      answer("Delete")
      assert.are.same({ "DeleteCategory", "Mats" }, calls[#calls])
      assert.are.equal("Empty", block.selected)
    end)
  end)

  describe("a plugin's category", function()
    it("can be used in bags, colored and prioritized, but its rule and items are the plugin's", function()
      choose("Openable")
      assert.is_true(block.info:IsShown())
      assert.are.equal("A plugin made this category: its rule and items are the plugin's.", block.info:GetText())
      assert.is_false(block.rename.frame:IsShown())
      assert.is_false(block.delete.frame:IsShown())
      assert.is_false(block.rule.frame:IsShown())
      assert.is_false(block.itemDrop:IsShown())
      assert.is_false(block.groupBy.frame:IsShown())
      assert.is_true(block.bagToggles[BACKPACK].frame:IsShown())
      assert.is_true(block.priority.frame:IsShown())
      assert.is_true(block.swatch.frame:IsShown())
      choose("Mats")
      assert.is_false(block.info:IsShown())
      assert.is_true(block.rule.frame:IsShown())
    end)
  end)

  describe("opened for a category or a search", function()
    it("chooses the category it was asked to show the next time it shows", function()
      editor:Show("Midnight")
      block:Refresh(ctx())
      assert.are.equal("Midnight", block.selected)
      choose("Mats")
      block:Refresh(ctx())
      assert.are.equal("Mats", block.selected, "once")
    end)

    -- The search box's Enter to Make Category (frames/search.lua).
    it("makes a new category whose rule is a search, asking for its name", function()
      editor:NewFromSearch("rarity = epic")
      block:Refresh(ctx())
      assert.is_true(nextDialog:IsShown())
      nextDialog.input.frame:SetText("Epics")
      answer("Create")
      assert.are.same({ name = "Epics", itemList = {}, save = true, searchCategory = { query = "rarity = epic" },
        enabled = { [BACKPACK] = true, [BANK] = true, [GUILD] = true } }, calls[#calls][2])
      assert.are.equal("Epics", block.selected)
      block:Refresh(ctx())
      assert.is_false(nextDialog:IsShown(), "asked once")
    end)
  end)
end)
