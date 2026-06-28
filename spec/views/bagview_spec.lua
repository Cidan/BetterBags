local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

-- Stub modules before loading views
local L = StubBetterBagsModule("Localization")
L.G = function(self, key) return key end

StubBetterBagsModule("Items")

local themes = StubBetterBagsModule("Themes")
themes.GetTabButton = function() return {} end

local database = StubBetterBagsModule("Database")
database.GetBagSizeInfo = function()
  return { itemsPerRow = 5, columnCount = 4 }
end
database.GetBagView = function() return 1 end
database.GetInBagSearch = function() return false end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { SECTION_GRID = 1, SECTION_ALL_BAGS = 2 }
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.GRID_COMPACT_STYLE = { NONE = 0 }
const.OFFSETS = {
  BAG_LEFT_INSET = 10,
  BAG_TOP_INSET = -40,
  BAG_RIGHT_INSET = -10,
  BAG_BOTTOM_INSET = 10,
  BOTTOM_BAR_HEIGHT = 20,
  BOTTOM_BAR_BOTTOM_INSET = 5,
  SCROLLBAR_WIDTH = 12,
}
const.BACKPACK_BAGS = { [0] = true, [1] = true }

local sort = StubBetterBagsModule("Sort")
sort.SortSectionsAlphabetically = function() return true end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.StartProfile = function() end
debug.EndProfile = function() end

StubBetterBagsModule("Categories")
StubBetterBagsModule("Groups")

-- Stub SectionFrame
local sectionFrame = StubBetterBagsModule("SectionFrame")
local sectionProto = {
  ReleaseAllCells = function() end,
  Release = function() end,
  GetCellCount = function() return 1 end,
  SetMaxCellWidth = function() end,
  Draw = function() end,
}
sectionFrame.Create = function()
  return setmetatable({}, { __index = sectionProto })
end

-- Stub ItemFrame
local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.Create = function()
  return {
    SetItem = function() end,
    SetFreeSlots = function() end,
    UpdateCount = function() end,
  }
end

-- Mock Grid module
local mockGridProto = {
  HideScrollBar = function() end,
  ShowScrollBar = function() end,
  EnableMouseWheelScroll = function() end,
  Wipe = function() end,
  Sort = function() end,
  Draw = function() return 100, 50 end,
  GetContainer = function(self)
    if not self._container then
      self._container = CreateFrame("Frame")
    end
    return self._container
  end,
  Show = function() end,
  Hide = function() end,
}

local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  return setmetatable({}, { __index = mockGridProto })
end

-- Load views/views.lua first (provides views:NewBlankView)
LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")

-- Load views/bagview.lua
LoadBetterBagsModule("views/bagview.lua")

local context = addon:GetModule("Context")

describe("Bag View", function()
  after_each(function()
    ResetModuleStub("Localization", "core/localization.lua")
    ResetModuleStub("Items", "data/items.lua")
    ResetModuleStub("Themes", "themes/themes.lua")
    ResetModuleStub("Database", "core/database.lua")
    ResetModuleStub("Constants", "core/constants.lua")
    ResetModuleStub("Sort", "util/sort.lua")
    ResetModuleStub("Debug", "debug/debug.lua")
    ResetModuleStub("Categories", "data/categories.lua")
    ResetModuleStub("Groups", "data/groups.lua")
    ResetModuleStub("SectionFrame", "frames/section.lua")
    ResetModuleStub("ItemFrame", "frames/item.lua")
    ResetModuleStub("Grid", "frames/grid.lua")
    ResetModuleStub("Views", "views/views.lua")
  end)

  describe("NewBagView", function()
    it("creates a new bag view correctly", function()
      local parent = CreateFrame("Frame")
      local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK)
      assert.is_not_nil(view)
      assert.is_not_nil(view.content)
      assert.are.equal(view.kind, const.BAG_KIND.BACKPACK)
      assert.are.equal(view.bagview, const.BAG_VIEW.SECTION_ALL_BAGS)
      assert.is_not_nil(view.Render)
      assert.is_not_nil(view.WipeHandler)
    end)
  end)

  describe("Wipe", function()
    it("wipes view and releases sections on wipe context", function()
      local parent = CreateFrame("Frame")
      local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK)
      local mockSection = setmetatable({
        releasedCells = false,
        released = false,
      }, {
        __index = {
          ReleaseAllCells = function(self) self.releasedCells = true end,
          Release = function(self) self.released = true end,
        }
      })
      view.sections["test_section"] = mockSection
      local ctx = context:New("WipeView")
      view:Wipe(ctx)
      assert.is_true(mockSection.releasedCells)
      assert.is_true(mockSection.released)
      assert.is_nil(view.sections["test_section"])
    end)
  end)

  describe("Render", function()
    it("renders the bag view and computes sizes correctly", function()
      local parent = CreateFrame("Frame")
      local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK)
      local bag = {
        kind = const.BAG_KIND.BACKPACK,
        frame = CreateFrame("Frame"),
      }
      local slotInfo = {
        GetChangeset = function() return {}, {}, {} end,
        emptySlotByBagAndSlot = {}
      }
      local callbackCalled = false
      local callback = function()
        callbackCalled = true
      end
      local ctx = context:New("RenderView")
      view:Render(ctx, bag, slotInfo, callback)
      assert.is_true(callbackCalled)
      assert.are.equal(bag.frame:GetHeight(), 50 + 10 + 40 + 20 + 5) -- h + bottom offsets
    end)
  end)
end)
