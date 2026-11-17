-- quality_spec.lua -- How well the help's search finds the article a player wants (help.md §2): searches written by
-- someone who never saw the articles' words (spec/help/queries.tsv, round, article, search), run through the real
-- search over the real articles, each with the bags and client its article shows with. Rounds 1 and 2 were what the
-- weights, synonyms and words were tuned against; round 3 was not, and measures it. Each round must keep finding the
-- article first, and among the first three, at least as often as it did when the articles were written from the code,
-- less a little.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

local bagSystem = StubBetterBagsModule("BagSystem")
for _, m in ipairs({ { "Localization", "core/localization.lua" }, { "NextSettingsPages", "next/settings/pages.lua" },
  { "HelpSearch", "help/search.lua" }, { "HelpArticles", "help/articles.lua" } }) do
  ResetModuleStub(m[1], m[2])
  LoadBetterBagsModule(m[2])
end
local articles = addon:GetModule("HelpArticles")

-- What each round found first and among the first three with the articles written from the code (round 1: 72.2% and
-- 90.8%; round 2: 72.2% and 90.8%; round 3: 73.0% and 86.5%), less about a point.
local FLOOR = {
  { first = 0.71, three = 0.90 },
  { first = 0.71, three = 0.90 },
  { first = 0.72, three = 0.855 },
}

-- The clients an article may show with: retail, Classic Era, Mists of Pandaria Classic, WoW: Forever.
local CLIENTS = {
  { isRetail = true, hasWarbank = true, hasGuildBank = true },
  { isClassic = true },
  { isMists = true, hasGuildBank = true },
  { isRetail = true, isForever = true, hasGuildBank = true },
}
local FLAGS = { "isRetail", "isClassic", "isMists", "isForever", "hasWarbank", "hasGuildBank", "isCata", "isBCC" }

describe("the help's search", function()
  local saved, design

  setup(function()
    saved = { design = bagSystem.ActiveDesign }
    for _, flag in ipairs(FLAGS) do
      saved[flag] = addon[flag]
    end
    bagSystem.ActiveDesign = function() return design end
    articles:Clear()
    for line in io.lines("BetterBags.toc") do
      local file = line:gsub("\r$", ""):match("^help\\articles\\(.+%.lua)$")
      if file then
        LoadBetterBagsModule("help/articles/" .. file)
      end
    end
  end)

  teardown(function()
    bagSystem.ActiveDesign = saved.design
    for _, flag in ipairs(FLAGS) do
      addon[flag] = saved[flag]
    end
    articles:Clear()
  end)

  -- show puts in place the bags and client an article shows with.
  local function show(article)
    for _, which in ipairs({ article.design or "next", "classic" }) do
      for _, client in ipairs(CLIENTS) do
        design = which
        for _, flag in ipairs(FLAGS) do
          addon[flag] = client[flag] == true
        end
        if articles:IsShown(article) then
          return true
        end
      end
    end
    return false
  end

  for round, floor in ipairs(FLOOR) do
    it("finds the article wanted in round " .. round .. " as often as it did", function()
      local total, first, three = 0, 0, 0
      for line in io.lines("spec/help/queries.tsv") do
        local r, id, query = line:match("^(%d)\t([^\t]+)\t(.+)$")
        if tonumber(r) == round then
          local article = articles:Get(id)
          assert.is_not_nil(article, "no article " .. id)
          assert.is_true(show(article), id .. " shows with no bags or client")
          total = total + 1
          for i, result in ipairs(articles:Search(query, 3)) do
            if result.article.id == id then
              if i == 1 then
                first = first + 1
              end
              three = three + 1
              break
            end
          end
        end
      end
      assert.are.equal(400, total)
      assert.is_true(first / total >= floor.first, string.format("first %.3f, at least %.2f", first / total, floor.first))
      assert.is_true(three / total >= floor.three, string.format("first three %.3f, at least %.2f", three / total,
        floor.three))
    end)
  end
end)
