-- content_spec.lua -- NextSettingsContent (next/settings/content.lua): the pages of BetterBags Next's
-- settings window (next-settings.md §4): where every setting goes, Appearance's theme pickers, Item
-- Colors, Profiles, Import / Export, QuickFind, and a page per plugin built from its AceConfig options.
-- The pages are opened in the real window, on the real settings catalog.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
const.BAG_KIND.GUILD = const.BAG_KIND.GUILD or 2
const.BAG_VIEW = const.BAG_VIEW or { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }
const.SEARCH_CATEGORY_GROUP_BY = const.SEARCH_CATEGORY_GROUP_BY or { NONE = 0, TYPE = 1, SUBTYPE = 2, EXPANSION = 3 }
const.SECTION_SORT_TYPE = const.SECTION_SORT_TYPE or { ALPHABETICALLY = 1, SIZE_DESCENDING = 2, SIZE_ASCENDING = 3 }
const.ITEM_SORT_TYPE = const.ITEM_SORT_TYPE
  or { ALPHABETICALLY_THEN_QUALITY = 1, QUALITY_THEN_ALPHABETICALLY = 2, ITEM_LEVEL = 3, EXPANSION = 4 }

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local db = StubBetterBagsModule("Database")
-- The saved BetterBags Next theme (DB:GetNextTheme), which SonataNext reads.
db.GetNextTheme = db.GetNextTheme or function() return "Default" end
-- The Animation switches (next-themes.md §20), all on, which SonataNext lays over the theme it uses.
db.GetNextAnimation = db.GetNextAnimation or function() return true end
StubBetterBagsModule("Bucket")
local bagSystem = StubBetterBagsModule("BagSystem")
StubBetterBagsModule("Items")
StubBetterBagsModule("Categories")
StubBetterBagsModule("Search")
StubBetterBagsModule("ItemRowFrame")
local sonata = StubBetterBagsModule("Sonata")
local debugModule = StubBetterBagsModule("Debug")
debugModule.Log = debugModule.Log or function() end
for _, m in ipairs({ { "SettingsCatalog", "config/catalog.lua" }, { "NextStyle", "next/style.lua" },
  { "NextTween", "next/tween.lua" }, { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextButton", "next/controls/button.lua" },
  { "NextToggle", "next/controls/toggle.lua" }, { "NextInput", "next/controls/input.lua" },
  { "NextSlider", "next/controls/slider.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDropdown", "next/controls/dropdown.lua" }, { "NextSwatch", "next/controls/swatch.lua" },
  { "NextTopTabs", "next/controls/toptabs.lua" }, { "NextDialog", "next/controls/dialog.lua" },
  { "NextItemGrid", "next/controls/itemgrid.lua" },
  { "NextSettingsRows", "next/settings/rows.lua" }, { "NextSettingsPage", "next/settings/page.lua" },
  { "NextSettingsPages", "next/settings/pages.lua" }, { "NextSettings", "next/settings/window.lua" },
  { "NextSettingsThemes", "next/settings/themes.lua" }, { "NextLift", "next/lift.lua" }, { "NextListReorder", "next/settings/reorder.lua" },
  { "NextSettingsCategories", "next/settings/categories.lua" },
  { "NextSettingsBagCategories", "next/settings/bagcategories.lua" },
  { "NextSettingsCurrency", "next/settings/currency.lua" },
  { "NextSettingsContent", "next/settings/content.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local content = addon:GetModule("NextSettingsContent")
local settings = addon:GetModule("NextSettings")
local pages = addon:GetModule("NextSettingsPages")
local catalog = addon:GetModule("SettingsCatalog")
local nextDialog = addon:GetModule("NextDialog")
local nextMenu = addon:GetModule("NextMenu")
local controls = addon:GetModule("NextControls")
local render = addon:GetModule("Render")
local tween = addon:GetModule("NextTween")
local sonataNext = addon:GetModule("SonataNext")

describe("NextSettingsContent", function()
  local sent, calls, saved, timers, reloads, handlers, design

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  local function call(name)
    return function(_, ...)
      table.insert(calls, { name, ... })
    end
  end

  -- idsOf lists a page's sections and their rows' settings, marking what shows for one design only.
  local function idsOf(page)
    local function marked(text, thing)
      return thing.design and (text .. " [" .. thing.design .. "]") or text
    end
    local list = {}
    for _, tab in ipairs(page.tabs) do
      for _, section in ipairs(pages:Sections(tab)) do
        local ids = {}
        for _, row in ipairs(section.rows) do
          table.insert(ids, marked(row.setting or row.title or (row.option and row.option.title) or row.text or "?", row))
        end
        table.insert(list, { tab.title, marked(section.title, section), ids })
      end
    end
    return list
  end

  local function rowsShown()
    local list = {}
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        table.insert(list, row)
      end
    end
    return list
  end

  local function rowTitled(title)
    for _, row in ipairs(rowsShown()) do
      if row.label and row.label:GetText() == title then return row end
    end
  end

  local function button(text)
    for _, row in ipairs(rowsShown()) do
      for _, b in ipairs(row.buttons or {}) do
        if b.label:GetText() == text then return b end
      end
    end
    error("no button " .. text)
  end

  local function click(b)
    b.frame:GetScript("OnClick")(b.frame, "LeftButton")
  end

  -- answer clicks the dialog's button labelled text.
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

  before_each(function()
    sent, calls, saved, timers, reloads, handlers = {}, {}, {}, {}, 0, {}
    override(_G, "UISpecialFrames", {})
    override(C_Timer, "After", function(_, fn) table.insert(timers, fn) end)
    override(_G, "ReloadUI", function() reloads = reloads + 1 end)
    override(events, "SendMessage", function(_, _, message, ...) table.insert(sent, { message, ... }) end)
    override(events, "RegisterMessage", function(_, message, fn) handlers[message] = fn end)
    override(addon, "hasGuildBank", false)
    design = "next"
    override(bagSystem, "ActiveDesign", function() return design end)
    controls.escape = {}
    render:Init()
    tween:Init()
    pages:Clear()
    settings:Init()
    content:Init()
  end)

  after_each(function()
    settings:Close()
    nextMenu:Close()
    nextDialog:Hide()
    for i = #saved, 1, -1 do
      saved[i][1][saved[i][2]] = saved[i][3]
    end
  end)

  describe("the pages", function()
    it("lists BetterBags, the bags, Profiles and Integrations, in that order", function()
      local list = {}
      for _, page in ipairs(pages:List()) do
        table.insert(list, page.group .. ": " .. page.title)
      end
      assert.are.same({ "BetterBags: General", "BetterBags: Appearance", "BetterBags: Item Colors",
        "BetterBags: Categories", "Bags: Backpack", "Bags: Bank", "Profiles: Profiles", "Integrations: QuickFind" }, list)
    end)

    -- Categories are defined once, on their own page (category-lifecycle.md §6), for both designs; a
    -- bag arranges them on its Categories tab.
    -- Categories are defined once, on their own page (category-lifecycle.md §6, next-settings.md §5): its
    -- list in the sidebar, its heading and buttons in the header, and three tabs, for both designs.
    it("defines every category on the Categories page: its list, heading, buttons and three tabs", function()
      local made = {}
      local editor = addon:GetModule("NextSettingsCategories")
      local rows = addon:GetModule("NextSettingsRows")
      local chosen, rule = true, true
      override(editor, "CreateList", function(_, parent, owner)
        made.list = { parent = parent, owner = owner }
        local list = { frame = CreateFrame("Frame", nil, parent) }
        function list:Place() end
        function list:Refresh() end
        return list
      end)
      override(editor, "CreateActions", function(_, parent, owner)
        made.actions = { parent = parent, owner = owner }
        local a = { frame = CreateFrame("Frame", nil, parent) }
        function a:Refresh() end
        return a
      end)
      override(editor, "Heading", function() return "Mats", "2 added items" end)
      override(editor, "RuleTabShown", function() return rule end)
      override(editor, "ItemsTabShown", function() return chosen end)
      override(editor, "AutomationTabShown", function() return chosen end)
      for _, name in ipairs({ "CreateSettingsTab", "CreateRuleTab", "CreateItemsTab" }) do
        override(editor, name, function(_, parent, owner, bags, mode)
          made[mode and (name .. ":" .. mode) or name] = { owner = owner, bags = bags }
          return rows:CreateText(parent, name)
        end)
      end
      override(db, "GetMaxItemLevel", function() return 100 end)
      settings:Open("categories")
      assert.are.equal("categories", settings.pageId)
      assert.are.equal(settings.frame, made.list.owner)
      assert.are.equal(settings.header, made.actions.parent)
      assert.are.equal("Mats", settings.title:GetText())
      local function tabs()
        local list = {}
        for _, t in ipairs(settings.tabs.list) do table.insert(list, t.text) end
        return list
      end
      -- Asked: "a new tab next to 'Added Items' called 'Ignored Items'".
      assert.are.same({ "Settings", "Search Rule", "Added Items", "Ignored Items", "Automation" }, tabs())
      assert.are.equal(settings.frame, made.CreateSettingsTab.owner)
      local function kinds(name)
        local list = {}
        for _, bag in ipairs(made[name].bags()) do table.insert(list, bag.kind) end
        return list
      end
      assert.are.same({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }, kinds("CreateSettingsTab"))
      addon.hasGuildBank = true
      assert.are.same({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK, const.BAG_KIND.GUILD }, kinds("CreateSettingsTab"),
        "the guild bank like any bag")
      design = "classic"
      assert.are.same({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK }, kinds("CreateSettingsTab"), "the classic bags have none")
      design = "next"
      settings:Select("categories", "rule")
      assert.are.same({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK, const.BAG_KIND.GUILD }, kinds("CreateRuleTab"))
      -- The Automation tab is a section of settings rows, as every other page draws its settings.
      local automation
      for _, t in ipairs(pages:Get("categories").tabs) do
        if t.id == "automation" then automation = t end
      end
      local sections = pages:Sections(automation)
      assert.are.equal(2, #sections)
      assert.are.equal("Merchants", sections[1].title)
      local automationRows = sections[1].rows
      local rowTitles = {}
      for i, row in ipairs(automationRows) do rowTitles[i] = row.option.title end
      assert.are.same({ "Auto Sell", "Confirm Auto Sell", "Destroy What Can't Be Sold" }, rowTitles)
      -- Asked: Skip Recent Items "under automation for categories (not under 'merchant' though)".
      assert.are.equal("Recent Items", sections[2].title)
      assert.are.same({ "Skip Recent Items" }, { sections[2].rows[1].option.title })
      assert.are.equal(1, #sections[2].rows)
      settings:Select("categories", "ignored")
      assert.are.equal(settings.frame, made["CreateItemsTab:ignored"].owner)
      assert.are.same({ const.BAG_KIND.BACKPACK, const.BAG_KIND.BANK, const.BAG_KIND.GUILD },
        kinds("CreateItemsTab:ignored"))
      settings:Select("categories", "items")
      assert.are.equal(settings.frame, made.CreateItemsTab.owner)
      local titles = {}
      for _, title in ipairs(settings.page.titles) do
        if title:IsShown() then table.insert(titles, title:GetText()) end
      end
      assert.are.same({}, titles, "the tab's name says it: no section title")
      rule, chosen = false, false
      settings:Select("categories", "rule")
      assert.are.equal("settings", settings.tabId)
      assert.is_false(settings.tabs.frame:IsShown(), "one tab: no tab bar")
    end)

    -- The classic bags' currency icons (frames/currency.lua): on clients with currencies (retail, WoW:
    -- Forever, Mists Classic; the classic window showed "not available" on TBC and Era).
    it("lists the classic bags' pages: Currency after Item Colors, on a client with currencies", function()
      design = "classic"
      for _, flag in ipairs({ "isRetail", "isMists", "isBCC", "isClassic" }) do
        override(addon, flag, false)
      end
      local function listed()
        local list = {}
        for _, page in ipairs(pages:List()) do table.insert(list, page.title) end
        return list
      end
      addon.isRetail = true
      assert.are.same({ "General", "Appearance", "Item Colors", "Categories", "Currency", "Backpack", "Bank",
        "Profiles", "QuickFind" }, listed())
      addon.isRetail = false
      addon.isMists = true
      assert.are.equal("Currency", listed()[5])
      addon.isMists = false
      addon.isBCC = true
      assert.are.equal("Backpack", listed()[5], "none on TBC")
      addon.isBCC, addon.isClassic = false, true
      assert.are.equal("Backpack", listed()[5], "none on Era")
      addon.isClassic, addon.isRetail = false, true
      design = "next"
      assert.are.equal("Backpack", listed()[5], "BetterBags Next shows no currencies")
    end)

    it("shows every currency on the Currency page, and finds it by name", function()
      design = "classic"
      override(addon, "isRetail", true)
      local made = 0
      local currency = addon:GetModule("NextSettingsCurrency")
      override(currency, "Create", function(_, parent)
        made = made + 1
        return addon:GetModule("NextSettingsRows"):CreateText(parent, "currencies")
      end)
      override(db, "GetMaxItemLevel", function() return 100 end)
      settings:Open("currency")
      assert.are.equal("currency", settings.pageId)
      assert.are.equal(1, made)
      settings:Search(addon:GetModule("Context"):New("spec"), "currenc")
      assert.are.equal("Currency", settings.page.sections[1].title)
    end)

    it("shows the guild bank's page on a client with one, while BetterBags Next is in use", function()
      assert.is_false(pages:IsShown(pages:Get("guild")))
      addon.hasGuildBank = true
      assert.is_true(pages:IsShown(pages:Get("guild")))
      assert.are.equal("Guild Bank", pages:Get("guild").bag.name)
      design = "classic"
      assert.is_false(pages:IsShown(pages:Get("guild")), "the classic bags have no guild bank")
    end)

    it("puts the bags' general settings on General, the classic bags' own only for them", function()
      assert.are.same({
        { "General", "Bags", { "nextEnabled", "enableBankBags", "showBagButton", "bagFading [classic]",
          "animateItemMovement [classic]" } },
        { "General", "Search", { "inBagSearch", "enterToMakeCategory [classic]" } },
        { "General", "Items", { "upgradeProvider", "newItemDuration", "categorySell" } },
        { "General", "What's New", { "changelogOnLogin" } },
      }, idsOf(pages:Get("general")))
    end)

    it("gives every bag its layout, items and categories, bound to it", function()
      local page = pages:Get("bank")
      assert.are.equal(const.BAG_KIND.BANK, page.bag.kind)
      assert.are.same({
        { "Layout", "Order", { "sectionOrder", "itemOrder" } },
        { "Layout", "Tabs", { "enableGroups" } },
        { "Layout", "Slots", { "showAllFreeSpace", "preserveGaps" } },
        { "Layout", "Window [classic]", { "resizableWindow", "snapToContent", "itemsPerRow", "columns", "opacity",
          "scale" } },
        { "Layout", "Sections [classic]", { "fullSectionNames" } },
        { "Items", "Item Level", { "itemLevel", "itemLevelColor" } },
        { "Items", "Quality", { "glowIntensity" } },
        { "Items", "Stacking", { "markRecentItems", "newItemFlash", "mergeStacks", "mergeUnstackable",
          "dontMergePartial", "dontMergeTransmog", "unmergeAtShop" } },
        { "Categories", "Automatic", { "filterEquipmentLocation", "filterExpansion", "filterGearSet",
          "filterRecentItems", "filterTradeSkill", "filterType", "filterSubtype" } },
        { "Categories", "In This Bag", { "Categories in This Bag" } },
      }, idsOf(page))
    end)

    it("arranges the categories on a bag's Categories tab, bound to it", function()
      local made
      local manager = addon:GetModule("NextSettingsBagCategories")
      override(manager, "Create", function(_, parent, windowFrame, bag)
        made = { parent = parent, owner = windowFrame, bag = bag }
        return addon:GetModule("NextSettingsRows"):CreateText(parent, "manager")
      end)
      for _, name in ipairs({ "GetCategoryFilters" }) do
        override(db, name, function() return {} end)
      end
      settings:Open("bank", "categories")
      assert.are.equal(settings.frame, made.owner)
      assert.are.equal(const.BAG_KIND.BANK, made.bag.kind)
    end)

    it("names only settings the catalog has, for the page's bag; the classic bags' own only for them", function()
      local classicOnly = { bagFading = true, animateItemMovement = true, fullSectionNames = true,
        resizableWindow = true, snapToContent = true, itemsPerRow = true, columns = true, opacity = true, scale = true }
      local nextOnly = { nextIconScale = true, nextBagScale = true, nextSparkles = true, nextShimmer = true,
        nextTitleCloud = true, nextTitleRibbon = true, nextBraid = true, nextOrnamentMotion = true }
      addon.hasGuildBank = true
      content:Init()
      local named = 0
      for _, page in ipairs(pages.list) do
        for _, tab in ipairs(page.tabs) do
          for _, section in ipairs(pages:Sections(tab)) do
            for _, row in ipairs(section.rows) do
              if row.setting then
                named = named + 1
                if classicOnly[row.setting] then
                  assert.are.equal("classic", row.design or section.design, row.setting)
                end
                if nextOnly[row.setting] then
                  assert.are.equal("next", row.design or section.design or tab.design, row.setting)
                end
                if catalog:Has(row.setting, page.bag) then
                  assert.has_no.errors(function() catalog:Get(row.setting, page.bag) end, row.setting)
                else
                  assert.are.equal("enableGroups", row.setting, "only Enable Groups is a backpack's alone")
                end
              end
            end
          end
        end
      end
      assert.are.equal(19 + 3 * 29, named)
    end)

    it("shows the bank's Layout without the backpack's Enable Groups", function()
      for _, name in ipairs({ "GetSectionSortType", "GetBagView", "GetItemSortType", "GetGroupsEnabled",
        "GetShowAllFreeSpace", "GetPreserveItemGaps" }) do
        override(db, name, function() return 1 end)
      end
      settings:Open("bank", "layout")
      local sections = {}
      for _, section in ipairs(settings.page.sections) do table.insert(sections, section.title) end
      assert.are.same({ "Order", "Slots" }, sections)
      settings:Open("backpack", "layout")
      assert.is_not_nil(rowTitled("Enable Groups"))
    end)

    -- Asked: rows and columns in the classic bags' Layout, and not in BetterBags Next's.
    it("shows a bag's window, rows and columns in the classic bags' Layout only", function()
      for _, name in ipairs({ "GetSectionSortType", "GetBagView", "GetItemSortType", "GetGroupsEnabled",
        "GetShowAllFreeSpace", "GetPreserveItemGaps", "GetBagSnapToContent", "GetShowFullSectionNames" }) do
        override(db, name, function() return 1 end)
      end
      override(db, "GetBagSizeMode", function() return "content" end)
      override(db, "GetBagSizeInfo", function() return { itemsPerRow = 7, columnCount = 2, opacity = 100, scale = 100 } end)
      settings:Open("bank", "layout")
      assert.is_nil(rowTitled("Items Per Row"))
      assert.is_nil(rowTitled("Columns"))
      settings:Close()
      tween:Step(1)
      design = "classic"
      settings:Open("bank", "layout")
      local sections = {}
      for _, section in ipairs(settings.page.sections) do table.insert(sections, section.title) end
      assert.are.same({ "Order", "Slots", "Window", "Sections" }, sections)
      assert.are.equal(7, rowTitled("Items Per Row").control:GetValue())
      assert.are.equal(2, rowTitled("Columns").control:GetValue())
    end)
  end)

  describe("Appearance", function()
    before_each(function()
      override(sonata, "GetThemes", function() return {} end)
      override(sonata, "IsAvailable", function() return true end)
      override(sonata, "IsSelectable", function() return true end)
      override(sonata, "GetSavedThemeKey", function() return "Default" end)
      override(sonata, "GetCurrentThemeKey", function() return "Default" end)
      override(sonata, "RestoreSavedTheme", function() end)
    end)

    local function shownTabIds()
      local ids = {}
      for _, tab in ipairs(pages:ShownTabs(pages:Get("appearance"))) do table.insert(ids, tab.id) end
      return ids
    end

    -- Asked: no classic (item button) themes while BetterBags Next is in use.
    it("picks BetterBags Next's theme alone while Next is in use", function()
      settings:Open("appearance")
      assert.are.equal("theme", settings.tabId)
      local rows = rowsShown()
      assert.are.equal(1, #rows)
      assert.are.equal(sonataNext, rows[1].engine)
      assert.are.equal("Theme", settings.page.sections[1].title)
    end)

    it("picks the bags' theme, then this window's, for the classic bags", function()
      design = "classic"
      settings:Open("appearance")
      local rows = rowsShown()
      assert.are.equal(2, #rows)
      assert.are.equal(sonata, rows[1].engine)
      assert.are.equal(sonataNext, rows[2].engine)
      assert.are.same({ "Bag Theme", "Settings Window" }, { settings.page.sections[1].title, settings.page.sections[2].title })
    end)

    -- Asked: "make 'Theme' here a tab, and add a tab for 'Size'; here we have a slider for 'icon scale' in
    -- the bag, and another slider for 'bag scale'" (docs/next-appearance-size.md).
    it("has a Theme tab and, with BetterBags Next, a Size tab with Icon Scale and Bag Scale", function()
      override(db, "GetNextIconScale", function() return 120 end)
      override(db, "GetNextBagScale", function() return 85 end)
      assert.are.same({ "theme", "size", "animation" }, shownTabIds())
      settings:Open("appearance", "size")
      assert.are.equal("size", settings.tabId)
      assert.is_true(settings.tabs.frame:IsShown())
      assert.are.equal(120, rowTitled("Icon Scale").control:GetValue())
      assert.are.equal(85, rowTitled("Bag Scale").control:GetValue())
    end)

    it("has only the Theme tab with the classic bags, which size themselves on each bag's page", function()
      design = "classic"
      assert.are.same({ "theme" }, shownTabIds())
      settings:Open("appearance", "size")
      assert.are.equal("theme", settings.tabId)
      assert.is_false(settings.tabs.frame:IsShown())
      override(db, "GetMaxItemLevel", function() return 100 end)
      settings:Search(addon:GetModule("Context"):New("spec"), "icon scale")
      assert.are.same({}, settings.page.sections, "no Size tab to find")
    end)

    -- Asked: "we need a way to disable sparkles etc on any theme ... a new option under appearance with a new tab",
    -- then: "title it 'Animation'". A switch per effect, each on until turned off (next-themes.md §20).
    it("has an Animation tab with BetterBags Next, a switch per effect showing whether it is on", function()
      local on = { sparkles = true, shimmer = false, titleCloud = true, ribbon = false, braid = true, ornaments = false }
      override(db, "GetNextAnimation", function(_, name) return on[name] end)
      settings:Open("appearance", "animation")
      assert.are.equal("animation", settings.tabId)
      assert.are.equal("Effects", settings.page.sections[1].title)
      local titles = {}
      for _, row in ipairs(rowsShown()) do table.insert(titles, row.label:GetText()) end
      assert.are.same({ "Sparkles", "Title Shimmer", "Title Cloud", "Title Ribbon", "Braid", "Moving Ornaments" }, titles)
      assert.is_true(rowTitled("Sparkles").control:GetChecked())
      assert.is_false(rowTitled("Title Shimmer").control:GetChecked())
      assert.is_false(rowTitled("Title Ribbon").control:GetChecked())
      assert.is_false(rowTitled("Moving Ornaments").control:GetChecked())
    end)

    it("has no Animation tab with the classic bags, and finds the switches with BetterBags Next", function()
      override(db, "GetMaxItemLevel", function() return 100 end)
      override(db, "GetNextAnimation", function() return true end)
      design = "classic"
      settings:Open("appearance")
      settings:Search(addon:GetModule("Context"):New("spec"), "sparkles")
      assert.are.same({}, settings.page.sections, "nothing to find for the classic bags")
      design = "next"
      settings:Open("appearance")
      settings:Search(addon:GetModule("Context"):New("spec"), "sparkles")
      assert.are.equal("Appearance > Animation", settings.page.sections[1].title)
    end)

    it("finds Icon Scale with BetterBags Next", function()
      override(db, "GetMaxItemLevel", function() return 100 end)
      override(db, "GetNextIconScale", function() return 100 end)
      override(db, "GetNextBagScale", function() return 100 end)
      -- Its search box is in the window.
      settings:Open("appearance")
      settings:Search(addon:GetModule("Context"):New("spec"), "icon scale")
      assert.are.equal("Appearance > Size", settings.page.sections[1].title)
    end)
  end)

  describe("Item Colors", function()
    local colors

    before_each(function()
      colors = {
        low = { red = 0.6, green = 0.6, blue = 0.6, alpha = 1 }, mid = { red = 1, green = 1, blue = 1, alpha = 1 },
        high = { red = 0, green = 0.55, blue = 0.87, alpha = 1 }, max = { red = 1, green = 0.5, blue = 0, alpha = 1 },
      }
      override(db, "GetMaxItemLevel", function() return 100 end)
      override(db, "GetItemLevelColors", function() return colors end)
      override(db, "SetItemLevelColor", function(_, key, color) colors[key] = color end)
      override(db, "ResetItemLevelColors", function() table.insert(calls, { "ResetItemLevelColors" })
        colors.low = { red = 0.1, green = 0.1, blue = 0.1, alpha = 1 } end)
      override(db, "ResetMaxItemLevel", call("ResetMaxItemLevel"))
      ColorPickerFrame:Hide()
    end)

    it("names each color with its range of item levels, from the highest seen", function()
      settings:Open("itemcolors")
      assert.is_not_nil(rowTitled("Low Item Level Color (1-60)"))
      assert.is_not_nil(rowTitled("Mid Item Level Color (61-85)"))
      assert.is_not_nil(rowTitled("High Item Level Color (86-99)"))
      assert.is_not_nil(rowTitled("Max Item Level Color (100+)"))
      assert.are.same({ 0, 0.55, 0.87, 1 }, rowTitled("High Item Level Color (86-99)").control:GetColor())
    end)

    it("saves a color picked and has the buttons show it; cancelling puts the saved one back too", function()
      settings:Open("itemcolors")
      local row = rowTitled("Low Item Level Color (1-60)")
      click(row.control)
      ColorPickerFrame:_Pick(0.2, 0.3, 0.4, 0.5)
      assert.are.same({ red = 0.2, green = 0.3, blue = 0.4, alpha = 0.5 }, colors.low)
      assert.are.same({ "itemLevel/MaxChanged", 100 }, sent[#sent])
      ColorPickerFrame:_Cancel()
      assert.are.same({ red = 0.6, green = 0.6, blue = 0.6, alpha = 1 }, colors.low)
    end)

    it("resets the colors and the highest item level seen", function()
      settings:Open("itemcolors")
      click(button("Reset Colors"))
      assert.are.same({ "ResetItemLevelColors" }, calls[1])
      assert.are.same({ "itemLevel/MaxChanged", 100 }, sent[#sent])
      assert.are.same({ 0.1, 0.1, 0.1, 1 }, rowTitled("Low Item Level Color (1-60)").control:GetColor())
      click(button("Reset Max Item Level"))
      assert.are.equal("ResetMaxItemLevel", calls[2][1])
    end)

    it("names the ranges again when the highest item level seen changes while it shows", function()
      settings:Open("itemcolors")
      content:OnEnable()
      override(db, "GetMaxItemLevel", function() return 200 end)
      handlers["itemLevel/MaxChanged"](nil, 200)
      assert.is_not_nil(rowTitled("Max Item Level Color (200+)"))
    end)
  end)

  describe("Profiles", function()
    local current, profiles

    before_each(function()
      current, profiles = "Raid", { "Default", "Raid" }
      override(db, "GetCurrentProfileName", function() return current end)
      override(db, "GetAvailableProfiles", function() return profiles end)
      override(db, "GetProfileCharacterCounts", function() return { Default = 2, Raid = 1, Unused = 0 } end)
      override(db, "SwitchToProfile", call("SwitchToProfile"))
      override(db, "CreateProfile", function(_, name)
        table.insert(calls, { "CreateProfile", name })
        if name == "Raid" then return false, "A profile with this name already exists" end
        return true, "ok"
      end)
      override(db, "CopyFromProfile", function(_, name) table.insert(calls, { "CopyFromProfile", name }) return true, "ok" end)
      override(db, "RenameProfile", function(_, a, b) table.insert(calls, { "RenameProfile", a, b }) return true, "ok" end)
      override(db, "DeleteProfile", function(_, name) table.insert(calls, { "DeleteProfile", name }) return true, "ok" end)
      override(db, "ResetCurrentProfile", call("ResetCurrentProfile"))
      settings:Open("profiles", "profiles")
    end)

    it("shows the active profile and how many characters use each", function()
      local row = rowTitled("Active Profile")
      assert.are.equal("Raid", row.control.text:GetText())
      local found = false
      for _, r in ipairs(rowsShown()) do
        if r.label and r.label:GetText() == "Characters: Default: 2 characters  |  Raid: 1 character" then found = true end
      end
      assert.is_true(found)
    end)

    it("asks before switching profiles, then switches and reloads", function()
      local row = rowTitled("Active Profile")
      click(row.control)
      local menuRows = nextMenu:Rows()
      menuRows[1].frame:GetScript("OnClick")(menuRows[1].frame, "LeftButton")
      assert.are.equal("Raid", row.control.text:GetText(), "still the active one until the reload")
      answer("Cancel")
      assert.are.same({}, calls)
      click(row.control)
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      answer("Switch")
      assert.are.same({ { "SwitchToProfile", "Default" } }, calls)
      assert.are.equal(1, reloads)
    end)

    it("keeps asking while no name is given", function()
      click(button("New Profile"))
      nextDialog.input.frame:SetText("   ")
      answer("Create")
      assert.is_true(nextDialog:IsShown())
      assert.are.equal("Name the new profile:", nextDialog.text:GetText())
      assert.are.same({}, calls)
    end)

    it("makes a new profile and offers to switch to it, or says why it cannot", function()
      click(button("New Profile"))
      nextDialog.input.frame:SetText("Mythic")
      answer("Create")
      assert.are.same({ "CreateProfile", "Mythic" }, calls[1])
      answer("Switch")
      assert.are.same({ "SwitchToProfile", "Mythic" }, calls[2])
      assert.are.equal(1, reloads)
      click(button("New Profile"))
      nextDialog.input.frame:SetText("Raid")
      answer("Create")
      assert.are.equal("A profile with this name already exists", nextDialog.text:GetText())
    end)

    it("copies the active profile to a new one, then reloads", function()
      click(button("Copy Profile"))
      nextDialog.input.frame:SetText("Raid Copy")
      answer("Copy")
      assert.are.same({ { "CreateProfile", "Raid Copy" }, { "CopyFromProfile", "Raid" } }, calls)
      answer("Reload")
      assert.are.equal(1, reloads)
    end)

    it("renames the active profile, but never Default", function()
      click(button("Rename Profile"))
      assert.are.equal("Raid", nextDialog.input:GetText())
      nextDialog.input.frame:SetText("Heroic")
      answer("Rename")
      assert.are.same({ { "RenameProfile", "Raid", "Heroic" } }, calls)
      assert.are.equal(1, reloads)
      current = "Default"
      click(button("Rename Profile"))
      assert.are.equal("The Default profile cannot be renamed.", nextDialog.text:GetText())
    end)

    it("deletes the active profile after asking, switching to Default first, but never Default", function()
      click(button("Delete Profile"))
      answer("Delete")
      assert.are.same({ { "SwitchToProfile", "Default" }, { "DeleteProfile", "Raid" } }, calls)
      assert.are.equal(1, reloads)
      current = "Default"
      click(button("Delete Profile"))
      assert.are.equal("The Default profile cannot be deleted.", nextDialog.text:GetText())
    end)

    it("resets the active profile after asking", function()
      click(button("Reset to Defaults"))
      answer("Cancel")
      assert.are.same({}, calls)
      click(button("Reset to Defaults"))
      answer("Reset")
      assert.are.same({ { "ResetCurrentProfile" } }, calls)
      assert.are.equal(1, reloads)
    end)
  end)

  describe("Import / Export", function()
    local imported

    before_each(function()
      imported = { true, "" }
      override(db, "ExportSettings", function() return "!BB:exported" end)
      override(db, "ImportSettings", function(_, text)
        table.insert(calls, { "ImportSettings", text })
        return imported[1], imported[2]
      end)
      settings:Open("profiles", "transfer")
    end)

    it("exports the categories into its text area, selected to copy", function()
      click(button("Export Categories"))
      assert.are.equal("!BB:exported", content.exportArea.area:GetText())
      assert.is_true(content.exportArea.area.editBox:HasFocus())
    end)

    it("imports the categories pasted after asking, and offers to reload", function()
      content.importArea.area:SetText("!BB:pasted")
      click(button("Import Categories"))
      answer("Import")
      assert.are.same({ { "ImportSettings", "!BB:pasted" } }, calls)
      assert.are.equal("", content.importArea.area:GetText())
      answer("Reload")
      assert.are.equal(1, reloads)
    end)

    it("says what is wrong: nothing pasted, or a string it cannot read", function()
      click(button("Import Categories"))
      assert.are.equal("Paste a category configuration string to import first.", nextDialog.text:GetText())
      answer("OK")
      imported = { false, "bad string" }
      content.importArea.area:SetText("junk")
      click(button("Import Categories"))
      answer("Import")
      assert.are.equal("The categories could not be imported: bad string", nextDialog.text:GetText())
      assert.are.equal("junk", content.importArea.area:GetText())
    end)
  end)

  describe("QuickFind", function()
    it("says what the integration does", function()
      settings:Open("quickfind")
      assert.is_true(#rowsShown() >= 2)
      assert.is_true(rowsShown()[1].label:GetText():find("QuickFind") ~= nil)
    end)
  end)

  describe("a plugin's page", function()
    local state, handler

    local function plugin()
      state = { enabled = true, mode = "b", size = 5, name = "x", notes = "hi", color = { 1, 0, 0, 0.5 }, ran = 0 }
      handler = { info = {} }
      function handler:GetSize(info) table.insert(self.info, info) return state.size end
      function handler:SetSize(info, value) table.insert(self.info, info) state.size = value end
      return {
        enabled = { type = "toggle", name = "Enabled", desc = "Turns it on.", order = 1,
          get = function(info) assert.are.equal("enabled", info[#info]) return state.enabled end,
          set = function(_, value) state.enabled = value end },
        mode = { type = "select", name = "Mode", order = 2,
          values = { a = "Echo", b = "Delta", c = "Charlie", d = "Bravo", e = "Alpha" },
          get = function() return state.mode end, set = function(_, value) state.mode = value end },
        sorted = { type = "select", name = "Sorted", order = 2.5, values = { x = "Ex", y = "Why", z = "Zed" },
          sorting = { "z", "x", "y" }, get = function() return "x" end, set = function() end },
        hidden = { type = "toggle", name = "Hidden", hidden = true, get = function() return true end, set = function() end },
        run = { type = "execute", name = "Run", order = 3, func = function() state.ran = state.ran + 1 end },
        about = { type = "description", name = "Some words.", order = 0 },
        look = { type = "group", name = "Look", order = 10, handler = handler, get = "GetSize", set = "SetSize", args = {
          size = { type = "range", name = "Size", min = 1, max = 10, step = 1, order = 1 },
          tint = { type = "color", name = "Tint", hasAlpha = true, order = 2,
            get = function() return unpack(state.color) end,
            set = function(_, r, g, b, a) state.color = { r, g, b, a } end },
          label = { type = "input", name = "Label", order = 3, get = function() return state.name end,
            set = function(_, value) state.name = value end,
            validate = function(_, value) return value ~= "" or "Label: it needs a name" end },
          notes = { type = "input", name = "Notes", multiline = true, order = 4, get = function() return state.notes end,
            set = function(_, value) state.notes = value end },
          danger = { type = "execute", name = "Wipe", order = 5, confirm = true, confirmText = "Wipe everything?",
            func = function() state.ran = state.ran + 10 end },
        } },
      }
    end

    before_each(function()
      content:AddPlugin("Some Plugin", plugin())
      settings:Open("plugin:Some Plugin")
    end)

    it("is a page under Integrations, after QuickFind, a section per group in AceConfig's order", function()
      local page = pages:Get("plugin:Some Plugin")
      assert.are.equal("Integrations", page.group)
      local list = pages:List()
      assert.are.equal(page, list[#list])
      -- What is laid out: a hidden option (order 100, after Look) is left out, and its section with it.
      local titles = {}
      for _, title in ipairs(settings.page.titles) do
        if title:IsShown() then table.insert(titles, title:GetText()) end
      end
      assert.are.same({ "SOME PLUGIN", "LOOK" }, titles)
      local labels = {}
      for _, row in ipairs(settings.page.sections[1].rows) do
        if row.frame:IsShown() then
          table.insert(labels, row.label and row.label:GetText() or (row.buttons and row.buttons[1].label:GetText()))
        end
      end
      assert.are.same({ "Some words.", "Enabled", "Mode", "Sorted", "Run" }, labels, "by order")
      local hidden = rowTitled("Hidden")
      assert.is_false(hidden.frame:IsShown(), "hidden left out")
    end)

    it("reads and writes a toggle with AceConfig's info", function()
      local row = rowTitled("Enabled")
      assert.is_true(row.control:GetChecked())
      click(row.control)
      assert.is_false(state.enabled)
    end)

    it("shows a select's names and writes its keys", function()
      local row = rowTitled("Mode")
      assert.are.equal("Delta", row.control.text:GetText())
      click(row.control)
      local names = {}
      for _, r in ipairs(nextMenu:Rows()) do table.insert(names, r.label:GetText()) end
      assert.are.same({ "Echo", "Delta", "Charlie", "Bravo", "Alpha" }, names, "sorted by key, as AceConfig sorts them")
      nextMenu:Rows()[1].frame:GetScript("OnClick")(nextMenu:Rows()[1].frame, "LeftButton")
      assert.are.equal("a", state.mode)
    end)

    it("lists a select's names in its own sorting when it has one", function()
      local row = rowTitled("Sorted")
      click(row.control)
      local names = {}
      for _, r in ipairs(nextMenu:Rows()) do table.insert(names, r.label:GetText()) end
      assert.are.same({ "Zed", "Ex", "Why" }, names)
    end)

    it("calls a handler's methods named by a group, for its options", function()
      local row = rowTitled("Size")
      assert.are.equal(5, row.control:GetValue())
      row.control.value.frame:SetText("7")
      row.control.value.frame:GetScript("OnEnterPressed")(row.control.value.frame)
      assert.are.equal(7, state.size)
      local info = handler.info[#handler.info]
      assert.are.same({ "look", "size" }, { info[1], info[2] })
      assert.are.equal("range", info.type)
      assert.are.equal(handler, info.handler)
    end)

    it("reads and writes a color, with its alpha", function()
      local row = rowTitled("Tint")
      assert.are.same({ 1, 0, 0, 0.5 }, row.control:GetColor())
      click(row.control)
      ColorPickerFrame:_Pick(0, 1, 0, 0.25)
      assert.are.same({ 0, 1, 0, 0.25 }, state.color)
    end)

    it("refuses a value its validate rejects, saying why", function()
      local row = rowTitled("Label")
      row.control.frame:SetText("")
      row.control.frame:GetScript("OnEnterPressed")(row.control.frame)
      assert.are.equal("x", state.name)
      assert.are.equal("Label: it needs a name", nextDialog.text:GetText())
      answer("OK")
      assert.are.equal("x", row.control:GetText(), "the field shows the value again")
      row.control.frame:SetText("y")
      row.control.frame:GetScript("OnEnterPressed")(row.control.frame)
      assert.are.equal("y", state.name)
    end)

    it("writes a multi-line input when Accept is clicked", function()
      local area
      for _, row in ipairs(rowsShown()) do
        if row.area then area = row end
      end
      assert.are.equal("hi", area.area:GetText())
      area.area:SetText("new notes")
      click(button("Accept"))
      assert.are.equal("new notes", state.notes)
    end)

    it("runs an execute, asking first when it must be confirmed", function()
      click(button("Run"))
      assert.are.equal(1, state.ran)
      click(button("Wipe"))
      assert.are.equal("Wipe everything?", nextDialog.text:GetText())
      answer("Cancel")
      assert.are.equal(1, state.ran)
      click(button("Wipe"))
      answer("Accept")
      assert.are.equal(11, state.ran)
    end)

    it("takes an AceConfig group as well as its args", function()
      content:AddPlugin("Grouped", { type = "group", args = { on = { type = "toggle", name = "On",
        get = function() return true end, set = function() end } } })
      settings:Open("plugin:Grouped")
      assert.is_not_nil(rowTitled("On"))
    end)

    -- AceConfigDialog reads hidden, disabled and names again after every change. Real plugins rely on
    -- it: BetterBags_ImportExport shows its "Unknown Items" header, list and Recheck button only once an
    -- export found unknown items. The classic window ignored hidden; read once, they never showed.
    describe("what a plugin shows, hides and disables as it changes", function()
      local live

      local function shownTitles()
        local list = {}
        for _, title in ipairs(settings.page.titles) do
          if title:IsShown() then table.insert(list, title:GetText()) end
        end
        return list
      end

      local function rowWith(text)
        for _, row in ipairs(rowsShown()) do
          for _, b in ipairs(row.buttons or {}) do
            if b.label:GetText() == text then return row, b end
          end
        end
      end

      before_each(function()
        live = { errors = "", name = "Recheck Items", locked = true }
        local function unknown() return live.errors == "" end
        content:AddPlugin("Export", {
          export = { type = "execute", name = "Export", order = 1, func = function() live.errors = "1,2," end },
          errorsection = { type = "header", name = "Unknown Items", order = 2, hidden = unknown },
          errors = { type = "input", multiline = 3, name = "Items with no name", order = 3, hidden = unknown,
            get = function() return live.errors end, set = function() end },
          recheck = { type = "execute", name = function() return live.name end, order = 4, hidden = unknown,
            disabled = function() return live.locked end, func = function() live.ran = true end },
          gone = { type = "group", inline = true, name = "Gone", order = 5, hidden = true, args = {
            inner = { type = "toggle", name = "Inner", hidden = false, get = function() return true end,
              set = function() end },
            sub = { type = "group", inline = true, name = "Sub", hidden = false, args = {
              deep = { type = "toggle", name = "Deep", get = function() return true end, set = function() end },
            } },
          } },
          quiet = { type = "header", name = "Quiet Header", order = 6, hidden = true },
          after = { type = "toggle", name = "After Quiet", order = 7, get = function() return true end,
            set = function() end },
        })
        settings:Open("plugin:Export")
      end)

      it("shows what it hid once a change makes it shown", function()
        assert.are.same({ "EXPORT" }, shownTitles())
        assert.is_false((rowWith("Recheck Items")).frame:IsShown())
        local _, export = rowWith("Export")
        export.frame:GetScript("OnClick")(export.frame, "LeftButton")
        render:Flush()
        assert.are.same({ "EXPORT", "UNKNOWN ITEMS" }, shownTitles())
        assert.is_true((rowWith("Recheck Items")).frame:IsShown())
      end)

      it("never shows what is in a hidden group, whatever it says of itself", function()
        local _, export = rowWith("Export")
        export.frame:GetScript("OnClick")(export.frame, "LeftButton")
        render:Flush()
        for _, name in ipairs({ "Inner", "Deep" }) do
          local row = rowTitled(name)
          assert.is_false(row ~= nil and row.frame:IsShown(), name)
        end
        for _, title in ipairs(shownTitles()) do
          assert.are_not.equal("GONE", title)
          assert.are_not.equal("SUB", title)
        end
      end)

      -- A header is a line: hiding it hides the line, never the options after it (AceConfigDialog).
      it("hides only the line of a hidden header, not the options after it", function()
        assert.is_true(rowTitled("After Quiet").frame:IsShown())
        for _, title in ipairs(shownTitles()) do
          assert.are_not.equal("QUIET HEADER", title)
        end
      end)

      it("disables a button while the plugin says so, and names it as the plugin does now", function()
        local _, export = rowWith("Export")
        export.frame:GetScript("OnClick")(export.frame, "LeftButton")
        local _, recheck = rowWith("Recheck Items")
        assert.is_false(recheck.frame:IsEnabled())
        live.locked, live.name = false, "Check Again"
        settings:Refresh()
        assert.is_true(recheck.frame:IsEnabled())
        assert.are.equal("Check Again", recheck.label:GetText())
        recheck.frame:GetScript("OnClick")(recheck.frame, "LeftButton")
        assert.is_true(live.ran)
      end)
    end)
  end)

  -- BetterBags Next, pixel perfect (docs/next-pixel-perfect.md): every page and tab of the settings window,
  -- at rest, on whole screen pixels, on the reporter's window at 65% and 70%, a common screen at 64% and a
  -- large one at 115% (where the window scales itself down to fit), for both designs.
  describe("on the screen's pixels", function()
    local layout = dofile("spec/helpers/layout.lua")
    local pixel = addon:GetModule("NextPixel")
    local undo

    after_each(function()
      if undo then undo() undo = nil end
      settings:Close()
      for _ = 1, 3 do tween:Step(5) end
    end)

    local function settle()
      for _ = 1, 3 do
        tween:Step(5)
        render:Flush()
      end
    end

    local function offGrid()
      settle()
      return layout.PixelCheck(settings.frame, { owners = { settings = settings } })
    end

    -- Every setting the real catalog and panes read (config/catalog.lua, next/settings/*.lua), at
    -- core/constants.lua's defaults, so every page opens with what a fresh profile shows.
    before_each(function()
      local function per(value)
        return function() return value end
      end
      local stacking = { mergeStacks = true, mergeUnstackable = true, unmergeAtShop = true, dontMergePartial = false,
        dontMergeTransmog = false }
      local size = { columnCount = 2, itemsPerRow = 7, scale = 100, width = 700, height = 500, opacity = 89,
        sizeMode = "content", snapToContent = true }
      local filters = { Type = true, Subtype = false, Expansion = false, TradeSkill = false, RecentItems = true,
        GearSet = true, EquipmentLocation = true }
      local colors = { low = { red = 0.62, green = 0.62, blue = 0.62, alpha = 1 }, mid = { red = 1, green = 1, blue = 1, alpha = 1 },
        high = { red = 0, green = 0.55, blue = 0.87, alpha = 1 }, max = { red = 1, green = 0.5, blue = 0, alpha = 1 } }
      local profile = { newItemTime = 300 }
      for name, value in pairs({
        GetAnimateItemMovement = per(false), GetBagSizeInfo = per(size), GetBagSizeMode = per("content"),
        GetBagSnapToContent = per(true), GetBagView = per(2), GetCategoryFilters = per(filters),
        GetCategorySell = per(false), GetChangelogAutoOpen = per(true), GetCustomSectionSort = per({}),
        GetData = per({ profile = profile }), GetEnableBagFading = per(false), GetEnableBankBag = per(true),
        GetEnterToMakeCategory = per(true), GetGlowIntensity = per(60), GetGroupsEnabled = per(false),
        GetInBagSearch = per(true), GetItemLevelColors = per(colors), GetItemLevelOptions = per({ enabled = true, color = true }),
        GetItemSortType = per(1), GetMarkRecentItems = per(false), GetMaxItemLevel = per(1), GetNextBagScale = per(100),
        GetNextEnabled = per(design == "next"), GetNextIconScale = per(100), GetPreserveItemGaps = per(true),
        GetSectionSortType = per(1), GetShowAllFreeSpace = per(false), GetShowBagButton = per(true),
        GetShowFullSectionNames = per(false), GetShowNewItemFlash = per(false), GetStackingOptions = per(stacking),
        GetCurrentProfileName = per("Default"), GetAvailableProfiles = per({ "Default" }),
        GetProfileCharacterCounts = per({ Default = 1 }),
      }) do
        override(db, name, value)
      end
      local items = addon:GetModule("Items")
      override(items, "GetActiveUpgradeProvider", per("None"))
      -- Two categories: one of added items, one by a search rule (data/categories.lua's shapes).
      local cats = addon:GetModule("Categories")
      local categoryFilters = {
        Mats = { name = "Mats", itemList = { [2589] = true, [2592] = true }, enabled = { [0] = true, [1] = true },
          priority = 10 },
        Potions = { name = "Potions", itemList = {}, searchCategory = { query = "type = consumable" },
          enabled = { [0] = true, [1] = true }, priority = 20 },
      }
      override(cats, "GetOrder", per({ "Mats", "Potions" }))
      override(cats, "GetAllCategories", per(categoryFilters))
      override(cats, "GetCategoryByName", function(_, name) return categoryFilters[name] end)
      override(cats, "DoesCategoryExist", function(_, name) return categoryFilters[name] ~= nil end)
      override(cats, "GetMergedCategory", function(_, name)
        return { name = name, itemList = categoryFilters[name] and categoryFilters[name].itemList or {} }
      end)
      override(cats, "RuleOf", function(_, filter)
        return filter and filter.searchCategory and filter.searchCategory.query or nil
      end)
      override(cats, "GetIgnoredItems", per({}))
      override(cats, "IgnoresItem", per(false))
      -- The classic bags' themes (Sonata), for their picker on Appearance.
      local classicThemes = {
        Default = { Name = "Default", DisplayName = "Default", Description = "Blizzard's look." },
        SimpleDark = { Name = "SimpleDark", DisplayName = "Simple Dark", Description = "A dark, flat look." },
      }
      override(sonata, "GetThemes", per(classicThemes))
      override(sonata, "IsAvailable", per(true))
      override(sonata, "IsSelectable", per(true))
      override(sonata, "GetCurrentThemeKey", per("Default"))
      override(sonata, "GetSavedThemeKey", per("Default"))
      override(sonata, "RestoreSavedTheme", function() end)
      override(sonata, "ApplyTheme", function() end)
      -- A client with currencies (retail), for the classic bags' Currency page: Blizzard's list, a heading
      -- and two currencies (CurrencyConstantsDocumentation's CurrencyInfo fields).
      override(addon, "isRetail", true)
      local currencies = {
        { name = "Dungeon and Raid", isHeader = true, isHeaderExpanded = true },
        { name = "Valor", quantity = 1234, maxQuantity = 3000, iconFileID = 101, isShowInBackpack = true },
        { name = "Honor", quantity = 50, maxQuantity = 0, iconFileID = 102, isShowInBackpack = false },
      }
      override(_G, "C_CurrencyInfo", setmetatable({
        GetCurrencyListSize = function() return #currencies end,
        GetCurrencyListInfo = function(i) return currencies[i] end,
        ExpandCurrencyList = function() end,
        SetCurrencyBackpack = function() end,
      }, { __index = _G.C_CurrencyInfo }))
    end)

    for _, screen in ipairs({ { 3396, 1362, 0.65 }, { 3396, 1362, 0.70 }, { 1920, 1080, 0.64 }, { 2560, 1440, 1.15 } }) do
      for _, which in ipairs({ "next", "classic" }) do
        local name = string.format("%dx%d at %d%%, %s", screen[1], screen[2], screen[3] * 100, which)
        it("draws every page and tab on whole pixels, " .. name, function()
          design = which
          undo = layout.UseScreen(screen[1], screen[2], screen[3])
          local problems = {}
          local listed = {}
          for _, page in ipairs(pages:List()) do listed[page.id] = true end
          assert.are.equal(which == "classic", listed.currency == true, "the classic bags' Currency page")
          for _, page in ipairs(pages:List()) do
            for _, tab in ipairs(pages:ShownTabs(page)) do
              settings:Open(page.id, tab.id)
              for _, line in ipairs(offGrid()) do
                table.insert(problems, page.id .. "/" .. tab.id .. ": " .. line)
              end
              -- Scrolled partway: its content, and the list of pages.
              settings.scroll.scrollBox._scrollRange = pixel:Length(settings.frame, 517)
              settings.scroll.scrollBox:SetScrollPercentage(0.37, true)
              settings.navBox._scrollRange = pixel:Length(settings.frame, 83)
              settings.navBox:SetScrollPercentage(0.61, true)
              for _, line in ipairs(offGrid()) do
                table.insert(problems, page.id .. "/" .. tab.id .. " scrolled: " .. line)
              end
              settings.scroll.scrollBox._scrollRange, settings.navBox._scrollRange = nil, nil
              settings.scroll.scrollBox:SetScrollPercentage(0, true)
              settings.navBox:SetScrollPercentage(0, true)
            end
          end
          assert.are.same({}, problems)
        end)
      end
    end
  end)
end)
