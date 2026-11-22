-- help_spec.lua -- NextSettingsHelp and NextHelpArticle (next/settings/help.lua, article.lua): the Help page of the
-- settings window (help.md §4, §5). Its sidebar slides the pages away for a tree of articles under their groups, every
-- group open; its home asks "What do you need help with?" over a search box and the featured
-- articles; typing glides the box to the top and ranks the articles as cards; an article shows its blocks, its related
-- articles and its neighbours. Everything moves: the tree cascades in, its selection glides, the views slide.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")
local L = StubBetterBagsModule("Localization")
L.G = L.G or function(_, key) return key end
local events = StubBetterBagsModule("Events")
local catalog = StubBetterBagsModule("SettingsCatalog")
local bagSystem = StubBetterBagsModule("BagSystem")
for _, m in ipairs({ { "NextStyle", "next/style.lua" }, { "NextTween", "next/tween.lua" },
  { "NextFrameArt", "next/frameart.lua" }, { "NextFill", "next/fill.lua" }, { "NextControls", "next/controls/base.lua" },
  { "NextScrollBar", "next/controls/scrollbar.lua" }, { "NextButton", "next/controls/button.lua" },
  { "NextToggle", "next/controls/toggle.lua" }, { "NextInput", "next/controls/input.lua" },
  { "NextSlider", "next/controls/slider.lua" }, { "NextMenu", "next/controls/menu.lua" },
  { "NextDropdown", "next/controls/dropdown.lua" }, { "NextSwatch", "next/controls/swatch.lua" },
  { "NextTopTabs", "next/controls/toptabs.lua" }, { "NextLift", "next/lift.lua" },
  { "NextDialog", "next/controls/dialog.lua" }, { "NextSettingsRows", "next/settings/rows.lua" },
  { "NextSettingsPage", "next/settings/page.lua" }, { "NextSettingsPages", "next/settings/pages.lua" },
  { "HelpSearch", "help/search.lua" }, { "HelpArticles", "help/articles.lua" },
  { "NextSettingsNav", "next/settings/nav.lua" }, { "NextSettings", "next/settings/window.lua" },
  { "NextSettingsCards", "next/settings/cards.lua" }, { "NextHelpArticle", "next/settings/article.lua" },
  { "NextSettingsHelp", "next/settings/help.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end

local settings = addon:GetModule("NextSettings")
local pages = addon:GetModule("NextSettingsPages")
local articles = addon:GetModule("HelpArticles")
local help = addon:GetModule("NextSettingsHelp")
local tween = addon:GetModule("NextTween")
local motion = addon:GetModule("Motion")
local style = addon:GetModule("NextStyle")
local context = addon:GetModule("Context")
local render = addon:GetModule("Render")
local controls = addon:GetModule("NextControls")

local function H()
  return style.Theme.Settings.Help
end

-- settle runs every animation to its end.
local function settle()
  for _ = 1, 4 do
    tween:Step(10)
    motion:Step(10)
  end
end

local function ctx()
  return context:New("spec")
end

local function click(button)
  button:GetScript("OnClick")(button, "LeftButton")
end

-- typed types text into a search box as the player does.
local function typed(input, text)
  input.frame:SetText(text)
  input.frame:GetScript("OnTextChanged")(input.frame, true)
end

describe("NextSettingsHelp", function()
  local values, saved, design, sent, handlers

  local function defineArticles()
    articles:Clear()
    articles:Group({ id = "start", title = "Getting Started" })
    articles:Group({ id = "bags", title = "Your Bags" })
    articles:Group({ id = "classic", title = "Classic Only" })
    articles:Define({
      id = "welcome", group = "start", title = "Welcome to BetterBags", featured = true,
      summary = "What BetterBags does with your bags.",
      body = {
        { text = "BetterBags sorts your items into sections." },
        { heading = "Where to start" },
        { list = { "Open your bags.", "Look at the sections." } },
        { steps = { "Open the settings.", "Pick a page." } },
        { tip = "Right-click the bag button for its menu." },
        { warning = "Reloading resets nothing." },
        { see = "search" },
        { open = { page = "general", text = "Open the General settings" } },
        { setting = "fade" },
      },
      related = { "search", "sort" },
    })
    articles:Define({
      id = "next", group = "start", title = "BetterBags Next", summary = "The redesigned bags.", design = "next",
      body = { { text = "Switch it on in General." } },
    })
    articles:Define({
      id = "search", group = "bags", title = "Searching your bags", featured = true,
      summary = "Find any item by typing.", keywords = { "find", "filter" },
      body = { { text = "Type in the search box at the top of your bags." },
        { heading = "ilvl", keyword = true },
        { example = "ilvl >= 600", text = "Items of item level 600 and up." } },
    })
    articles:Define({
      id = "sort", group = "bags", title = "Sorting", summary = "How items are ordered.",
      body = { { text = "Items sort by quality, then name." } },
    })
    articles:Define({
      id = "old", group = "classic", title = "The classic window", design = "classic",
      summary = "The classic bags' window.", body = { { text = "Only with the classic bags." } },
    })
  end

  local function definePages()
    pages:Clear()
    pages:Define({
      id = "general", group = "BetterBags", title = "General", description = "How BetterBags works.",
      tabs = { { id = "main", title = "General", sections = { { title = "Bags", rows = { {
        option = { kind = "toggle", title = "Enable Fading", description = "Fade the bags.",
          get = function() return values.fade end, set = function(_, v) values.fade = v end },
      } } },
        -- The catalog's settings as the window shows them; an article shows a setting only where the window does.
        { title = "Fading", rows = { { setting = "fade", hidden = function() return values.hideFade == true end },
          { setting = "quick" },
          { setting = "secret", hidden = function() return true end } } } } } },
    })
    pages:Define(help:Page())
  end

  local function view()
    for _, v in ipairs(help.views) do
      if v.frame:IsVisible() then
        return v
      end
    end
  end

  local function tree()
    for _, t in ipairs(help.trees) do
      if t.frame:IsVisible() then
        return t
      end
    end
  end

  -- treeLabels lists the tree's rows shown, in order: headings in capitals as the list draws them.
  local function treeLabels()
    local list = {}
    for _, entry in ipairs(tree().entries) do
      table.insert(list, tree().byKey[entry.key].label:GetText())
    end
    return list
  end

  local function resultTitles()
    local list = {}
    for _, card in ipairs(view().shownCards) do
      table.insert(list, card.name:GetText())
    end
    return list
  end

  before_each(function()
    values = { fade = false }
    sent = {}
    design = "next"
    handlers = {}
    saved = { _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign, catalog.Has, catalog.Get,
      events.RegisterMessage, catalog.Bags }
    _G.UISpecialFrames = {}
    C_Timer.After = function() end
    -- Messages reach what listens for them, as Events delivers them.
    events.RegisterMessage = function(_, message, fn) handlers[message] = fn end
    events.SendMessage = function(_, c, message, ...)
      table.insert(sent, { message, ... })
      if handlers[message] then handlers[message](c, ...) end
    end
    catalog.Bags = function() return { { name = "Backpack", kind = 0 } } end
    bagSystem.ActiveDesign = function() return design end
    catalog.Has = function(_, id) return id == "fade" end
    catalog.Get = function(_, id)
      assert(id == "fade")
      return { kind = "toggle", title = "Enable Fading", description = "Fade the bags.",
        get = function() return values.fade end, set = function(_, v) values.fade = v end }
    end
    UseNextTheme(nil)
    controls.escape = {}
    render:Init()
    tween:Init()
    motion:Init()
    settings:Init()
    help:Init()
    help:OnEnable()
    defineArticles()
    definePages()
  end)

  after_each(function()
    if settings.frame then
      settings:Close()
      tween:Step(10)
    end
    _G.UISpecialFrames, C_Timer.After, events.SendMessage, bagSystem.ActiveDesign, catalog.Has, catalog.Get,
      events.RegisterMessage, catalog.Bags = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7], saved[8]
  end)

  teardown(function()
    articles:Clear()
    pages:Clear()
  end)

  local function openHelp(query)
    help:Open(ctx(), query)
    settle()
  end

  describe("the page", function()
    it("is a page of its own, under its own heading, with its own list in the sidebar", function()
      local page = pages:Get("help")
      assert.are.equal("Help", page.group)
      assert.are.equal("Help", page.title)
      assert.is_function(page.sidebar)
      assert.is_function(page.heading)
      openHelp()
      assert.are.equal("help", settings.pageId)
      assert.are.equal(page, settings.sidebarPage)
      assert.is_true(tree().frame:IsVisible())
    end)

    it("opens on its home, and on a search's results when /bb help names one", function()
      openHelp()
      assert.are.equal("home", view().showing)
      assert.are.equal("Help", settings.title:GetText())
      settings:Close()
      settle()
      openHelp("sort")
      assert.are.equal("results", view().showing)
      assert.are.equal("sort", view().search:GetText())
      assert.are.equal("Sorting", resultTitles()[1])
    end)

    it("opens on an article", function()
      help:OpenArticle(ctx(), "sort")
      settle()
      assert.are.equal("article", view().showing)
      assert.are.equal("Sorting", settings.title:GetText())
      assert.are.equal("How items are ordered.", settings.description:GetText())
    end)

    it("opens from the help/Open and help/OpenArticle messages", function()
      handlers["help/Open"](ctx(), "filter")
      settle()
      assert.are.same({ "Searching your bags" }, resultTitles())
      handlers["help/OpenArticle"](ctx(), "next")
      settle()
      assert.are.equal("BetterBags Next", settings.title:GetText())
    end)
  end)

  describe("the tree", function()
    -- Asked: "expand and keep expanded, all the help headers on the left": every group's articles listed, under a heading
    -- that is a heading only, as the window's own list of pages has.
    it("lists Home, then each group's heading and all its articles, every group open", function()
      openHelp()
      assert.are.same({ "Help Home", "GETTING STARTED", "Welcome to BetterBags", "BetterBags Next", "YOUR BAGS",
        "Searching your bags", "Sorting" }, treeLabels())
    end)

    it("leaves out the articles and groups of the other bags", function()
      design = "classic"
      openHelp()
      local labels = table.concat(treeLabels(), "|")
      assert.is_truthy(labels:find("CLASSIC ONLY", 1, true))
      assert.is_falsy(labels:find("BetterBags Next", 1, true))
    end)

    it("keeps its headings open: a heading takes no click and has nothing to fold", function()
      openHelp()
      local heading = tree().byKey["group:bags"]
      assert.is_false(heading.frame:IsMouseEnabled())
      assert.is_nil(heading.chevron)
      heading.frame:GetScript("OnClick")(heading.frame, "LeftButton")
      settle()
      assert.are.same({ "Help Home", "GETTING STARTED", "Welcome to BetterBags", "BetterBags Next", "YOUR BAGS",
        "Searching your bags", "Sorting" }, treeLabels())
    end)

    it("opens an article clicked and chooses its row", function()
      openHelp()
      help:OpenArticle(ctx(), "sort")
      settle()
      assert.is_true(tree().byKey["article:sort"].frame:IsShown())
      click(tree().byKey["article:next"].frame)
      settle()
      assert.are.equal("BetterBags Next", settings.title:GetText())
      assert.are.equal(tree().byKey["article:next"].frame, select(2, tree().marker:GetPoint(1)))
    end)

    it("glides its choice from one row to the next", function()
      openHelp()
      local marker = tree().marker
      assert.is_true(marker:IsShown())
      assert.are.equal(tree().byKey["home"].frame, select(2, marker:GetPoint(1)), "on Home")
      local _, _, _, _, homeY = tree().byKey["home"].frame:GetPoint(1)
      click(tree().byKey["article:next"].frame)
      tween:Step(style.Time.TabMarker / 2)
      local _, rel, _, _, y = marker:GetPoint(1)
      assert.are.equal(tree().content, rel, "on its way, along the list")
      local row = tree().byKey["article:next"].frame
      local _, _, _, _, rowY = row:GetPoint(1)
      assert.is_true(y < homeY and y > rowY, "between the rows")
      settle()
      assert.are.equal(row, select(2, marker:GetPoint(1)))
    end)

    it("fades its rows in one after another as it slides in", function()
      help:Open(ctx())
      tween:Step(0)
      local first, last = tree().byKey["home"].frame:GetAlpha(), tree().byKey["group:bags"].frame:GetAlpha()
      assert.is_true(first < 1 and last < 1)
      tween:Step(style.Time.Stagger * 2)
      assert.is_true(tree().byKey["home"].frame:GetAlpha() > tree().byKey["group:bags"].frame:GetAlpha())
      settle()
      assert.are.equal(1, tree().byKey["group:bags"].frame:GetAlpha())
    end)

    it("goes Home", function()
      help:OpenArticle(ctx(), "sort")
      settle()
      click(tree().byKey["home"].frame)
      settle()
      assert.are.equal("home", view().showing)
      assert.are.equal("Help", settings.title:GetText())
    end)
  end)

  describe("the home", function()
    it("asks what you need help with over a search box, and shows the featured articles", function()
      openHelp()
      local v = view()
      assert.are.equal("What do you need help with?", v.prompt:GetText())
      assert.is_true(v.prompt:IsVisible())
      assert.is_true(v.search.frame:IsVisible())
      local titles = {}
      for _, card in ipairs(v.featuredCards) do
        if card.frame:IsShown() then table.insert(titles, card.name:GetText()) end
      end
      assert.are.same({ "Welcome to BetterBags", "Searching your bags" }, titles)
    end)

    it("centers the search box across the page", function()
      openHelp()
      local v = view()
      local _, _, _, x = v.search.frame:GetPoint(1)
      local width = v.frame:GetWidth()
      assert.is_true(math.abs(x + v.search.frame:GetWidth() / 2 - width / 2) <= 1)
    end)

    it("rises and fades in", function()
      help:Open(ctx())
      tween:Step(0)
      assert.is_true(view().hero:GetAlpha() < 1)
      settle()
      assert.are.equal(1, view().hero:GetAlpha())
    end)

    it("opens a featured article clicked", function()
      openHelp()
      click(view().featuredCards[2].frame)
      settle()
      assert.are.equal("Searching your bags", settings.title:GetText())
    end)
  end)

  describe("search", function()
    it("glides the box to the top and lists the articles found as cards", function()
      openHelp()
      local v = view()
      local _, _, _, _, homeY = v.search.frame:GetPoint(1)
      typed(v.search, "sor")
      tween:Step(style.Time.Glide / 2)
      local _, _, _, _, midY = v.search.frame:GetPoint(1)
      assert.is_true(midY > homeY, "on its way up")
      settle()
      assert.are.equal("results", v.showing)
      local _, _, _, x, topY = v.search.frame:GetPoint(1)
      assert.is_true(topY > midY)
      assert.are.equal(style.Theme.Settings.Content.RowPad, x)
      assert.are.equal("Sorting", resultTitles()[1])
      assert.is_false(v.hero:IsShown())
    end)

    it("says what it searched for in the header, and marks the words matched", function()
      openHelp()
      typed(view().search, "search box ")
      settle()
      assert.are.equal("Search Results", settings.title:GetText())
      assert.is_truthy(settings.description:GetText():find("search box", 1, true))
      local text = view().shownCards[1].text:GetText()
      local r, g, b = style:RGBA(H().MatchColor)
      local code = string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
      assert.is_truthy(text:find(code .. "search|r", 1, true))
    end)

    it("says when nothing matches", function()
      openHelp()
      typed(view().search, "xylophone ")
      settle()
      assert.are.same({}, resultTitles())
      assert.is_true(view().empty:IsShown())
      assert.is_truthy(view().empty:GetText():find("xylophone", 1, true))
    end)

    it("goes back home when the box is cleared, or on Escape", function()
      openHelp()
      typed(view().search, "sort")
      settle()
      typed(view().search, "")
      settle()
      assert.are.equal("home", view().showing)
      typed(view().search, "sort")
      settle()
      view().search.frame:GetScript("OnEscapePressed")(view().search.frame)
      settle()
      assert.are.equal("home", view().showing)
      assert.are.equal("", view().search:GetText())
    end)

    it("staggers the cards in", function()
      openHelp()
      typed(view().search, "bags ")
      tween:Step(0)
      local cards = view().shownCards
      assert.is_true(#cards >= 2)
      tween:Step(style.Time.Stagger)
      assert.is_true(cards[1].frame:GetAlpha() > cards[#cards].frame:GetAlpha())
      settle()
      assert.are.equal(1, cards[#cards].frame:GetAlpha())
    end)

    it("slides a card to its new place as the ranking changes", function()
      openHelp()
      typed(view().search, "bags ")
      settle()
      assert.are.equal("Searching your bags", resultTitles()[1])
      local card = view().shownCards[1]
      typed(view().search, "bags sort ")
      local x0, y0, _, y1 = motion:GetMove(card.frame)
      assert.is_truthy(x0, "it slides")
      assert.is_true(y1 < y0, "down, to its new place")
      settle()
      assert.are.equal("Sorting", resultTitles()[1])
      assert.are.equal(card, view().shownCards[3])
    end)

    -- Found by the bug review: a card an earlier search left showed at once, before the cards ranked above it.
    it("staggers every card in when the results come into view, a card an earlier search showed too", function()
      openHelp()
      typed(view().search, "sort ")
      settle()
      typed(view().search, "")
      settle()
      typed(view().search, "bags ")
      tween:Step(0)
      for _, card in ipairs(view().shownCards) do
        assert.are.equal(0, card.frame:GetAlpha(), card.name:GetText())
      end
      settle()
      for _, card in ipairs(view().shownCards) do
        assert.are.equal(1, card.frame:GetAlpha(), card.name:GetText())
      end
    end)

    -- Found by the bug review: a new search kept the scroll of the last one, its best results above the view.
    it("shows a new search from its top", function()
      for i = 1, 20 do
        articles:Define({ id = "bank" .. i, group = "bags", title = "Bank " .. i, summary = "About the bank, part " .. i .. ".",
          body = { { text = "The bank holds things." } } })
      end
      openHelp()
      typed(view().search, "bank ")
      settle()
      local box = view().results.box
      assert.is_true(box:GetDerivedScrollRange() > 0)
      box:ScrollToOffset(box:GetDerivedScrollRange(), true)
      typed(view().search, "bank holds")
      settle()
      assert.are.equal(0, box:GetDerivedScrollOffset(), "refined")
      box:ScrollToOffset(box:GetDerivedScrollRange(), true)
      typed(view().search, "")
      settle()
      typed(view().search, "bank ")
      settle()
      assert.are.equal(0, box:GetDerivedScrollOffset(), "searched again from the home")
      -- The same words again (the second review): what was scrolled before the results left is not kept.
      box:ScrollToOffset(box:GetDerivedScrollRange(), true)
      typed(view().search, "")
      settle()
      typed(view().search, "bank ")
      settle()
      assert.are.equal(0, box:GetDerivedScrollOffset(), "the same search again")
    end)

    -- Found by the second review: typed again while the results faded out, the cards showed at once.
    it("staggers the cards in when they are typed for again while the results fade out", function()
      openHelp()
      typed(view().search, "sort ")
      settle()
      typed(view().search, "")
      tween:Step(style.Time.Glide / 4)
      typed(view().search, "sort ")
      tween:Step(0)
      for _, card in ipairs(view().shownCards) do
        assert.are.equal(0, card.frame:GetAlpha(), card.name:GetText())
      end
    end)

    it("opens a result clicked, Enter opens the first, and the arrows choose another", function()
      openHelp()
      typed(view().search, "bags ")
      settle()
      local second = view().shownCards[2].name:GetText()
      view().search.frame:GetScript("OnArrowPressed")(view().search.frame, "DOWN")
      view().search.frame:GetScript("OnArrowPressed")(view().search.frame, "DOWN")
      assert.is_true(view().shownCards[2].hovered)
      view().search.frame:GetScript("OnEnterPressed")(view().search.frame)
      settle()
      assert.are.equal("article", view().showing)
      assert.are.equal(second, settings.title:GetText())
      typed(view().search, "sort")
      settle()
      click(view().shownCards[1].frame)
      settle()
      assert.are.equal("Sorting", settings.title:GetText())
    end)

    it("leaves the settings window's own search for its pages, and shows matching articles there too", function()
      openHelp()
      settings.search:SetText("sorting")
      settings:Search(ctx(), "sorting")
      local found
      local titles = {}
      for _, section in ipairs(settings.results.sections) do
        if section.title == "Help Articles" then found = section end
        assert.is_nil(titles[section.title], "two sections named " .. section.title)
        titles[section.title] = true
      end
      assert.is_truthy(found)
      click(found.rows[1].button.frame)
      settle()
      assert.are.equal("help", settings.pageId)
      assert.are.equal("Sorting", settings.title:GetText())
    end)
  end)

  describe("an article", function()
    local function blocksOf(kind)
      local list = {}
      for _, block in ipairs(view().article.blocks) do
        if block.kind == kind then table.insert(list, block) end
      end
      return list
    end

    it("draws its blocks: headings in capitals, paragraphs, lists, steps, tips and warnings", function()
      help:OpenArticle(ctx(), "welcome")
      settle()
      assert.are.equal("BetterBags sorts your items into sections.", blocksOf("text")[1].label:GetText())
      assert.are.equal("WHERE TO START", blocksOf("heading")[1].label:GetText())
      local list = blocksOf("list")[1]
      assert.are.same({ "Open your bags.", "Look at the sections." },
        { list.lines[1].label:GetText(), list.lines[2].label:GetText() })
      assert.is_truthy(list.lines[1].bullet)
      local steps = blocksOf("steps")[1]
      assert.are.same({ "1.", "2." }, { steps.lines[1].number:GetText(), steps.lines[2].number:GetText() })
      assert.are.equal("Right-click the bag button for its menu.", blocksOf("tip")[1].label:GetText())
      assert.are.equal("Reloading resets nothing.", blocksOf("warning")[1].label:GetText())
    end)

    it("lays its blocks one under another, no wider than MaxWidth", function()
      help:OpenArticle(ctx(), "welcome")
      settle()
      local last = -1
      for _, block in ipairs(view().article.blocks) do
        local _, _, _, _, y = block.frame:GetPoint(1)
        assert.is_true(-y > last, block.kind)
        last = -y
        assert.is_true(block.frame:GetWidth() <= H().MaxWidth)
      end
    end)

    -- Asked: the search help's keywords as the titles of its sections; a search keyword is typed as it is written.
    it("titles a part with a search keyword as it is typed, not in capitals", function()
      help:OpenArticle(ctx(), "search")
      settle()
      assert.are.equal("ilvl", blocksOf("heading")[1].label:GetText())
    end)

    it("shows a search example as typed in a field, with what it finds", function()
      help:OpenArticle(ctx(), "search")
      settle()
      local example = blocksOf("example")[1]
      assert.are.equal("ilvl >= 600", example.code:GetText())
      assert.are.equal("Items of item level 600 and up.", example.label:GetText())
    end)

    it("links to another article, and to a settings page", function()
      help:OpenArticle(ctx(), "welcome")
      settle()
      click(blocksOf("see")[1].button.frame)
      settle()
      assert.are.equal("Searching your bags", settings.title:GetText())
      help:OpenArticle(ctx(), "welcome")
      settle()
      click(blocksOf("open")[1].button.frame)
      settle()
      assert.are.equal("general", settings.pageId)
      assert.is_nil(settings.sidebarPage, "the pages back in the sidebar")
    end)

    it("shows a setting it explains as the setting itself, which changes it", function()
      help:OpenArticle(ctx(), "welcome")
      settle()
      local block = blocksOf("setting")[1]
      assert.are.equal("Enable Fading", block.row.label:GetText())
      assert.is_false(block.row.control:GetChecked())
      block.row:Write(ctx(), true)
      assert.is_true(values.fade)
    end)

    -- Found by the review of the text written from the code: a link to a page or tab not shown now opened another
    -- page (the window falls back to its first page and first tab).
    it("leaves out a link to a settings page or tab not shown now", function()
      pages:Define({ id = "guild", group = "Bags", title = "Guild Bank", description = "The guild bank.",
        shown = function() return false end,
        tabs = { { id = "layout", title = "Layout", sections = { { title = "Layout", rows = {} } } } } })
      pages:Define({ id = "currencies", group = "BetterBags", title = "Currencies", description = "Currencies.",
        tabs = { { id = "tracked", title = "Tracked", sections = { { title = "Tracked", rows = {} } } },
          { id = "currencies", title = "Currencies", shown = function() return false end,
            sections = { { title = "Currencies", rows = {} } } } } })
      articles:Define({ id = "links", group = "bags", title = "Links", summary = "Links.", body = {
        { open = { page = "guild", tab = "layout", text = "Open the Guild Bank" } },
        { open = { page = "currencies", tab = "currencies", text = "Open the Currencies tab" } },
        { open = { page = "currencies", tab = "tracked", text = "Open the Tracked tab" } },
        { open = { page = "general", text = "Open General" } },
      } })
      help:OpenArticle(ctx(), "links")
      settle()
      local labels = {}
      for _, block in ipairs(blocksOf("open")) do table.insert(labels, block.button.label:GetText()) end
      assert.are.same({ "Open the Tracked tab", "Open General" }, labels)
    end)

    -- Found by the second review: a link to a category's tab was left out until the Categories page had been shown,
    -- though its list chooses a category, and so the tabs, before the window reads them.
    it("draws a link to a tab its page's list would choose, before the list has shown", function()
      local chosen = false
      pages:Define({ id = "cats", group = "BetterBags", title = "Cats", description = "Cats.",
        choose = function() chosen = true end,
        tabs = { { id = "settings", title = "Settings", sections = { { title = "Settings", rows = {} } } },
          { id = "rule", title = "Rule", shown = function() return chosen end,
            sections = { { title = "Rule", rows = {} } } } } })
      articles:Define({ id = "cat", group = "bags", title = "Cat", summary = "Cat.",
        body = { { open = { page = "cats", tab = "rule", text = "Open the Rule tab" } } } })
      help:OpenArticle(ctx(), "cat")
      settle()
      assert.are.equal(1, #blocksOf("open"))
    end)

    -- Found by the second review: what an article draws is read when it shows, but an article was read only when another
    -- was chosen, so coming back to the Help page showed what the article drew before.
    it("reads its article again when it comes back into view", function()
      values.hideFade = true
      help:OpenArticle(ctx(), "welcome")
      settle()
      assert.are.equal(0, #blocksOf("setting"))
      settings:Select("general", nil, ctx())
      settle()
      values.hideFade = false
      settings:Select("help", nil, ctx())
      settle()
      assert.are.equal("welcome", help.state.articleId)
      assert.are.equal(1, #blocksOf("setting"))
      -- And the other way: a setting it drew before is left out once the window hides it.
      settings:Select("general", nil, ctx())
      settle()
      values.hideFade = true
      settings:Select("help", nil, ctx())
      settle()
      assert.are.equal(0, #blocksOf("setting"))
    end)

    -- Found by the same review: Show Keystone Level showed on clients whose settings window hides it.
    it("leaves out a setting the settings window does not show now", function()
      catalog.Has = function(_, id) return id == "fade" or id == "secret" end
      articles:Define({ id = "hidden", group = "bags", title = "Hidden", summary = "Hidden.",
        body = { { setting = "fade" }, { setting = "secret" } } })
      help:OpenArticle(ctx(), "hidden")
      settle()
      local shown = {}
      for _, block in ipairs(blocksOf("setting")) do table.insert(shown, block.def.setting) end
      assert.are.same({ "fade" }, shown)
    end)

    it("lists its related articles shown, and its neighbours in the tree", function()
      help:OpenArticle(ctx(), "next")
      settle()
      local a = view().article
      assert.are.same({}, a.related)
      assert.are.equal("Welcome to BetterBags", a.previous.name:GetText())
      assert.are.equal("Searching your bags", a.nextCard.name:GetText())
      click(a.nextCard.frame)
      settle()
      assert.are.equal("Searching your bags", settings.title:GetText())
      help:OpenArticle(ctx(), "welcome")
      settle()
      local titles = {}
      for _, link in ipairs(view().article.related) do table.insert(titles, link.label:GetText()) end
      assert.are.same({ "Sorting" }, titles, "its body links Searching your bags already")
      assert.is_false(view().article.previous.frame:IsShown(), "nothing before the first")
    end)

    it("slides in from the right going forward, from the left going back", function()
      help:OpenArticle(ctx(), "next")
      settle()
      local scroll = view().articleScroll
      click(view().article.nextCard.frame)
      tween:Step(0)
      local _, _, _, forward = scroll:GetPoint(1)
      assert.is_true(forward > style.Theme.Settings.Content.RowPad, "coming from the right")
      settle()
      click(view().article.previous.frame)
      tween:Step(0)
      local _, _, _, back = scroll:GetPoint(1)
      assert.is_true(back < style.Theme.Settings.Content.RowPad, "coming from the left")
      settle()
      local _, _, _, still = scroll:GetPoint(1)
      assert.are.equal(style.Theme.Settings.Content.RowPad, still)
      assert.are.equal(1, scroll:GetAlpha())
    end)

    it("scrolls to its top when another opens", function()
      help:OpenArticle(ctx(), "welcome")
      settle()
      view().articleScroll.box:ScrollToOffset(40, true)
      help:OpenArticle(ctx(), "sort")
      settle()
      assert.are.equal(0, view().articleScroll.box:GetDerivedScrollOffset())
    end)
  end)

  it("goes back to the page shown before with All Settings", function()
    settings:Open("general")
    settle()
    help:Open(ctx())
    settle()
    settings:Back(ctx())
    settle()
    assert.are.equal("general", settings.pageId)
  end)

  it("lists the articles of the bags switched to while it shows", function()
    openHelp()
    design = "classic"
    settings:OnDesignChanged(ctx())
    settle()
    local labels = table.concat(treeLabels(), "|")
    assert.is_truthy(labels:find("CLASSIC ONLY", 1, true))
    assert.is_falsy(labels:find("BetterBags Next", 1, true))
  end)

  -- Found by the bug review: the article stayed, titled, with no row in the tree marked.
  it("leaves an article the bags switched to do not show, for its home", function()
    help:OpenArticle(ctx(), "next")
    settle()
    design = "classic"
    settings:OnDesignChanged(ctx())
    settle()
    assert.are.equal("home", view().showing)
    assert.are.equal("Help", settings.title:GetText())
    assert.are.equal(tree().byKey["home"].frame, select(2, tree().marker:GetPoint(1)))
  end)

  it("leaves an article the bags switched to do not show for the search it was opened from", function()
    openHelp("next")
    settle()
    help:OpenArticle(ctx(), "next")
    settle()
    design = "classic"
    settings:OnDesignChanged(ctx())
    settle()
    assert.are.equal("results", view().showing)
    assert.are.equal("Search Results", settings.title:GetText())
  end)

  -- Found by the bug review: Compact Sections stayed off in its article after Section Columns let it be used.
  it("shows every setting an article shows again when one of them changes", function()
    values.quick = false
    catalog.Has = function(_, id) return id == "fade" or id == "quick" end
    catalog.Get = function(_, id)
      if id == "quick" then
        return { kind = "toggle", title = "Fade Quickly", description = "Fade faster.",
          disabled = function() return not values.fade end,
          get = function() return values.quick end, set = function(_, v) values.quick = v end }
      end
      return { kind = "toggle", title = "Enable Fading", description = "Fade the bags.",
        get = function() return values.fade end, set = function(_, v) values.fade = v end }
    end
    articles:Define({ id = "fading", group = "bags", title = "Fading", summary = "Fading the bags.",
      body = { { setting = "fade" }, { setting = "quick" } } })
    help:OpenArticle(ctx(), "fading")
    settle()
    local fade, quick = view().article.blocks[1].row, view().article.blocks[2].row
    assert.is_false(quick.control.frame:IsEnabled())
    fade:Write(ctx(), true)
    assert.is_true(quick.control.frame:IsEnabled())
  end)

  -- Found by the bug review: a chosen article's row could be far below the tree's view.
  it("scrolls the tree to the article chosen", function()
    for i = 1, 40 do
      articles:Define({ id = "bank" .. i, group = "bags", title = "Bank " .. i, summary = "About the bank, part " .. i .. ".",
        body = { { text = "The bank holds things." } } })
    end
    openHelp()
    help:OpenArticle(ctx(), "bank40")
    settle()
    local t = tree()
    local row = t.byKey["article:bank40"]
    local offset = t.box:GetDerivedScrollOffset()
    assert.is_true(offset > 0)
    assert.is_true(row.y >= offset and row.y + row.height <= offset + t.box:GetHeight(), "in view")
    -- Found by the second review: a theme applied scrolled the tree back to the row chosen.
    t.box:ScrollToOffset(0, true)
    help:ApplyStyle(ctx())
    assert.are.equal(0, t.box:GetDerivedScrollOffset(), "where the player scrolled it, through a restyle")
    help:OpenArticle(ctx(), "welcome")
    settle()
    local up, top = t.byKey["article:welcome"], t.box:GetDerivedScrollOffset()
    assert.is_true(top < offset or top == 0, "back up")
    assert.is_true(up.y >= top and up.y + up.height <= top + t.box:GetHeight(), "to it")
  end)

  it("is restyled by a theme", function()
    openHelp()
    UseNextTheme({ Settings = { Help = { SearchWidth = 300 } } })
    help:ApplyStyle(ctx())
    settings:Relayout()
    addon:GetModule("Render"):RenderNow(settings.root, { ctx = ctx() })
    assert.are.equal(300, view().search.frame:GetWidth())
  end)

  -- Found by the second review: Help restyled before the buttons, its links kept the old buttons' height.
  it("lays a link out at a theme's button height, whatever restyles first", function()
    help:OpenArticle(ctx(), "welcome")
    settle()
    local link
    for _, block in ipairs(view().article.blocks) do
      if block.kind == "see" then link = block end
    end
    UseNextTheme({ Controls = { Button = { Height = 40 } } })
    help:ApplyStyle(ctx())
    assert.are.equal(40, link.button.frame:GetHeight())
    assert.are.equal(40, link.frame:GetHeight())
  end)

  -- Found by the bug review: a theme's bigger text left the article's blocks as tall as the old text.
  it("lays an article out again for a theme's fonts", function()
    help:OpenArticle(ctx(), "sort")
    settle()
    local block = view().article.blocks[1]
    local before = block.frame:GetHeight()
    UseNextTheme({ Fonts = { SettingsLabel = { Size = 30, Color = "Text" } } })
    addon:GetModule("SonataNext"):RestyleWidgets(ctx())
    settle()
    assert.is_true(block.frame:GetHeight() > before)
  end)
end)
