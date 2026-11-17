-- articles_spec.lua -- The help's articles (help/articles.lua, HelpArticles): groups and articles in the order they
-- are defined, each shown only with the bags it is about (design) and while it says so (shown), as the settings
-- pages are; the tree the Help page's sidebar draws, the articles its home page features, an article's related
-- articles and its neighbours in the tree, and search over the articles shown, each result with its snippet.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local bagSystem = StubBetterBagsModule("BagSystem")
for _, m in ipairs({ { "NextSettingsPages", "next/settings/pages.lua" }, { "HelpSearch", "help/search.lua" },
  { "HelpArticles", "help/articles.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local articles = addon:GetModule("HelpArticles")
local search = addon:GetModule("HelpSearch")

-- idsOf returns the ids of a list of articles (or of search results' articles).
local function idsOf(list)
  local out = {}
  for i, a in ipairs(list) do
    out[i] = (a.article or a).id
  end
  return out
end

describe("HelpArticles", function()
  local design, saved, guild

  local function define()
    articles:Clear()
    articles:Group({ id = "start", title = "Getting Started" })
    articles:Group({ id = "bags", title = "Your Bags" })
    articles:Group({ id = "empty", title = "Nothing Shown" })
    articles:Define({
      id = "welcome", group = "start", title = "Welcome to BetterBags", featured = true,
      summary = "What BetterBags does with your bags.",
      body = { { text = "BetterBags sorts your items into sections." } },
    })
    articles:Define({
      id = "next", group = "start", title = "BetterBags Next", design = "next",
      summary = "The redesigned bags.", related = { "welcome", "classic", "missing" },
      body = { { heading = "Turning it on" }, { text = "Switch it on in General." } },
    })
    articles:Define({
      id = "classic", group = "start", title = "The classic bags", design = "classic",
      summary = "The original bags.",
      body = { { text = "The classic bags have a window of their own." } },
    })
    articles:Define({
      id = "search", group = "bags", title = "Searching", featured = true,
      summary = "Find any item.",
      keywords = { "find", "filter" }, questions = { "How do I look for a potion?" },
      body = {
        { text = "Type in the search box. Results light up as you type." },
        { list = { "Search by name.", "Search by item level." } },
        { example = "ilvl >= 600", text = "Items of item level 600 and up." },
      },
    })
    articles:Define({
      id = "guild", group = "bags", title = "The guild bank", shown = function() return guild end,
      summary = "Your guild's bank.", body = { { text = "Open the guild bank at a guild vault." } },
    })
    articles:Define({
      id = "hidden", group = "empty", title = "Never shown", shown = function() return false end,
      summary = "", body = { { text = "Nothing." } },
    })
  end

  before_each(function()
    saved = bagSystem.ActiveDesign
    design, guild = "next", true
    bagSystem.ActiveDesign = function() return design end
    define()
  end)

  after_each(function()
    bagSystem.ActiveDesign = saved
  end)

  teardown(function()
    articles:Clear()
  end)

  it("gets an article by its id, and replaces one defined again in its place", function()
    assert.are.equal("Searching", articles:Get("search").title)
    articles:Define({ id = "search", group = "bags", title = "Search", summary = "", body = {} })
    assert.are.equal("Search", articles:Get("search").title)
    assert.are.same({ "search", "guild" }, idsOf(articles:Tree()[2].articles))
    assert.is_nil(articles:Get("nope"))
  end)

  it("refuses an article in a group never defined", function()
    assert.has_error(function()
      articles:Define({ id = "lost", group = "nowhere", title = "Lost", summary = "", body = {} })
    end)
  end)

  it("lists the groups with articles shown, in order, each article in order, for the bags in use", function()
    local tree = articles:Tree()
    assert.are.equal(2, #tree)
    assert.are.equal("Getting Started", tree[1].group.title)
    assert.are.same({ "welcome", "next" }, idsOf(tree[1].articles))
    assert.are.same({ "search", "guild" }, idsOf(tree[2].articles))
    design = "classic"
    assert.are.same({ "welcome", "classic" }, idsOf(articles:Tree()[1].articles))
    guild = false
    assert.are.same({ "search" }, idsOf(articles:Tree()[2].articles))
  end)

  it("says whether an article is shown", function()
    assert.is_true(articles:IsShown(articles:Get("next")))
    assert.is_false(articles:IsShown(articles:Get("classic")))
    assert.is_false(articles:IsShown(articles:Get("hidden")))
  end)

  it("features the articles marked so that are shown", function()
    assert.are.same({ "welcome", "search" }, idsOf(articles:Featured()))
  end)

  it("lists an article's related articles that are shown, in order", function()
    assert.are.same({ "welcome" }, idsOf(articles:Related(articles:Get("next"))))
    design = "classic"
    assert.are.same({ "welcome", "classic" }, idsOf(articles:Related(articles:Get("next"))))
  end)

  it("gives an article's neighbours in the tree, across groups", function()
    local before, after = articles:Adjacent(articles:Get("next"))
    assert.are.equal("welcome", before.id)
    assert.are.equal("search", after.id)
    before, after = articles:Adjacent(articles:Get("welcome"))
    assert.is_nil(before)
    assert.are.equal("next", after.id)
    before, after = articles:Adjacent(articles:Get("guild"))
    assert.are.equal("search", before.id)
    assert.is_nil(after)
  end)

  it("puts an article's text together for its snippet: its summary, paragraphs, lists and what its examples find", function()
    local text = articles:TextOf(articles:Get("search"))
    assert.is_truthy(text:find("Find any item.", 1, true))
    assert.is_truthy(text:find("Search by item level.", 1, true))
    assert.is_truthy(text:find("Items of item level 600 and up.", 1, true))
  end)

  describe("Search", function()
    it("ranks the articles shown, each with a snippet of why it matched", function()
      local results = articles:Search("search box ")
      assert.are.equal("search", results[1].article.id)
      assert.are.equal("Type in the search box.", results[1].snippet)
      local s, e = results[1].spans[1][1], results[1].spans[1][2]
      assert.are.equal("search", results[1].snippet:sub(s, e))
    end)

    it("finds an article by its keywords, its questions and its examples", function()
      assert.are.equal("search", articles:Search("filter ")[1].article.id)
      assert.are.equal("search", articles:Search("potion ")[1].article.id)
      assert.are.equal("search", articles:Search("ilvl ")[1].article.id)
    end)

    it("leaves out the articles not shown, and searches the ones the bags switched to", function()
      assert.are.same({ "next" }, idsOf(articles:Search("redesigned ")))
      assert.are.same({}, idsOf(articles:Search("original ")))
      design = "classic"
      assert.are.same({ "classic" }, idsOf(articles:Search("original ")))
      assert.are.same({}, idsOf(articles:Search("redesigned ")))
    end)

    it("finds an article defined after the last search", function()
      assert.are.same({}, idsOf(articles:Search("currencies ")))
      articles:Define({ id = "money", group = "bags", title = "Currencies", summary = "", body = {} })
      assert.are.same({ "money" }, idsOf(articles:Search("currencies ")))
    end)

    it("returns at most the limit asked for", function()
      assert.are.equal(1, #articles:Search("bags ", 1))
    end)

    it("snippets a title-only match with the article's summary", function()
      local results = articles:Search("welcome ")
      assert.are.equal("welcome", results[1].article.id)
      assert.are.equal("What BetterBags does with your bags.", results[1].snippet)
    end)

    it("builds its index over every word an article holds", function()
      local index = search:Build(articles:Docs())
      assert.are.equal("search", index:Query("potion ")[1].id)
    end)
  end)
end)
