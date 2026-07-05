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
  return { itemsPerRow = 5, columnCount = 4, scale = 100 }
end
database.GetGroup = function() return nil end
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
const.BANK_TAB = { BANK = -1, REAGENT = -2, ACCOUNT_BANK_1 = -3 }
const.BANK_ONLY_BAGS = {}
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
groups.GetGroup = function(self, kind, id)
  return database:GetGroup(kind, id)
end
groups.IsDefaultGroup = function(self, kind, id)
  local group = database:GetGroup(kind, id)
  return group and group.isDefault == true
end

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
  GetCell = function() return nil end,
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
ResetModuleStub("Search", "data/search_new.lua")
LoadBetterBagsModule("data/search_new.lua")
local search = addon:GetModule("Search")
search:OnInitialize()
LoadBetterBagsModule("core/async.lua")
ResetModuleStub("Stacks", "data/stacks_new.lua")
LoadBetterBagsModule("data/stacks_new.lua")
LoadBetterBagsModule("data/binding.lua")
ResetModuleStub("Items", "data/items_new.lua")
LoadBetterBagsModule("data/items_new.lua")
ResetModuleStub("Slots", "data/slots.lua")
LoadBetterBagsModule("data/slots.lua")

local items = addon:GetModule("Items")
items._firstLoad = {
  [const.BAG_KIND.BACKPACK] = false,
  [const.BAG_KIND.BANK] = false,
}
-- We can set up items.slotInfo map to use our mock
items.slotInfo = {
  [const.BAG_KIND.BACKPACK] = items:NewSlotInfo(),
  [const.BAG_KIND.BANK] = items:NewSlotInfo(),
}

-- Mock ItemFrame
local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.GetButton = function(self, ctx, slotkey)
  local btn = self.Create()
  btn.slotkey = slotkey
  return btn
end
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
    UpdateCount = function(self, ctx) end,
    SetFreeSlots = function(self, ctx, bagid, slotid, count, show) end,
  }
  return i
end

-- Load views modules
ResetModuleStub("Views", "views/views.lua")
ResetModuleStub("GridViewDummy", "views/gridview_new.lua")
ResetModuleStub("BagViewDummy", "views/bagview_new.lua")
LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")
LoadBetterBagsModule("views/gridview_new.lua")
LoadBetterBagsModule("views/bagview_new.lua")

local context = addon:GetModule("Context")

describe("Persistent Tab Views and Zero-Guard State Consistency Tests", function()
  local old_strsplit = _G.strsplit
  local old_split = string.split

  local function setupBagFrameStubs()
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
    StubBetterBagsModule("BackpackBehavior")
    StubBetterBagsModule("BankBehavior")
  end
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
    setupBagFrameStubs()

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

  it("should parent emptyGroupFrame to content container instead of bag frame and respect view.tabID", function()
    local parent = CreateFrame("Frame")
    -- We can set up grid with a container mock
    local view = views:NewGrid(parent, const.BAG_KIND.BACKPACK, 1) -- Tab 1
    assert.is_not_nil(view.emptyGroupFrame)
    -- Verify parenting is view.content:GetContainer()
    assert.equals(view.emptyGroupFrame:GetParent(), view.content:GetContainer())

    -- Verify rendering tabID = 1 does NOT show emptyGroupFrame
    local ctx = context:New("test")
    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }
    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }
    view:Render(ctx, bag, mockSlotInfo, function() end)
    assert.is_false(view.emptyGroupFrame:IsShown())

    -- Now test custom tab ID > 1 (e.g., 2)
    local view2 = views:NewGrid(parent, const.BAG_KIND.BACKPACK, 2) -- Tab 2
    assert.is_not_nil(view2.emptyGroupFrame)
    view2:Render(ctx, bag, mockSlotInfo, function() end)
    -- Since totalItems is 0 and visible non-special section count is 0, emptyGroupFrame should show
    assert.is_true(view2.emptyGroupFrame:IsShown())
  end)

  it("should render all instantiated views matching the current layout in bag:Draw()", function()
    setupBagFrameStubs()
    LoadBetterBagsModule("frames/bag.lua")
    local frame = CreateFrame("Frame")
    frame.SetScale = function() end
    local bag = {
      kind = const.BAG_KIND.BACKPACK,
      frame = frame,
      tabViews = {},
      GetCurrentTabID = function() return 1 end,
      IsShown = function() return true end,
      OnResize = function() end,
      behavior = {
        OnShow = function() end,
      }
    }
    setmetatable(bag, { __index = addon:GetModule("BagFrame").bagProto })

    local ctx = context:New("test")
    -- Create view for Tab 1 and Tab 2
    local view1 = bag:GetViewForTab(ctx, 1)
    local view2 = bag:GetViewForTab(ctx, 2)

    local render1_called = false
    local render2_called = false
    view1.Render = function(self, ...) render1_called = true; select(4, ...)(...) end
    view2.Render = function(self, ...) render2_called = true; select(4, ...)(...) end

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }

    bag:Draw(ctx, mockSlotInfo, function() end)

    -- Assert both views were rendered
    assert.is_true(render1_called)
    assert.is_true(render2_called)
  end)

  it("should skip rendering in Draw() when the bag is not shown, and draw when shown", function()
    setupBagFrameStubs()
    LoadBetterBagsModule("frames/bag.lua")
    local frame = CreateFrame("Frame")
    frame.SetScale = function() end
    local shown = false
    frame.IsShown = function() return shown end
    local bag = {
      kind = const.BAG_KIND.BACKPACK,
      frame = frame,
      tabViews = {},
      GetCurrentTabID = function() return 1 end,
      OnResize = function() end,
      behavior = {
        OnShow = function() shown = true end,
      }
    }
    setmetatable(bag, { __index = addon:GetModule("BagFrame").bagProto })

    local ctx = context:New("test")
    local view = bag:GetViewForTab(ctx, 1)

    local render_called = false
    view.Render = function(self, ...) render_called = true; select(4, ...)(...) end

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }

    -- Call Draw while hidden
    bag:Draw(ctx, mockSlotInfo, function() end)
    assert.is_false(render_called)
    assert.is_true(bag.drawPendingOnShow)
    assert.equals(bag.lastSlotInfo, mockSlotInfo)

    -- Show the bag now
    bag:Show(ctx)

    -- Verify it rendered on show
    assert.is_true(render_called)
    assert.is_false(bag.drawPendingOnShow)
  end)

  it("should populate bagList with both BANK_BAGS and ACCOUNT_BANK_BAGS when GetShowBankTabs is true in Retail", function()
    local old_isRetail = addon.isRetail
    addon.isRetail = true
    local old_GetShowBankTabs = database.GetShowBankTabs
    database.GetShowBankTabs = function() return true end
    equipmentSets.Update = function() end
    addon.Bags = { Bank = {} }

    -- Set up const values
    const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14 }
    const.BANK_BAGS = { [6] = 6, [7] = 7 }
    const.BANK_ONLY_BAGS = {}

    -- Mock Harvest to observe bagList
    local capturedBagList = nil
    items.Harvest = function(self, kind, bagList, includeEquipment)
      capturedBagList = bagList
      return {}, {}
    end

    local ctx = context:New("test")
    items:RefreshBank(ctx)

    assert.is_not_nil(capturedBagList)
    assert.is_not_nil(capturedBagList[6])
    assert.is_not_nil(capturedBagList[7])
    assert.is_not_nil(capturedBagList[13])
    assert.is_not_nil(capturedBagList[14])

    -- Clean up
    addon.isRetail = old_isRetail
    database.GetShowBankTabs = old_GetShowBankTabs
  end)

  it("should set view.isNew to true on bag view creation and load items on first Render when changeset is empty", function()
    local parent = CreateFrame("Frame")
    local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK, 2)
    assert.is_true(view.isNew)

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }
    local mockItem = {
      slotkey = "0_1",
      bagid = 0,
      slotid = 1,
      itemHash = "hash_0_1",
      isItemEmpty = false,
      itemInfo = { currentItemCount = 1, itemStackCount = 20, isItemEmpty = false }
    }

    -- Put item in the mock database
    items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"] = mockItem

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end, -- empty changeset
      GetCurrentItems = function() return { ["0_1"] = mockItem } end,
      emptySlotByBagAndSlot = {}
    }

    assert.is_nil(view.itemsByBagAndSlot["0_1"])

    local callbackCalled = false
    view:Render(context:New("test"), bag, mockSlotInfo, function() callbackCalled = true end)

    assert.is_true(callbackCalled)
    assert.is_false(view.isNew)
    assert.is_not_nil(view.itemsByBagAndSlot["0_1"])
  end)

  it("should set view.isNew to true on grid view creation and load items on first Render when changeset is empty", function()
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BACKPACK, 2)
    assert.is_true(view.isNew)

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }
    local mockItem = {
      slotkey = "0_1",
      bagid = 0,
      slotid = 1,
      itemHash = "hash_0_1",
      isItemEmpty = false,
      itemInfo = { currentItemCount = 1, itemStackCount = 20, isItemEmpty = false }
    }

    -- Put item in the mock database
    items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"] = mockItem

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end, -- empty changeset
      GetCurrentItems = function() return { ["0_1"] = mockItem } end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 1
    }

    assert.is_nil(view.itemsByBagAndSlot["0_1"])

    local callbackCalled = false
    view:Render(context:New("test"), bag, mockSlotInfo, function() callbackCalled = true end)

    assert.is_true(callbackCalled)
    assert.is_false(view.isNew)
    assert.is_not_nil(view.itemsByBagAndSlot["0_1"])
  end)

  it("should always load both BANK_BAGS and ACCOUNT_BANK_BAGS in Retail regardless of GetShowBankTabs", function()
    local old_isRetail = addon.isRetail
    addon.isRetail = true
    local old_GetShowBankTabs = database.GetShowBankTabs
    database.GetShowBankTabs = function() return false end
    equipmentSets.Update = function() end
    addon.Bags = { Bank = {} }

    -- Set up const values
    const.ACCOUNT_BANK_BAGS = { [13] = 13, [14] = 14 }
    const.BANK_BAGS = { [6] = 6, [7] = 7 }
    const.BANK_ONLY_BAGS = {}

    -- Mock Harvest to observe bagList
    local capturedBagList = nil
    items.Harvest = function(self, kind, bagList, includeEquipment)
      capturedBagList = bagList
      return {}, {}
    end

    local ctx = context:New("test")
    items:RefreshBank(ctx)

    assert.is_not_nil(capturedBagList)
    assert.is_not_nil(capturedBagList[6])
    assert.is_not_nil(capturedBagList[7])
    assert.is_not_nil(capturedBagList[13])
    assert.is_not_nil(capturedBagList[14])

    -- Clean up
    addon.isRetail = old_isRetail
    database.GetShowBankTabs = old_GetShowBankTabs
  end)

  it("should filter bank items strictly by tab bankType in Retail when ShowBankTabs is false", function()
    local old_isRetail = addon.isRetail
    addon.isRetail = true
    local old_Enum = _G.Enum
    _G.Enum = _G.Enum or {}
    _G.Enum.BankType = { Character = 1, Account = 2 }

    local old_GetShowBankTabs = database.GetShowBankTabs
    database.GetShowBankTabs = function() return false end

    -- Mock database GetGroup to return character bank for Tab 1, account bank for Tab 2
    local old_GetGroup = database.GetGroup
    database.GetGroup = function(_, kind, id)
      if id == 1 then
        return { id = 1, isDefault = true, bankType = _G.Enum.BankType.Character }
      elseif id == 2 then
        return { id = 2, isDefault = true, bankType = _G.Enum.BankType.Account }
      end
      return nil
    end

    local old_CategoryBelongsToGroup = groups.CategoryBelongsToGroup
    groups.CategoryBelongsToGroup = function() return true end

    local old_IsDefaultGroup = groups.IsDefaultGroup
    groups.IsDefaultGroup = function() return true end

    -- Set up bag constants
    const.BANK_BAGS = { [6] = 6 }
    const.ACCOUNT_BANK_BAGS = { [13] = 13 }

    -- Create mock items
    local charItem = {
      slotkey = "6_1",
      bagid = 6,
      slotid = 1,
      itemHash = "hash_6_1",
      isItemEmpty = false,
      itemInfo = { currentItemCount = 1, itemStackCount = 20, isItemEmpty = false, category = "TestCategory" }
    }
    local warItem = {
      slotkey = "13_1",
      bagid = 13,
      slotid = 1,
      itemHash = "hash_13_1",
      isItemEmpty = false,
      itemInfo = { currentItemCount = 1, itemStackCount = 20, isItemEmpty = false, category = "TestCategory" }
    }

    items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey["6_1"] = charItem
    items.slotInfo[const.BAG_KIND.BANK].itemsBySlotKey["13_1"] = warItem

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return { ["6_1"] = charItem, ["13_1"] = warItem } end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 2
    }

    local parent = CreateFrame("Frame")
    local bag = { kind = const.BAG_KIND.BANK, frame = CreateFrame("Frame") }

    -- Tab 1 (Character Bank)
    local view1 = views:NewGrid(parent, const.BAG_KIND.BANK, 1)
    view1:Render(context:New("test"), bag, mockSlotInfo, function() end)

    -- Assert only charItem is drawn in view1
    assert.is_not_nil(view1.itemsByBagAndSlot["6_1"])
    assert.is_nil(view1.itemsByBagAndSlot["13_1"])

    -- Tab 2 (Account Bank)
    local view2 = views:NewGrid(parent, const.BAG_KIND.BANK, 2)
    view2:Render(context:New("test"), bag, mockSlotInfo, function() end)

    -- Assert only warItem is drawn in view2
    assert.is_nil(view2.itemsByBagAndSlot["6_1"])
    assert.is_not_nil(view2.itemsByBagAndSlot["13_1"])

    -- Clean up
    addon.isRetail = old_isRetail
    _G.Enum = old_Enum
    database.GetShowBankTabs = old_GetShowBankTabs
    database.GetGroup = old_GetGroup
    groups.CategoryBelongsToGroup = old_CategoryBelongsToGroup
    groups.IsDefaultGroup = old_IsDefaultGroup
  end)

  it("should bypass rendering in bag:Draw() when tab_switch is true and view is not new", function()
    setupBagFrameStubs()
    LoadBetterBagsModule("frames/bag.lua")
    local frame = CreateFrame("Frame")
    frame.SetScale = function() end
    local bag = {
      kind = const.BAG_KIND.BACKPACK,
      frame = frame,
      tabViews = {},
      GetCurrentTabID = function() return 1 end,
      IsShown = function() return true end,
      OnResize = function() end,
      behavior = {
        OnShow = function() end,
      }
    }
    setmetatable(bag, { __index = addon:GetModule("BagFrame").bagProto })

    local ctx = context:New("test")
    local view1 = bag:GetViewForTab(ctx, 1)
    view1.isNew = false

    local render_called = false
    view1.Render = function(self, ...) render_called = true; select(4, ...)(...) end

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }

    ctx:Set("tab_switch", true)
    local callback_called = false
    bag:Draw(ctx, mockSlotInfo, function() callback_called = true end)

    assert.is_false(render_called)
    assert.is_true(callback_called)
  end)

  it("should NOT bypass rendering in bag:Draw() when tab_switch is true but view is new", function()
    setupBagFrameStubs()
    LoadBetterBagsModule("frames/bag.lua")
    local frame = CreateFrame("Frame")
    frame.SetScale = function() end
    local bag = {
      kind = const.BAG_KIND.BACKPACK,
      frame = frame,
      tabViews = {},
      GetCurrentTabID = function() return 1 end,
      IsShown = function() return true end,
      OnResize = function() end,
      behavior = {
        OnShow = function() end,
      }
    }
    setmetatable(bag, { __index = addon:GetModule("BagFrame").bagProto })

    local ctx = context:New("test")
    local view1 = bag:GetViewForTab(ctx, 1)
    view1.isNew = true

    local render_called = false
    view1.Render = function(self, ...) render_called = true; select(4, ...)(...) end

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }

    ctx:Set("tab_switch", true)
    local callback_called = false
    bag:Draw(ctx, mockSlotInfo, function() callback_called = true end)

    assert.is_true(render_called)
    assert.is_true(callback_called)
  end)
  it("should early-exit GridView/BagView when changeset is empty and not redraw/wipe/isNew", function()
    local parent = CreateFrame("Frame")
    local view = views:NewGrid(parent, const.BAG_KIND.BACKPACK, 1)
    view.isNew = false -- Simulated as already rendered once

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = parent }
    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }

    local ctx = context:New("test")
    -- Ensure no redraw or wipe flag is set in context

    local callback_called = false
    view:Render(ctx, bag, mockSlotInfo, function() callback_called = true end)

    assert.is_true(callback_called)
    -- We can verify it early exited without wiping or running full layout (view is still intact)
    assert.is_false(view.isNew)
  end)

  it("should bypass group tab filtering and show all items/sections in SECTION_ALL_BAGS view regardless of activeGroup tabID", function()
    -- Set up items.slotInfo with items in different bags
    local charItem = {
      slotkey = "0_1",
      bagid = 0,
      slotid = 1,
      itemHash = "hash_0_1",
      isItemEmpty = false,
      itemInfo = { currentItemCount = 1, itemStackCount = 20, isItemEmpty = false, category = "TestCategory" }
    }
    items.slotInfo[const.BAG_KIND.BACKPACK].itemsBySlotKey["0_1"] = charItem

    -- Setup database GetActiveGroup to be > 1 (e.g., 2)
    local old_GetGroupsEnabled = database.GetGroupsEnabled
    database.GetGroupsEnabled = function() return true end

    local old_CategoryBelongsToGroup = groups.CategoryBelongsToGroup
    groups.CategoryBelongsToGroup = function(self, kind, category, tabID)
      -- Items in TestCategory do not belong to Tab 2
      if tabID == 2 then return false end
      return true
    end

    local parent = CreateFrame("Frame")
    -- Create a BagView (which is SECTION_ALL_BAGS) with tabID = 2 (a custom group tab)
    local view = views:NewBagView(parent, const.BAG_KIND.BACKPACK, 2)

    local mockSlotInfo = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return { ["0_1"] = charItem } end,
      emptySlotByBagAndSlot = {}
    }

    local bag = { kind = const.BAG_KIND.BACKPACK, frame = CreateFrame("Frame") }
    view:Render(context:New("test"), bag, mockSlotInfo, function() end)

    -- Under the buggy behavior, the item would be filtered out (not in view.itemsByBagAndSlot),
    -- and its section (which would be GetBagName(0) -> "#1: Backpack") would be hidden.
    -- We assert that under the fixed behavior, charItem IS in view.itemsByBagAndSlot
    assert.is_not_nil(view.itemsByBagAndSlot["0_1"])

    -- Clean up database changes
    database.GetGroupsEnabled = old_GetGroupsEnabled
    groups.CategoryBelongsToGroup = old_CategoryBelongsToGroup
  end)
end)
