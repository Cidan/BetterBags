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
-- The real values (core/constants.lua).
const.MOVEMENT_FLOW = { UNDEFINED = -1, BANK = 0, REAGENT = 1, WARBANK = 2, SENDMAIL = 3, TRADE = 4, NPCSHOP = 5 }

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
  -- Measure packs the cells 37 wide in rows of maxWidthPerRow (one 50-tall row for these specs'
  -- single cell) and records what it was asked; Arrange records what it applied.
  Measure = function(self, options)
    self.measured = (self.measured or 0) + 1
    self.lastLimit = options.maxWidthPerRow
    local width = 100
    if options.maxWidthPerRow == math.huge then
      width = 41 * #options.cells - 4
    end
    return { width = width, height = 50, positions = {}, columnOf = {}, cells = options.cells }
  end,
  Arrange = function(self, measured)
    self.arranged = measured
    return measured.width, measured.height
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
    idToCell = {},
    -- The frame the real grid's cells hang from (frames/grid.lua).
    inner = CreateFrame("Frame"),
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

  -- Motion works out where an item that changes section was from the anchors up to a frame both
  -- sections hang from; the frame a section's cells hang from is placed by Blizzard's scroll box,
  -- so the section links it to its own frame at the offset its cells start (render/motion.lua).
  -- A render recording shows every item 6 pixels in and a title's height down from its section.
  describe("where its cells start", function()
    it("links the frame its cells hang from to its own frame, past its title", function()
      local motion = addon:GetModule("Motion")
      local s = sectionFrame:Create(context:New("test"))
      local link = motion.links[s.content.inner]
      assert.are.equal(s.frame, link.to)
      assert.are.same({ 6, -s.title:GetHeight() }, { link.offset() })
      assert.are.same({ 6, -s.title:GetHeight() }, { s:GetCellOrigin() })
      s:RemoveHeader()
      assert.are.same({ 6, 0 }, { link.offset() })
    end)
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

    -- BetterBags Next drops a whole section on the other bag or one of its tabs (next.md §7):
    -- the same move as the right click, for a list of items, into a given bank type.
    describe("MoveItems", function()
      local used, saved

      before_each(function()
        used, saved = {}, {}
        for _, k in ipairs({ "GetMovementFlow" }) do saved[#saved + 1] = { movementFlow, k, movementFlow[k] } end
        saved[#saved + 1] = { items, "GetAllSlotInfo", items.GetAllSlotInfo }
        saved[#saved + 1] = { items, "GetItemDataFromSlotKey", items.GetItemDataFromSlotKey }
        saved[#saved + 1] = { addon, "GetBagFromBagID", addon.GetBagFromBagID }
        saved[#saved + 1] = { addon, "atBank", addon.atBank }
        saved[#saved + 1] = { database, "GetCategorySell", database.GetCategorySell }
        _G.C_Container.UseContainerItem = function(bagid, slotid, unit, bankType, reagent)
          table.insert(used, { bagid, slotid, unit, bankType, reagent or nil })
        end
        addon.GetBagFromBagID = function() return { kind = const.BAG_KIND.BACKPACK } end
        items.GetAllSlotInfo = function()
          return { [const.BAG_KIND.BACKPACK] = { stacks = { GetStackInfo = function(_, hash)
            if hash == "stacked" then return { slotkeys = { ["0_9"] = true } } end
            return nil
          end } } }
        end
        items.GetItemDataFromSlotKey = function(_, key)
          if key == "0_9" then return { bagid = 0, slotid = 9, itemHash = "stacked" } end
        end
      end)

      after_each(function()
        for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
      end)

      local function item(slot, hash)
        return { bagid = 0, slotid = slot, itemHash = hash or ("h" .. slot) }
      end

      -- What a section stands for: each item shown and every pile its virtual stack hides (BetterBags
      -- Next's vendor sells the same, next.md §10).
      it("lists every item and every pile its virtual stack hides, without empty slots", function()
        local all = sectionFrame:WithStacks({ item(1), item(2, "stacked"), { isItemEmpty = true, bagid = 0, slotid = 3 } })
        local slots = {}
        for _, data in ipairs(all) do table.insert(slots, { data.bagid, data.slotid }) end
        assert.are.same({ { 0, 1 }, { 0, 2 }, { 0, 9 } }, slots)
      end)

      it("moves every item and every pile of its virtual stack to the window the flow names", function()
        movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.BANK end
        sectionFrame:MoveItems({ item(1), item(2, "stacked"), { isItemEmpty = true, bagid = 0, slotid = 3 } })
        assert.are.same({ { 0, 1 }, { 0, 2 }, { 0, 9 } }, used)
      end)

      it("moves into the Warbank when the flow says so", function()
        movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.WARBANK end
        sectionFrame:MoveItems({ item(1) })
        assert.are.same({ { 0, 1, nil, Enum.BankType.Account } }, used)
      end)

      it("moves into the bank type it is given while the bank is open, whatever the flow", function()
        movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.BANK end
        addon.atBank = true
        sectionFrame:MoveItems({ item(1) }, Enum.BankType.Account)
        sectionFrame:MoveItems({ item(2) }, Enum.BankType.Character)
        assert.are.same({ { 0, 1, nil, Enum.BankType.Account }, { 0, 2 } }, used)
        addon.atBank = false
        sectionFrame:MoveItems({ item(3) }, Enum.BankType.Account)
        assert.are.equal(2, #used, "not while the bank is closed")
      end)

      it("moves nothing without an open window, and sells only with the setting, ten at most", function()
        movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.UNDEFINED end
        sectionFrame:MoveItems({ item(1) })
        assert.are.equal(0, #used)
        movementFlow.GetMovementFlow = function() return const.MOVEMENT_FLOW.NPCSHOP end
        database.GetCategorySell = function() return false end
        sectionFrame:MoveItems({ item(1) })
        assert.are.equal(0, #used)
        database.GetCategorySell = function() return true end
        local list = {}
        for i = 1, 12 do list[i] = item(i) end
        sectionFrame:MoveItems(list)
        assert.are.equal(10, #used)
      end)
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

    -- Measure works the size out and moves nothing; Arrange applies it (render-pipeline.md, the
    -- layout engine). Draw is the two in a row.
    it("measures its size at an items per row without moving anything", function()
      local s = sectionFrame:Create(context:New("TestMeasure"))
      s:AddCell("cell1", {})
      s.frame:SetSize(1, 1)
      local measured = s:Measure(const.BAG_KIND.BACKPACK, 9)
      assert.are.same({ 112, 74, 9 }, { measured.width, measured.height, measured.itemsPerRow })
      assert.are.equal((37 + 4) * 9 + 16, s.content.lastLimit)
      assert.is_nil(s.content.arranged)
      assert.are.same({ 1, 1 }, { s.frame:GetWidth(), s.frame:GetHeight() })
    end)

    it("arranges a measure: its cells, its size and the items per row it was measured at", function()
      local s = sectionFrame:Create(context:New("TestArrange"))
      s:AddCell("cell1", {})
      local measured = s:Measure(const.BAG_KIND.BANK, 4)
      assert.are.same({ 112, 74 }, { s:Arrange(const.BAG_KIND.BANK, measured) })
      assert.are.equal(measured.content, s.content.arranged)
      assert.are.same({ 112, 74 }, { s.frame:GetWidth(), s.frame:GetHeight() })
      assert.are.equal(4, s:GetMaxCellWidth())
      assert.are.equal(const.BAG_KIND.BANK, s:GetKind())
      assert.is_true(s.frame:IsShown())
    end)

    it("draws by measuring at its items per row and arranging", function()
      local s = sectionFrame:Create(context:New("TestDrawMeasure"))
      s:AddCell("cell1", {})
      s:SetMaxCellWidth(6)
      s:Draw(const.BAG_KIND.BACKPACK, nil, false)
      assert.are.equal(1, s.content.measured)
      assert.are.equal((37 + 4) * 6 + 16, s.content.lastLimit)
      assert.are.equal(6, s.content.arranged.itemsPerRow or s:GetMaxCellWidth())
    end)

    -- A full section name widens a section to its title, rounded up to a whole pixel.
    it("widens to its title's text, in whole pixels, when full names show", function()
      local s = sectionFrame:Create(context:New("TestTitleWidth"))
      s:AddCell("cell1", {})
      s:SetTitle("A long category name here")
      s.title.GetTextWidth = function() return 150.3 end
      database.GetShowFullSectionNames = function() return true end
      local measured = s:Measure(const.BAG_KIND.BACKPACK, 3)
      database.GetShowFullSectionNames = function() return false end
      assert.are.equal(151 + 12, measured.width)
    end)

    -- Past this many items per row the section's cells all fit one row: measuring at more
    -- changes nothing (frames/bagcanvas.lua tries no more).
    it("says the items per row past which it no longer changes", function()
      local s = sectionFrame:Create(context:New("TestCap"))
      for i = 1, 7 do s:AddCell("cell" .. i, {}) end
      assert.are.equal(7, s:GetItemsPerRowCap())
      local one = sectionFrame:Create(context:New("TestCapOne"))
      one:AddCell("cell1", {})
      assert.are.equal(1, one:GetItemsPerRowCap())
      local none = sectionFrame:Create(context:New("TestCapNone"))
      assert.are.equal(1, none:GetItemsPerRowCap())
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
