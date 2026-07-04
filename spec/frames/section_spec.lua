local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required core modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

-- Stub file-scope modules required by frames/section.lua
local categories = StubBetterBagsModule("Categories")
categories.GetGroupForCategory = function() return nil end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { SECTION_GRID = 1 }
const.BAG_KIND = { BACKPACK = 1, BANK = 2 }
const.MOVEMENT_FLOW = { UNDEFINED = 0, NPCSHOP = 1 }

local sort = StubBetterBagsModule("Sort")
sort.GetItemSortBySlot = function() end
sort.GetItemSortFunction = function() end

local database = StubBetterBagsModule("Database")
database.GetShowFullSectionNames = function() return false end
database.GetShowFullSectionNames = function() return false end
database.ToggleSectionCollapsed = function() end

local themes = StubBetterBagsModule("Themes")
themes.UpdateSectionFont = function() end
themes.RegisterSectionFont = function() end

StubBetterBagsModule("Items")
local movementFlow = StubBetterBagsModule("MovementFlow")
movementFlow.GetMovementFlow = function() return 0 end

local groups = StubBetterBagsModule("Groups")
groups.GetGroupForCategory = function() return nil end
groups.IsDefaultGroup = function() return false end

local L = StubBetterBagsModule("Localization")
L.G = function(self, key) return key end

-- Mock Grid module
local mockGridProto = {
  HideScrollBar = function() end,
  EnableMouseWheelScroll = function() end,
  Wipe = function(self)
    self.cells = {}
    self.idToCell = {}
  end,
  AddCell = function(self, id, cell)
    table.insert(self.cells, cell)
    self.idToCell[id] = cell
  end,
  RemoveCell = function(self, id)
    local cell = self.idToCell[id]
    if cell then
      for i, c in ipairs(self.cells) do
        if c == cell then
          table.remove(self.cells, i)
          break
        end
      end
      self.idToCell[id] = nil
    end
  end,
  GetCell = function(self, id)
    return self.idToCell[id]
  end,
  Sort = function() end,
  SortHorizontal = function() end,
  Draw = function()
    return 100, 50
  end,
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
  local g = setmetatable({
    cells = {},
    idToCell = {}
  }, { __index = mockGridProto })
  return g
end

local context = addon:GetModule("Context")

-- Load the SectionFrame module
ResetModuleStub("SectionFrame", "frames/section.lua")
LoadBetterBagsModule("frames/section.lua")
local sectionFrame = addon:GetModule("SectionFrame")

describe("Section Frame", function()
  before_each(function()
    sectionFrame:OnInitialize()
  end)

  after_each(function()
    ResetModuleStub("Categories", "data/categories.lua")
    ResetModuleStub("Constants", "core/constants.lua")
    ResetModuleStub("Sort", "util/sort.lua")
    ResetModuleStub("Database", "core/database.lua")
    ResetModuleStub("Themes", "themes/themes.lua")
    ResetModuleStub("Items", "data/items.lua")
    ResetModuleStub("MovementFlow", "util/movementflow.lua")
    ResetModuleStub("Groups", "data/groups.lua")
    ResetModuleStub("Localization", "core/localization.lua")
    ResetModuleStub("Grid", "frames/grid.lua")
  end)

  describe("Creation and Pooling", function()
    it("creates a new section frame", function()
      local ctx = context:New("TestCreate")
      local s = sectionFrame:Create(ctx)
      assert.is_not_nil(s)
      assert.is_not_nil(s.frame)
      assert.is_not_nil(s.title)
      assert.is_not_nil(s.content)
      assert.are.equal(s.title:GetText(), "Not set")
    end)

    it("resets and pools section correctly", function()
      local ctx = context:New("TestPool")
      local s = sectionFrame:Create(ctx)
      s:SetTitle("Category A")
      s:SetCollapsed(true)
      s:Release(ctx)
      -- Acquire again, should be reset (collapsed=false, but text remains until overwritten)
      local s2 = sectionFrame:Create(ctx)
      assert.are.equal(s2.title:GetText(), "Category A")
      assert.is_false(s2:IsCollapsed())
    end)
  end)

  describe("Title and Colors", function()
    it("sets title correctly", function()
      local ctx = context:New("TestTitle")
      local s = sectionFrame:Create(ctx)
      s:SetTitle("Weapons")
      assert.are.equal(s:GetTitleWithoutIndicator(), "Weapons")
    end)

    it("supports custom title color", function()
      local ctx = context:New("TestColor")
      local s = sectionFrame:Create(ctx)
      s:SetTitle("Epic Items", {1, 0, 0}) -- Red color
      local r, g, b, a = s.title:GetFontString():GetTextColor()
      assert.are.equal(r, 1)
      assert.are.equal(g, 0)
      assert.are.equal(b, 0)
      assert.are.equal(a, 1)
    end)
  end)

  describe("Collapsed State", function()
    it("sets and retrieves collapsed state", function()
      local ctx = context:New("TestCollapse")
      local s = sectionFrame:Create(ctx)
      assert.is_false(s:IsCollapsed())
      s:SetCollapsed(true)
      assert.is_true(s:IsCollapsed())
    end)
  end)

  describe("Cells Management", function()
    it("manages cells correctly", function()
      local ctx = context:New("TestCells")
      local s = sectionFrame:Create(ctx)
      local mockCell = { Release = function() end }
      s:AddCell("cell1", mockCell)
      assert.are.equal(s:GetCellCount(), 1)
      assert.is_true(s:HasItem(mockCell))
      s:RemoveCell("cell1")
      assert.are.equal(s:GetCellCount(), 0)
    end)
  end)

  describe("Draw and Sizing", function()
    it("returns correct width and height when drawing standard section", function()
      local ctx = context:New("TestDraw")
      local s = sectionFrame:Create(ctx)
      s:AddCell("cell1", {})
      local w, h = s:Draw(const.BAG_KIND.BACKPACK, nil, false)
      assert.are.equal(w, 112)
      assert.are.equal(h, 74)
    end)

    it("returns title-only height when collapsed and shouldShrinkWhenCollapsed is true", function()
      local ctx = context:New("TestDrawCollapsed")
      local s = sectionFrame:Create(ctx)
      s:AddCell("cell1", {})
      s:SetCollapsed(true)
      s.shouldShrinkWhenCollapsed = true
      local w, h = s:Draw(const.BAG_KIND.BACKPACK, nil, false)
      assert.are.equal(w, 112)
      assert.are.equal(h, 24) -- title:GetHeight() + 6 = 18 + 6 = 24
    end)

    it("returns full height when collapsed and shouldShrinkWhenCollapsed is false", function()
      local ctx = context:New("TestDrawCollapsedNoShrink")
      local s = sectionFrame:Create(ctx)
      s:AddCell("cell1", {})
      s:SetCollapsed(true)
      s.shouldShrinkWhenCollapsed = false
      local w, h = s:Draw(const.BAG_KIND.BACKPACK, nil, false)
      assert.are.equal(w, 112)
      assert.are.equal(h, 74) -- full height is still 74 even when collapsed if shrink is false
    end)
  end)
end)
