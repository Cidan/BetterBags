-- search_spec.lua -- Unit tests for frames/search.lua (SearchBox module).
--
-- Focus: searchBox:GetSearchText(kind), the query source the data pipeline
-- (data/items.lua Phase8_EnrichCategories) consults to recompute
-- item.isSearchResult on every redraw. The live filter is driven by the
-- per-kind in-bag box (searchBox:CreateBox, kept by its bag as bag.searchBox), which is
-- distinct from the module-level overlay searchFrame. Reading only the overlay
-- box reset the filter to "everything matches" on any redraw while the user was
-- using the in-bag search (the reported "right-click to bank clears the search
-- filter" bug).

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- frames/search.lua resolves these modules at file scope; stub the ones it needs.
StubBetterBagsModule("Animations")
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
addon:GetModule("Events"):Init()
StubBetterBagsModule("Search")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = const.BAG_KIND or { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }

local database = StubBetterBagsModule("Database")

local _, createdSonata = StubBetterBagsModule("Sonata")
local _, createdWindow = StubBetterBagsModule("Window")

-- Other specs stub "SearchBox"; clear any prior stub so the real module file
-- can register cleanly here (mirrors the data/search.lua reset-then-load pattern).
ResetModuleStub("SearchBox", "frames/search.lua")
LoadBetterBagsModule("frames/search.lua")
local searchBox = addon:GetModule("SearchBox")

--- Build a fake SearchFrame-like box whose textBox returns the given text.
local function makeBox(text)
  return { textBox = { GetText = function() return text end } }
end

describe("SearchBox:GetSearchText", function()
  teardown(function()
    if createdSonata then ResetModuleStub("Sonata") end
    if createdWindow then ResetModuleStub("Window") end
  end)

  before_each(function()
    addon.Bags = {
      Backpack = { frame = {} },
      Bank = { frame = {} },
    }
    -- Overlay box is empty by default (mirrors in-bag search being the active box).
    searchBox.searchFrame = makeBox("")
    database.GetInBagSearch = function() return true end
  end)

  it("reads the per-kind in-bag box, not the empty overlay box, when in-bag search is on", function()
    addon.Bags.Backpack.searchBox = makeBox("ink")
    addon.Bags.Bank.searchBox = makeBox("")

    -- The overlay-only getter still returns empty -- this is the source of the bug.
    assert.equal("", searchBox:GetText())
    -- The kind-aware getter must find the backpack's in-bag query.
    assert.equal("ink", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  it("resolves the bank in-bag box for the BANK kind", function()
    addon.Bags.Backpack.searchBox = makeBox("ink")
    addon.Bags.Bank.searchBox = makeBox("cloth")

    assert.equal("cloth", searchBox:GetSearchText(const.BAG_KIND.BANK))
  end)

  it("falls back to the overlay box when the in-bag box is empty", function()
    addon.Bags.Backpack.searchBox = makeBox("")
    searchBox.searchFrame = makeBox("overlayquery")

    assert.equal("overlayquery", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  it("uses the overlay box when in-bag search is disabled", function()
    database.GetInBagSearch = function() return false end
    addon.Bags.Backpack.searchBox = makeBox("ink")
    searchBox.searchFrame = makeBox("overlayquery")

    assert.equal("overlayquery", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  it("finds each bag's own in-bag box, and none for a bag that was not made", function()
    local box = makeBox("x")
    addon.Bags.Backpack.searchBox = box
    addon.Bags.Bank = nil
    assert.are.equal(box, searchBox:GetInBagBox(const.BAG_KIND.BACKPACK))
    assert.is_nil(searchBox:GetInBagBox(const.BAG_KIND.BANK))
    assert.equal("", searchBox:GetSearchText(const.BAG_KIND.BANK))
  end)

  -- The guild bank's in-bag box is BetterBags Next's guild bank panel's (guild-bank.md §5).
  describe("the guild bank", function()
    local GUILD = 2
    local saved, searched, reset

    before_each(function()
      saved = {
        guild = rawget(const.BAG_KIND, "GUILD"),
        attach = rawget(addon:GetModule("Animations"), "AttachFadeGroup"),
        register = rawget(addon:GetModule("Sonata"), "RegisterElement"),
        search = rawget(addon:GetModule("Search"), "Search"),
      }
      const.BAG_KIND.GUILD = GUILD
      addon:GetModule("Animations").AttachFadeGroup = function()
        local group = { Play = function() end }
        return group, group
      end
      addon:GetModule("Sonata").RegisterElement = function() end
      addon:GetModule("Search").Search = function(_, text) return { query = text } end
      searched, reset = nil, 0
      addon.Bags.GuildBank = {
        frame = {},
        Search = function(_, _, results) searched = results end,
        ResetSearch = function() reset = reset + 1 end,
      }
      addon.Bags.Bank.Search = function() error("the bank is not searched") end
    end)

    after_each(function()
      const.BAG_KIND.GUILD = saved.guild
      addon:GetModule("Animations").AttachFadeGroup = saved.attach
      addon:GetModule("Sonata").RegisterElement = saved.register
      addon:GetModule("Search").Search = saved.search
    end)

    it("finds the guild bank's in-bag box, and its query", function()
      addon.Bags.GuildBank.searchBox = makeBox("ore")
      assert.are.equal(addon.Bags.GuildBank.searchBox, searchBox:GetInBagBox(GUILD))
      assert.equal("ore", searchBox:GetSearchText(GUILD))
    end)

    it("names its box after the guild bank, and searches only the guild bank as it is typed in", function()
      local box = searchBox:CreateBox(GUILD, CreateFrame("Frame"))
      assert.are.equal("Search Guild Bank", box.helpText:GetText())
      local ctx = addon:GetModule("Context"):New("test")
      box.textBox:SetText("ore")
      box:UpdateSearch(ctx)
      assert.are.same({ query = "ore" }, searched)
      box.textBox:SetText("")
      box:UpdateSearch(ctx)
      assert.are.equal(1, reset)
    end)
  end)

  -- Enter to Make Category opens the Categories page with a new category from the search
  -- (category-lifecycle.md §6); the old search category dialog is gone.
  it("asks for a category made from the search on Enter, when Enter to Make Category is on", function()
    local events = addon:GetModule("Events")
    local savedSend, savedOn, savedAttach, savedRegister = events.SendMessage, database.GetEnterToMakeCategory,
      rawget(addon:GetModule("Animations"), "AttachFadeGroup"), rawget(addon:GetModule("Sonata"), "RegisterElement")
    local sent = {}
    events.SendMessage = function(_, _, message, ...) table.insert(sent, { message, ... }) end
    addon:GetModule("Animations").AttachFadeGroup = function()
      local group = { Play = function() end }
      return group, group
    end
    addon:GetModule("Sonata").RegisterElement = function() end
    local on = true
    database.GetEnterToMakeCategory = function() return on end
    local box = searchBox:CreateBox(const.BAG_KIND.BACKPACK, CreateFrame("Frame"))
    box.textBox:SetText("rarity = epic")
    box.textBox:GetScript("OnEnterPressed")(box.textBox)
    on = false
    box.textBox:GetScript("OnEnterPressed")(box.textBox)
    events.SendMessage, database.GetEnterToMakeCategory = savedSend, savedOn
    addon:GetModule("Animations").AttachFadeGroup = savedAttach
    addon:GetModule("Sonata").RegisterElement = savedRegister
    assert.are.same({ { "config/NewCategoryFromSearch", "rarity = epic" } }, sent)
  end)

  it("returns empty string when no search box holds any text", function()
    searchBox.searchFrame = makeBox("")
    assert.equal("", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  -- This spec loads the real SearchBox module into the shared suite state; every
  -- other spec expects SearchBox to be a plain stub. Restore that so later
  -- Phase8-driving specs don't invoke the real GetSearchText against their bare
  -- Database/Themes stubs.
  teardown(function()
    ResetModuleStub("SearchBox", "frames/search.lua")
  end)
end)
