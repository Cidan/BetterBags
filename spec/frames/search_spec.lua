-- search_spec.lua -- Unit tests for frames/search.lua (SearchBox module).
--
-- Focus: searchBox:GetSearchText(kind), the query source the data pipeline
-- (data/items.lua Phase8_EnrichCategories) consults to recompute
-- item.isSearchResult on every redraw. The live filter is driven by the
-- per-kind in-bag box (searchBox:CreateBox -> decoration.search), which is
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

local themes = StubBetterBagsModule("Themes")

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
  local backpackFrame, bankFrame
  local inBagBoxes

  before_each(function()
    backpackFrame = {}
    bankFrame = {}
    addon.Bags = {
      Backpack = { frame = backpackFrame },
      Bank = { frame = bankFrame },
    }
    inBagBoxes = {}
    themes.GetInBagSearchBox = function(_, frame) return inBagBoxes[frame] end
    -- Overlay box is empty by default (mirrors in-bag search being the active box).
    searchBox.searchFrame = makeBox("")
    database.GetInBagSearch = function() return true end
  end)

  it("reads the per-kind in-bag box, not the empty overlay box, when in-bag search is on", function()
    inBagBoxes[backpackFrame] = makeBox("ink")
    inBagBoxes[bankFrame] = makeBox("")

    -- The overlay-only getter still returns empty -- this is the source of the bug.
    assert.equal("", searchBox:GetText())
    -- The kind-aware getter must find the backpack's in-bag query.
    assert.equal("ink", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  it("resolves the bank in-bag box for the BANK kind", function()
    inBagBoxes[backpackFrame] = makeBox("ink")
    inBagBoxes[bankFrame] = makeBox("cloth")

    assert.equal("cloth", searchBox:GetSearchText(const.BAG_KIND.BANK))
  end)

  it("falls back to the overlay box when the in-bag box is empty", function()
    inBagBoxes[backpackFrame] = makeBox("")
    searchBox.searchFrame = makeBox("overlayquery")

    assert.equal("overlayquery", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
  end)

  it("uses the overlay box when in-bag search is disabled", function()
    database.GetInBagSearch = function() return false end
    inBagBoxes[backpackFrame] = makeBox("ink")
    searchBox.searchFrame = makeBox("overlayquery")

    assert.equal("overlayquery", searchBox:GetSearchText(const.BAG_KIND.BACKPACK))
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
