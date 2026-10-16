local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required core modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:Init()

-- Stub file-scope modules required by frames/section.lua
local categories = StubBetterBagsModule("Categories")
categories.GetGroupForCategory = function() return nil end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { SECTION_GRID = 1 }
const.BAG_KIND = { BACKPACK = 1, BANK = 2 }
const.MOVEMENT_FLOW = { UNDEFINED = 0, NPCSHOP = 1, SENDMAIL = 2 }

local sort = StubBetterBagsModule("Sort")
sort.GetItemSortBySlot = function() end
sort.GetItemSortFunction = function() end

local database = StubBetterBagsModule("Database")
database.GetShowFullSectionNames = function() return false end

-- Sonata: section titles are SectionHeader elements; the theme's title color is (0.2, 0.4, 0.6).
local sonata, createdSonata = StubBetterBagsModule("Sonata")
local elements, createdElements = StubBetterBagsModule("SonataElements")
local replacedSonata = {
  RegisterElement = rawget(sonata, "RegisterElement"),
  GetSectionHeaderColor = rawget(elements, "GetSectionHeaderColor"),
}
local registeredElements = {}
sonata.RegisterElement = function(_, kind, element) table.insert(registeredElements, { kind, element }) end
elements.GetSectionHeaderColor = function() return 0.2, 0.4, 0.6, 1 end

local items = StubBetterBagsModule("Items")
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
    sectionFrame:Init()
  end)

  after_each(function()
    ResetModuleStub("Categories", "data/categories.lua")
    ResetModuleStub("Constants", "core/constants.lua")
    ResetModuleStub("Sort", "util/sort.lua")
    ResetModuleStub("Database", "core/database.lua")
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
      s:Release(ctx)
      -- Acquire again: the text remains until overwritten
      local s2 = sectionFrame:Create(ctx)
      assert.are.equal(s2.title:GetText(), "Category A")
    end)
  end)

  describe("Title and Colors", function()
    it("sets title correctly", function()
      local ctx = context:New("TestTitle")
      local s = sectionFrame:Create(ctx)
      s:SetTitle("Weapons")
      assert.are.equal(s:GetTitle(), "Weapons")
    end)

    it("makes its title font a Sonata section header, once", function()
      local s = sectionFrame:Create(context:New("TestHeader"))
      local count = 0
      for _, entry in ipairs(registeredElements) do
        if entry[2] == s.title:GetFontString() then
          count = count + 1
          assert.are.equal("SectionHeader", entry[1])
        end
      end
      assert.are.equal(1, count)
    end)

    it("gives a title without a color the theme's color back", function()
      local s = sectionFrame:Create(context:New("TestThemeColor"))
      s:SetTitle("Epic Items", { 1, 0, 0 })
      s:SetTitle("Weapons")
      assert.are.same({ 0.2, 0.4, 0.6, 1 }, { s.title:GetFontString():GetTextColor() })
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

    it("skips frameless gap cells when releasing all cells", function()
      local ctx = context:New("TestReleaseGap")
      local s = sectionFrame:Create(ctx)
      local released = false
      local realCell = { Release = function() released = true end }
      -- Gap cells are plain math tables with no Release method.
      local gapCell = { isGap = true, width = 37, height = 37 }
      s:AddCell("real1", realCell)
      s:AddCell("gap:0_5", gapCell)
      assert.has_no.errors(function()
        s:ReleaseAllCells(ctx)
      end)
      assert.is_true(released)
    end)

    it("skips frameless gap cells when right-clicking the title to move items", function()
      -- Reproduces the bug where mailing items from Recent Items leaves
      -- persistent gap cells; the next right-click iterated them and called
      -- cell:GetItemData() on a frameless gap table (section.lua:522 crash).
      movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.SENDMAIL end

      local used = {}
      local realBagID = 0
      _G.C_Container = _G.C_Container or {}
      _G.C_Container.UseContainerItem = function(bagid, slotid)
        table.insert(used, { bagid = bagid, slotid = slotid })
      end
      addon.GetBagFromBagID = function() return { kind = const.BAG_KIND.BACKPACK } end
      items.GetAllSlotInfo = function()
        return { [const.BAG_KIND.BACKPACK] = { stacks = { GetStackInfo = function() return nil end } } }
      end

      local ctx = context:New("TestRightClickGap")
      local s = sectionFrame:Create(ctx)
      local realCell = {
        Release = function() end,
        GetItemData = function()
          return { isItemEmpty = false, bagid = realBagID, slotid = 3, itemHash = "hash" }
        end,
      }
      -- A frameless gap cell has no GetItemData method.
      local gapCell = { isGap = true, width = 37, height = 37 }
      s:AddCell("0_3", realCell)
      s:AddCell("gap:0_5", gapCell)

      assert.has_no.errors(function()
        sectionFrame:OnTitleRightClick(s)
      end)
      -- The real item is still moved; the gap is simply skipped.
      assert.are.equal(1, #used)
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

    it("supports headerless section layout", function()
      local ctx = context:New("TestRemoveHeader")
      local s = sectionFrame:Create(ctx)
      s:AddCell("cell1", {})
      s:RemoveHeader()
      local w, h = s:Draw(const.BAG_KIND.BACKPACK, nil, false)
      assert.are.equal(w, 112)
      assert.are.equal(h, 50) -- 50 instead of 74 (title height 18 and offset 6 are skipped)
      assert.is_true(s.removeHeader)
    end)

    it("resets headerless state upon wipe or release", function()
      local ctx = context:New("TestResetHeader")
      local s = sectionFrame:Create(ctx)
      s:RemoveHeader()
      assert.is_true(s.removeHeader)
      s:Release(ctx)

      local s2 = sectionFrame:Create(ctx)
      assert.is_false(s2.removeHeader)
    end)
  end)

  describe("Dragging a section", function()
    it("puts every tab of both bags back in its state when a drag ends", function()
      local tabsModule, created = StubBetterBagsModule("Tabs")
      local saved = { reset = rawget(tabsModule, "ResetDropHighlights"), bags = addon.Bags, hide = GameTooltip.Hide }
      local reset, hidden = {}, 0
      tabsModule.ResetDropHighlights = function(_, bar) table.insert(reset, bar) end
      GameTooltip.Hide = function() hidden = hidden + 1 end
      local backpackTabs, bankTabs = {}, {}
      addon.Bags = { Backpack = { tabs = backpackTabs }, Bank = { tabs = bankTabs } }
      finally(function()
        tabsModule.ResetDropHighlights = saved.reset
        addon.Bags = saved.bags
        GameTooltip.Hide = saved.hide
        if created then ResetModuleStub("Tabs") end
      end)
      sectionFrame:ResetTabHighlights()
      assert.are.same({ backpackTabs, bankTabs }, reset)
      assert.are.equal(1, hidden)
      reset = {}
      addon.Bags = { Bank = { tabs = bankTabs } }
      sectionFrame:ResetTabHighlights()
      assert.are.same({ bankTabs }, reset)
    end)
  end)

  teardown(function()
    sonata.RegisterElement = replacedSonata.RegisterElement
    elements.GetSectionHeaderColor = replacedSonata.GetSectionHeaderColor
    if createdSonata then ResetModuleStub("Sonata") end
    if createdElements then ResetModuleStub("SonataElements") end
  end)
end)
