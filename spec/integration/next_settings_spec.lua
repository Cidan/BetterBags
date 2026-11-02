-- next_settings_spec.lua -- BetterBags Next's settings window (next-settings.md) on the whole addon
-- (spec/helpers/whole_addon.lua): every file of the TOC loaded and started as the client does, with the
-- real database, catalog, categories and bags. One settings window for both designs (next-settings.md
-- §7): it opens for either, builds every page and tab of each, finds settings, and turning BetterBags
-- Next off from it shows the classic bags' settings without closing.
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("BetterBags Next's settings window on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
      handle = nil
    end
  end)

  local function start(opts)
    handle = WholeAddon.Load(opts)
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  local function ctx(addon)
    return addon:GetModule("Context"):New("spec")
  end

  local function rowOf(settings, id)
    for _, section in ipairs(settings.page.sections) do
      for _, row in ipairs(section.rows) do
        if row.option and row.option.id == id then
          return row
        end
      end
    end
  end

  -- builtEveryTab opens every page and tab the design in use has and returns them, "page > tab".
  local function builtEveryTab(addon)
    local settings = addon:GetModule("NextSettings")
    local pages = addon:GetModule("NextSettingsPages")
    local built = {}
    for _, page in ipairs(pages:List()) do
      -- Every tab for the bags in use, those shown only once something is chosen included.
      for _, tab in ipairs(page.tabs) do
        if pages:InDesign(tab) then
          settings:Open(page.id, tab.id)
          assert.are.same({}, handle.errors, page.id .. " > " .. tab.id)
          assert.are.equal(page.id, settings.pageId)
          assert.are.equal(tab.id, settings.tabId, page.id .. " > " .. tab.id .. " shows")
          assert.is_true(#settings.page.sections > 0, page.id .. " > " .. tab.id .. " shows something")
          table.insert(built, page.id .. " > " .. tab.id)
        end
      end
    end
    return built
  end

  -- A category of the player's, so the Categories page shows its Rule and Added Items tabs too.
  local function makeCategory(addon)
    addon:GetModule("Categories"):CreateCategory(ctx(addon), { name = "Spec Mats", itemList = { [2589] = true },
      save = true, searchCategory = { query = "type = trade goods" } })
  end

  -- On the real database: a bag nobody has set anything on.
  it("starts every bag in two columns, side to side, wide sections spanning them, its largest section first", function()
    local addon = start({ next = true })
    local database, const = addon:GetModule("Database"), addon:GetModule("Constants")
    for _, panel in ipairs({ addon.Bags.Backpack, addon.Bags.Bank, addon.Bags.GuildBank }) do
      assert.are.same({ 2, "across", true, 2 }, { panel:SectionColumns() }, "bag " .. panel.kind)
      assert.are.equal(const.SECTION_SORT_TYPE.SIZE_DESCENDING,
        database:GetSectionSortType(panel.kind, const.BAG_VIEW.SECTION_GRID), "bag " .. panel.kind)
    end
    assert.are.same({}, handle.errors)
  end)

  -- Asked of the default of largest section first: "i did mean bbn here".
  it("leaves the classic bags' sections alphabetical, and each design keeps its own through a switch", function()
    local addon = start()
    local database, const = addon:GetModule("Database"), addon:GetModule("Constants")
    local function sort() return database:GetSectionSortType(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID) end
    assert.are.equal(const.SECTION_SORT_TYPE.ALPHABETICALLY, sort())
    addon:GetModule("BagSystem"):Switch(ctx(addon), "next")
    assert.are.equal(const.SECTION_SORT_TYPE.SIZE_DESCENDING, sort())
    database:SetSectionSortType(const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, const.SECTION_SORT_TYPE.SIZE_ASCENDING)
    addon:GetModule("BagSystem"):Switch(ctx(addon), "classic")
    assert.are.equal(const.SECTION_SORT_TYPE.ALPHABETICALLY, sort())
    addon:GetModule("BagSystem"):Switch(ctx(addon), "next")
    assert.are.equal(const.SECTION_SORT_TYPE.SIZE_ASCENDING, sort())
    assert.are.same({}, handle.errors)
  end)

  it("opens for BetterBags Next and builds every page and tab", function()
    local addon = start({ next = true })
    makeCategory(addon)
    local settings = addon:GetModule("NextSettings")
    addon:GetModule("Events"):SendMessage(ctx(addon), "config/Open")
    assert.is_true(settings:IsShown())
    assert.is_nil(addon:GetModule("Config").configFrame, "no classic window")
    assert.are.same({ "general > main", "appearance > theme", "appearance > size", "appearance > animation",
      "itemcolors > main",
      "categories > settings",
      "categories > rule", "categories > items", "categories > ignored", "categories > automation",
      "currencies > tracked", "currencies > currencies", "currencies > items", "currencies > display",
      "backpack > layout", "backpack > items", "backpack > categories", "backpack > order", "bank > layout", "bank > items",
      "bank > categories", "bank > order", "guild > layout", "guild > items", "guild > categories", "guild > order",
      "profiles > profiles",
      "profiles > transfer", "quickfind > main" }, builtEveryTab(addon))
    settings:Close()
    assert.are.same({}, handle.errors, "closing")
  end)

  -- Asked: "no scrollbox within tabs, just make the whole list scroll the tab content itself".
  it("scrolls a bag's Order tab with the tab's own content", function()
    local addon = start({ next = true })
    local categories = addon:GetModule("Categories")
    for i = 1, 40 do
      categories:CreateCategory(ctx(addon), { name = "Spec " .. i, itemList = {}, save = true })
    end
    local settings = addon:GetModule("NextSettings")
    settings:Open("backpack", "order")
    assert.are.same({}, handle.errors)
    local blocks = addon:GetModule("NextSettingsBagCategories").all
    local block = blocks[#blocks]
    assert.is_not_nil(block:RowFor("Spec 40"), "listed")
    assert.is_nil(block.listBox, "no scroll box of its own")
    assert.is_true(block:Measure(600) > settings:ContentHeight(), "taller than the tab shows")
    assert.is_true(settings.scroll.scrollChild:GetHeight() >= block:Measure(600), "and what the tab scrolls holds it")
    assert.are.same({}, handle.errors)
  end)

  -- The Categories page on the real window (next-settings.md §5): its list slides into the sidebar, the
  -- chosen category titles the page, and the first Escape goes back.
  it("shows the Categories page's list in the sidebar, the category chosen in the header", function()
    local addon = start({ next = true })
    makeCategory(addon)
    local settings = addon:GetModule("NextSettings")
    settings:Open("general")
    settings:Select("categories")
    assert.are.same({}, handle.errors)
    local list = settings.lists[settings.sidebarPage]
    assert.is_not_nil(list:RowFor("Spec Mats"))
    assert.are.equal("Spec Mats", addon:GetModule("NextSettingsCategories").selected)
    assert.are.equal("Spec Mats", settings.title:GetText())
    local listed = {}
    for _, name in ipairs(UISpecialFrames) do listed[name] = true end
    assert.is_true(listed.BetterBagsNextSettingsBack, "the first Escape goes back")
    assert.is_nil(listed.BetterBagsNextSettings, "not closing the window")
    settings.backKey:Hide()
    settings.backKey:GetScript("OnHide")(settings.backKey)
    assert.are.equal("general", settings.pageId)
    assert.is_nil(settings.sidebarPage)
    assert.are.same({}, handle.errors)
  end)

  it("reads the real settings into its rows", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    local db = addon:GetModule("Database")
    settings:Open("backpack", "items")
    local row = rowOf(settings, "mergeStacks")
    assert.are.equal(db:GetStackingOptions(0).mergeStacks == true, row.control:GetChecked())
    settings:Open("general")
    assert.is_true(rowOf(settings, "nextEnabled").control:GetChecked())
  end)

  it("lays out a bag's section columns through its real settings, and shows them on one line", function()
    local addon = start({ next = true })
    local db = addon:GetModule("Database")
    db:SetNextSectionColumns(1, 1)
    local settings = addon:GetModule("NextSettings")
    settings:Open("backpack", "layout")
    local c = ctx(addon)
    rowOf(settings, "sectionColumns").option.set(c, 3)
    rowOf(settings, "sectionFill").option.set(c, "Top to Bottom")
    rowOf(settings, "sectionWideRows").option.set(c, 3)
    assert.are.equal(3, db:GetNextSectionColumns(0))
    assert.are.equal("down", db:GetNextSectionFill(0))
    assert.are.equal(3, db:GetNextSectionWideRows(0))
    assert.are.equal(1, db:GetNextSectionColumns(1), "another bag keeps its own")
    addon:GetModule("Render"):Flush()
    assert.is_not_nil(addon.Bags.Backpack.content.grid)
    assert.is_nil(addon.Bags.Bank.content.grid)
    assert.are.same({}, handle.errors)
  end)

  -- Reported: after Tracker Layout went from Row to Column, Tracker Grows still said "Left" (its menu offered Up and
  -- Down, the tracker grew down). Its value follows the layout, so the page shows every value again after a change.
  it("shows Tracker Grows by the layout chosen as soon as Tracker Layout changes", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    settings:Open("currencies", "display")
    local layout, grows = rowOf(settings, "nextCurrencyLayout"), rowOf(settings, "nextCurrencyGrow")
    assert.are.equal("Row", layout.control.text:GetText())
    assert.are.equal("Left", grows.control.text:GetText())
    layout.control:Pick(ctx(addon), "Column")
    assert.are.same({}, handle.errors)
    assert.are.equal("Down", grows.control.text:GetText())
    grows.control:Pick(ctx(addon), "Up")
    layout.control:Pick(ctx(addon), "List")
    assert.are.equal("Up", grows.control.text:GetText(), "a list grows the way a column does")
    layout.control:Pick(ctx(addon), "Row")
    assert.are.equal("Left", grows.control.text:GetText())
  end)

  it("finds settings by what they do", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    settings:Open()
    settings:Search(ctx(addon), "stack")
    assert.are.same({}, handle.errors)
    assert.is_true(#settings.page.sections >= 2, "the stacking settings of every bag")
  end)

  it("opens for the classic bags too, with their own settings, and builds every page and tab", function()
    local addon = start({})
    makeCategory(addon)
    local settings = addon:GetModule("NextSettings")
    addon:GetModule("Events"):SendMessage(ctx(addon), "config/Open")
    assert.is_true(settings:IsShown())
    assert.are.same({ "general > main", "appearance > theme", "itemcolors > main", "categories > settings",
      "categories > rule", "categories > items", "categories > ignored", "categories > automation", "currency > main",
      "backpack > layout", "backpack > items", "backpack > categories", "backpack > order", "bank > layout", "bank > items",
      "bank > categories", "bank > order", "profiles > profiles", "profiles > transfer", "quickfind > main" }, builtEveryTab(addon))
    settings:Open("backpack", "layout")
    assert.is_not_nil(rowOf(settings, "itemsPerRow"), "rows and columns, for the classic bags")
    assert.is_not_nil(rowOf(settings, "columns"))
  end)

  it("shows the classic bags' settings, staying open, when BetterBags Next is turned off from it", function()
    local addon = start({ next = true })
    local settings = addon:GetModule("NextSettings")
    settings:Open("general")
    assert.is_nil(rowOf(settings, "bagFading"))
    local row = rowOf(settings, "nextEnabled")
    row.control.frame:GetScript("OnClick")(row.control.frame, "LeftButton")
    assert.are.same({}, handle.errors, "switching")
    assert.are.equal("classic", addon:GetModule("BagSystem"):ActiveDesign())
    assert.is_true(settings:IsShown())
    assert.are.equal("general", settings.pageId)
    assert.is_not_nil(rowOf(settings, "bagFading"), "the classic bags' own settings")
    assert.is_false(rowOf(settings, "nextEnabled").control:GetChecked())
  end)
end)
