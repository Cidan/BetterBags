-- search_spec.lua -- The help search (help/search.lua, HelpSearch): text made comparable (case, accents, the client's
-- escape codes), words stemmed, stop words left out, and documents ranked by BM25F over their fields, with the word
-- being typed matched as a prefix, typos and words run together matched, and Korean and Chinese text matched by pairs
-- of characters; and the snippet of an article that shows why it matched.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("help/search.lua")
local search = addon:GetModule("HelpSearch")

-- doc makes a document from its fields, each a list of strings.
local function doc(id, fields)
  return { id = id, fields = fields }
end

-- ids returns the ids of a query's results, in order.
local function ids(results)
  local list = {}
  for i, r in ipairs(results) do
    list[i] = r.id
  end
  return list
end

describe("HelpSearch", function()
  describe("Normalize", function()
    it("lowercases text and drops the client's escape codes, keeping a link's text", function()
      assert.are.equal("sell  junk ", search:Normalize("|cffff0000Sell|r |TInterface\\Icons\\Coin:14|t Junk|n"))
      assert.are.equal("[hearthstone]", search:Normalize("|cff0070dd|Hitem:6948::::::::|h[Hearthstone]|h|r"))
      assert.are.equal("a b", search:Normalize("|A:bags-icon:14:14|aA|nB"))
    end)

    it("folds accents so a search typed without them still matches", function()
      assert.are.equal("cafe creme naive", search:Normalize("Café Crème naïve"))
      assert.are.equal("taschen fur gegenstande", search:Normalize("Taschen für Gegenstände"))
      assert.are.equal("espanol", search:Normalize("ESPAÑOL"))
    end)

    it("lowercases Cyrillic", function()
      assert.are.equal("сумки ёлка", search:Normalize("СУМКИ Ёлка"))
    end)
  end)

  describe("Stem", function()
    it("gives a word and its plural, past and -ing forms one stem", function()
      local same = {
        { "category", "categories" },
        { "setting", "settings" },
        { "sell", "selling", "sells" },
        { "sort", "sorted", "sorting", "sorts" },
        { "move", "moved", "moving", "moves" },
        { "bag", "bags" },
        { "stack", "stacking", "stacked" },
        { "use", "used", "using" },
        { "create", "created", "creating" },
        { "glass", "glasses" },
      }
      for _, words in ipairs(same) do
        local stem = search:Stem(words[1])
        for _, word in ipairs(words) do
          assert.are.equal(stem, search:Stem(word), word .. " and " .. words[1])
        end
      end
    end)

    it("keeps a setting apart from an equipment set", function()
      assert.are.equal(search:Stem("setting"), search:Stem("settings"))
      assert.are_not.equal(search:Stem("set"), search:Stem("settings"))
      assert.are.equal(search:Stem("set"), search:Stem("sets"))
    end)

    it("leaves words whose ending is not a suffix alone", function()
      assert.are.equal("thing", search:Stem("thing"))
      assert.are.equal("string", search:Stem("string"))
      assert.are.not_equal(search:Stem("bank"), search:Stem("bag"))
    end)
  end)

  describe("Terms", function()
    it("leaves the stop words out", function()
      local terms = search:Terms("How do I sell my junk?")
      assert.are.same({ search:Stem("sell"), "junk" }, terms)
    end)

    it("splits Korean and Chinese runs into pairs of characters", function()
      assert.are.same({ "가방", "방정", "정리" }, search:Terms("가방정리"))
      assert.are.same({ "背包", "包整", "整理" }, search:Terms("背包整理"))
      assert.are.same({ "가" }, search:Terms("가"))
    end)
  end)

  describe("Query", function()
    local index
    before_each(function()
      index = search:Build({
        doc("selling", {
          title = { "Selling junk at a merchant" },
          keywords = { "vendor", "junk", "gray items" },
          body = { "Open a merchant and BetterBags offers to sell your junk." },
        }),
        doc("categories", {
          title = { "Making a category" },
          keywords = { "custom category", "section" },
          body = { "A category groups items in a section of your bags. You can sell a category too." },
        }),
        doc("search", {
          title = { "Searching your bags" },
          keywords = { "find", "filter" },
          questions = { "How do I find an item?" },
          body = { "Type in the search box at the top of your bags." },
        }),
        doc("auto", {
          title = { "Auto Sell" },
          keywords = { "auto sell", "automation" },
          body = { "Mark a category Auto Sell and a merchant sells it." },
        }),
        doc("korean", { title = { "가방 정리" }, body = { "가방을 정리합니다." } }),
        doc("chinese", { title = { "背包整理" }, body = { "整理你的背包。" } }),
        doc("russian", { title = { "Сумки" }, body = { "Ваши сумки." } }),
      })
    end)

    it("ranks a document matching in its title above one matching in its body", function()
      local results = index:Query("merchant ")
      assert.are.equal("selling", results[1].id)
    end)

    it("ranks the document matching every word above one matching a word many times", function()
      -- Equally common words, in one field of one length: "one" scores more for beta alone than "two" for both, until it
      -- counts for matching half.
      local both = search:Build({
        doc("one", { body = { "beta beta beta beta" } }),
        doc("two", { body = { "alpha beta gamma delta" } }),
        doc("three", { body = { "alpha" } }),
        doc("four", { body = { "alpha" } }),
        doc("five", { body = { "beta" } }),
      })
      local results = both:Query("alpha beta ")
      assert.are.equal("two", results[1].id)
      assert.are.equal("one", results[2].id)
    end)

    it("counts a word in a title for more than the same word twice in a body", function()
      local fields = search:Build({
        doc("titled", { title = { "Merchant" }, body = { "Open it." } }),
        doc("body", { title = { "Other" }, body = { "A merchant, another merchant." } }),
      })
      assert.are.equal("titled", fields:Query("merchant ")[1].id)
    end)

    it("matches every form of a word", function()
      assert.are.equal("categories", index:Query("categories ")[1].id)
      assert.are.equal("search", index:Query("search ")[1].id)
    end)

    it("matches the word being typed as the start of a word", function()
      assert.are.equal("categories", index:Query("categ")[1].id)
      assert.are.equal("search", index:Query("searc")[1].id)
    end)

    it("does not match a finished word as the start of another", function()
      assert.are.same({}, index:Query("categ "))
    end)

    it("matches a word typed with a letter wrong, missing, added or swapped", function()
      assert.are.equal("categories", index:Query("catagory ")[1].id)
      assert.are.equal("selling", index:Query("merchnt ")[1].id)
      assert.are.equal("selling", index:Query("merchaant ")[1].id)
      assert.are.equal("search", index:Query("serach ")[1].id)
    end)

    it("does not guess at typos in short words", function()
      assert.are.same({}, index:Query("bgs "))
    end)

    it("matches two words typed as one", function()
      assert.are.equal("auto", index:Query("autosell ")[1].id)
    end)

    -- Measured on held-out searches: "myvault", "howitems" and "filterby" found nothing, or a word one letter off.
    it("splits two words typed as one when one is a stop word, a plural or a synonym", function()
      local words = search:Build({
        doc("bank", { title = { "Your bank" }, body = { "Open the bank." } }),
        doc("items", { title = { "Your items" }, body = { "Where items go." } }),
        doc("filter", { title = { "Filter what you see" }, body = { "Type to filter." } }),
        doc("other", { body = { "Something else entirely." } }),
      })
      assert.are.equal("bank", words:Query("myvault ")[1].id, "a stop word and a synonym")
      assert.are.equal("items", words:Query("howitems ")[1].id, "a stop word and a plural")
      assert.are.equal("filter", words:Query("filterby ")[1].id, "a word and a stop word")
      assert.are.same({}, words:Query("andor "), "two stop words search for nothing")
    end)

    it("prefers two real words typed as one over a word a letter from it", function()
      local words = search:Build({
        doc("split", { title = { "Gold limit" }, body = { "Gold and a limit." } }),
        doc("near", { title = { "Goldlimix" }, body = { "One word." } }),
        doc("other", { body = { "Something else entirely." } }),
      })
      assert.are.equal("split", words:Query("goldlimit ")[1].id)
    end)

    it("finds a document by a player's word for what it names, below one that uses that word", function()
      local words = search:Build({
        doc("bank", { title = { "Your bank" }, body = { "Open the bank." } }),
        doc("vault", { title = { "The vault" }, body = { "Nothing else." } }),
        doc("other", { body = { "Something else." } }),
      })
      assert.are.equal("bank", words:Query("storage ")[1].id)
      local results = words:Query("vault ")
      assert.are.equal("vault", results[1].id, "the word itself first")
      assert.are.equal("bank", results[2].id)
    end)

    -- Found by the bug review: guide and tutorial named help, a stop word the index never holds.
    it("names only words the index keeps as a synonym's meaning", function()
      for word, meanings in pairs(search.SYNONYMS) do
        for _, meaning in ipairs(meanings) do
          assert.is_nil(search.STOP[meaning], word .. " means " .. meaning .. ", a stop word")
          assert.is_nil(meaning:find("%s"), word .. " means " .. meaning .. ", more than one word")
        end
      end
    end)

    it("finds nothing for a question of stop words alone", function()
      assert.are.same({}, index:Query("how do I"))
      assert.are.same({}, index:Query(""))
      assert.are.same({}, index:Query("   "))
    end)

    it("matches Korean, Chinese and Cyrillic", function()
      assert.are.equal("korean", index:Query("가방")[1].id)
      assert.are.equal("chinese", index:Query("背包")[1].id)
      assert.are.equal("russian", index:Query("СУМКИ ")[1].id)
    end)

    it("returns at most the limit asked for", function()
      assert.are.equal(1, #index:Query("sell ", { limit = 1 }))
      assert.is_true(#index:Query("sell ") > 1)
    end)

    it("returns the stems it matched, for the snippet", function()
      local _, matched = index:Query("selling catagory ")
      assert.is_true(matched[search:Stem("sell")])
      assert.is_true(matched[search:Stem("category")])
    end)

    it("breaks ties by the order the documents were given in", function()
      local tied = search:Build({ doc("b", { body = { "alpha" } }), doc("a", { body = { "alpha" } }) })
      assert.are.same({ "b", "a" }, ids(tied:Query("alpha ")))
    end)
  end)

  describe("Snippet", function()
    it("picks the sentence with the most words matched and marks them", function()
      local text = "Bags hold items. You can sell junk at a merchant. Categories group items."
      local snippet, spans = search:Snippet(text, { [search:Stem("sell")] = true, junk = true }, 80)
      assert.are.equal("You can sell junk at a merchant.", snippet)
      assert.are.same({ { 9, 12 }, { 14, 17 } }, spans)
    end)

    it("starts with the first sentence when nothing matched", function()
      assert.are.equal("Bags hold items.", (search:Snippet("Bags hold items. Others.", {}, 80)))
    end)

    it("cuts a long sentence round its first match at a word's edge", function()
      local text = "One two three four five six seven eight nine ten eleven twelve merchant thirteen fourteen."
      local snippet, spans = search:Snippet(text, { merchant = true }, 30)
      assert.is_truthy(snippet:find("merchant", 1, true))
      assert.is_truthy(snippet:find("^…"))
      assert.is_true(#snippet <= 30 + #"……")
      local s, e = spans[1][1], spans[1][2]
      assert.are.equal("merchant", snippet:sub(s, e))
      local inner = snippet:gsub("^…", ""):gsub("…$", "")
      local at = (" " .. text):find(" " .. inner, 1, true)
      assert.is_truthy(at, "starts at a word's start: " .. inner)
      assert.is_truthy(text:sub(at + #inner, at + #inner):find("^[ %.]?$"), "ends at a word's end: " .. inner)
    end)

    it("ignores the client's escape codes in what it shows", function()
      local snippet, spans = search:Snippet("|cffffd100Sell|r your junk.", { [search:Stem("sell")] = true }, 80)
      assert.are.equal("Sell your junk.", snippet)
      assert.are.same({ { 1, 4 } }, spans)
    end)
  end)
end)
