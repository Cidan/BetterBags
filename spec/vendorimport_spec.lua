-- vendorimport_spec.lua -- Reading the Vendor addon's saved rules and making categories of them
-- (data/vendorimport.lua, .claude/rules/search-indexing.md §18).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("util/query.lua")
ResetModuleStub("Localization", "core/localization.lua")
LoadBetterBagsModule("core/localization.lua")
ResetModuleStub("VendorRule", "util/vendorrule.lua")
LoadBetterBagsModule("util/vendorrule.lua")

local categories = StubBetterBagsModule("Categories")
local events = StubBetterBagsModule("Events")
ResetModuleStub("VendorImport", "data/vendorimport.lua")
LoadBetterBagsModule("data/vendorimport.lua")
local VendorImport = addon:GetModule("VendorImport")

-- Vendor's own saved-variables test data (github.com/typicalzergling/vendor, MIT licensed,
-- test/migration/11.7.2022/Vendor.lua): an account's ten custom rules, seven in the list Vendor
-- reads and three an older Vendor saved under their ID.
local function savedRules()
  return {
    { Type = "Keep", Script = 'HasStat("speed")', Id = "cr.malvir.lightbringer.1601961838", Name = "Has Speed",
      Description = "Has Speed" },
    { Type = "Sell", Script = 'SubType == "Artifact Relic"', Id = "cr.malvir.lightbringer.1602290239",
      Name = "Artifacts", Description = "Vendors old artifact relics" },
    { Type = "Sell", Script = 'TypeId == 15 and SubTypeId == 4 and IsAlreadyKnown and TooltipContains("Garrison Blueprint")',
      Id = "cr.szarekh.lightbringer.1605511839", Name = "Known Garrison Blueprints",
      Description = "Sell Known Garrison Blueprints" },
    { Type = "Sell", Script = "(Id ==  163569) and (NumKeep() >= 1)", Id = "cr.thoekh.lightbringer.1605999007",
      Name = "Destroy all but 1 scourgestone stack", Description = "Keep 1 scourgestone stack, destroy the rest." },
    { Type = "Keep", Script = "string.find(Name, 'Selfless Bearer')", Id = "cr.szarekh.lightbringer.1618358047",
      Name = "Selfless Bearer Gear", Description = "Keeps Kyrian Covenant Gear" },
    { Type = "Sell", Script = "(not IsEquipment) and (SubTypeId == 0) and (TypeId == 15) and (ExpansionPackId == 0) " ..
      "and (IsUsable) and (not IsUnsellable) and (Quality == 4) and (not TooltipContains(PlayerClass()))",
      Id = "cr.szarekh.lightbringer.1623817524", Name = "Unusable TBC Equipment Tokens",
      Description = "Sells unusable TBC equipment tokens." },
    { Type = "Sell", Script = "IsCraftingReagent and (ExpansionPackId == 0)", Id = "cr.szarekh.lightbringer.1623817952",
      Name = "Old Crafting Materials", Description = "Old crafting materials not worth selling." },
    ["cr.Severin.Windrunner.1532721676"] = {
      Script = 'TypeId == 0\nand\nSubTypeId() == 8\nand\nTooltipContains("Champion Equipment")',
      Id = "cr.Severin.Windrunner.1532721676", Name = "Champion Equipment", Description = "Sells Champion equipment" },
    ["cr.Severin.Windrunner.1532503831"] = {
      Script = "TypeId() == 3\nand\nSubTypeId() == 11\nand\nLevel() < 225\nand\nExpansionPackId() == 6\n",
      Id = "cr.Severin.Windrunner.1532503831", Name = "Relics < 225", Description = "Relics under item level 225" },
    ["cr.Severin.Windrunner.1532501893"] = {
      Script = "ExpansionPackId() == 6  -- Legion\nand\nSubTypeId() == 11  -- Artifact Relic\nand\nTypeId() == 3 -- Gem\n\n",
      Id = "cr.Severin.Windrunner.1532501893", Name = "Relics < 200",
      Description = "Sells Legion Relics under Item Level 200" },
  }
end

describe("VendorImport", function()
  local saved, existing, created, sent

  local function override(tbl, key, value)
    table.insert(saved, { tbl, key, rawget(tbl, key) })
    tbl[key] = value
  end

  before_each(function()
    saved, existing, created, sent = {}, {}, {}, {}
    override(_G, "Vendor_CustomRuleDefinitions", savedRules())
    override(_G, "Vendor_Profiles", nil)
    override(_G, "Vendor_ActiveProfile", nil)
    override(_G, "ITEM_MOD_CR_SPEED_SHORT", "Speed")
    override(addon, "isRetail", true)
    override(categories, "DoesCategoryExist", function(_, name) return existing[name] ~= nil end)
    override(categories, "CreateCategory", function(_, ctx, filter)
      existing[filter.name] = filter
      table.insert(created, { ctx = ctx, filter = filter })
    end)
    override(events, "SendMessage", function(_, ctx, message, options)
      table.insert(sent, { ctx = ctx, message = message, options = options })
    end)
  end)

  after_each(function()
    for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
  end)

  describe("Rules", function()
    it("reads every custom rule, the list first, then those saved under their ID", function()
      local rules = VendorImport:Rules()
      assert.are.equal(10, #rules)
      assert.are.same({ id = "cr.malvir.lightbringer.1601961838", name = "Has Speed", type = "Keep",
        description = "Has Speed", script = 'HasStat("speed")', params = {} }, rules[1])
      local ids = {}
      for i, rule in ipairs(rules) do ids[i] = rule.id end
      assert.are.same({ "cr.malvir.lightbringer.1601961838", "cr.malvir.lightbringer.1602290239",
        "cr.szarekh.lightbringer.1605511839", "cr.thoekh.lightbringer.1605999007",
        "cr.szarekh.lightbringer.1618358047", "cr.szarekh.lightbringer.1623817524",
        "cr.szarekh.lightbringer.1623817952", "cr.Severin.Windrunner.1532501893",
        "cr.Severin.Windrunner.1532503831", "cr.Severin.Windrunner.1532721676" }, ids)
    end)

    it("reads nothing without Vendor's saved rules", function()
      _G.Vendor_CustomRuleDefinitions = nil
      assert.are.same({}, VendorImport:Rules())
      _G.Vendor_CustomRuleDefinitions = "broken"
      assert.are.same({}, VendorImport:Rules())
    end)

    it("reads a rule once, whatever case its ID has, and skips what is not a rule", function()
      _G.Vendor_CustomRuleDefinitions = {
        { Id = "cr.a", Name = "A", Script = "IsToy" },
        { Id = "CR.A", Name = "A again", Script = "IsPet" },
        { Name = "No ID", Script = "IsPet" },
        "not a table",
        b = { Id = "cr.b", Name = "B", Script = function() end },
      }
      local rules = VendorImport:Rules()
      assert.are.equal(2, #rules)
      assert.are.equal("A", rules[1].name)
      assert.is_nil(rules[2].script, "a script that is not text")
    end)

    -- Vendor saves a rule's parameters with its definition (Params: Key, Default) and the values a
    -- profile sets in the profile's rule lists ({ rule = id, KEY = value }, rules/ruleconfig.lua).
    it("gives each parameter the active profile's value, else its default", function()
      _G.Vendor_CustomRuleDefinitions = {
        { Id = "cr.gear", Name = "Gear", Script = "MaxLevel < ITEMLEVEL and (not SKIP or IsToy)",
          Params = { { Key = "ITEMLEVEL", Default = 100 }, { Key = "SKIP", Default = false },
            { Key = "COMPUTED", Default = function() return 1 end } } },
      }
      assert.are.same({ ITEMLEVEL = 100, SKIP = false }, VendorImport:Rules()[1].params)
      _G.Vendor_ActiveProfile = "Vendor:2"
      _G.Vendor_Profiles = {
        ["Vendor:1"] = { ["rules:sell"] = { { rule = "cr.gear", ITEMLEVEL = 1 } } },
        ["Vendor:2"] = { ["rules:keep"] = { "keep.legendaryandup" },
          ["rules:sell"] = { "sell.poor", { rule = "CR.GEAR", ITEMLEVEL = 250 } } },
      }
      assert.are.same({ ITEMLEVEL = 250, SKIP = false }, VendorImport:Rules()[1].params)
    end)
  end)

  describe("Convert", function()
    it("converts a rule with its parameters", function()
      local rule = { id = "x", name = "X", script = "MaxLevel < ITEMLEVEL", params = { ITEMLEVEL = 250 } }
      assert.are.equal("maxlevel < 250", VendorImport:Convert(rule).query)
    end)

    it("converts for the client it runs on", function()
      local rule = { id = "x", name = "X", script = "IsSoulbound", params = {} }
      addon.isRetail = false
      assert.are.equal("bound = true", VendorImport:Convert(rule).query)
    end)

    it("says when Vendor saved a rule without its text", function()
      assert.truthy(VendorImport:Convert({ id = "x", name = "X", params = {} }).problem:find("without its text", 1, true))
    end)
  end)

  describe("Import", function()
    it("makes a category of every rule that converts, and says why the others were not", function()
      local report = VendorImport:Import("ctx")
      assert.are.equal(9, #report.created)
      assert.are.equal(1, #report.skipped)
      assert.are.equal("Destroy all but 1 scourgestone stack", report.skipped[1].rule.name)
      assert.truthy(report.skipped[1].reason:find("NumKeep", 1, true))
      assert.are.same({ name = "Has Speed", itemList = {}, save = true, searchCategory = { query = 'stat == "Speed"' } },
        existing["Has Speed"])
      assert.are.equal('class = 0 AND subclass = 8 AND tooltip %= "Champion Equipment"',
        existing["Champion Equipment"].searchCategory.query)
      assert.are.equal("exp = 6 AND subclass = 11 AND class = 3", existing["Relics < 200"].searchCategory.query)
      assert.are.equal('stat == "Speed"', report.created[1].query)
      assert.truthy(#report.created[9].notes > 0, "Champion Equipment was written the old way")
      assert.are.equal("ctx", created[1].ctx)
    end)

    it("recalculates the bags once, after making the categories", function()
      VendorImport:Import("ctx")
      assert.are.same({ { ctx = "ctx", message = "bags/Rederive", options = { resetLayout = true, buttons = true } } }, sent)
    end)

    it("recalculates nothing when it made nothing", function()
      local report = VendorImport:Import("ctx", { { id = "x", name = "X", script = "NumKeep()", params = {} } })
      assert.are.same({}, report.created)
      assert.are.same({}, sent)
    end)

    it("leaves a category that already has the name as it is", function()
      existing["Artifacts"] = { name = "Artifacts", mine = true }
      local report = VendorImport:Import("ctx")
      assert.is_true(existing["Artifacts"].mine)
      assert.are.equal(2, #report.skipped)
      assert.truthy(report.skipped[1].reason:find("Artifacts", 1, true))
    end)

    it("imports only the rules it is given, by the names they are given", function()
      local rules = VendorImport:Rules()
      rules[2].name = "  Vendor: Artifacts  "
      local report = VendorImport:Import("ctx", { rules[2], rules[2] })
      assert.are.equal(1, #report.created)
      assert.is_not_nil(existing["Vendor: Artifacts"])
      assert.are.equal(1, #report.skipped, "the second time, the name is taken")
      local unnamed = VendorImport:Import("ctx", { { id = "y", name = " ", script = "IsToy", params = {} } })
      assert.are.equal(1, #unnamed.skipped)
    end)
  end)
end)
