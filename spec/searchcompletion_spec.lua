-- searchcompletion_spec.lua -- SearchCompletion (data/searchcompletion.lua): the suggestions a search rule's field
-- offers at its cursor (search-completion.md), each with how many of the items given the rule then matches. Run on the
-- real QueryParser and Search over indexed items.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

ResetModuleStub("Constants")
ResetModuleStub("Items")
ResetModuleStub("Search", "data/search.lua")
ResetModuleStub("SearchCompletion", "data/searchcompletion.lua")

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

local const = StubBetterBagsModule("Constants")
const.BRIEF_EXPANSION_MAP = { [0] = "classic", [1] = "bc", [2] = "wotlk", [3] = "cata", [9] = "tww", [254] = "bc" }
const.BINDING_MAP = { [-1] = "", [0] = "nonbinding", [1] = "", [2] = "boe", [5] = "soulbound" }
-- As core/constants.lua makes it: Blizzard's global names as keys, then each quality's name in the client's language.
const.ITEM_QUALITY_TO_ENUM = {
  ITEM_QUALITY0_DESC = 0, ITEM_QUALITY4_DESC = 4,
  poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, ["wow token"] = 8,
}

local items = StubBetterBagsModule("Items")
items.GetAllSlotInfo = function() return {} end

LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("data/searchcompletion.lua")
local search = addon:GetModule("Search")
local completion = addon:GetModule("SearchCompletion")

describe("SearchCompletion", function()
  local within

  -- add indexes an item and counts it among the items given.
  local function add(opts)
    search:Add(MockData.ItemData(opts))
    within[opts.slotkey] = true
  end

  local function suggest(text, cursor)
    return completion:Suggest(text, cursor or #text, within)
  end

  local function labels(list)
    local out = {}
    for i, s in ipairs(list) do out[i] = s.label end
    return out
  end

  local function find(list, label)
    for _, s in ipairs(list) do
      if s.label == label then return s end
    end
  end

  before_each(function()
    search:Init()
    within = {}
    add({ slotkey = "plate", name = "Plate Helm", itemType = "Armor", currentItemLevel = 600, quality = 4,
      traits = { upgradeTrack = "Hero", craftingQuality = 2, stats = {} } })
    add({ slotkey = "cloth", name = "Cloth Robe", itemType = "Armor", currentItemLevel = 500, quality = 3,
      traits = { stats = {} } })
    add({ slotkey = "blade", name = "Blade", itemType = "Weapon", currentItemLevel = 100, quality = 4,
      traits = { upgradeTrack = "Myth", isPet = false, stats = {} } })
    add({ slotkey = "snake", name = "Snake", itemType = "Battle Pets", currentItemLevel = 1, quality = 1,
      traits = { isPet = true, stats = {} } })
  end)

  describe("at a condition", function()
    it("offers fields, NOT, player values and functions once a word is typed, the closest first", function()
      local list = suggest("tr")
      assert.same({ "track", "transmoggable" }, labels(list), "starting with what is typed, by name")
      list = suggest("no")
      assert.same({ "NOT" }, labels(list))
      assert.are.equal("keyword", list[1].kind)
      assert.same({ "player.level" }, labels(suggest("player.le")))
      assert.same({ "minlevel", "min(" }, labels(suggest("mi")), "fields, then functions")
      assert.same({ "slot", "slotbest", "slotequipped", "slotid" }, labels(suggest("slot")),
        "what is typed exactly first, the others after")
    end)

    it("offers nothing for an empty condition", function()
      assert.same({}, suggest(""))
      assert.same({}, suggest("type = armor AND "))
    end)

    it("takes a field with a space after it and the operators next", function()
      local track = find(suggest("tr"), "track")
      assert.are.equal("field", track.kind)
      assert.are.equal("track ", track.text)
      assert.are.equal(6, track.cursor)
      assert.is_true(track.chain)
    end)

    it("counts a field by the items the rest of the rule leaves that have it", function()
      assert.are.equal(2, find(suggest("tr"), "track").count, "the two items on an upgrade track")
      assert.are.equal(1, find(suggest("type = armor AND tr"), "track").count, "the armor among them")
      assert.are.equal(2, find(suggest("NOT tr"), "track").count, "the two without one")
    end)

    it("counts a true-or-false field as the word alone, which matches the items where it is true", function()
      assert.are.equal(1, find(suggest("pe"), "pet").count)
    end)

    it("counts a field followed by its comparison as the whole rule", function()
      local list = suggest("ty = armor", 2)
      assert.are.equal("type = armor", find(list, "type").text, "the word replaced, nothing added before the space")
      assert.are.equal(4, find(list, "type").cursor)
      assert.are.equal(2, find(list, "type").count)
      assert.is_falsy(find(list, "type").chain, "its operator is there already")
    end)

    it("counts nothing for NOT, a player value or a function, which do not make a whole rule", function()
      assert.are.equal(0, suggest("no")[1].count)
      assert.are.equal(0, suggest("player.le")[1].count)
      assert.are.equal(0, find(suggest("mi"), "min(").count)
      assert.is_true(suggest("player.le")[1].chain, "a player value is compared next")
      assert.are.equal("min(", find(suggest("mi"), "min(").text)
      assert.are.equal(4, find(suggest("mi"), "min(").cursor, "inside its parentheses")
    end)
  end)

  describe("after a field", function()
    it("offers the operators the field takes, counting nothing, the values next", function()
      assert.same({ "=", "==", "!=", "~=", "%=" }, labels(suggest("type ")))
      assert.same({ "=", "!=", "<", "<=", ">", ">=" }, labels(suggest("ilvl ")))
      assert.same({ "=", "!=" }, labels(suggest("pet ")))
      assert.same({ "=", "==", "!=", "~=", "%=", "<", "<=", ">", ">=" }, labels(suggest("exp ")),
        "expansions also compare in release order")
      assert.same({ "=", "!=", "<", "<=", ">", ">=" }, labels(suggest("player.level ")))
      local ge = find(suggest("ilvl "), ">=")
      assert.are.same({ "ilvl >= ", 8, 0, true }, { ge.text, ge.cursor, ge.count, ge.chain })
    end)

    it("narrows the operators to what is typed of one", function()
      assert.same({ ">", ">=" }, labels(suggest("ilvl >")))
    end)

    -- Found in review: an operator put in before a value already there opened the values, and one taken doubled it.
    it("opens no values after an operator put in before a value already there", function()
      local eq = find(suggest("type  armor", 5), "=")
      assert.are.equal("type = armor", eq.text)
      assert.are.equal(6, eq.cursor)
      assert.is_falsy(eq.chain)
    end)

    it("offers no operator after a word that names no field, and AND or OR once a letter is typed", function()
      assert.same({}, suggest("sword "))
      assert.same({ "AND" }, labels(suggest("type a")))
      assert.are.equal("type AND ", suggest("type a")[1].text)
    end)
  end)

  describe("after an operator", function()
    it("offers the values the items have, the most common first, each counted with the whole rule", function()
      local list = suggest("type = ")
      assert.same({ "Armor", "Battle Pets", "Weapon" }, labels(list))
      assert.are.equal("value", list[1].kind)
      assert.are.equal(2, list[1].count)
      assert.are.equal('type = "Battle Pets" ', list[2].text, "a value with a space is quoted")
      assert.are.equal("type = Armor ", list[1].text)
      assert.is_falsy(list[1].chain)
    end)

    it("counts a value with what follows it in the rule", function()
      local list = suggest("type =  AND ilvl > 550", 7)
      assert.are.equal("type = Armor AND ilvl > 550", find(list, "Armor").text)
      assert.are.equal(1, find(list, "Armor").count)
      assert.are.equal(0, find(list, "Weapon").count)
    end)

    it("counts 0 when the rule cannot be read with the value", function()
      assert.are.equal(0, find(suggest("type = Ar AND (", 9), "Armor").count)
    end)

    it("narrows the values to what is typed, quoted in the quote it was typed in", function()
      assert.same({ "Battle Pets" }, labels(suggest("type = ba")))
      assert.are.equal("type = 'Battle Pets' ", suggest("type = 'ba")[1].text)
      assert.same({ "Battle Pets" }, labels(suggest("type = pets")), "a word inside the value")
    end)

    -- Found in review: a name the player chose (a bag, a set) ending in a backslash was quoted, and the lexer reads \"
    -- as a quote inside the text: the rule never closed. Unquoted it is one word.
    it("writes a value ending in a backslash as one word, which the rule reads", function()
      add({ slotkey = "satchel", bagName = "Back\\" })
      local s = find(suggest("bag = "), "Back\\")
      assert.are.equal("bag = Back\\ ", s.text)
      assert.are.equal(1, s.count)
    end)

    it("replaces the whole value at the cursor", function()
      assert.are.equal("type = Armor ", find(suggest("type = Armour", 9), "Armor").text)
    end)

    it("hides a lone suggestion that is what is typed already", function()
      assert.same({}, suggest("type = Weapon"))
      assert.same({}, suggest("type = armor AND"))
    end)

    it("lists every rarity, expansion, binding and true-or-false value, in their order", function()
      assert.same({ "poor", "common", "uncommon", "rare", "epic", "legendary", "wow token" }, labels(suggest("rarity = ")))
      assert.are.equal(2, find(suggest("rarity = "), "epic").count)
      assert.are.equal('rarity = "wow token" ', find(suggest("rarity = "), "wow token").text)
      assert.same({ "classic", "bc", "wotlk", "cata", "tww" }, labels(suggest("exp >= ")))
      assert.same({ "nonbinding", "boe", "soulbound" }, labels(suggest("binding = ")))
      assert.same({ "true", "false" }, labels(suggest("pet = ")))
      assert.are.equal(1, find(suggest("pet = "), "true").count)
      assert.same({ "known", "unknown" }, labels(suggest("appearance = ")))
      assert.same({ "epic" }, labels(suggest("rarity = e")), "a rarity is a number named by its quality's name")
      assert.same({ "true" }, labels(suggest("pet = t")))
    end)

    it("orders numbers from the lowest for <, <=, > and >=, and by how common for =", function()
      assert.same({ "1", "100", "500", "600" }, labels(suggest("ilvl > ")))
      assert.are.equal(2, find(suggest("ilvl > "), "100").count)
    end)

    it("offers number fields, player values and functions for a word typed after a number field's operator", function()
      assert.same({ "slotbest", "slotequipped", "slotid" }, labels(suggest("ilvl > slot")))
      assert.same({ "player.level", "player.ilvl", "player.equippedilvl", "player.classid", "player.specid" },
        labels(suggest("ilvl > player.")))
      assert.same({ "maxlevel", "max(" }, labels(suggest("ilvl > max")), "fields, player values, then functions")
    end)

    it("counts a field or a player value compared with the field, which makes a whole rule", function()
      assert.are.equal(4, find(suggest("ilvl = max"), "maxlevel").count, "every item read with its data")
      assert.are.equal(0, find(suggest("ilvl = max"), "max(").count)
    end)

    -- Each value's count comes from the rest of the rule evaluated once, with the comparison standing for every item
    -- and for none (an item's match follows only whether it matches the comparison), not from the whole rule again.
    it("counts each value as the whole rule with it would match, from the rest of the rule evaluated once", function()
      -- quality: only the plate has a crafting tier, so != and ~= count the items without one too.
      local texts = { "ilvl > ", "ilvl <= ", "ilvl = ", "ilvl != ", "type = ", "type != ", "NOT (ilvl > ",
        "type = armor OR ilvl >= ", "rarity >= ", "pet = ", "type =  AND ilvl > 550", "NOT type = ", "quality != ",
        "quality ~= ", "quality = ", "quality < ", "type = armor AND quality != " }
      for _, text in ipairs(texts) do
        local cursor = text == "type =  AND ilvl > 550" and 7 or #text
        for _, s in ipairs(suggest(text, cursor)) do
          assert.are.equal(completion:CountOf(s.text, within), s.count, text .. " | " .. s.label)
        end
      end
      local searched, evaluated = 0, 0
      local realSearch, realEvaluate = search.Search, search.EvaluateQuery
      search.Search = function(...) searched = searched + 1 return realSearch(...) end
      search.EvaluateQuery = function(...) evaluated = evaluated + 1 return realEvaluate(...) end
      local list = suggest("type = armor OR name = ")
      local textEvaluated = evaluated
      evaluated = 0
      local numbers = suggest("type = armor OR ilvl > ")
      search.Search, search.EvaluateQuery = realSearch, realEvaluate
      assert.are.equal(0, searched, "no value searched as a whole rule")
      assert.are.equal(2 + #list, textEvaluated, "the rest twice, then each value's comparison alone")
      assert.is_true(#numbers > 1)
      assert.are.equal(2, evaluated, "a number field's numbers counted from its items' values in order, none evaluated")
    end)

    it("offers no values for the tooltip, an item's GUID, or a word that names no field", function()
      assert.same({}, suggest("tooltip = "))
      assert.same({}, suggest("guid = "))
      assert.same({}, suggest("sword = "))
    end)
  end)

  describe("after a whole condition", function()
    it("offers AND and OR once a letter is typed, counting nothing", function()
      assert.same({}, suggest("type = armor "))
      assert.same({ "AND" }, labels(suggest("type = armor a")))
      assert.same({ "OR" }, labels(suggest("type = armor o")))
      assert.are.equal("type = armor OR ", suggest("type = armor o")[1].text)
      assert.are.equal(0, suggest("type = armor o")[1].count)
    end)
  end)

  it("counts only the items given", function()
    search:Add(MockData.ItemData({ slotkey = "elsewhere", itemType = "Armor" }))
    assert.are.equal(2, find(suggest("type = "), "Armor").count)
  end)

  it("offers no more than 50", function()
    for i = 1, 60 do
      add({ slotkey = "n" .. i, name = string.format("Ore %02d", i) })
    end
    assert.are.equal(50, #suggest("name = "))
  end)

  it("offers nothing for a query the lexer cannot read", function()
    assert.same({}, suggest("a\1"))
  end)

  it("says what it replaces, for where the suggestions show", function()
    local _, context = suggest("type = Ar")
    assert.same({ 8, 9 }, { context.from, context.to })
  end)
end)
