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

local items = StubBetterBagsModule("Items")
items.GetItemDataFromSlotKey = function() return nil end
items.GetCategory = function() return "TestCategory" end

local themes = StubBetterBagsModule("Themes")
themes.GetTabButton = function() return {} end
themes.GetFlatHeaderHeight = function() return 12 end

local database = StubBetterBagsModule("Database")
database.GetBagSizeInfo = function()
  return { itemsPerRow = 5, columnCount = 4 }
end
database.GetBagView = function() return 1 end
database.GetInBagSearch = function() return false end
database.GetShowNewItemFlash = function() return false end
database.GetGroupsEnabled = function() return true end
database.GetActiveGroup = function() return 2 end -- Active Group is 2
database.GetShowBankTabs = function() return false end
database.GetShowAllFreeSpace = function() return false end
database.GetStackingOptions = function()
  return {
    mergeStacks = false,
    unmergeAtShop = false,
    dontMergePartial = false,
    mergeUnstackable = false,
  }
end

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
debug.WalkAndFixAnchorGraph = function() end

local categories = StubBetterBagsModule("Categories")
categories.IsCategoryShown = function() return true end
categories.GetCategoryByName = function() return nil end
categories.CreateCategory = function() end

local groups = StubBetterBagsModule("Groups")
groups.CategoryBelongsToGroup = function() return false end -- Does NOT belong to active group 2 by default

-- Stub SectionFrame
local sectionFrame = StubBetterBagsModule("SectionFrame")
local sectionProto = {
  ReleaseAllCells = function() end,
  Release = function() end,
  GetCellCount = function() return 1 end,
  SetMaxCellWidth = function() end,
  Draw = function() end,
  SetTitle = function() end,
  GetAllCells = function() return {} end,
  AddCell = function() end,
}
sectionFrame.Create = function()
  local s = setmetatable({}, { __index = sectionProto })
  s.frame = CreateFrame("Frame")
  return s
end

-- Stub ItemFrame
local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.Create = function()
  return {
    SetItem = function() end,
    SetFreeSlots = function() end,
    UpdateCount = function() end,
    GetItemData = function() return { slotkey = "1_1" } end,
  }
end

-- Mock Grid module
local mockGridProto = {
  HideScrollBar = function() end,
  ShowScrollBar = function() end,
  EnableMouseWheelScroll = function() end,
  Wipe = function() end,
  Sort = function() end,
  SortVertical = function() end,
  Draw = function(self, options)
    self.lastMask = options and options.mask
    return 100, 50
  end,
  GetContainer = function(self)
    if not self._container then
      self._container = CreateFrame("Frame")
    end
    return self._container
  end,
  GetScrollView = function()
    return CreateFrame("Frame")
  end,
  Show = function() end,
  Hide = function() end,
  AddCell = function() end,
  RemoveCell = function() end,
  GetCell = function() return nil end,
  WalkAndFixAnchorGraph = function() end,
}

local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  local g = setmetatable({}, { __index = mockGridProto })
  g.cells = {}
  return g
end

-- Load views/views.lua first
LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")

-- Load views/gridview.lua
LoadBetterBagsModule("views/gridview.lua")

local context = addon:GetModule("Context")

describe("Grid View Category Filtering Bypass Tests", function()
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

  it("should hide categories that do not belong to the active group when bank slots panel is INACTIVE", function()
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BANK)

    -- When GetShowBankTabs() is false
    database.GetShowBankTabs = function() return false end

    -- Setup mock section and bag
    local mockSection = sectionFrame.Create()
    mockSection.hidden = false
    mockSection.Hide = function(self) self.hidden = true end
    mockSection.Show = function(self) self.hidden = false end

    view.sections["TestCategory"] = mockSection

    local bag = { kind = const.BAG_KIND.BANK, frame = CreateFrame("Frame") }
    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = {
        GetStackInfo = function() return nil end
      }
    }

    -- Trigger Render/GridView drawing
    view:Render(context:New("test"), bag, mockSlotInfo, function() end)

    local function tableContains(tbl, value)
      if not tbl then return false end
      for _, v in ipairs(tbl) do
        if v == value then return true end
      end
      return false
    end

    -- Since the category belongs to NO group, and activeGroup is 2, it should be hidden (in lastMask)
    assert.is_true(tableContains(view.content.lastMask, mockSection), "The section should be in the hidden mask because group-filtering is active")
  end)

  it("should NOT hide categories when bank slots panel is ACTIVE", function()
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BANK)

    -- When GetShowBankTabs() is true
    database.GetShowBankTabs = function() return true end

    -- Setup mock section and bag
    local mockSection = sectionFrame.Create()

    view.sections["TestCategory"] = mockSection

    local bag = { kind = const.BAG_KIND.BANK, frame = CreateFrame("Frame") }
    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = {
        GetStackInfo = function() return nil end
      }
    }

    -- Trigger Render/GridView drawing
    view:Render(context:New("test"), bag, mockSlotInfo, function() end)

    local function tableContains(tbl, value)
      if not tbl then return false end
      for _, v in ipairs(tbl) do
        if v == value then return true end
      end
      return false
    end

    -- Since bank slots panel is active, group-filtering should be bypassed, so it should NOT be hidden (not in lastMask)
    assert.is_false(tableContains(view.content.lastMask, mockSection), "The section should NOT be in the hidden mask because group-filtering is bypassed")
  end)
end)
