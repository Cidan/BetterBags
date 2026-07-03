local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

-- Stub modules before loading views and items
local L = StubBetterBagsModule("Localization")
L.G = function(self, key) return key end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end
debug.StartProfile = function() end
debug.EndProfile = function() end
debug.WalkAndFixAnchorGraph = function() end

local database = StubBetterBagsModule("Database")
database.GetBagSizeInfo = function()
  return { itemsPerRow = 5, columnCount = 4 }
end
database.GetBagView = function() return 1 end
database.GetInBagSearch = function() return false end
database.GetShowNewItemFlash = function() return false end
database.GetGroupsEnabled = function() return true end
database.GetActiveGroup = function() return 1 end
database.GetShowBankTabs = function() return false end
database.GetShowAllFreeSpace = function() return false end
database.GetCategoryFilter = function() return nil end
database.GetStackingOptions = function()
  return {
    mergeStacks = true,
    unmergeAtShop = false,
    dontMergePartial = false,
    mergeUnstackable = false,
  }
end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { SECTION_GRID = 1, SECTION_ALL_BAGS = 2 }
const.BAG_KIND = { UNDEFINED = -1, BACKPACK = 0, BANK = 1 }
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
const.BANK_BAGS = { [6] = 6, [7] = 7, [8] = 8, [9] = 9, [10] = 10, [11] = 11 }
const.ACCOUNT_BANK_BAGS = {}

local sort = StubBetterBagsModule("Sort")
sort.SortSectionsAlphabetically = function() return true end
sort.GetSectionSortFunction = function() return function() return true end end
sort.GetItemSortFunction = function() return function() return true end end

local themes = StubBetterBagsModule("Themes")
themes.GetTabButton = function() return {} end
themes.GetItemButton = function() return { UpgradeIcon = { SetShown = function() end } } end
themes.RegisterPortraitWindow = function() end
themes.SetSearchState = function() end

local categories
local ok = pcall(function() categories = addon:GetModule("Categories") end)
if not ok or not categories then
  categories = StubBetterBagsModule("Categories")
end
categories.IsCategoryShown = function() return true end
categories.GetCategoryByName = function() return nil end
categories.GetCategoryFilter = function() return nil end
categories.CreateCategory = function() end

local groups = StubBetterBagsModule("Groups")
groups.CategoryBelongsToGroup = function() return true end

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
  RemoveCell = function() end,
}
sectionFrame.Create = function()
  local s = setmetatable({}, { __index = sectionProto })
  s.frame = CreateFrame("Frame")
  return s
end

-- Mock Grid module
local mockGridProto = {
  HideScrollBar = function() end,
  ShowScrollBar = function() end,
  EnableMouseWheelScroll = function() end,
  Wipe = function() end,
  Sort = function() end,
  SortVertical = function() end,
  Draw = function(self, options) return 100, 50 end,
  GetContainer = function(self)
    if not self._container then self._container = CreateFrame("Frame") end
    return self._container
  end,
  GetScrollView = function() return CreateFrame("Frame") end,
  Show = function() end,
  Hide = function() end,
  AddCell = function() end,
  RemoveCell = function() end,
}
local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  local g = setmetatable({}, { __index = mockGridProto })
  g.cells = {}
  return g
end

-- Load items.lua (actual module) so we use the real GetBagKindFromSlotKey / GetItemDataFromSlotKey
local equipmentSets = StubBetterBagsModule("EquipmentSets")
equipmentSets.GetItemSets = function() return nil end

local tooltipScanner = StubBetterBagsModule("TooltipScanner")
tooltipScanner.GetTooltipText = function() return "" end

LoadBetterBagsModule("util/query.lua")
LoadBetterBagsModule("util/trees/trees.lua")
LoadBetterBagsModule("util/trees/intervaltree.lua")
LoadBetterBagsModule("data/search.lua")
LoadBetterBagsModule("core/async.lua")
LoadBetterBagsModule("data/stacks.lua")
LoadBetterBagsModule("data/binding.lua")
LoadBetterBagsModule("data/items.lua")

local items = addon:GetModule("Items")
-- We can set up items.slotInfo map to use our mock
items.slotInfo = {
  [const.BAG_KIND.BACKPACK] = {
    itemsBySlotKey = {},
  },
  [const.BAG_KIND.BANK] = {
    itemsBySlotKey = {},
  },
}

-- Mock ItemFrame
local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.Create = function()
  local i = {
    slotkey = nil,
    SetItem = function(self, ctx, slotkey)
      local data = items:GetItemDataFromSlotKey(slotkey)
      if data == nil then
        return
      end
      self.slotkey = slotkey
    end,
    GetItemData = function(self)
      if self.staticData then return self.staticData end
      return items:GetItemDataFromSlotKey(self.slotkey)
    end,
    UpdateUpgrade = function(self, ctx)
      self:GetItemData()
    end,
  }
  return i
end

-- Load views modules
ResetModuleStub("Views", "views/views.lua")
ResetModuleStub("GridViewDummy", "views/gridview.lua")
LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")
LoadBetterBagsModule("views/gridview.lua")

local context = addon:GetModule("Context")

describe("Persistent Tab Views and Zero-Guard State Consistency Tests", function()
  local old_strsplit = _G.strsplit
  local old_split = string.split

  before_each(function()
    _G.strsplit = function(sep, str, max)
      if str == nil then
        error("bad argument #2 to 'strsplit' (string expected, got nil)", 2)
      end
      return old_strsplit(sep, str, max)
    end
    string.split = function(sep, str, max)
      if str == nil then
        error("bad argument #2 to 'split' (string expected, got nil)", 2)
      end
      return old_strsplit(sep, str, max)
    end
  end)

  after_each(function()
    _G.strsplit = old_strsplit
    string.split = old_split
    items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey = {}
    items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey = {}
    ResetModuleStub("ContextMenu")
    ResetModuleStub("BagSlots")
    ResetModuleStub("Resize")
    ResetModuleStub("Currency")
    ResetModuleStub("SearchBox")
    ResetModuleStub("ThemeConfig")
    ResetModuleStub("WindowGroup", "util/windowgroup.lua")
    ResetModuleStub("Anchor")
    ResetModuleStub("Question")
    ResetModuleStub("Search")
    ResetModuleStub("BackpackBehavior")
    ResetModuleStub("BankBehavior")
    ResetModuleStub("BagFrame", "frames/bag.lua")
  end)

  it("should reproduce the nil slotkey crash when items data is transient/nil during UpdateButton", function()
    -- Set up an empty slotInfo with slotkeys but NO actual item data in the slotInfo database
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BANK)

    -- Define a slot key for which we have NO item data (transient loading state)
    local testSlotKey = "6_1"

    local testItemData = {
      slotkey = testSlotKey,
      bagid = 6,
      slotid = 1,
      itemHash = "hash1",
      isItemEmpty = false,
      itemInfo = {
        currentItemCount = 20,
        itemStackCount = 20,
      }
    }

    -- Define a mock slotInfo where stackInfo claims rootItem is testSlotKey
    local mockStackInfo = {
      rootItem = testSlotKey,
      slotkeys = { [testSlotKey] = true },
      itemHash = "hash1",
    }

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return { [testSlotKey] = testItemData } end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = {
        GetStackInfo = function(self, hash)
          return mockStackInfo
        end
      },
      totalItems = 1
    }

    -- Verify that calling GridView (view.Render) triggers ReconcileStack.
    -- Because items:GetItemDataFromSlotKey(testSlotKey) is nil (stale/loading),
    -- CreateButton returns false, prompting UpdateButton to run.
    -- UpdateButton allocates an itemButton with view:GetOrCreateItemButton(ctx, testSlotKey),
    -- and then calls itemButton:SetItem(ctx, testSlotKey).
    -- itemButton:SetItem sees the item data is nil and returns early, leaving itemButton.slotkey as nil.
    -- The button remains registered in view.itemsByBagAndSlot[testSlotKey] = itemButton.
    local ctx = context:New("test")
    ctx:Set("redraw", true)
    local bag = { kind = const.BAG_KIND.BANK, frame = CreateFrame("Frame") }
    view:Render(ctx, bag, mockSlotInfo, function() end)

    -- Assert that under the new refactored state-consistent logic,
    -- no ghost button is created when item data is nil.
    local itemButton = view:GetItemsByBagAndSlot()[testSlotKey]
    assert.is_nil(itemButton)

    -- Assert that calling UpdateUpgrade on all mapped view items is completely
    -- safe and does not crash because no ghost buttons exist.
    for _, item in pairs(view:GetItemsByBagAndSlot()) do
      local success = pcall(function()
        item:UpdateUpgrade(context:New("test"))
      end)
      assert.is_true(success)
    end
  end)

  it("should cleanly wipe and recycle views and buttons when a tab is deleted", function()
    -- Register mock LibWindow-1.1 library
    local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
    libWindow.RestorePosition = libWindow.RestorePosition or function() end
    libWindow.RegisterConfig = libWindow.RegisterConfig or function() end

    -- Stub remaining modules needed by frames/bag.lua
    local contextMenu = StubBetterBagsModule("ContextMenu")
    contextMenu.CreateContextMenu = function() return {} end

    StubBetterBagsModule("BagSlots")
    local resize = StubBetterBagsModule("Resize")
    resize.MakeResizable = function() return { Hide = function() end } end

    StubBetterBagsModule("Currency")
    local searchBox = StubBetterBagsModule("SearchBox")
    searchBox.GetText = function() return "" end

    StubBetterBagsModule("ThemeConfig")
    StubBetterBagsModule("WindowGroup")
    local anchor = StubBetterBagsModule("Anchor")
    anchor.New = function() return {} end

    StubBetterBagsModule("Question")
    StubBetterBagsModule("Search")
    StubBetterBagsModule("BackpackBehavior")
    StubBetterBagsModule("BankBehavior")

    -- Mock a bag portrait window frame and load BagFrame
    LoadBetterBagsModule("frames/bag.lua")
    local bag = {
      kind = const.BAG_KIND.BACKPACK,
      frame = CreateFrame("Frame"),
      tabViews = {}
    }
    setmetatable(bag, { __index = addon:GetModule("BagFrame").bagProto })

    local ctx = context:New("test")
    -- Create view for Tab 2
    local view2 = bag:GetViewForTab(ctx, 2)
    assert.is_not_nil(view2)
    assert.is_not_nil(bag.tabViews[database:GetBagView(bag.kind) .. "_2"])

    -- Stub view:Wipe and view:GetContent():Wipe
    local wipeCalled = false
    local contentWipeCalled = false
    view2.WipeHandler = function() wipeCalled = true end
    view2:GetContent().Wipe = function() contentWipeCalled = true end

    -- Delete tab/view 2
    bag:DeleteTabView(ctx, 2)

    -- Assert that clean wipe was performed and reference was removed
    assert.is_true(wipeCalled)
    assert.is_true(contentWipeCalled)
    assert.is_nil(bag.tabViews[database:GetBagView(bag.kind) .. "_2"])
  end)
end)
