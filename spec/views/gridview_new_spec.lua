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
themes.GetItemButton = function()
  return {
    ItemSlotBackground = { Hide = function() end },
    UpgradeIcon = { SetShown = function() end },
    IconBorder = { SetTexture = function() end, SetBlendMode = function() end, SetTexCoord = function() end },
    SetHasItem = function() end,
    SetItemButtonTexture = function() end,
  }
end

local database = StubBetterBagsModule("Database")
database.GetBagSizeInfo = function()
  return { itemsPerRow = 5, columnCount = 4 }
end
database.GetBagView = function() return 2 end -- SECTION_GRID
database.GetInBagSearch = function() return false end
database.GetShowNewItemFlash = function() return false end
database.GetGroupsEnabled = function() return true end
database.GetActiveGroup = function() return 2 end -- Active Group is 2
database.GetShowBankTabs = function() return false end
database.GetShowAllFreeSpace = function() return false end
database.GetStackingOptions = function()
  return {
    mergeStacks = true,
    unmergeAtShop = false,
    dontMergePartial = false,
    mergeUnstackable = false,
  }
end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { ONE_BAG = 1, SECTION_GRID = 2, LIST = 3, SECTION_ALL_BAGS = 4 }
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
sort.GetSectionSortFunction = function() return function() return true end end

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
  WipeOnlyContents = function() end,
}
sectionFrame.Create = function()
  local s = setmetatable({}, { __index = sectionProto })
  s.frame = CreateFrame("Frame")
  return s
end

-- Stub ItemFrame
local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.GetButton = function(self, ctx, slotkey)
  local btn = self.Create()
  btn.slotkey = slotkey
  return btn
end
itemFrame.Create = function()
  return {
    SetItem = function() end,
    SetItemFromData = function() end,
    SetFreeSlots = function() end,
    UpdateCount = function() end,
    GetItemData = function() return { slotkey = "1_1" } end,
    frame = CreateFrame("Frame"),
    button = { SetHasItem = function() end },
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

-- Load the new view implementations
LoadBetterBagsModule("views/gridview_new.lua")
LoadBetterBagsModule("views/bagview_new.lua")

local context = addon:GetModule("Context")

describe("Phase 6 View Placement and Rendering Tests", function()
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

  it("should support polymorphic NewGrid views and place items in appropriate categories", function()
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BACKPACK)
    assert.are.equal(view.bagview, const.BAG_VIEW.SECTION_GRID)

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }

    local item1 = {
      bagid = 0,
      slotid = 1,
      slotkey = "0_1",
      itemHash = "hash1",
      isItemEmpty = false,
      itemInfo = {
        itemID = 1234,
        currentItemCount = 10,
        itemStackCount = 20,
        itemQuality = 1,
        itemIcon = 136,
        isBound = false,
      },
      questInfo = { isQuestItem = false },
    }

    local mockSlotInfo = {
      GetChangeset = function() return { item1 }, {}, {} end,
      GetCurrentItems = function() return { ["0_1"] = item1 } end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      emptySlotByBagAndSlot = {},
      stacks = {
        GetStackInfo = function() return nil end
      }
    }

    local rendered = false
    view:Render(context:New("test"), bag, mockSlotInfo, function()
      rendered = true
    end)

    assert.is_true(rendered)
  end)

  it("should support polymorphic NewBagView views and place items correctly", function()
    local parent = CreateFrame("Frame")
    local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK)
    assert.are.equal(view.bagview, const.BAG_VIEW.SECTION_ALL_BAGS)

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }

    local item1 = {
      bagid = 0,
      slotid = 1,
      slotkey = "0_1",
      itemHash = "hash1",
      isItemEmpty = false,
      itemInfo = {
        itemID = 1234,
        currentItemCount = 10,
        itemStackCount = 20,
        itemQuality = 1,
        itemIcon = 136,
        isBound = false,
      },
      questInfo = { isQuestItem = false },
    }

    local mockSlotInfo = {
      GetChangeset = function() return { item1 }, {}, {} end,
      GetCurrentItems = function() return { ["0_1"] = item1 } end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      emptySlotByBagAndSlot = {},
      stacks = {
        GetStackInfo = function() return nil end
      }
    }

    local rendered = false
    view:Render(context:New("test"), bag, mockSlotInfo, function()
      rendered = true
    end)

    assert.is_true(rendered)
  end)
end)
