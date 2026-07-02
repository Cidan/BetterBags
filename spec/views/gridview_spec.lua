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

local themes = StubBetterBagsModule("Themes")
themes.GetTabButton = function() return {} end

local database = StubBetterBagsModule("Database")
database.GetBagSizeInfo = function()
  return { itemsPerRow = 5, columnCount = 4 }
end
database.GetBagView = function() return 1 end
database.GetInBagSearch = function() return false end
database.GetShowNewItemFlash = function() return false end
database.GetStackingOptions = function() return {} end
database.GetShowAllFreeSpace = function() return false end

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

-- Stub SectionFrame
local sectionFrame = StubBetterBagsModule("SectionFrame")
local sectionProto = {
  ReleaseAllCells = function() end,
  Release = function() end,
  GetCellCount = function() return 0 end,
  SetMaxCellWidth = function() end,
  Draw = function() end,
  IsCollapsed = function() return false end,
  SetTitle = function() end,
}
sectionFrame.Create = function()
  local f = CreateFrame("Frame")
  f.GetWidth = function() return 100 end
  f.IsShown = function() return true end
  return setmetatable({ frame = f }, { __index = sectionProto })
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
  GetScrollView = function() return CreateFrame("Frame") end,
  Show = function() end,
  Hide = function() end,
  SortVertical = function() end,
  AddCell = function() end,
  RemoveCell = function() end,
}

local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  local g = setmetatable({ cells = {} }, { __index = mockGridProto })
  return g
end

-- Load views/views.lua first (provides views:NewBlankView)
LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")

-- Load views/gridview.lua
LoadBetterBagsModule("views/gridview.lua")

local context = addon:GetModule("Context")

describe("Grid View", function()
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

  describe("NewGrid", function()
    it("creates a new grid view correctly", function()
      local parent = CreateFrame("Frame")
      local view = views:NewGrid(parent, const.BAG_KIND.BANK)
      assert.is_not_nil(view)
      assert.is_not_nil(view.content)
      assert.are.equal(view.kind, const.BAG_KIND.BANK)
      assert.are.equal(view.bagview, const.BAG_VIEW.SECTION_GRID)
      assert.is_not_nil(view.Render)
      assert.is_not_nil(view.WipeHandler)
    end)
  end)

  describe("Bank Tab Filtering", function()
    it("filters sections by active group when show bank tabs is disabled", function()
      -- Setup
      local parent = CreateFrame("Frame")
      local view = views:NewGrid(parent, const.BAG_KIND.BANK)
      local bag = {
        kind = const.BAG_KIND.BANK,
        frame = CreateFrame("Frame"),
      }
      local slotInfo = {
        GetChangeset = function() return {}, {}, {} end,
        emptySlotByBagAndSlot = {},
        emptySlotsSorted = {},
        emptySlots = {},
        freeSlotKeys = {},
        totalItems = 0,
        stacks = {
          GetStackInfo = function() return nil end
        }
      }

      database.GetGroupsEnabled = function() return true end
      database.GetActiveGroup = function() return "Sylvanas" end
      database.GetShowBankTabs = function() return false end

      -- Create sections to filter
      local section1 = view:GetOrCreateSection(context:New("test"), "Armor")
      local section2 = view:GetOrCreateSection(context:New("test"), "Weapons")

      local belongsToGroupCalled = {}
      groups.CategoryBelongsToGroup = function(self, kind, sectionName, activeGroup)
        belongsToGroupCalled[sectionName] = { kind = kind, activeGroup = activeGroup }
        if sectionName == "Armor" then
          return true
        else
          return false
        end
      end

      local capturedMask = nil
      view.content.Draw = function(self, options)
        capturedMask = options.mask
        return 100, 50
      end

      local callbackCalled = false
      local callback = function() callbackCalled = true end

      local ctx = context:New("RenderView")
      view:Render(ctx, bag, slotInfo, callback)

      -- Verify belongsToGroup filter was applied
      assert.is_true(callbackCalled)
      assert.is_not_nil(belongsToGroupCalled["Armor"])
      assert.is_not_nil(belongsToGroupCalled["Weapons"])

      -- When show bank tabs is disabled, weapons (which return false for belongs to group) should be filtered out.
      local weaponsHidden = false
      local armorHidden = false
      for _, section in ipairs(capturedMask) do
        if section == section1 then
          armorHidden = true
        elseif section == section2 then
          weaponsHidden = true
        end
      end
      assert.is_true(weaponsHidden)
      assert.is_false(armorHidden)
    end)

    it("bypasses section filtering by active group when show bank tabs is enabled", function()
      -- Setup
      local parent = CreateFrame("Frame")
      local view = views:NewGrid(parent, const.BAG_KIND.BANK)
      local bag = {
        kind = const.BAG_KIND.BANK,
        frame = CreateFrame("Frame"),
      }
      local slotInfo = {
        GetChangeset = function() return {}, {}, {} end,
        emptySlotByBagAndSlot = {},
        emptySlotsSorted = {},
        emptySlots = {},
        freeSlotKeys = {},
        totalItems = 0,
        stacks = {
          GetStackInfo = function() return nil end
        }
      }

      database.GetGroupsEnabled = function() return true end
      database.GetActiveGroup = function() return "Sylvanas" end
      database.GetShowBankTabs = function() return true end

      -- Create sections to filter
      local section1 = view:GetOrCreateSection(context:New("test"), "Armor")
      local section2 = view:GetOrCreateSection(context:New("test"), "Weapons")

      local belongsToGroupCalled = {}
      groups.CategoryBelongsToGroup = function(self, kind, sectionName, activeGroup)
        belongsToGroupCalled[sectionName] = { kind = kind, activeGroup = activeGroup }
        if sectionName == "Armor" then
          return true
        else
          return false
        end
      end

      local capturedMask = nil
      view.content.Draw = function(self, options)
        capturedMask = options.mask
        return 100, 50
      end

      local callbackCalled = false
      local callback = function() callbackCalled = true end

      local ctx = context:New("RenderView")
      view:Render(ctx, bag, slotInfo, callback)

      assert.is_true(callbackCalled)
      -- Verify belongsToGroup filter was NOT called
      assert.is_nil(belongsToGroupCalled["Armor"])
      assert.is_nil(belongsToGroupCalled["Weapons"])

      -- Also verify neither section is in the masked (hidden) list
      local weaponsHidden = false
      local armorHidden = false
      for _, section in ipairs(capturedMask) do
        if section == section1 then
          armorHidden = true
        elseif section == section2 then
          weaponsHidden = true
        end
      end
      assert.is_false(weaponsHidden)
      assert.is_false(armorHidden)
    end)
  end)
end)
