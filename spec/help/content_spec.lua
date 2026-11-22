-- content_spec.lua -- The help's articles (help/articles/*.lua, help.md §1): every file loaded in every TOC in the same
-- order, each article whole (a title, a summary, a body of blocks of one kind each, words and questions to be found
-- by), its links to articles that exist, and every string ready for tools/translate, which finds them with a regular
-- expression that ends a string at its first quote followed by a parenthesis and never crosses a line.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local bagSystem = StubBetterBagsModule("BagSystem")
for _, m in ipairs({ { "Localization", "core/localization.lua" }, { "NextSettingsPages", "next/settings/pages.lua" },
  { "HelpSearch", "help/search.lua" }, { "HelpArticles", "help/articles.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local articles = addon:GetModule("HelpArticles")

local TOCS = { "BetterBags.toc", "BetterBags_Camelot.toc", "BetterBags_Mists.toc", "BetterBags_TBC.toc",
  "BetterBags_Vanilla.toc" }

-- lines returns a file's lines.
local function lines(path)
  local list = {}
  for line in io.lines(path) do
    table.insert(list, (line:gsub("\r$", "")))
  end
  return list
end

-- tocArticles returns the article files a TOC loads, in its order.
local function tocArticles(toc)
  local list = {}
  for _, line in ipairs(lines(toc)) do
    local file = line:match("^help\\articles\\(.+%.lua)$")
    if file then
      table.insert(list, "help/articles/" .. file)
    end
  end
  return list
end

-- The block kinds an article's body may hold, and what each needs.
local KINDS = { heading = "string", text = "string", list = "table", steps = "table", example = "string", tip = "string",
  warning = "string", open = "table", see = "string", setting = "string" }

describe("the help's articles", function()
  local files, defined, saved

  setup(function()
    saved = bagSystem.ActiveDesign
    files = tocArticles("BetterBags.toc")
    articles:Clear()
    defined = {}
    local define = articles.Define
    articles.Define = function(self, def)
      table.insert(defined, def.id)
      return define(self, def)
    end
    for _, file in ipairs(files) do
      LoadBetterBagsModule(file)
    end
    articles.Define = define
  end)

  teardown(function()
    bagSystem.ActiveDesign = saved
    articles:Clear()
  end)

  it("loads every file in help/articles, in the same order in every TOC", function()
    local onDisk = {}
    local ls = io.popen("ls help/articles/*.lua")
    for file in ls:lines() do
      onDisk[file] = true
    end
    ls:close()
    assert.is_true(#files > 0)
    for _, file in ipairs(files) do
      assert.is_true(onDisk[file] == true, file .. " is listed but missing")
      onDisk[file] = nil
    end
    assert.are.same({}, onDisk, "files no TOC loads")
    for _, toc in ipairs(TOCS) do
      assert.are.same(files, tocArticles(toc), toc)
    end
  end)

  it("gives every article an id of its own", function()
    local seen = {}
    for _, id in ipairs(defined) do
      assert.is_nil(seen[id], "defined twice: " .. id)
      seen[id] = true
    end
    assert.are.equal(#defined, #articles.list)
  end)

  it("gives every article a title, a summary, a body and words to be found by", function()
    for _, a in ipairs(articles.list) do
      assert.is_true(type(a.title) == "string" and a.title ~= "", a.id)
      assert.is_true(type(a.summary) == "string" and a.summary ~= "", a.id)
      assert.is_true(#a.body > 0, a.id)
      assert.is_true(#(a.keywords or {}) + #(a.questions or {}) >= 6, a.id .. " has few words to be found by")
      assert.is_not_nil(articles:GroupOf(a.group), a.id)
    end
  end)

  -- Asked: "titles should be 1, 2, MAYBE 3 words max. they are titles, not descriptions." The summary describes it.
  it("names every article in at most three words, each name its own", function()
    local seen = {}
    for _, a in ipairs(articles.list) do
      local words = 0
      for _ in a.title:gmatch("%S+") do
        words = words + 1
      end
      assert.is_true(words >= 1 and words <= 3, a.id .. ": " .. a.title)
      assert.is_nil(seen[a.title], "two articles named " .. a.title)
      seen[a.title] = true
    end
  end)

  -- Asked, of headings such as "Where sections come from": "these are a hard no. do not make statements in subtitle or
  -- sections. this should be 'Section Sources' and 'Section Ordering'". A heading is a title, never a clause.
  local CLAUSE = { where = true, which = true, what = true, when = true, why = true, how = true, who = true,
    is = true, are = true, making = true, turning = true, at = true, from = true, without = true, the = true,
    a = true, an = true, one = true, using = true, keeping = true }

  it("heads a part of an article with a title of at most three words, never a clause", function()
    for _, a in ipairs(articles.list) do
      local seen = {}
      for _, block in ipairs(a.body) do
        if block.heading then
          local h = block.heading
          local words, first = 0, nil
          for word in h:gmatch("%S+") do
            words = words + 1
            first = first or word:lower()
          end
          assert.is_true(words >= 1 and words <= 3, a.id .. ": " .. h)
          assert.is_nil(seen[h], a.id .. ": two parts headed " .. h)
          seen[h] = true
          -- A search keyword (keyword = true: ilvl, %=, player.level) is the title as it is typed; the integration
          -- spec checks a query reads it (spec/integration/help_coverage_spec.lua).
          if not block.keyword then
            assert.is_nil(CLAUSE[first], a.id .. ": " .. h .. " reads as a clause")
            assert.is_nil(h:find("[%.%?!:,]$"), a.id .. ": " .. h)
            assert.is_truthy(h:find("^%u"), a.id .. ": " .. h .. " in Title Case")
          end
        end
      end
    end
  end)

  it("makes every block of a body one kind, as it should be", function()
    for _, a in ipairs(articles.list) do
      for i, block in ipairs(a.body) do
        local kinds = {}
        for kind, want in pairs(KINDS) do
          if block[kind] ~= nil then
            assert.are.equal(want, type(block[kind]), a.id .. " block " .. i .. " " .. kind)
            if kind ~= "text" or block.example == nil then
              table.insert(kinds, kind)
            end
          end
        end
        for key in pairs(block) do
          assert.is_true(KINDS[key] ~= nil or key == "bag" or (key == "keyword" and block.heading ~= nil),
            a.id .. " block " .. i .. " has " .. key)
        end
        assert.are.equal(1, #kinds, a.id .. " block " .. i .. ": " .. table.concat(kinds, ", "))
        if block.open then
          assert.is_string(block.open.page, a.id)
          assert.is_string(block.open.text, a.id)
        end
      end
    end
  end)

  it("links only to articles that exist", function()
    for _, a in ipairs(articles.list) do
      for _, id in ipairs(a.related or {}) do
        assert.is_not_nil(articles:Get(id), a.id .. " relates to " .. id)
        assert.are_not.equal(a.id, id, a.id .. " relates to itself")
      end
      for _, block in ipairs(a.body) do
        if block.see then
          assert.is_not_nil(articles:Get(block.see), a.id .. " sees " .. block.see)
        end
      end
    end
  end)

  it("shows every article with one design or the other", function()
    local shown = {}
    for _, design in ipairs({ "next", "classic" }) do
      bagSystem.ActiveDesign = function() return design end
      for _, a in ipairs(articles.list) do
        if a.design == nil or a.design == design then
          shown[a.id] = true
        end
      end
    end
    for _, a in ipairs(articles.list) do
      assert.is_true(shown[a.id] == true, a.id)
    end
  end)

  -- tools/translate/translate.go: `L:G\(["'](.+?)["']\)`, one line at a time.
  it("writes every string so tools/translate reads it whole", function()
    for _, file in ipairs(files) do
      for n, line in ipairs(lines(file)) do
        local from = 1
        while true do
          local s = line:find('L:G(', from, true)
          if s == nil then
            break
          end
          local quote = line:sub(s + 4, s + 4)
          assert.is_true(quote == '"', file .. ":" .. n .. " a string on one line, in double quotes")
          local body, close = nil, nil
          local i = s + 5
          while i <= #line do
            local c = line:sub(i, i)
            if c == "\\" then
              i = i + 2
            elseif c == '"' then
              body, close = line:sub(s + 5, i - 1), i
              break
            else
              i = i + 1
            end
          end
          assert.is_not_nil(body, file .. ":" .. n .. " a string that ends on its line")
          assert.are.equal(")", line:sub(close + 1, close + 1), file .. ":" .. n)
          local first = line:sub(s + 5):find("[\"']%)")
          assert.are.equal(close, s + 4 + first, file .. ":" .. n .. " a quote and a parenthesis inside: " .. body)
          assert.is_nil(body:find("\\", 1, true), file .. ":" .. n .. " no escapes: " .. body)
          assert.is_nil(body:find("|", 1, true), file .. ":" .. n .. " no escape codes: " .. body)
          from = close + 1
        end
      end
    end
  end)
end)
