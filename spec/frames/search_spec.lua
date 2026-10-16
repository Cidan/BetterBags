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
StubBetterBagsModule("SearchCategoryConfig")

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
