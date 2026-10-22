-- vendorrule_spec.lua -- Converting the Vendor addon's rules into BetterBags searches (util/vendorrule.lua,
-- docs/vendor-compat.md, .claude/rules/search-indexing.md §18).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")

ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")

ResetModuleStub("Constants")
ResetModuleStub("Items")
ResetModuleStub("Search", "data/search.lua")
ResetModuleStub("VendorRule", "util/vendorrule.lua")

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.Inspect = function() end

-- The constants the search reads; every expansion Vendor names has its own short name.
local const = StubBetterBagsModule("Constants")
const.BRIEF_EXPANSION_MAP = {
  [0] = "classic", [1] = "bc", [2] = "wotlk", [3] = "cata", [4] = "mop", [5] = "wod", [6] = "legion",
  [7] = "bfa", [8] = "sl", [9] = "df", [10] = "tww",
}
const.BINDING_MAP = { [0] = "", [1] = "boe", [2] = "soulbound" }
const.ITEM_QUALITY_TO_ENUM = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

local items = StubBetterBagsModule("Items")
items.GetAllSlotInfo = function() return {} end

LoadBetterBagsModule("data/search.lua")
local search = addon:GetModule("Search")
LoadBetterBagsModule("util/vendorrule.lua")
local VendorRule = addon:GetModule("VendorRule")
local QueryParser = addon:GetModule("QueryParser")

-- Blizzard's stat names for the HasStat aliases used here (GlobalStrings, enUS).
local GLOBALS = {
  ITEM_MOD_CR_SPEED_SHORT = "Speed", ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike",
  ITEM_MOD_EXTRA_ARMOR_SHORT = "Bonus Armor", ITEM_MOD_VERSATILITY = "Versatility",
  ITEM_MOD_HASTE_RATING_SHORT = "Haste",
}

local function convert(script, opts)
  opts = opts or {}
  opts.globals = opts.globals or GLOBALS
  return VendorRule:Convert(script, opts)
end

local function query(script, opts)
  local result = convert(script, opts)
  assert.is_nil(result.problem, script .. ": " .. tostring(result.problem))
  return result.query
end

local SOULBOUND = "(binding = soulbound OR binding = quest OR binding = refundable)"

describe("VendorRule", function()

  -- ─── Vendor's own rules (rules/definitions.lua, systems/extensionmanager/*.lua) ─────────────────

  describe("Vendor's built-in rules", function()
    local params = { ITEMLEVEL = 200, FOOD_LEVEL = 10, NO_LEVEL_ONE = true }
    local cases = {
      { "sell.poor", "Quality == POOR", "rarity = 0" },
      { "sell.oldfood",
        "TypeId == 0 and SubTypeId == 5 and (not NO_LEVEL_ONE or Level ~= 1) and Level <= (PlayerLevel() - FOOD_LEVEL)",
        "class = 0 AND subclass = 5 AND ilvl != 1 AND ilvl <= player.level - 10" },
      { "sell.knowntoys", "IsSoulbound and IsToy and IsAlreadyKnown and not IsUnsellable",
        SOULBOUND .. " AND toy = true AND known = true AND NOT price = 0" },
      { "sell.uncommongear",
        "(not IsInEquipmentSet()) and IsEquipment and (Quality == UNCOMMON) and (not IsUnsellable) and (MaxLevel < ITEMLEVEL)",
        "NOT inset = true AND equipment = true AND rarity = 2 AND NOT price = 0 AND maxlevel < 200" },
      { "sell.raregear",
        "(not IsInEquipmentSet()) and IsEquipment and (Quality == RARE) and (not IsUnsellable) and (MaxLevel < ITEMLEVEL)",
        "NOT inset = true AND equipment = true AND rarity = 3 AND NOT price = 0 AND maxlevel < 200" },
      { "sell.epicgear",
        "(not IsInEquipmentSet()) and IsEquipment and IsSoulbound and (Quality == EPIC) and (not IsUnsellable) and (MaxLevel < ITEMLEVEL)",
        "NOT inset = true AND equipment = true AND " .. SOULBOUND .. " AND rarity = 4 AND NOT price = 0 AND maxlevel < 200" },
      { "keep.legendaryandup", "Quality >= 5", "rarity >= 5" },
      { "keep.soulboundgear", "IsEquippable and IsSoulbound", "equippable = true AND " .. SOULBOUND },
      { "keep.bindonequipgear", "IsEquipment and IsBindOnEquip", "equipment = true AND (binding = boe OR binding = wue)" },
      { "keep.unknownappearance", "IsUnknownAppearance", "appearance = unknown" },
      { "keep.cosmetic", "IsCosmetic and not IsAppearanceCollected", "cosmetic = true AND NOT appearance = known" },
      { "keep.potentialupgrades", "IsEquippable and (MaxLevel >= math.min(PlayerItemLevel() * .95, PlayerItemLevel() - 5))",
        "equippable = true AND maxlevel >= min(player.ilvl * 0.95, player.ilvl - 5)" },
      { "keep.common", "Quality == 1", "rarity = 1" },
      { "keep.uncommongear", "IsEquipment and Quality == 2 and (MaxLevel >= ITEMLEVEL)",
        "equipment = true AND rarity = 2 AND maxlevel >= 200" },
      { "keep.equipmentset", "IsInEquipmentSet()", "inset = true" },
      { "keep.craftingreagent", "IsCraftingReagent", "reagent = true" },
      { "keep.sidegradeorbetter",
        "IsEquippable and (Quality > 1) and (MaxLevel >= WatermarkLevel()) and (MaxLevel >= (.8 * PlayerItemLevel()))",
        "equippable = true AND rarity > 1 AND maxlevel >= slotbest AND maxlevel >= 0.8 * player.ilvl" },
      { "keep.craftedgear", "IsEquippable and (CraftedQuality > 0) and (Quality >= 4)",
        "equippable = true AND quality > 0 AND rarity >= 4" },
      { "keep.professiongear", "IsProfessionEquipment", "equipment = true AND class = 19" },
      { "keep.levelinggear", "IsEquipment and (MinLevel > PlayerLevel())", "equipment = true AND minlevel > player.level" },
      { "destroy.knowntoys", "IsSoulbound and IsToy and IsAlreadyKnown and IsUnsellable",
        SOULBOUND .. " AND toy = true AND known = true AND price = 0" },
      { "pawn.isupgrade", "IsEquipment and Pawn_IsUpgrade()", "equipment = true AND upgrade = true" },
      { "pawn.isnotupgrade", "IsEquipment and not Pawn_IsUpgrade() and not IsEquipped and not IsUnsellable",
        "equipment = true AND NOT upgrade = true AND NOT price = 0" },
    }
    for _, case in ipairs(cases) do
      it("converts " .. case[1], function()
        assert.are.equal(case[3], query(case[2], { params = params }))
      end)
    end

    it("converts the Classic rules with Classic's binding", function()
      assert.are.equal("equipment = true AND bound = true AND rarity = 4 AND NOT price = 0 AND maxlevel < 200",
        query("IsEquipment and IsSoulbound and (Quality == EPIC) and (not IsUnsellable) and (MaxLevel < ITEMLEVEL)",
          { params = params, classic = true }))
      assert.are.equal("equipment = true AND ilvl >= slotequipped",
        query("IsEquipment and (Level >= CurrentEquippedLevel())", { classic = true }))
    end)

    it("says why the rules that read Vendor's lists or other addons cannot be converted", function()
      for _, script in ipairs({ "IsAlwaysSellItem()", "IsNeverSellItem()", "IsImportantItem()", 'IsInList("Destroy")',
        "IsDestroyItem()" }) do
        local result = convert(script)
        assert.is_nil(result.query, script)
        assert.truthy(result.problem:find("list", 1, true), script)
      end
      for _, script in ipairs({ "ATT_CompletionPercentage() < 1",
        "not IsSoulbound and CIMI_IsTransmogable() and not CIMI_PlayerKnowsTransmog()",
        'TSM_IsAuctionItem() and (TSM_CustomValue("dbregionsalerate * 100") > SALERATE)',
        "not IsSoulbound and (Auc_AuctionProfit() > MIN_AUCTIONPROFIT)" }) do
        local result = convert(script)
        assert.is_nil(result.query, script)
        assert.truthy(result.problem:find("addon", 1, true), script)
      end
    end)

    it("notes what reads differently", function()
      local notes = convert("IsUnknownAppearance").notes
      assert.are.equal(1, #notes)
      assert.truthy(notes[1]:find("soulbound", 1, true))
      assert.truthy(convert("IsEquipment and Pawn_IsUpgrade()").notes[1]:find("upgrade", 1, true))
      assert.are.same({}, convert("Quality == POOR").notes)
    end)
  end)

  -- ─── Rules players wrote (docs/vendor-compat.md, "Appendix: the player rules in the corpus") ─────

  describe("player rules", function()
    local cases = {
      { "(not IsEquipment) and (SubTypeId == 0) and (TypeId == 15) and (ExpansionPackId == 0) and (IsUsable) and " ..
        "(not IsUnsellable) and (Quality == 4) and (not TooltipContains(PlayerClass()))",
        "NOT equipment = true AND subclass = 0 AND class = 15 AND exp = 0 AND usable = true AND NOT price = 0 AND " ..
        "rarity = 4 AND NOT tooltip %= player.class" },
      { "ExpansionPackId() == 6 -- Legion\nand SubTypeId() == 11 -- Artifact Relic\nand TypeId() == 3 -- Gem",
        "exp = 6 AND subclass = 11 AND class = 3" },
      { 'HasStat("speed")', 'stat == "Speed"' },
      { "IsCraftingReagent and (ExpansionPackId == 0)", "reagent = true AND exp = 0" },
      { 'SubType == "Artifact Relic"', 'subtype == "Artifact Relic"' },
      { 'TypeId == 0 and SubTypeId() == 8 and TooltipContains("Champion Equipment")',
        'class = 0 AND subclass = 8 AND tooltip %= "Champion Equipment"' },
      { 'TypeId == 15 and SubTypeId == 4 and IsAlreadyKnown and TooltipContains("Garrison Blueprint")',
        'class = 15 AND subclass = 4 AND known = true AND tooltip %= "Garrison Blueprint"' },
      { "TypeId() == 3 and SubTypeId() == 11 and Level() < 225 and ExpansionPackId() == 6",
        "class = 3 AND subclass = 11 AND ilvl < 225 AND exp = 6" },
      { "string.find(Name, 'Selfless Bearer')", 'name %= "Selfless Bearer"' },
      { "(not IsInEquipmentSet()) and IsSoulbound and IsEquipment and Quality == UNCOMMON and Level < 300",
        "NOT inset = true AND " .. SOULBOUND .. " AND equipment = true AND rarity = 2 AND ilvl < 300" },
      { 'TooltipContains("Garrison") or TooltipContains("garrison") or Name == "Miner\'s Coffee"',
        'tooltip %= "Garrison" OR tooltip %= "garrison" OR name == "Miner\'s Coffee"' },
      { "TooltipContains('alcohol', 'left') or (Name == \"Mad Brewer's Breakfast\")",
        'tooltip %= "alcohol" OR name == "Mad Brewer\'s Breakfast"' },
      { '(not IsEquipment) and (Level < 300) and IsSoulbound and (SubType == "Junk") and TooltipContains("Classes:") ' ..
        "and (not TooltipContains(PlayerClass()))",
        "NOT equipment = true AND ilvl < 300 AND " .. SOULBOUND .. ' AND subtype == "Junk" AND tooltip %= "Classes:" ' ..
        "AND NOT tooltip %= player.class" },
      { "IsEquipment and IsSoulbound and (not IsEquippable) and (Quality < 5)",
        "equipment = true AND " .. SOULBOUND .. " AND NOT equippable = true AND rarity < 5" },
      { 'TooltipContains("Artifact Relic") and BindType == 1 and ExpansionPackId == 6',
        'tooltip %= "Artifact Relic" AND bindtype = 1 AND exp = 6' },
      { "Quality == (POOR or COMMON) and IsEquipment and (IsEquippable or not IsSoulbound)",
        "rarity = 0 AND equipment = true AND (equippable = true OR NOT " .. SOULBOUND .. ")" },
    }
    for _, case in ipairs(cases) do
      it("converts " .. case[1]:gsub("\n", " "), function()
        assert.are.equal(case[2], query(case[1]))
      end)
    end

    it("notes the old way of writing properties, a tooltip side, and Lua's or of two values", function()
      assert.truthy(convert("Level() < 225").notes[1]:find("Level()", 1, true))
      assert.truthy(convert("TooltipContains('alcohol', 'left')").notes[1]:find("left", 1, true))
      assert.truthy(convert("Quality == (POOR or COMMON)").notes[1]:find("POOR", 1, true))
    end)

    it("says why the rules it cannot convert cannot be", function()
      local failing = {
        { "(Id == 163569) and (NumKeep() >= 1)", "NumKeep" },
        { "(not IsInEquipmentSet()) and IsSoulbound and Level < {itemlevel}", "table" },
        { 'TSM_CustomValue("dbregionmarketavg") > 0', "TSM" },
        { 'IsInList("Precious")', "list" },
      }
      for _, case in ipairs(failing) do
        local result = convert(case[1])
        assert.is_nil(result.query, case[1])
        assert.truthy(result.problem:find(case[2], 1, true), result.problem)
      end
    end)
  end)

  -- ─── Reading the rule as Lua ─────────────────────────────────────────────────────────────────

  describe("reading Lua", function()
    it("skips comments, short and long", function()
      assert.are.equal("toy = true AND known = true", query("IsToy --[[ a toy ]] and --[==[ ]] ]==] IsAlreadyKnown -- end"))
    end)

    it("reads every way Lua writes a text", function()
      assert.are.equal('name == \'say "hi"\'', query('Name == "say \\"hi\\""'))
      assert.are.equal('name == "A"', query("Name == '\\65'"))
      assert.are.equal('name == "x\\y"', query('Name == [[x\\y]]'))
      assert.are.equal('name == "a"', query("Name == [==[a]==]"))
      assert.are.equal('name == "x"', query("Name == [[\nx]]"), "a long text drops its first newline")
      assert.are.equal('name == "ab"', query('Name == "a" .. "b"'))
      assert.are.equal('tooltip %= "Garrison"', query('TooltipContains "Garrison"'), "a call with a text and no ()")
    end)

    it("reads every way Lua writes a number", function()
      assert.are.equal("ilvl > 16", query("Level > 0x10"))
      assert.are.equal("ilvl > 0.5", query("Level > .5"))
      assert.are.equal("ilvl > 1000", query("Level > 1e3"))
      assert.is_nil(convert("Level > 5and IsToy").query, "Lua reads 5and as a malformed number")
    end)

    it("writes a number the search reads back exactly", function()
      assert.are.equal("ilvl > 0.30000000000000004", query("Level > 0.1 + 0.2"))
    end)

    it("follows Lua's precedence", function()
      assert.are.equal("toy = true", query("not IsToy == false"), "not before ==")
      assert.are.equal("toy = true OR known = true AND pet = true", query("IsToy or IsAlreadyKnown and IsPet"))
      assert.are.equal("(toy = true OR known = true) AND pet = true", query("(IsToy or IsAlreadyKnown) and IsPet"))
      assert.are.equal("ilvl > 2 + 3 * count", query("Level > 2 + 3 * Count"))
      assert.are.equal("ilvl > (2 + count) * 3", query("Level > (2 + Count) * 3"))
      assert.are.equal("ilvl > count - (count - 1)", query("Level > Count - (Count - 1)"))
      assert.are.equal("ilvl > - count", query("Level > -Count"))
      assert.are.equal("ilvl > 8", query("Level > 2 ^ 3"), "constants fold")
      assert.are.equal("ilvl > 512", query("Level > 2 ^ 3 ^ 2"), "^ groups to the right")
    end)

    it("reads and / or between values as Lua does", function()
      assert.are.equal("NOT toy = true", query("IsToy == (false and true)"), "and gives its first value when false")
      assert.are.equal("rarity = 3", query("Quality == (EPIC and RARE)"))
      assert.truthy(convert("Quality == (nil and 4)").problem:find("no item", 1, true))
      assert.are.same({}, convert("IsToy == (true or false)").notes, "booleans need no note")
    end)

    it("reads a rule's result as Vendor does: a number is true when it is not 0", function()
      assert.are.equal("ilvl != 0", query("Level"))
      assert.are.equal("toy = true AND ilvl != 0", query("IsToy and Level"))
      assert.are.equal("ilvl != 0", query("Level or IsToy"), "Lua's or gives the number")
      assert.are.equal("toy = true OR ilvl != 0", query("IsToy or Level"))
      assert.are.equal("toy = true", query("Level and IsToy"), "a number is always true inside the rule")
    end)

    it("says when a rule is not valid Lua", function()
      for _, script in ipairs({ "Level >", "Level == 5)", "Name == 'open", "IsToy and", "--[[ open", "Level @ 5",
        "function() return true end", "Level[1]" }) do
        local result = convert(script)
        assert.is_nil(result.query, script)
        assert.is_string(result.problem, script)
      end
    end)

    it("says when a rule matches every item or none", function()
      assert.truthy(convert("not IsEquipped").problem:find("every", 1, true))
      assert.truthy(convert("IsEquipped").problem:find("no item", 1, true))
      assert.truthy(convert("Name").problem:find("no item", 1, true), "a text is false as a result")
      assert.truthy(convert('"x"').problem:find("no item", 1, true))
      assert.truthy(convert("0").problem:find("no item", 1, true))
      assert.truthy(convert("1").problem:find("every", 1, true))
    end)
  end)

  -- ─── Properties, functions and constants ───────────────────────────────────────────────────────

  describe("properties, functions and constants", function()
    it("compares the slot by its token", function()
      assert.are.equal("slot == INVTYPE_HEAD", query('EquipLoc == "INVTYPE_HEAD"'))
      assert.are.equal("slot ~= INVTYPE_HEAD", query('EquipLoc ~= "INVTYPE_HEAD"'))
      assert.are.equal("slot == INVTYPE_CLOAK", query("EquipLocName == INVTYPE_CLOAK"))
      assert.are.same({}, convert("EquipLocName == INVTYPE_CLOAK").notes)
      local result = convert("EquipLoc == INVTYPE_HEAD")
      assert.are.equal("slot == INVTYPE_HEAD", result.query)
      assert.truthy(result.notes[1]:find("INVTYPE_HEAD", 1, true), "Vendor reads INVTYPE_HEAD as the slot's name")
      assert.is_nil(convert('EquipLoc == ""').query)
      assert.is_nil(convert('EquipLoc == "Head"').query, "EquipLoc holds a token, never a name")
      assert.is_nil(convert("Name == INVTYPE_HEAD").query, "only the slot is compared with a slot")
    end)

    it("finds stats by Blizzard's names, any of several", function()
      assert.are.equal('stat == "Critical Strike" OR stat == "Versatility"', query('HasStat("crit", "VERS", "nope")'))
      assert.are.equal('stat == "Bonus Armor"', query('HasStat("armor")'))
      assert.truthy(convert('HasStat("nope")').problem:find("no item", 1, true))
    end)

    it("reads professions by skill line, by name or by Vendor's constant", function()
      assert.are.equal("player.profession = 186 OR player.profession = 197",
        query('HasProfession("Mining", TAILORING, 999)'))
    end)

    it("reads equipment sets by name", function()
      assert.are.equal('equipmentset == "Tank" OR equipmentset == "Heal"', query('IsInEquipmentSet("Tank", "Heal")'))
    end)

    it("reads the counts, values and slot values", function()
      assert.are.equal("total > 10", query("TotalItemCount() > 10"))
      assert.truthy(convert("TotalItemCount(true) > 10").notes[1]:find("bank", 1, true))
      assert.are.equal("floor(price / 10000) > 5", query("UnitGoldValue > 5"))
      assert.are.equal("price * count >= 100", query("TotalValue >= 100"))
      assert.are.equal("floor(price * count / 10000) < 1", query("TotalGoldValue < 1"))
      assert.are.equal("100 / (price * count) > 1", query("100 / TotalValue > 1"))
      assert.are.equal("ilvl < slotbest", query("Level < WatermarkLevel()"))
      assert.truthy(convert("Level < WatermarkLevel(true)").problem:find("account", 1, true))
    end)

    it("reads every player value", function()
      assert.are.equal('player.class == "PALADIN"', query('PlayerClass() == "PALADIN"'))
      assert.are.equal("player.classid = 2", query("PlayerClassId() == 2"))
      assert.are.equal('player.spec == "Protection"', query('PlayerSpecialization() == "Protection"'))
      assert.are.equal("player.specid = 66", query("PlayerSpecializationId() == 66"))
      assert.are.equal('name == player.name', query("Name == PlayerName"))
      assert.are.equal('name == player.name', query("PlayerName == Name"), "the item's text on the left")
      assert.are.equal('player.realm == "Somewhere"', query('PlayerRealm == "Somewhere"'))
    end)

    it("swaps a comparison written constant first", function()
      assert.are.equal("ilvl < 5", query("5 > Level"))
      assert.are.equal('name == "x"', query('"x" == Name'))
    end)

    it("reads Lua's string functions on an item's text", function()
      assert.are.equal('name %= "Bearer"', query('Name:find("Bearer")'))
      assert.are.equal('subtype %= "Relic"', query('string.match(SubType, "Relic")'))
      assert.are.equal('name %= "[x]"', query('string.find(Name, "[x]", 1, true)'), "plain: not a pattern")
      assert.are.equal("NOT name %= \"x\"", query('string.find(Name, "x") == nil'))
      assert.is_nil(convert('string.find(Link, "x")').query)
      assert.is_nil(convert('string.find(Name, "x", 5)').query, "from a position")
      assert.is_nil(convert('string.find(EquipLoc, "HEAD")').query, "the slot's token")
    end)

    it("reads a tooltip text as plain text, and refuses a Lua pattern", function()
      assert.are.equal('tooltip %= "50% off"', query('TooltipContains("50%% off")'))
      local result = convert('TooltipContains("Wrath-Touched")')
      assert.are.equal('tooltip %= "Wrath-Touched"', result.query)
      assert.truthy(result.notes[1]:find("plain", 1, true))
      for _, pattern in ipairs({ "%d+ Armor", "^Use:", "[Aa]rmor", "Armor$" }) do
        assert.is_nil(convert('TooltipContains("' .. pattern .. '")').query, pattern)
      end
      assert.is_nil(convert("TooltipContains(Name)").query, "the item's own text")
    end)

    it("quotes a text that has both quotes", function()
      assert.are.equal("name == \"it's \\\"x\\\"\"", query("Name == 'it\\'s \"x\"'"))
    end)

    it("reads Vendor's expansion constants, CURRENT_EXPANSION as Vendor sets it", function()
      assert.are.equal("exp >= 9", query("ExpansionPackId >= DRAGONFLIGHT"))
      assert.are.equal("exp = 10", query("ExpansionPackId == CURRENT_EXPANSION"))
      assert.are.equal("exp = 4", query("ExpansionPackId == CURRENT_EXPANSION", { classic = true }))
      assert.are.equal("expansionid + 1 > 7", query("ExpansionPackId + 1 > 7"), "the number in arithmetic")
    end)

    it("reads a rule's parameters", function()
      assert.are.equal("ilvl < 300", query("Level < ITEMLEVEL", { params = { ITEMLEVEL = 300 } }))
      assert.truthy(convert("Level < ITEMLEVEL").problem:find("ITEMLEVEL", 1, true))
    end)

    it("says which property BetterBags has nothing for", function()
      for _, name in ipairs({ "Link", "InventoryType", "IsConduit", "IsAzeriteItem", "PetName", "PetType",
        "IsPetTradeable", "PetSpeciesId", "AppearanceId", "SourceId", "TooltipData", "Location" }) do
        local result = convert(name .. " == 1")
        assert.is_nil(result.query, name)
        assert.truthy(result.problem:find(name, 1, true), name)
        assert.truthy(result.problem:find("nothing for", 1, true), name)
      end
      assert.truthy(convert("Frobnicate == 1").problem:find("Frobnicate is not something", 1, true))
      assert.is_nil(convert("Level(5) > 1").query, "a property called with arguments")
      assert.truthy(convert("print(Level)").problem:find("print", 1, true))
    end)

    it("works out math with fixed values, and refuses it on texts", function()
      assert.are.equal("ilvl > 3", query("Level > math.min(3, 4)"))
      assert.are.equal("ilvl > floor(count)", query("Level > math.floor(Count, 2)"), "Lua ignores a second value")
      assert.is_nil(convert("Level > math.min(Name, 1)").query)
    end)

    it("compares a condition with true and false", function()
      assert.are.equal("toy = true", query("IsToy == true"))
      assert.are.equal("NOT toy = true", query("IsToy ~= true"))
      assert.are.equal("toy = true", query("IsToy ~= false"))
      assert.are.equal("NOT toy = true", query("IsToy == false"))
    end)

    it("compares two conditions with each other", function()
      assert.are.equal("toy = true AND known = true OR NOT toy = true AND NOT known = true",
        query("IsToy == IsAlreadyKnown"))
    end)

    it("refuses what has no meaning for an item", function()
      assert.is_nil(convert("Name < 5").query)
      assert.is_nil(convert('Name < "m"').query, "the search does not order texts")
      assert.is_nil(convert("Name == Type").query, "two texts of the item")
      assert.is_nil(convert("Level .. Name").query)
    end)
  end)

  -- ─── Every conversion is a search BetterBags reads ───────────────────────────────────────────

  it("gives only queries the search parses", function()
    local scripts = {
      "IsToy or (Level > 5 and not (Count < 2 or IsPet))", "Level > Count * 2 - -3", "HasStat('haste', 'crit')",
      "Quality == EPIC and (TooltipContains(\"x\") or not IsInEquipmentSet('a b'))", "MaxLevel >= math.max(1, Level)",
      "not (not IsToy)",
    }
    for _, script in ipairs(scripts) do
      local q = query(script)
      assert.is_not_nil(QueryParser:Query(q), q)
    end
  end)

  it("says so rather than give a query the search cannot read", function()
    local read = QueryParser.Query
    QueryParser.Query = function() return nil end
    local result = convert("IsToy")
    QueryParser.Query = read
    assert.is_nil(result.query)
    assert.truthy(result.problem:find("IsToy", 1, true))
  end)

  -- ─── Converted rules pick the same items Vendor's rules do ───────────────────────────────────

  -- Random Vendor rules over properties that map one to one are run as Lua over random items (as
  -- Vendor runs them, rules/rule.lua: a boolean as is, a number when not 0), and converted and run by
  -- the search over the same items.
  describe("the same items as Vendor", function()
    local saved = {}
    local NUMBER = { "Level", "Quality", "TypeId", "SubTypeId", "MaxLevel", "MinLevel", "UnitValue", "Count",
      "ExpansionPackId" }
    local BOOL = { "IsEquipment", "IsToy", "IsCraftingReagent", "IsUsable", "IsEquippable", "IsUnsellable" }
    local NAMES = { "sword", "potion", "cheese", "orb", "swordfish" }
    local CMP = { "==", "~=", "<", "<=", ">", ">=" }

    local function pick(list) return list[math.random(#list)] end

    local function number(depth)
      local r = math.random(depth > 2 and 3 or 7)
      if r == 1 then return pick(NUMBER) end
      if r == 2 then return tostring(math.random(0, 60)) end
      if r == 3 then return pick({ "POOR", "EPIC", "LEGION", "PlayerLevel()", "0.5" }) end
      if r == 4 then return "(" .. number(depth + 1) .. " " .. pick({ "+", "-", "*" }) .. " " .. number(depth + 1) .. ")" end
      if r == 5 then return "math." .. pick({ "min", "max" }) .. "(" .. number(depth + 1) .. ", " .. number(depth + 1) .. ")" end
      if r == 6 then return "(" .. number(depth + 1) .. " " .. pick({ "/ 2", "% 7" }) .. ")" end
      return "-" .. pick(NUMBER)
    end

    local function condition(depth)
      local r = math.random(depth > 3 and 4 or 8)
      if r == 1 then return pick(BOOL) end
      if r == 2 then return number(depth + 1) .. " " .. pick(CMP) .. " " .. number(depth + 1) end
      if r == 3 then return "Name " .. pick({ "==", "~=" }) .. ' "' .. pick(NAMES) .. '"' end
      if r == 4 then return 'string.find(Name, "' .. pick({ "or", "sw", "ee", "fish" }) .. '")' end
      if r == 5 then return "not (" .. condition(depth + 1) .. ")" end
      if r == 6 then return "(" .. condition(depth + 1) .. " and " .. condition(depth + 1) .. ")" end
      if r == 7 then return "(" .. condition(depth + 1) .. " or " .. condition(depth + 1) .. ")" end
      return pick(BOOL) .. " == " .. pick({ "true", "false" })
    end

    before_each(function()
      saved = { UnitLevel = _G.UnitLevel }
      _G.UnitLevel = function() return 30 end
      search:Init()
    end)

    after_each(function()
      _G.UnitLevel = saved.UnitLevel
    end)

    for _, seed in ipairs({ 11, 12, 13 }) do
      it("over random rules and items (seed " .. seed .. ")", function()
        math.randomseed(seed)
        local vendorItems = {}
        for i = 1, 40 do
          local level = math.random(1, 60)
          local v = {
            Level = level, Quality = math.random(0, 6), TypeId = math.random(0, 6), SubTypeId = math.random(0, 6),
            MaxLevel = level + math.random(0, 3) * 5, MinLevel = math.random(0, 3) * 10,
            UnitValue = math.random(3) == 1 and 0 or math.random(1, 50), Count = math.random(1, 20),
            ExpansionPackId = math.random(0, 10), IsEquipment = math.random(2) == 1, IsToy = math.random(3) == 1,
            IsCraftingReagent = math.random(3) == 1, IsUsable = math.random(2) == 1, Name = pick(NAMES),
          }
          v.IsEquippable = v.IsUsable and v.IsEquipment
          v.IsUnsellable = v.UnitValue == 0
          vendorItems["v" .. i] = v
          local item = MockData.ItemData({ slotkey = "v" .. i, name = v.Name, currentItemLevel = v.Level,
            quality = v.Quality, classID = v.TypeId, subclassID = v.SubTypeId, count = v.Count, isReagent = v.IsCraftingReagent,
            expacID = v.ExpansionPackId, traits = { minLevel = v.MinLevel, sellPrice = v.UnitValue,
              upgradeMaxItemLevel = v.MaxLevel, isEquipment = v.IsEquipment, stats = {} } })
          item.itemInfo.tooltipMarks = { toy = v.IsToy }
          item.isUsable = v.IsUsable
          search:Add(item)
        end
        local env = { POOR = 0, EPIC = 4, LEGION = 6, math = math, string = string,
          PlayerLevel = function() return 30 end }
        local checked = 0
        for _ = 1, 1500 do
          local rule = condition(0)
          local fn = assert(loadstring("return (" .. rule .. ")"))
          local vendor = {}
          for key, v in pairs(vendorItems) do
            local scope = setmetatable({}, { __index = function(_, name)
              if v[name] ~= nil then return v[name] end
              return env[name]
            end })
            setfenv(fn, scope)
            local result = fn()
            if type(result) == "number" then result = result ~= 0 else result = result == true end
            if result then vendor[key] = true end
          end
          local converted = convert(rule)
          if converted.query then
            assert.are.same(vendor, search:Search(converted.query), rule .. "  =>  " .. converted.query)
            checked = checked + 1
          else
            -- Only a rule that matches every item or none is not converted.
            local all = 0
            for _ in pairs(vendor) do all = all + 1 end
            local every = converted.problem:find("every", 1, true) ~= nil
            assert.truthy(every or converted.problem:find("no item", 1, true), rule .. ": " .. converted.problem)
            assert.are.equal(every and 40 or 0, all, rule)
          end
        end
        assert.is_true(checked > 1200, checked)
      end)
    end
  end)
end)
