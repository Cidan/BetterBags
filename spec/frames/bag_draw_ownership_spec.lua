-- bag_draw_ownership_spec.lua -- Every physical slot maps to exactly one static item
-- button (itemFrame.buttonsBySlotkey) that is shared by the bag's global sections
-- (Recent Items / Free Space) and by every tab view. A bagProto:Draw pass claims, then
-- sweeps: renderers record the buttons they draw, and only buttons the previous pass
-- drew that nobody claimed are released, after every renderer has run. If a button
-- another renderer just claimed were released mid-pass, it would be hidden and
-- unparented and simply vanish from the UI (.claude/rules/layout-rendering.md §1).
--
-- These specs run the real ItemFrame, SectionFrame, Views and BagFrame modules so
-- that button identity and section cell release behave exactly as in the client.

-- Base's text roles, kept for the specs that swap in a test Base theme.
local baseTextRoles = {}

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:Init()
local context = addon:GetModule("Context")

-- Grid stub. Stores cells like frames/grid.lua and, like layoutSingleColumn, shows
-- every non-gap cell frame it lays out.
local mockGridProto = {
  HideScrollBar = function() end,
  ShowScrollBar = function() end,
  EnableMouseWheelScroll = function() end,
  SortVertical = function() end,
  SortHorizontal = function() end,
  Sort = function() end,
  Show = function(self) self._shown = true end,
  Hide = function(self) self._shown = false end,
  Wipe = function(self)
    self.cells = {}
    self.idToCell = {}
  end,
  AddCell = function(self, id, cell)
    if self.idToCell[id] ~= nil then return end
    table.insert(self.cells, cell)
    self.idToCell[id] = cell
  end,
  RemoveCell = function(self, id)
    local cell = self.idToCell[id]
    if not cell then return nil end
    for i, c in ipairs(self.cells) do
      if c == cell then
        table.remove(self.cells, i)
        break
      end
    end
    self.idToCell[id] = nil
    return cell
  end,
  GetCell = function(self, id)
    return self.idToCell[id]
  end,
  Draw = function(self, options)
    local cells = options and options.cells or self.cells
    for _, cell in ipairs(cells) do
      if not cell.isGap and cell.frame then
        cell.frame:SetParent(self.inner)
        cell.frame:Show()
      end
    end
    local count = #cells
    if count == 0 then
      self.contentWidth, self.contentHeight = 0, 0
      return 0, 0
    end
    self.contentWidth, self.contentHeight = 41 * count, 41
    return self.contentWidth, self.contentHeight
  end,
  -- Measure sizes the cells like Draw, moving nothing; Arrange shows them like Draw.
  Measure = function(self, options)
    local cells = options and options.cells or self.cells
    local count = #cells
    local width, height = 41 * count, count > 0 and 41 or 0
    return { width = width, height = height, positions = {}, columnOf = {}, cells = cells }
  end,
  Arrange = function(self, measured)
    for _, cell in ipairs(measured.cells) do
      if not cell.isGap and cell.frame then
        cell.frame:SetParent(self.inner)
        cell.frame:Show()
      end
    end
    self.contentWidth, self.contentHeight = measured.width, measured.height
    return measured.width, measured.height
  end,
  GetContainer = function(self)
    return self.frame
  end,
  GetScrollView = function(self)
    return self.inner
  end,
}

local overrides = {}
local function override(tbl, key, value)
  table.insert(overrides, { tbl = tbl, key = key, original = tbl[key] })
  tbl[key] = value
end
local function restoreOverrides()
  for i = #overrides, 1, -1 do
    local o = overrides[i]
    o.tbl[o.key] = o.original
  end
  overrides = {}
end

-- Stub modules registered by this spec are torn down again so later spec files can
-- load the real module (AceAddon refuses to NewModule a name that already exists).
local createdStubs = {}
local function stubModule(name)
  local mod, created = _G.StubBetterBagsModule(name)
  if created then
    table.insert(createdStubs, name)
  end
  return mod
end
local function resetCreatedStubs()
  for i = #createdStubs, 1, -1 do
    ResetModuleStub(createdStubs[i])
  end
  createdStubs = {}
end

local const
-- What the bag windows handed to CursorPlacement, and the windows LibWindow saved.
local placements = {}
local savedPositions = {}

local function stubModules()
  placements = {}
  savedPositions = {}
  local L = stubModule("Localization")
  override(L, "G", function(_, key) return key end)

  local debug = stubModule("Debug")
  override(debug, "Log", function() end)
  override(debug, "WalkAndFixAnchorGraph", function() end)
  override(debug, "ShowItemTooltip", function() end)
  override(debug, "HideItemTooltip", function() end)

  const = stubModule("Constants")
  override(const, "BAG_KIND", { UNDEFINED = -1, BACKPACK = 0, BANK = 1 })
  override(const, "BAG_VIEW", { UNDEFINED = 0, SECTION_GRID = 2, SECTION_ALL_BAGS = 4 })
  override(const, "GRID_COMPACT_STYLE", { NONE = 0 })
  override(const, "MOVEMENT_FLOW", { UNDEFINED = -1, NPCSHOP = 5 })
  override(const, "ITEM_QUALITY", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 })
  override(const, "ITEM_QUALITY_COLOR", {
    [0] = { 0.62, 0.62, 0.62, 1 },
    [1] = { 1, 1, 1, 1 },
    [2] = { 0.12, 1, 0, 1 },
    [3] = { 0, 0.44, 0.87, 1 },
    [4] = { 0.64, 0.21, 0.93, 1 },
  })
  override(const, "BACKPACK_BAGS", { [0] = 0, [1] = 1 })
  override(const, "BANK_BAGS", { [6] = 6 })
  override(const, "ACCOUNT_BANK_BAGS", {})
  override(const, "BACKPACK_ONLY_REAGENT_BAGS", {})
  override(const, "GLOW_INTENSITY_HALO_THRESHOLD", 60)
  override(const, "GLOW_INTENSITY_MAX", 100)
  override(const, "GLOW_INTENSITY_DEFAULT", 60)
  override(const, "OFFSETS", {
    BAG_LEFT_INSET = 6,
    BAG_TOP_INSET = -38,
    BAG_RIGHT_INSET = -6,
    BAG_BOTTOM_INSET = 3,
    BOTTOM_BAR_HEIGHT = 20,
    BOTTOM_BAR_BOTTOM_INSET = 6,
    SCROLLBAR_WIDTH = 14,
  })

  local database = stubModule("Database")
  override(database, "GetBagSizeInfo", function() return { itemsPerRow = 5, columnCount = 2, scale = 100, opacity = 89 } end)
  override(database, "GetBagView", function() return const.BAG_VIEW.SECTION_GRID end)
  override(database, "GetInBagSearch", function() return false end)
  override(database, "GetGroupsEnabled", function() return false end)
  override(database, "GetActiveGroup", function() return 1 end)
  override(database, "GetShowBankTabs", function() return false end)
  override(database, "GetShowAllFreeSpace", function() return false end)
  override(database, "GetShowFullSectionNames", function() return false end)
  override(database, "GetItemLevelOptions", function() return { enabled = false, color = false } end)
  override(database, "GetStackingOptions", function() return { mergeUnstackable = false } end)
  override(database, "GetGlowIntensity", function() return 60 end)
  override(database, "GetUpgradeIconProvider", function() return "None" end)

  local color = stubModule("Color")
  override(color, "GetItemLevelColor", function() return 1, 1, 1 end)

  local items = stubModule("Items")
  override(items, "GetSlotKeyFromBagAndSlot", function(_, bagid, slotid) return bagid .. "_" .. slotid end)
  override(items, "GetStackData", function() return nil end)
  override(items, "IsNewItem", function() return false end)
  override(items, "GetItemDataFromSlotKey", function() return nil end)
  override(items, "GetAllSlotInfo", function() return {} end)

  local sort = stubModule("Sort")
  override(sort, "GetItemSortBySlot", function() end)
  override(sort, "GetItemSortFunction", function() end)
  override(sort, "GetSectionSortFunction", function() return function() return true end end)

  local categories = stubModule("Categories")
  override(categories, "IsCategoryShown", function() return true end)
  override(categories, "GetCategoryByName", function() return nil end)
  override(categories, "GetGroupForCategory", function() return nil end)

  local groups = stubModule("Groups")
  override(groups, "CategoryBelongsToGroup", function() return true end)
  override(groups, "GetGroupForCategory", function() return nil end)
  override(groups, "IsDefaultGroup", function() return true end)

  stubModule("Seller")
  local movementFlow = stubModule("MovementFlow")
  override(movementFlow, "GetMovementFlow", function() return const.MOVEMENT_FLOW.UNDEFINED end)

  local grid = stubModule("Grid")
  override(grid, "Create", function(_, parent)
    local g = setmetatable({}, { __index = mockGridProto })
    g.frame = CreateFrame("Frame", nil, parent)
    g.inner = g.frame
    g.cells = {}
    g.idToCell = {}
    return g
  end)

  local libWindow = LibStub:NewLibrary("LibWindow-1.1", 1) or LibStub("LibWindow-1.1")
  libWindow.RestorePosition = libWindow.RestorePosition or function() end
  libWindow.RegisterConfig = libWindow.RegisterConfig or function() end
  override(libWindow, "SavePosition", function(frame) table.insert(savedPositions, frame) end)

  local cursorPlacement = stubModule("CursorPlacement")
  override(cursorPlacement, "PlaceCursorItem", function(_, kind, bankTab)
    table.insert(placements, { kind = kind, bankTab = bankTab })
    return "placed"
  end)

  local contextMenu = stubModule("ContextMenu")
  override(contextMenu, "CreateContextMenu", function() return {} end)
  stubModule("BagMenuButton")
  stubModule("BagActions")
  stubModule("SearchBox")
  override(database, "GetBagPosition", function() return {} end)
  override(database, "GetBagSizeMode", function() return "content" end)
  override(database, "GetBagViewFrameSize", function() return 700, 500 end)
  override(database, "SetBagViewFrameSize", function() end)
  override(database, "GetEnableBagFading", function() return false end)
  override(database, "GetClampBagsToScreen", function() return false end)
  override(database, "GetAnimateItemMovement", function() return false end)
  override(database, "GetTheme", function() return "Default" end)
  override(database, "SetTheme", function() end)
  stubModule("Fonts")
  stubModule("Question")
  stubModule("Anchor")
  stubModule("BackpackBehavior")
  stubModule("BankBehavior")
end

-- newDecoration builds what ContainerFrameItemButtonTemplate gives an item's decoration.
local function newDecoration(item)
  local d = CreateFrame("ItemButton", item.button:GetName() .. "Decoration", item.frame)
  d.IconBorder = d:CreateTexture()
  d.IconQuestTexture = d:CreateTexture()
  d.IconTexture = d:CreateTexture()
  d.IconOverlay = d:CreateTexture()
  d.ItemSlotBackground = d:CreateTexture()
  d.flashAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end }
  d.newitemglowAnim = { IsPlaying = function() return false end, Play = function() end, Stop = function() end }
  d.SetMatchesSearch = function() end
  d.SetItemButtonTexture = function() end
  d.UpdateQuestItem = function() end
  d.UpdateNewItem = function() end
  d.UpdateJunkItem = function() end
  d.UpdateItemContextMatching = function() end
  d.UpdateCooldown = function() end
  d.SetReadable = function() end
  d.CheckUpdateTooltip = function() end
  return d
end

local function loadRealModules()
  LoadBetterBagsModule("render/render.lua")
  LoadBetterBagsModule("render/drawable.lua")
  LoadBetterBagsModule("render/scrollbox.lua")
  LoadBetterBagsModule("sonata/engine.lua")
  LoadBetterBagsModule("sonata/apply.lua")
  LoadBetterBagsModule("sonata/decoration.lua")
  ResetModuleStub("SonataElements", "sonata/elements.lua")
  LoadBetterBagsModule("sonata/elements.lua")
  LoadBetterBagsModule("window/window.lua")
  ResetModuleStub("BagCanvas", "frames/bagcanvas.lua")
  LoadBetterBagsModule("frames/bagcanvas.lua")
  addon:GetModule("Render"):Init()
  addon:GetModule("Sonata"):Init()
  -- Base and Default: the views draw their hints, and a bag its Loading..., with Base's text roles.
  UseSonataTextRoles()
  baseTextRoles.Text = addon:GetModule("Sonata").themes.Base.Text
  baseTextRoles.Variables = addon:GetModule("Sonata").themes.Base.Variables
  ResetModuleStub("ItemFrame", "frames/item.lua")
  LoadBetterBagsModule("frames/item.lua")
  addon:GetModule("ItemFrame").CreateDecoration = function(_, item) return newDecoration(item) end
  ResetModuleStub("SectionFrame", "frames/section.lua")
  LoadBetterBagsModule("frames/section.lua")
  ResetModuleStub("Views", "views/views.lua")
  LoadBetterBagsModule("views/views.lua")
  ResetModuleStub("GridViewDummy", "views/gridview.lua")
  LoadBetterBagsModule("views/gridview.lua")
  ResetModuleStub("BagViewDummy", "views/bagview.lua")
  LoadBetterBagsModule("views/bagview.lua")
  ResetModuleStub("BagFrame", "frames/bag.lua")
  LoadBetterBagsModule("frames/bag.lua")
end

local function unloadRealModules()
  ResetModuleStub("BagFrame", "frames/bag.lua")
  ResetModuleStub("BagCanvas", "frames/bagcanvas.lua")
  ResetModuleStub("Views", "views/views.lua")
  ResetModuleStub("GridViewDummy", "views/gridview.lua")
  ResetModuleStub("BagViewDummy", "views/bagview.lua")
  ResetModuleStub("SectionFrame", "frames/section.lua")
  ResetModuleStub("ItemFrame", "frames/item.lua")
end

-- Builds a Bag object on top of the real bagProto with the window, scroll box and canvas
-- bagFrame:Create() builds (BuildWindow), shown, as an open bag is.
local bagCount = 0
local function newBag()
  local bagProto = addon:GetModule("BagFrame").bagProto
  bagCount = bagCount + 1
  local bag = setmetatable({
    kind = const.BAG_KIND.BACKPACK,
    tabViews = {},
    itemFrames = {},
    globalSections = {},
    behavior = {
      OnShow = function() end,
      GetFrameStrata = function() return "MEDIUM" end,
      GetFrameLevel = function() return 500 end,
    },
  }, { __index = bagProto })
  bag:BuildWindow("OwnershipSpec" .. bagCount)
  bag.OnResize = function() end
  bag.hiddenText = bag.frame:CreateFontString()
  bag.hiddenText:SetFontObject("GameFontNormal")
  bag.frame:Show()
  return bag
end

local function itemAt(bagid, slotid, category)
  return MockData.ItemData({
    bagid = bagid,
    slotid = slotid,
    slotkey = bagid .. "_" .. slotid,
    category = category,
    quality = 2,
    itemID = 1000 + slotid,
    name = "Item " .. bagid .. "_" .. slotid,
  })
end

local function freeSpaceButton(bagid, slotid, count)
  return {
    slotkey = bagid .. "_" .. slotid,
    bagid = bagid,
    slotid = slotid,
    count = count,
    isIndividual = false,
    key = "Bag",
    itemInfo = { emptySlotName = "Bag", itemQuality = 1 },
  }
end

-- Builds the slotInfo shape produced by Phase10_PartitionIntoTabs / Phase11 for a
-- single default tab. Items with the "Recent Items" category are excluded from the tab
-- (mirroring ItemBelongsToTab) but remain in the visible item map that
-- DrawGlobalSections sweeps for the header section.
local function slotInfoWith(allItems, freeButtons)
  local visible = {}
  local tabItems = {}
  local categories = {}
  local seen = {}
  for _, item in ipairs(allItems) do
    visible[item.slotkey] = item
    if item.itemInfo.category ~= "Recent Items" then
      table.insert(tabItems, item)
      if not seen[item.itemInfo.category] then
        seen[item.itemInfo.category] = true
        table.insert(categories, { name = item.itemInfo.category })
      end
    end
  end
  return {
    totalItems = #allItems,
    sectionLayouts = {},
    GetVisibleItems = function() return visible end,
    GetCurrentItems = function() return visible end,
    tabs = {
      [1] = {
        items = tabItems,
        categories = categories,
        totalItems = #tabItems,
        freeSpace = { showAll = false, buttons = freeButtons },
      },
    },
  }
end

-- Builds the slotInfo shape for a bag whose ordered layout (sortedItems) is the
-- single source of truth for item order and persistent gaps, exactly as
-- Phase11_CommitAndDispatch commits it. The Recent Items global section must be
-- rendered from this ordered, gap-carrying list -- not from an arbitrary pairs()
-- scan of the visible item map. Gap entries (isItemGap) are excluded from the
-- visible map, mirroring production where gaps live only in sortedItems.
local function slotInfoOrdered(sortedItems, freeButtons)
  local visible = {}
  local tabItems = {}
  local categories = {}
  local seen = {}
  for _, item in ipairs(sortedItems) do
    if not item.isItemGap then
      visible[item.slotkey] = item
    end
    if item.itemInfo.category ~= "Recent Items" and not item.isItemGap then
      table.insert(tabItems, item)
      if not seen[item.itemInfo.category] then
        seen[item.itemInfo.category] = true
        table.insert(categories, { name = item.itemInfo.category })
      end
    end
  end
  return {
    totalItems = #sortedItems,
    sectionLayouts = {},
    sortedItems = sortedItems,
    GetVisibleItems = function() return visible end,
    GetCurrentItems = function() return visible end,
    tabs = {
      [1] = {
        items = tabItems,
        categories = categories,
        totalItems = #tabItems,
        freeSpace = { showAll = false, buttons = freeButtons or {} },
      },
    },
  }
end

-- A persistent empty gap left behind by a consumed/removed Recent Items entry, as
-- CloneAsGap produces it: isItemGap, a "gap:"-prefixed slotkey, and the departed
-- item's category preserved so the hole routes to the same section.
local function recentGap(originalSlotkey)
  return {
    isItemGap = true,
    slotkey = "gap:" .. originalSlotkey,
    itemInfo = { category = "Recent Items", itemQuality = 1 },
  }
end

describe("Bag Draw: shared item button ownership across global sections and views", function()
  local itemFrame
  local savedGlobals = {}

  before_each(function()
    stubModules()
    savedGlobals.SetItemButtonQuality = _G.SetItemButtonQuality
    savedGlobals.SetItemButtonCount = _G.SetItemButtonCount
    savedGlobals.SetItemButtonDesaturated = _G.SetItemButtonDesaturated
    savedGlobals.ClearItemButtonOverlay = _G.ClearItemButtonOverlay
    savedGlobals.GetOwner = _G.GameTooltip.GetOwner
    savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY = _G.NEW_ITEM_ATLAS_BY_QUALITY
    savedGlobals.isRetail = addon.isRetail
    _G.SetItemButtonQuality = function() end
    _G.SetItemButtonCount = function() end
    _G.SetItemButtonDesaturated = function() end
    _G.ClearItemButtonOverlay = function() end
    _G.GameTooltip.GetOwner = function() return nil end
    _G.NEW_ITEM_ATLAS_BY_QUALITY = { [1] = "bags-glow-white", [2] = "bags-glow-green" }
    addon.isRetail = true

    loadRealModules()
    itemFrame = addon:GetModule("ItemFrame")
    itemFrame:Init()
    addon:GetModule("SectionFrame"):Init()
  end)

  after_each(function()
    unloadRealModules()
    restoreOverrides()
    _G.SetItemButtonQuality = savedGlobals.SetItemButtonQuality
    _G.SetItemButtonCount = savedGlobals.SetItemButtonCount
    _G.SetItemButtonDesaturated = savedGlobals.SetItemButtonDesaturated
    _G.ClearItemButtonOverlay = savedGlobals.ClearItemButtonOverlay
    _G.GameTooltip.GetOwner = savedGlobals.GetOwner
    _G.NEW_ITEM_ATLAS_BY_QUALITY = savedGlobals.NEW_ITEM_ATLAS_BY_QUALITY
    addon.isRetail = savedGlobals.isRetail
    resetCreatedStubs()
  end)

  it("keeps the Free Space button visible when its slot held a grid item in the previous draw", function()
    local bag = newBag()

    -- Draw 1: slot 0_1 holds an item in the grid, slot 0_2 is the free space representative.
    bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 2, 3) }), function() end)
    local button1 = itemFrame.buttonsBySlotkey["0_1"]
    local button2 = itemFrame.buttonsBySlotkey["0_2"]
    assert.is_not_nil(button1)
    assert.is_not_nil(button2)
    assert.is_true(button1.frame:IsShown())
    assert.is_true(button2.frame:IsShown())
    assert.is_true(button2.isFreeSlot)

    -- Draw 2: the item moved to slot 0_2 and the now-empty slot 0_1 becomes the free
    -- space representative. The Free Space section acquires button 0_1 first; the tab
    -- view must not hide it while releasing its own previous cells.
    bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 2, "Weapons") }, { freeSpaceButton(0, 1, 3) }), function() end)

    assert.equal(button1, itemFrame.buttonsBySlotkey["0_1"], "physical buttons are static per slot")
    assert.is_true(button1.isFreeSlot, "slot 0_1 must be drawn as the Free Space button")
    assert.is_true(button1.frame:IsShown(), "Free Space button 0_1 must still be visible after the tab view re-rendered")
    assert.is_not_nil(button1.frame:GetParent(), "Free Space button 0_1 must still be parented to the free space section")
    assert.is_true(button2.frame:IsShown())
    assert.is_false(button2.isFreeSlot or false)
  end)

  it("keeps the Recent Items button visible when its slot held a grid item in the previous draw", function()
    local bag = newBag()

    bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 3, 2) }), function() end)
    local button1 = itemFrame.buttonsBySlotkey["0_1"]
    assert.is_true(button1.frame:IsShown())

    -- Draw 2: a freshly looted item now occupies slot 0_1 and belongs to Recent Items,
    -- which is rendered by the global header section, not the tab view.
    bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Recent Items") }, { freeSpaceButton(0, 3, 2) }), function() end)

    assert.equal(button1, itemFrame.buttonsBySlotkey["0_1"])
    assert.is_true(button1.frame:IsShown(), "Recent Items button 0_1 must still be visible after the tab view re-rendered")
    assert.is_not_nil(bag.globalSections["Recent Items"])
    assert.is_true(bag.globalSections["Recent Items"]:HasItem(button1))
  end)

  -- The data phase leaves freeSpace out of a tab with no free slots (data/items.lua
  -- Phase10_PartitionIntoTabs); the draw follows the data. An empty Free Space section
  -- showed its header squeezed into two dots: an empty grid reports its spacing as width.
  -- Recent Items spans every column; Free Space is one section wide, or spans every column when it
  -- shows every free slot. The canvas measures them with each layout it tries and arranges the
  -- chosen one (frames/bagcanvas.lua).
  describe("global sections in a layout", function()
    local function drawWith(showAll)
      local bag = newBag()
      local info = slotInfoWith({ itemAt(0, 1, "Recent Items"), itemAt(0, 3, "Weapons") }, { freeSpaceButton(0, 2, 1) })
      info.tabs[1].freeSpace.showAll = showAll
      bag:Draw(context:New("draw"), info, function() end)
      return bag
    end

    it("lists Recent Items as spanning the columns, and Free Space only when it shows every slot", function()
      local bag = drawWith(false)
      local listed = bag:GetGlobalLayoutSections()
      assert.are.same({ { bag.recentSection, true, "header" }, { bag.freeSpaceSection, false, "footer" } },
        { { listed[1].section, listed[1].spansColumns, listed[1].place }, { listed[2].section, listed[2].spansColumns, listed[2].place } })
      assert.is_true(drawWith(true):GetGlobalLayoutSections()[2].spansColumns)
    end)

    it("measures them without moving anything, with the items per row each takes", function()
      local bag = drawWith(false)
      bag.recentSection.frame:SetSize(1, 1)
      local asked = {}
      local measured = bag:MeasureGlobalSections(5, 3, function(section, itemsPerRow)
        asked[section] = itemsPerRow
        return section:Measure(bag.kind, itemsPerRow)
      end)
      assert.are.equal(15, asked[bag.recentSection])
      assert.are.equal(5, asked[bag.freeSpaceSection])
      assert.are.same({ 15, 5 }, { measured.header.itemsPerRow, measured.footer.itemsPerRow })
      assert.are.same({ 1, 1 }, { bag.recentSection.frame:GetWidth(), bag.recentSection.frame:GetHeight() })
      assert.are.equal(15, bag:MeasureGlobalSections(5, 3).header.itemsPerRow)
    end)

    it("arranges a measure and sizes the header and footer containers to it", function()
      local bag = drawWith(false)
      local measured = bag:MeasureGlobalSections(4, 2)
      local headerW, headerH, footerW, footerH = bag:ArrangeGlobalSections(measured)
      assert.are.same({ measured.header.width, measured.header.height }, { headerW, headerH })
      assert.are.same({ measured.footer.width, measured.footer.height }, { footerW, footerH })
      assert.are.equal(headerH, bag.headerContainer:GetHeight())
      assert.are.equal(footerH, bag.footerContainer:GetHeight())
      assert.are.equal(8, bag.recentSection:GetMaxCellWidth())
    end)
  end)

  describe("Free Space only when the data carries it", function()
    it("draws no Free Space section when the tab's data carries no freeSpace", function()
      local bag = newBag()
      local info = slotInfoWith({ itemAt(0, 1, "Weapons") }, {})
      info.tabs[1].freeSpace = nil

      bag:Draw(context:New("draw"), info, function() end)

      assert.is_nil(bag.globalSections["Free Space"])
      assert.is_true(itemFrame.buttonsBySlotkey["0_1"].frame:IsShown())
    end)

    it("removes the Free Space section once the bag fills up", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 2, 1) }), function() end)
      local freeSection = bag.globalSections["Free Space"]
      assert.is_not_nil(freeSection)
      assert.is_true(freeSection.frame:IsShown())

      local full = slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Weapons") }, {})
      full.tabs[1].freeSpace = nil
      bag:Draw(context:New("draw2"), full, function() end)

      assert.is_nil(bag.globalSections["Free Space"])
      assert.is_false(freeSection.frame:IsShown(), "the old Free Space section is released")
      local button2 = itemFrame.buttonsBySlotkey["0_2"]
      assert.is_false(button2.isFreeSlot or false)
      assert.is_true(button2.frame:IsShown())
    end)
  end)

  -- Claim, then sweep. A draw pass releases nothing up front: every renderer claims the
  -- buttons and sections it draws, and only what the previous pass drew and nobody
  -- claimed is released, after every renderer has run. A button drawn in consecutive
  -- passes is never hidden or unparented in between, so Blizzard's OnHide/OnShow
  -- handlers on the item button template do not run on every redraw.
  describe("claim, then sweep", function()
    -- Blizzard's item buttons react to being visible (the enchant event, the item context
    -- callback). Only the buttons a draw placed are visible: a slot made earlier and never
    -- drawn stays hidden, and closing the bag hides the drawn ones with it.
    it("leaves visible only the buttons it drew, and none once the bag closes", function()
      local bag = newBag()
      local untouched = itemFrame:GetButton(context:New("boot"), "0_7")
      bag:Draw(context:New("draw"), slotInfoWith(
        { itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items") }, {}), function() end)
      local drawn = { itemFrame.buttonsBySlotkey["0_1"], itemFrame.buttonsBySlotkey["0_2"] }
      for _, item in ipairs(drawn) do
        assert.is_true(item.button:IsVisible(), item.slotkey)
      end
      assert.is_false(untouched.button:IsVisible())
      bag.frame:Hide()
      for _, item in ipairs(drawn) do
        assert.is_false(item.button:IsVisible(), item.slotkey)
      end
    end)

    local log

    local function watch(button)
      local frame = button.frame
      local hide, setParent = frame.Hide, frame.SetParent
      frame.Hide = function(self)
        table.insert(log, "hide:" .. tostring(button.slotkey))
        return hide(self)
      end
      frame.SetParent = function(self, parent)
        if parent == nil then
          table.insert(log, "unparent:" .. tostring(button.slotkey))
        end
        return setParent(self, parent)
      end
    end

    local function watchPass()
      local originalRelease = itemFrame.itemProto.Release
      local originalGetButton = itemFrame.GetButton
      override(itemFrame.itemProto, "Release", function(self, ctx)
        table.insert(log, "release:" .. tostring(self.slotkey))
        return originalRelease(self, ctx)
      end)
      override(itemFrame, "GetButton", function(self, ctx, slotkey)
        table.insert(log, "acquire:" .. slotkey)
        return originalGetButton(self, ctx, slotkey)
      end)
    end

    local function entries(prefix)
      local out = {}
      for _, entry in ipairs(log) do
        if entry:sub(1, #prefix) == prefix then table.insert(out, entry) end
      end
      return out
    end

    before_each(function()
      log = {}
    end)

    it("never releases, hides or unparents a button that is drawn again", function()
      local bag = newBag()
      local info = function()
        return slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items") }, { freeSpaceButton(0, 3, 3) })
      end
      bag:Draw(context:New("draw1"), info(), function() end)
      for _, key in ipairs({ "0_1", "0_2", "0_3" }) do watch(itemFrame.buttonsBySlotkey[key]) end
      watchPass()

      bag:Draw(context:New("draw2"), info(), function() end)

      assert.are.same({}, entries("release:"))
      assert.are.same({}, entries("hide:"))
      assert.are.same({}, entries("unparent:"))
      for _, key in ipairs({ "0_1", "0_2", "0_3" }) do
        assert.is_true(itemFrame.buttonsBySlotkey[key].frame:IsShown(), key)
      end
    end)

    it("releases a button no longer drawn, after every renderer has run", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Weapons") }, {}), function() end)
      local gone = itemFrame.buttonsBySlotkey["0_2"]
      watchPass()

      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 3, 1) }), function() end)

      assert.are.same({ "release:0_2" }, entries("release:"))
      local lastAcquire, release
      for i, entry in ipairs(log) do
        if entry:match("^acquire:") then lastAcquire = i end
        if entry == "release:0_2" then release = i end
      end
      assert.is_true(release > lastAcquire, "unclaimed buttons are released only after every renderer: " .. table.concat(log, ", "))
      assert.is_false(gone.frame:IsShown())
      assert.is_nil(gone.frame:GetParent())
    end)

    it("moves a button between Recent Items and a tab section without releasing it", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Recent Items") }, {}), function() end)
      local button = itemFrame.buttonsBySlotkey["0_1"]
      watchPass()

      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      assert.are.same({}, entries("release:"))
      local view = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_1"]
      assert.is_true(view.sections["Weapons"]:HasItem(button))
      assert.is_true(button.frame:IsShown())
      assert.is_nil(bag.globalSections["Recent Items"])

      bag:Draw(context:New("draw3"), slotInfoWith({ itemAt(0, 1, "Recent Items") }, {}), function() end)
      assert.are.same({}, entries("release:"))
      assert.is_true(bag.globalSections["Recent Items"]:HasItem(button))
      assert.is_true(button.frame:IsShown())
    end)

    it("keeps the section of a category drawn again and releases the section of a category that is gone", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Armor") }, {}), function() end)
      local view = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_1"]
      local weapons, armor = view.sections["Weapons"], view.sections["Armor"]
      local weaponsHidden = false
      local hide = weapons.frame.Hide
      weapons.frame.Hide = function(self)
        weaponsHidden = true
        return hide(self)
      end

      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)

      assert.are.equal(weapons, view.sections["Weapons"])
      assert.is_false(weaponsHidden)
      assert.is_nil(view.sections["Armor"])
      assert.is_false(armor.frame:IsShown())
    end)

    it("draws only the active tab and releases the hidden tab's sections and buttons", function()
      local active = 1
      local database = addon:GetModule("Database")
      override(database, "GetGroupsEnabled", function() return true end)
      override(database, "GetActiveGroup", function() return active end)
      local function info()
        local weapons, armor = itemAt(0, 1, "Weapons"), itemAt(0, 2, "Armor")
        return {
          totalItems = 2,
          sectionLayouts = {},
          GetVisibleItems = function() return { ["0_1"] = weapons, ["0_2"] = armor } end,
          tabs = {
            [1] = { items = { weapons }, categories = { { name = "Weapons" } }, totalItems = 1, freeSpace = { buttons = {} } },
            [2] = { items = { armor }, categories = { { name = "Armor" } }, totalItems = 1, freeSpace = { buttons = {} } },
          },
        }
      end
      local bag = newBag()
      bag:Draw(context:New("tab1"), info(), function() end)
      local tab1 = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_1"]
      local weaponsButton = itemFrame.buttonsBySlotkey["0_1"]
      assert.is_nil(itemFrame.buttonsBySlotkey["0_2"], "the hidden tab is not rendered")

      active = 2
      bag:Draw(context:New("tab2"), info(), function() end)
      local tab2 = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_2"]
      assert.is_not_nil(tab2.sections["Armor"])
      assert.is_nil(next(tab1.sections), "the now hidden tab's sections are released")
      assert.is_false(weaponsButton.frame:IsShown(), "the now hidden tab's buttons are released")

      active = 1
      bag:Draw(context:New("tab1again"), info(), function() end)
      assert.is_not_nil(tab1.sections["Weapons"])
      assert.is_true(weaponsButton.frame:IsShown())
      assert.is_nil(next(tab2.sections))
    end)

    it("does not keep last pass's cells in a reused section", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Weapons") }, {}), function() end)
      local gone = itemFrame.buttonsBySlotkey["0_2"]
      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      local weapons = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_1"].sections["Weapons"]
      assert.are.equal(1, #weapons.content.cells)
      assert.is_false(weapons:HasItem(gone))
    end)

    describe("after a draw that failed partway", function()
      local failOn

      before_each(function()
        failOn = nil
        local original = itemFrame.itemProto.SetItemFromData
        override(itemFrame.itemProto, "SetItemFromData", function(self, c, data)
          if data.slotkey == failOn then
            error("simulated draw failure")
          end
          return original(self, c, data)
        end)
      end)

      it("a wipe releases every button, including those left in sections the failed pass did not reach", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Armor") }, {}), function() end)
        local weaponsButton = itemFrame.buttonsBySlotkey["0_1"]
        local armorButton = itemFrame.buttonsBySlotkey["0_2"]

        -- Armor is gone this pass; the pass fails before its sweep, leaving the Armor
        -- section (still holding 0_2) set aside.
        failOn = "0_1"
        assert.has_error(function()
          bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
        end)
        failOn = nil

        bag:Wipe(context:New("wipe"))
        for _, button in ipairs({ weaponsButton, armorButton }) do
          assert.is_false(button.frame:IsShown(), button.slotkey)
          assert.is_nil(button.frame:GetParent(), button.slotkey)
        end
      end)

      it("a wipe releases a button the previous pass drew outside any view", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items") }, {}), function() end)
        local recent = itemFrame.buttonsBySlotkey["0_2"]

        -- No recent items this pass, so the Recent Items section is released (without its
        -- button), and the pass then fails in the tab view before its sweep.
        failOn = "0_1"
        assert.has_error(function()
          bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
        end)
        failOn = nil

        bag:Wipe(context:New("wipe"))
        assert.is_false(recent.frame:IsShown())
        assert.is_nil(recent.frame:GetParent())
      end)

      it("a wipe tears down a tab whose first render failed", function()
        local active = 1
        local database = addon:GetModule("Database")
        override(database, "GetGroupsEnabled", function() return true end)
        override(database, "GetActiveGroup", function() return active end)
        local function info()
          local weapons, armor = itemAt(0, 1, "Weapons"), itemAt(0, 2, "Armor")
          return {
            totalItems = 2,
            sectionLayouts = {},
            GetVisibleItems = function() return { ["0_1"] = weapons, ["0_2"] = armor } end,
            tabs = {
              [1] = { items = { weapons }, categories = { { name = "Weapons" } }, totalItems = 1, freeSpace = { buttons = {} } },
              [2] = { items = { armor }, categories = { { name = "Armor" } }, totalItems = 1, freeSpace = { buttons = {} } },
            },
          }
        end
        local bag = newBag()
        bag:Draw(context:New("tab1"), info(), function() end)

        active = 2
        failOn = "0_2"
        assert.has_error(function()
          bag:Draw(context:New("tab2"), info(), function() end)
        end)
        failOn = nil
        local tab2 = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_2"]
        assert.is_not_nil(next(tab2.sections))

        bag:Wipe(context:New("wipe"))
        assert.is_nil(next(tab2.sections))
        assert.is_false(tab2.rendering)
      end)

      it("a wipe releases a button claimed by a pass that failed while drawing it", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)

        failOn = "0_2"
        assert.has_error(function()
          bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons"), itemAt(0, 2, "Weapons") }, {}), function() end)
        end)
        failOn = nil
        local claimedOnly = itemFrame.buttonsBySlotkey["0_2"]

        bag:Wipe(context:New("wipe"))
        assert.is_true(claimedOnly.released)
        assert.is_false(claimedOnly.frame:IsShown())
      end)

      it("the next pass releases a button only the failed pass drew", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)

        failOn = "0_3"
        assert.has_error(function()
          bag:Draw(context:New("draw2"), slotInfoWith(
            { itemAt(0, 1, "Weapons"), itemAt(0, 2, "Armor"), itemAt(0, 3, "Weapons") }, {}), function() end)
        end)
        failOn = nil
        local drawnByFailedPass = itemFrame.buttonsBySlotkey["0_2"]
        assert.is_true(drawnByFailedPass.frame:IsShown())

        bag:Draw(context:New("draw3"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
        assert.is_false(drawnByFailedPass.frame:IsShown())
        assert.is_true(itemFrame.buttonsBySlotkey["0_1"].frame:IsShown())
      end)
    end)

    it("fully redraws only the button whose item changed (using a potion)", function()
      local function potion(count)
        return MockData.ItemData({ bagid = 0, slotid = 1, slotkey = "0_1", category = "Consumables",
          quality = 1, itemID = 1001, name = "Potion", count = count })
      end
      local function info(count)
        return slotInfoWith({ potion(count), itemAt(0, 2, "Weapons"), itemAt(0, 3, "Recent Items") },
          { freeSpaceButton(0, 4, 3) })
      end
      local bag = newBag()
      bag:Draw(context:New("draw1"), info(5), function() end)

      local full = {}
      for _, key in ipairs({ "0_1", "0_2", "0_3", "0_4" }) do
        local decoration = itemFrame.buttonsBySlotkey[key]._decoration
        decoration.SetReadable = function() full[key] = (full[key] or 0) + 1 end
        decoration.UpdateQuestItem = function() full[key] = (full[key] or 0) + 1 end
      end

      bag:Draw(context:New("draw2"), info(4), function() end)
      assert.are.same({ ["0_1"] = 2 }, full, "the potion's item draw calls both setters; nothing else redraws")
      for _, key in ipairs({ "0_1", "0_2", "0_3", "0_4" }) do
        assert.is_true(itemFrame.buttonsBySlotkey[key].frame:IsShown(), key)
      end
      assert.are.equal(4, itemFrame.buttonsBySlotkey["0_1"].currentData.itemInfo.currentItemCount)
    end)

    it("re-enables a button drawn as an item after it was a zero-count free slot", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({}, { freeSpaceButton(0, 1, 0) }), function() end)
      local button = itemFrame.buttonsBySlotkey["0_1"]
      assert.is_false(button.button:IsEnabled())

      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      assert.is_true(button.button:IsEnabled())
      assert.is_false(button.isFreeSlot or false)
    end)

    describe("free slots drawn without a count", function()
      local counts

      local function showAllInfo(allItems, freeButtons)
        local info = slotInfoWith(allItems, freeButtons)
        info.tabs[1].freeSpace.showAll = true
        return info
      end

      local function lastCount(button)
        local entry = counts[button._decoration]
        return entry and entry.count, entry and entry.minDisplayCount
      end

      before_each(function()
        counts = {}
        _G.SetItemButtonCount = function(decoration, count)
          counts[decoration] = { count = count, minDisplayCount = decoration.minDisplayCount }
        end
      end)

      it("clears the count an item left on the button", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({ MockData.ItemData({
          bagid = 0, slotid = 1, slotkey = "0_1", category = "Weapons", quality = 2, itemID = 1001,
          name = "Stack", stackedCount = 20,
        }) }, {}), function() end)
        local button = itemFrame.buttonsBySlotkey["0_1"]
        assert.are.equal(20, (lastCount(button)))

        bag:Draw(context:New("draw2"), showAllInfo({}, { freeSpaceButton(0, 1, 1) }), function() end)
        local count, minDisplayCount = lastCount(button)
        assert.are.equal(0, count)
        assert.are.equal(1, minDisplayCount, "0 must not exceed the minimum, so the count stays hidden")
      end)

      it("clears the count a counted free slot left on the button", function()
        local bag = newBag()
        bag:Draw(context:New("draw1"), slotInfoWith({}, { freeSpaceButton(0, 1, 5) }), function() end)
        local button = itemFrame.buttonsBySlotkey["0_1"]
        assert.are.equal(5, (lastCount(button)))

        bag:Draw(context:New("draw2"), showAllInfo({}, { freeSpaceButton(0, 1, 1) }), function() end)
        local count, minDisplayCount = lastCount(button)
        assert.are.equal(0, count)
        assert.are.equal(1, minDisplayCount)
      end)
    end)
  end)

  -- Regression: the Recent Items global section was built by iterating
  -- GetVisibleItems() (a hash map) via pairs(), so it rendered in arbitrary Lua
  -- hash-iteration order and could never show the persistent gaps that
  -- BuildOrderedItems computes into slotInfo.sortedItems. Users saw Recent Items in
  -- a "random" order that re-shuffled on every loot/consume, and consuming an item
  -- collapsed its slot instead of leaving a gap. The section must instead be built
  -- from the ordered, gap-carrying slotInfo.sortedItems.
  local function recentOrder(section)
    local order = {}
    for _, cell in ipairs(section.content.cells) do
      if cell.isGap then
        table.insert(order, "gap")
      else
        table.insert(order, cell.slotkey)
      end
    end
    return order
  end

  it("renders Recent Items in slotInfo.sortedItems order, not hash-iteration order", function()
    local bag = newBag()
    -- A deterministic layout order the pairs() scan is not guaranteed to reproduce.
    local sorted = {
      itemAt(0, 5, "Recent Items"),
      itemAt(0, 2, "Recent Items"),
      itemAt(0, 8, "Recent Items"),
      itemAt(0, 1, "Recent Items"),
    }
    bag:Draw(context:New("draw1"), slotInfoOrdered(sorted), function() end)

    local section = bag.globalSections["Recent Items"]
    assert.is_not_nil(section)
    assert.same({ "0_5", "0_2", "0_8", "0_1" }, recentOrder(section))
  end)

  it("preserves a consumed Recent Items slot as an in-place gap in the header section", function()
    local bag = newBag()
    -- 0_2 was consumed; BuildOrderedItems holds its position as a gap between 0_1 and 0_3.
    local sorted = {
      itemAt(0, 1, "Recent Items"),
      recentGap("0_2"),
      itemAt(0, 3, "Recent Items"),
    }
    bag:Draw(context:New("draw1"), slotInfoOrdered(sorted), function() end)

    local section = bag.globalSections["Recent Items"]
    assert.is_not_nil(section)
    assert.same({ "0_1", "gap", "0_3" }, recentOrder(section))
  end)

  -- OnCooldown applies a button's cooldown when the client reports a different one than
  -- the button last applied (frames/item.lua UpdateCooldown); these set one per slot.
  describe("cooldown refresh (OnCooldown)", function()
    after_each(function()
      _G._containerCooldowns = {}
    end)

    local function startCooldowns(slotkeys)
      for _, key in ipairs(slotkeys) do
        _G._containerCooldowns[key] = { 100, 30, 1 }
      end
    end

    local function spyCooldowns(slotkeys)
      local calls = {}
      for _, key in ipairs(slotkeys) do
        local button = itemFrame.buttonsBySlotkey[key]
        button._decoration.UpdateCooldown = function()
          calls[key] = (calls[key] or 0) + 1
        end
      end
      return calls
    end

    it("refreshes Recent Items buttons as well as tab view buttons", function()
      local bag = newBag()
      bag:Draw(context:New("draw"), slotInfoWith(
        { itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items") }, {}), function() end)
      local calls = spyCooldowns({ "0_1", "0_2" })
      startCooldowns({ "0_1", "0_2" })

      bag:OnCooldown(context:New("cooldown"))

      assert.are.equal(1, calls["0_1"])
      assert.are.equal(1, calls["0_2"], "Recent Items buttons live outside the tab view and must refresh too")
    end)

    -- The call trace records return values (data-driven.md): each refresh says how many
    -- buttons it checked and how many it applied Blizzard's update to.
    it("returns how many buttons it checked and how many it updated", function()
      local bag = newBag()
      bag:Draw(context:New("draw"), slotInfoWith(
        { itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items"), itemAt(0, 3, "Weapons") }, {}), function() end)
      spyCooldowns({ "0_1", "0_2", "0_3" })
      startCooldowns({ "0_1", "0_2" })
      assert.are.same({ 3, 2 }, { bag:OnCooldown(context:New("cooldown")) })
      assert.are.same({ 3, 0 }, { bag:OnCooldown(context:New("cooldown")) })
      bag.frame:Hide()
      assert.are.same({ 0, 0 }, { bag:OnCooldown(context:New("cooldown")) })
    end)

    it("skips buttons whose cooldown is unchanged since it was applied", function()
      local bag = newBag()
      bag:Draw(context:New("draw"), slotInfoWith(
        { itemAt(0, 1, "Weapons"), itemAt(0, 2, "Recent Items") }, {}), function() end)
      local calls = spyCooldowns({ "0_1", "0_2" })
      startCooldowns({ "0_1" })

      bag:OnCooldown(context:New("cooldown"))
      bag:OnCooldown(context:New("cooldown"))

      assert.are.equal(1, calls["0_1"], "applied once, when it changed")
      assert.is_nil(calls["0_2"])
    end)

    it("skips Free Space buttons, even when they previously held an item", function()
      local bag = newBag()
      bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 2, 3) }), function() end)
      -- Slot 0_1 empties and its button becomes the Free Space representative.
      bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 2, "Weapons") }, { freeSpaceButton(0, 1, 3) }), function() end)
      local calls = spyCooldowns({ "0_1", "0_2" })
      startCooldowns({ "0_1", "0_2" })

      bag:OnCooldown(context:New("cooldown"))

      assert.is_nil(calls["0_1"])
      assert.are.equal(1, calls["0_2"])
    end)

    it("does nothing while the bag is hidden", function()
      local bag = newBag()
      bag:Draw(context:New("draw"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      local calls = spyCooldowns({ "0_1" })
      startCooldowns({ "0_1" })
      bag.frame:Hide()

      bag:OnCooldown(context:New("cooldown"))

      assert.is_nil(calls["0_1"])
    end)
  end)

  -- Recent Items only expire when the bag closes, and the refresh that applies the expiry
  -- (and collapses held gaps) runs while the bag is hidden, so nothing moves while it is open.
  -- Switching between the classic design and BetterBags Next without a reload (next.md §11): the
  -- design switched off hides at once and lets go of its buttons; switched back on, it catches up
  -- on what its handlers would have done while they were off.
  describe("switching designs (Deactivate, Activate)", function()
    local calls

    local function partsOn(bag)
      calls = {}
      bag.behavior.Resync = function(_, c) table.insert(calls, { "resync", c }) end
      bag.moneyFrame = { Update = function() table.insert(calls, { "money" }) end }
      bag.currencyIconGrid = { Update = function() table.insert(calls, { "currency" }) end }
      bag.slots = { Draw = function(_, c) table.insert(calls, { "slots", c }) end }
      bag.searchFrame = { Hide = function() table.insert(calls, { "overlay hidden" }) end }
      local anchorFrame = CreateFrame("Frame")
      anchorFrame:Show()
      bag.anchor = { frame = anchorFrame, Load = function() table.insert(calls, { "anchor loaded" }) end,
        Hide = function() error("hiding the anchor through Hide saves it hidden") end }
      bag.UpdateSearchShown = function() table.insert(calls, { "search shown" }) end
      return bag
    end

    it("says it is closing while its window fades out", function()
      local bag = newBag()
      assert.is_false(bag:IsClosing())
      bag.window.IsClosing = function() return true end
      assert.is_true(bag:IsClosing())
    end)

    it("hides at once and lets go of every button it drew, its overlay search and anchor hidden", function()
      local bag = partsOn(newBag())
      local released = {}
      local button = { Release = function() table.insert(released, "button") end }
      bag.drawnButtons = { [button] = true }
      bag:Deactivate(context:New("switch"))
      assert.is_false(bag.frame:IsShown())
      assert.is_false(bag.window:IsClosing(), "not through the fade")
      assert.are.same({ "button" }, released)
      assert.are.same({}, bag.drawnButtons)
      assert.are.same({ { "overlay hidden" } }, calls)
      assert.is_false(bag.anchor.frame:IsShown())
    end)

    it("catches up on its search box, behavior, money, currencies, slots panel and anchor", function()
      local bag = partsOn(newBag())
      bag.frame:Hide()
      local c = context:New("switch")
      bag:Activate(c)
      assert.are.same({ { "search shown" }, { "resync", c }, { "money" }, { "currency" }, { "slots", c },
        { "anchor loaded" } }, calls)
    end)

    it("catches up without the parts it does not have", function()
      local bag = newBag()
      bag.behavior.Resync = function() end
      bag.UpdateSearchShown = function() end
      assert.has_no.errors(function() bag:Activate(context:New("switch")) end)
      assert.has_no.errors(function() bag:Deactivate(context:New("switch")) end)
    end)
  end)

  describe("closing the bag (OnClosed)", function()
    local expireCalls, expireResult

    local function closedBag(kind)
      local bag = newBag()
      bag.kind = kind or const.BAG_KIND.BACKPACK
      bag.refreshes = 0
      bag.behavior.OnRefresh = function() bag.refreshes = bag.refreshes + 1 end
      bag.frame:Hide()
      return bag
    end

    before_each(function()
      expireCalls, expireResult = {}, false
      override(addon:GetModule("Items"), "ExpireRecentItems", function(_, kind)
        table.insert(expireCalls, kind)
        return expireResult
      end)
    end)

    it("expires its kind's Recent Items and refreshes once while hidden when something expired", function()
      expireResult = true
      local bag = closedBag()

      bag:OnClosed(context:New("close"))

      assert.same({ const.BAG_KIND.BACKPACK }, expireCalls)
      assert.are.equal(1, bag.refreshes)
    end)

    it("refreshes once for held gaps when nothing expired, and clears the flag", function()
      local bag = closedBag()
      bag.drawOnClose = true

      bag:OnClosed(context:New("close"))

      assert.are.equal(1, bag.refreshes)
      assert.is_false(bag.drawOnClose)
    end)

    it("refreshes once when something expired and gaps are held", function()
      expireResult = true
      local bag = closedBag()
      bag.drawOnClose = true

      bag:OnClosed(context:New("close"))

      assert.are.equal(1, bag.refreshes)
    end)

    it("does not refresh when nothing expired and no gaps are held", function()
      local bag = closedBag()

      bag:OnClosed(context:New("close"))

      assert.same({ const.BAG_KIND.BACKPACK }, expireCalls)
      assert.are.equal(0, bag.refreshes)
    end)

    it("does nothing while the frame is still shown (hidden only with its parent, e.g. Alt+Z)", function()
      expireResult = true
      local bag = closedBag()
      bag.drawOnClose = true
      bag.frame:Show()

      bag:OnClosed(context:New("close"))

      assert.same({}, expireCalls)
      assert.are.equal(0, bag.refreshes)
      assert.is_true(bag.drawOnClose)
    end)

    it("expires the bank's Recent Items when the bank closes", function()
      local bag = closedBag(const.BAG_KIND.BANK)

      bag:OnClosed(context:New("close"))

      assert.same({ const.BAG_KIND.BANK }, expireCalls)
    end)

    it("WatchForClose runs OnClosed from the frame's own OnHide, which every close path fires (ESC included)", function()
      expireResult = true
      local bag = closedBag()

      bag:WatchForClose()
      local onHide = bag.frame:GetScript("OnHide")
      assert.is_function(onHide)
      onHide(bag.frame)

      assert.are.equal(1, bag.refreshes)
    end)

    it("bagFrame:Create watches every bag for close", function()
      local source = assert(io.open("frames/bag.lua", "r")):read("*a")
      local create = source:match("function bagFrame:Create%(ctx, kind%)(.-)\nend\n")
      assert.is_not_nil(create)
      assert.is_not_nil(create:find("b:WatchForClose()", 1, true))
    end)
  end)

  -- Showing a bag draws what was deferred while it was hidden, and says so, so the bank's
  -- refresh handler does not draw the same data a second time (a captured bank open drew the
  -- bank twice in one frame).
  describe("showing a bag (Show)", function()
    it("draws a deferred draw with the data it is given, and reports that it drew", function()
      local bag = newBag()
      bag.frame:Hide()
      local old = slotInfoWith({ itemAt(0, 1, "Weapons") }, {})
      bag:Draw(context:New("hidden"), old, function() end)
      assert.is_true(bag.drawPendingOnShow)
      local drawnWith
      local draw = bag.Draw
      bag.Draw = function(self, ctx, slotInfo, cb)
        drawnWith = slotInfo
        bag.frame:Show()
        return draw(self, ctx, slotInfo, cb)
      end
      local current = slotInfoWith({ itemAt(0, 2, "Armor") }, {})
      assert.is_true(bag:Show(context:New("show"), current))
      assert.equal(current, drawnWith)
    end)

    it("reports that it did not draw when nothing was deferred", function()
      local bag = newBag()
      bag.frame:Hide()
      local drew = false
      bag.Draw = function() drew = true end
      assert.is_false(bag:Show(context:New("show"), slotInfoWith({}, {})))
      assert.is_false(drew)
    end)

    -- The bank is loaded once its window has finished showing (refresh-scheduler.md §11).
    it("hands its behavior what to call once the window has finished showing", function()
      local bag = newBag()
      bag.frame:Hide()
      local given
      bag.behavior.OnShow = function(_, _, onShown) given = onShown end
      local onShown = function() end
      bag:Show(context:New("show"), nil, onShown)
      assert.equal(onShown, given)
    end)

    it("calls back at once when it is already open, without showing again", function()
      local bag = newBag()
      local showings, called = 0, 0
      bag.behavior.OnShow = function() showings = showings + 1 end
      bag:Show(context:New("show"), nil, function() called = called + 1 end)
      assert.equal(0, showings)
      assert.equal(1, called)
    end)

    -- The window calls back at once when it is shown, or when a fade in still playing ends
    -- (window.md §4, spec/window/window_spec.lua).
    it("leaves an open bag's callback to its window, which knows whether it is still fading in", function()
      local bag = newBag()
      local given
      bag.window.Show = function(_, _, onShown) given = onShown end
      local onShown = function() end
      bag:Show(context:New("show"), nil, onShown)
      assert.equal(onShown, given)
    end)
  end)

  -- Asked: the classic bank waits for its window to finish showing before it is read, "can we add
  -- a loading text on the classic bags maybe? just so it's not blank blank" (refresh-scheduler.md
  -- §11). A bag says Loading... while what it shows has never been read: data without tabs, or
  -- nothing drawn (before its first draw, or once its drawing was torn down, as the bank's is when
  -- it closes).
  describe("the loading text", function()
    -- What items:NewSlotInfo gives before a read (data/slots.lua): no tabs.
    local neverRead = { itemsBySlotKey = {}, visibleItemsBySlotKey = {}, emptySlots = {}, totalItems = 0,
      GetVisibleItems = function(self) return self.visibleItemsBySlotKey end }

    it("says Loading... in the middle of the bag, above its content, before anything is drawn", function()
      local bag = newBag()
      local text = bag.loadingText
      assert.equal("Loading...", text:GetText())
      assert.is_true(text:IsShown())
      local holder = text:GetParent()
      assert.are.same({ "CENTER", bag.scrollBox, "CENTER", 0, 0 }, { holder:GetPoint(1) })
      assert.is_true(holder:GetFrameLevel() > bag.scrollBox:GetFrameLevel())
      assert.equal(addon:GetModule("Sonata"):GetTextFont("Empty"), text:GetFontObject())
    end)

    it("hides once a read is drawn, and says it again for data never read", function()
      local bag = newBag()
      bag:Draw(context:New("read"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      assert.is_false(bag.loadingText:IsShown())
      bag:Draw(context:New("never read"), neverRead, function() end)
      assert.is_true(bag.loadingText:IsShown())
    end)

    it("says it again once its drawing is torn down (the bank closing)", function()
      local bag = newBag()
      bag:Draw(context:New("read"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      bag:Wipe(context:New("wipe"))
      assert.is_true(bag.loadingText:IsShown())
    end)

    it("leaves a draw deferred while hidden to the draw that shows it", function()
      local bag = newBag()
      bag.frame:Hide()
      bag:Draw(context:New("hidden"), slotInfoWith({ itemAt(0, 1, "Weapons") }, {}), function() end)
      assert.is_true(bag.loadingText:IsShown(), "nothing drawn yet")
    end)

    -- The retail bank's Purchase Bank button sits in the same place (bags/bank.lua).
    it("gives way to the Purchase Bank button", function()
      local bag = newBag()
      local button = CreateFrame("Button", nil, bag.frame)
      bag.purchaseBankButton = button
      button:Show()
      bag:UpdateLoadingText()
      assert.is_false(bag.loadingText:IsShown())
      button:Hide()
      bag:UpdateLoadingText()
      assert.is_true(bag.loadingText:IsShown())
    end)
  end)

  -- Issue #408: an item dropped anywhere on a bag window, or the window clicked while holding
  -- one, goes into a free slot of that window's bags (util/cursorplacement.lua).
  describe("the window as a drop target (WatchMouse)", function()
    local function watchedBag(kind, bankTab)
      local bag = newBag()
      bag.kind = kind or const.BAG_KIND.BACKPACK
      bag.bankTab = bankTab
      bag.frame.GetBottom = function() return 100 end
      bag.frame:SetMovable(true)
      bag:WatchMouse()
      return bag
    end

    local function holdItem()
      _G._cursorHasItem = true
      _G._cursorType = "item"
      _G._cursorItemID = 1001
    end

    after_each(function()
      _G.ClearCursor()
      _G._isShiftKeyDown = false
    end)

    it("places an item dropped on the window, in the bank's shown tab", function()
      local bag = watchedBag(const.BAG_KIND.BANK, 12)
      holdItem()
      bag.frame:GetScript("OnReceiveDrag")(bag.frame)
      assert.are.same({ { kind = const.BAG_KIND.BANK, bankTab = 12 } }, placements)
    end)

    it("places on a left click, and only on a left click", function()
      local bag = watchedBag()
      holdItem()
      local onMouseUp = bag.frame:GetScript("OnMouseUp")
      onMouseUp(bag.frame, "RightButton")
      assert.are.same({}, placements)
      onMouseUp(bag.frame, "LeftButton")
      assert.are.same({ { kind = const.BAG_KIND.BACKPACK } }, placements)
    end)

    it("never moves the window while an item is on the cursor", function()
      local bag = watchedBag()
      holdItem()
      bag.frame:GetScript("OnDragStart")(bag.frame)
      bag.frame:GetScript("OnDragStop")(bag.frame)
      assert.is_falsy(bag.frame._moving)
      assert.are.same({}, savedPositions)
    end)

    it("still moves the window, and saves where it was left, with nothing on the cursor", function()
      local bag = watchedBag()
      bag.frame:_SetRect(100, 100, 300, 300)
      bag.frame:GetScript("OnDragStart")(bag.frame)
      assert.is_true(bag.frame._moving)
      bag.frame:GetScript("OnDragStop")(bag.frame)
      assert.is_false(bag.frame._moving)
      assert.are.same({ bag.frame }, savedPositions)
    end)

    it("bagFrame:Create wires the window's mouse through WatchMouse", function()
      local source = assert(io.open("frames/bag.lua", "r")):read("*a")
      local create = source:match("function bagFrame:Create%(ctx, kind%)(.-)\nend\n")
      assert.is_not_nil(create)
      assert.is_not_nil(create:find("b:WatchMouse()", 1, true))
      assert.is_nil(create:find('SetScript("OnDragStart"', 1, true))
    end)

    it("places an item dropped on a section title without Shift in the title's window", function()
      local sectionFrame = addon:GetModule("SectionFrame")
      local bag = watchedBag(const.BAG_KIND.BANK, 7)
      override(addon, "GetBagFromKind", function(_, kind)
        if kind == const.BAG_KIND.BANK then return bag end
        return nil
      end)
      local section = {
        GetKind = function() return const.BAG_KIND.BANK end,
        GetTitle = function() return "Armor" end,
      }
      holdItem()
      sectionFrame:OnTitleClickOrDrop(context:New("drop"), section)
      assert.are.same({ { kind = const.BAG_KIND.BANK, bankTab = 7 } }, placements)
    end)

    it("still adds the item to the title's category with Shift", function()
      local sectionFrame = addon:GetModule("SectionFrame")
      local added = {}
      override(addon:GetModule("Categories"), "AddPermanentItemToCategory", function(_, _, itemID, category)
        table.insert(added, { itemID = itemID, category = category })
      end)
      override(addon, "GetBagFromKind", function() return watchedBag() end)
      local section = {
        GetKind = function() return const.BAG_KIND.BACKPACK end,
        GetTitle = function() return "Armor" end,
      }
      holdItem()
      _G._isShiftKeyDown = true
      sectionFrame:OnTitleClickOrDrop(context:New("drop"), section)
      assert.are.same({ { itemID = 1001, category = "Armor" } }, added)
      assert.are.same({}, placements)
    end)
  end)

  describe("the bag's window (BuildWindow, BuildParts, PlaceParts)", function()
    local sizeInfo, sizeMode, view, frameSizes, inBagSearch, sent, placed

    before_each(function()
      sizeInfo = { itemsPerRow = 5, columnCount = 2, scale = 100, opacity = 89 }
      sizeMode, view, inBagSearch = "content", const.BAG_VIEW.SECTION_GRID, false
      frameSizes, sent, placed = {}, {}, {}
      local database = addon:GetModule("Database")
      override(database, "GetBagSizeInfo", function() return sizeInfo end)
      override(database, "GetBagView", function() return view end)
      override(database, "GetBagSizeMode", function() return sizeMode end)
      override(database, "GetInBagSearch", function() return inBagSearch end)
      override(database, "GetBagViewFrameSize", function() return 640, 480 end)
      override(database, "SetBagViewFrameSize", function(_, kind, v, w, h)
        table.insert(frameSizes, { kind, v, w, h })
      end)
      override(events, "SendMessage", function(_, _, message, payload)
        table.insert(sent, { message, payload })
      end)
      local searchBox = addon:GetModule("SearchBox")
      override(searchBox, "CreateBox", function(_, kind, parent)
        return { kind = kind, frame = CreateFrame("Frame", nil, parent) }
      end)
      local menuButton = addon:GetModule("BagMenuButton")
      override(menuButton, "Create", function(_, bag) return CreateFrame("Button", nil, bag.frame) end)
      override(menuButton, "Place", function(_, button, layout, frame, overlay)
        table.insert(placed, { button = button, layout = layout, frame = frame, overlay = overlay })
      end)
      local bagActions = addon:GetModule("BagActions")
      override(bagActions, "Create", function(_, bag) return { bag = bag, buttons = {} } end)
      override(bagActions, "Place", function(_, actions, layout, frame, overlay)
        table.insert(placed, { actions = actions, layout = layout, frame = frame, overlay = overlay })
      end)
    end)

    -- partsBag builds a bag with its window and parts, decorated with a theme whose bag
    -- window has insets and a layout like the Base theme's, and Base's text roles (a bag draws
    -- its Loading... text in one).
    local function partsBag()
      local sonata = addon:GetModule("Sonata")
      override(sonata, "themes", {})
      sonata:RegisterTheme({ Name = "Base", Hidden = true, Text = baseTextRoles.Text, Variables = baseTextRoles.Variables,
        Windows = { Bag = {
        Insets = { Left = 6, Right = 6, Top = 42, Bottom = 3 },
        Layout = {
          Search = { Points = { { Point = "TOPLEFT", X = 20, Y = -30 },
            { Point = "BOTTOMRIGHT", RelativePoint = "TOPRIGHT", X = -10, Y = -50 } }, Reserve = 20 },
          Footer = { Left = 6, Right = 6, Bottom = 6, Height = 20, Reserve = 26 },
          MenuButton = { Points = { { Point = "TOPLEFT", X = -10, Y = 7 } } },
          Actions = { Size = 32, Buttons = { { Action = "Sort" } } },
        },
      } } })
      sonata:RegisterTheme({ Name = "Default" })
      local bag = newBag()
      bag:BuildParts()
      sonata:ApplyTheme(context:New("spec"), "Default")
      return bag
    end

    -- Themes whose art reaches far below the window hang the tab bar below it
    -- (Layout.Tabs.Offset: where the bar's top left sits from the bag's bottom left).
    describe("the tab bar (PlaceTabs)", function()
      local function bagWithTabs(layout)
        local sonata = addon:GetModule("Sonata")
        override(sonata, "themes", {})
        sonata:RegisterTheme({ Name = "Base", Hidden = true, Text = baseTextRoles.Text, Variables = baseTextRoles.Variables })
        sonata:RegisterTheme({ Name = "Default", Windows = { Bag = { Layout = layout } } })
        local bag = newBag()
        bag:BuildParts()
        bag.tabs = { frame = CreateFrame("Frame", nil, bag.frame) }
        sonata:ApplyTheme(context:New("spec"), "Default")
        return bag
      end

      it("hangs it where the theme's Layout.Tabs says", function()
        local bag = bagWithTabs({ Tabs = { Offset = { X = 14, Y = -30 } } })
        local bar = bag.tabs.frame
        assert.are.equal(2, bar:GetNumPoints())
        assert.are.same({ "TOPLEFT", bag.frame, "BOTTOMLEFT", 14, -30 }, { bar:GetPoint(1) })
        assert.are.same({ "TOPRIGHT", bag.frame, "BOTTOMRIGHT", 14, -30 }, { bar:GetPoint(2) })
      end)

      it("hangs it 2 into the window when the theme says nothing", function()
        local bag = bagWithTabs({})
        assert.are.same({ "TOPLEFT", bag.frame, "BOTTOMLEFT", 0, 2 }, { bag.tabs.frame:GetPoint(1) })
        assert.are.same({ "TOPRIGHT", bag.frame, "BOTTOMRIGHT", 0, 2 }, { bag.tabs.frame:GetPoint(2) })
      end)

      it("does nothing for a bag without tabs", function()
        local bag = newBag()
        bag:BuildParts()
        assert.has_no.errors(function() bag:PlaceTabs() end)
      end)

      -- bagFrame:Create places them once the bag's behavior made them (PlacePartsIfDecorated,
      -- checked below): before any theme, only the tab bar.
      it("places the tab bar of a window not styled yet once its behavior made it", function()
        local bag = bagWithTabs(nil)
        bag.window.decoration = nil
        bag.tabs.frame:ClearAllPoints()
        bag:PlacePartsIfDecorated(context:New("spec"))
        assert.are.same({ "TOPLEFT", bag.frame, "BOTTOMLEFT", 0, 2 }, { bag.tabs.frame:GetPoint(1) })
      end)
    end)

    -- The window keeps every window on the screen (window.md); the bag no longer loosens the
    -- clamp to let all but 50 pixels of itself go off it.
    it("leaves keeping the window on the screen to the window, with nothing allowed off it", function()
      local bag = newBag()
      assert.is_nil(bag.KeepBagInBounds)
      for _, m in ipairs({ "window", "content" }) do
        sizeMode = m
        bag.frame:SetClampRectInsets(0, 0, 0, 0)
        bag:OnResize()
        assert.are.same({ 0, 0, 0, 0 }, bag.frame._clampRectInsets, m)
      end
    end)

    -- Its minimums read parts BuildWindow makes after the window (the scroll box), so creating
    -- the window must not ask for them, even for a bag the player sized.
    it("builds its window when the bag is sized by the player", function()
      sizeMode = "window"
      local bag
      assert.has_no.errors(function() bag = newBag() end)
      assert.is_not_nil(bag.scroll)
    end)

    it("is a Bag window named for its bag, laying out the bag's canvas in a scroll box", function()
      local bag = newBag()
      assert.are.equal("Bag", bag.window.kind)
      assert.are.equal(bag.window.frame, bag.frame)
      assert.is_truthy(bag.frame:GetName():find("^BetterBagsBag"))
      assert.are.equal(bag.scroll, bag.window:GetContent())
      assert.are.equal(bag.canvas, bag.scroll.child)
      assert.are.equal(bag.canvas.headerContainer, bag.headerContainer)
      assert.are.equal(bag.canvas.tabContainer, bag.tabContainer)
      assert.are.equal(bag.canvas.footerContainer, bag.footerContainer)
    end)

    it("reads its opacity, scale, size mode, saved size and fading from the bag's settings", function()
      local bag = newBag()
      sizeInfo.opacity, sizeInfo.scale, sizeMode = 40, 150, "window"
      assert.are.equal(40, bag.window:GetOpacity())
      bag.window:UpdateScale(true)
      assert.are.equal(1.5, bag.frame:GetScale())
      assert.are.equal("window", bag.window:GetSizeMode())
      assert.are.same({ 640, 480 }, { bag.window.opts.Size() })
      override(addon:GetModule("Database"), "GetEnableBagFading", function() return true end)
      assert.is_true(bag.window.opts.Fade())
    end)

    it("saves the size the player left it at for the view it shows", function()
      local bag = newBag()
      bag.window.opts.OnResized(context:New("spec"), 640, 480)
      assert.are.same({ { const.BAG_KIND.BACKPACK, const.BAG_VIEW.SECTION_GRID, 640, 480 } }, frameSizes)
    end)

    it("never makes its content narrower than its tabs or the minimum, plus the scroll bar's room on both sides", function()
      local bag = newBag()
      local room = 2 * bag.scroll:GetBarWidth()
      assert.are.equal(room, bag.scroll:GetGutterWidth())
      assert.are.equal(260 + room, bag.window.opts.MinContentWidth())
      bag.tabs = { width = 400 }
      assert.are.equal(400 + room, bag.window.opts.MinContentWidth())
      assert.are.equal(100, bag.window.opts.MinContentHeight)
    end)

    -- Its content is centered and never moves for the scroll bar: the bar's room is kept on both
    -- sides, and the bar shows only while it is used (window.md, centering).
    it("scrolls its canvas in a box with the bar's room on both sides and a bar that hides itself", function()
      local bag = newBag()
      assert.is_true(bag.scroll.symmetric)
      assert.is_not_nil(bag.scroll.barDriver)
      assert.are.equal(0, bag.scroll.scrollBar:GetAlpha())
    end)

    it("snaps to its content after a resize when the bag's setting says so", function()
      local bag = newBag()
      local snap = true
      override(addon:GetModule("Database"), "GetBagSnapToContent", function(_, kind)
        assert.are.equal(const.BAG_KIND.BACKPACK, kind)
        return snap
      end)
      assert.is_true(bag.window.opts.SnapToContent())
      snap = false
      assert.is_false(bag.window.opts.SnapToContent())
    end)

    -- One setting for every bag (Clamp Bags to Screen, window.md §3a).
    it("is clamped to the screen while the bags' setting says so", function()
      local bag = newBag()
      local clamp = false
      override(addon:GetModule("Database"), "GetClampBagsToScreen", function() return clamp end)
      assert.is_false(bag.window.opts.Clamp())
      clamp = true
      assert.is_true(bag.window.opts.Clamp())
    end)

    it("is at least as wide as its slots panel while that shows", function()
      local bag = newBag()
      local slotsFrame = CreateFrame("Frame")
      slotsFrame:SetWidth(500)
      local shown = false
      bag.slots = { frame = slotsFrame, IsShown = function() return shown end }
      assert.are.equal(0, bag.window.opts.MinWidth())
      shown = true
      assert.are.equal(500, bag.window.opts.MinWidth())
    end)

    -- New data in the sections: the canvas measures them again (frames/bagcanvas.lua).
    it("has its canvas forget its section measures on every draw, before laying out", function()
      local bag = newBag()
      local order = {}
      override(bag.canvas, "ForgetMeasures", function() table.insert(order, "forget") end)
      local render = addon:GetModule("Render")
      override(render, "RenderNow", function() table.insert(order, "render") end)
      bag:Draw(context:New("spec"), slotInfoWith({}, {}), function() end)
      assert.are.same({ "forget", "render" }, order)
    end)

    -- texture-sharpening.md: the client's sharpening drew each texture of a bag a fraction of a pixel differently from
    -- frame to frame while it was resized, though nothing moved; the classic bags too (asked: "literally all bags").
    it("draws its window's textures without the client's sharpening, after laying it out", function()
      local bag = newBag()
      local parts = { bag.frame:CreateTexture(), bag.window.content:CreateTexture(),
        CreateFrame("Frame", nil, bag.frame):CreateTexture() }
      for _, t in ipairs(parts) do
        t:SetSnapToPixelGrid(true)
        t:SetTexelSnappingBias(1)
      end
      bag:Draw(context:New("spec"), slotInfoWith({}, {}), function() end)
      for i, t in ipairs(parts) do
        assert.is_false(t:IsSnappingToPixelGrid(), "part " .. i)
        assert.are.equal(0, t:GetTexelSnappingBias(), "part " .. i)
      end
    end)

    it("asks its bag to close when its close button is clicked", function()
      local bag = newBag()
      local hidden
      bag.Hide = function(_, c) hidden = c end
      local c = context:New("spec")
      bag.window.opts.OnClose(c)
      assert.are.equal(c, hidden)
    end)

    it("applies the view's scale and opacity on every draw", function()
      local bag = newBag()
      local opacities = 0
      local updateOpacity = bag.window.UpdateOpacity
      bag.window.UpdateOpacity = function(w)
        opacities = opacities + 1
        return updateOpacity(w)
      end
      sizeInfo.scale = 120
      bag:Draw(context:New("spec"), slotInfoWith({}, {}), function() end)
      assert.are.equal(1.2, bag.frame:GetScale())
      assert.are.equal(1, opacities)
    end)

    it("applies the size mode on a draw only when it or the view changed", function()
      local bag = newBag()
      local applied = 0
      local updateSizeMode = bag.window.UpdateSizeMode
      bag.window.UpdateSizeMode = function(w)
        applied = applied + 1
        return updateSizeMode(w)
      end
      local data = slotInfoWith({}, {})
      bag:Draw(context:New("spec"), data, function() end)
      bag:Draw(context:New("spec"), data, function() end)
      assert.are.equal(1, applied)
      sizeMode = "window"
      bag:Draw(context:New("spec"), data, function() end)
      assert.are.equal(2, applied)
      assert.are.same({ 640, 480 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      bag.frame:SetSize(700, 500)
      bag:Draw(context:New("spec"), data, function() end)
      assert.are.same({ 700, 500 }, { bag.frame:GetWidth(), bag.frame:GetHeight() })
      view = const.BAG_VIEW.SECTION_ALL_BAGS
      bag:Draw(context:New("spec"), data, function() end)
      assert.are.equal(3, applied)
    end)

    it("puts the search box where the theme says, and reserves its room while in-bag search is on", function()
      inBagSearch = true
      local bag = partsBag()
      local box = bag.searchBox.frame
      assert.are.equal(const.BAG_KIND.BACKPACK, bag.searchBox.kind)
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 20, -30 }, { box:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "TOPRIGHT", -10, -50 }, { box:GetPoint(2) })
      assert.is_true(box:IsShown())
      assert.is_true(box:GetFrameLevel() > bag.window.decoration:GetOverlayFrame():GetFrameLevel())
      assert.are.same({ Left = 6, Right = 6, Top = 62, Bottom = 29 }, bag.window:GetContentInsets())

      inBagSearch = false
      bag:UpdateSearchShown()
      assert.is_false(box:IsShown())
      assert.are.same({ Left = 6, Right = 6, Top = 42, Bottom = 29 }, bag.window:GetContentInsets())
    end)

    it("recalculates the bags when in-bag search is turned on or off", function()
      local bag = partsBag()
      inBagSearch = true
      bag:SetSearchShown(context:New("spec"))
      assert.is_true(bag.searchBox.frame:IsShown())
      assert.are.same({ "bags/Rederive", { resetLayout = true, buttons = true, categoriesUnchanged = true } }, sent[#sent])
    end)

    -- A bag made after a theme was applied (the classic bags made the first time the bags switch
    -- from BetterBags Next, next.md §11) has its window styled as the window registers, before its
    -- parts are made: placing them must wait for them, then happen.
    it("places its parts once made when its window was styled before them", function()
      local sonata = addon:GetModule("Sonata")
      override(sonata, "themes", {})
      sonata:RegisterTheme({ Name = "Base", Hidden = true, Text = baseTextRoles.Text, Variables = baseTextRoles.Variables,
        Windows = { Bag = {
        Insets = { Left = 6, Right = 6, Top = 42, Bottom = 3 },
        Layout = {
          Search = { Points = { { Point = "TOPLEFT", X = 20, Y = -30 } }, Reserve = 20 },
          Footer = { Left = 6, Right = 6, Bottom = 6, Height = 20, Reserve = 26 },
          MenuButton = { Points = { { Point = "TOPLEFT", X = -10, Y = 7 } } },
        },
      } } })
      sonata:RegisterTheme({ Name = "Default" })
      sonata:ApplyTheme(context:New("spec"), "Default")
      local errors = {}
      override(_G, "geterrorhandler", function() return function(e) table.insert(errors, e) end end)
      inBagSearch = true
      local bag = newBag()
      assert.are.same({}, errors)
      assert.is_not_nil(bag.window.decoration)
      bag:BuildParts()
      bag:PlacePartsIfDecorated(context:New("spec"))
      assert.are.same({ "TOPLEFT", bag.frame, "TOPLEFT", 20, -30 }, { bag.searchBox.frame:GetPoint(1) })
      assert.is_true(bag.searchBox.frame:IsShown())
      assert.are.same({ "BOTTOMLEFT", bag.frame, "BOTTOMLEFT", 6, 6 }, { bag.bottomBar:GetPoint(1) })
      assert.are.equal(bag.menuButton, placed[#placed - 1].button or placed[#placed].button)
    end)

    it("bagFrame:Create places its parts once made, for a window styled before them", function()
      local source = assert(io.open("frames/bag.lua", "r")):read("*a")
      local create = source:match("function bagFrame:Create%(ctx, kind%)(.-)\nend\n")
      local made = create:find("b.behavior:OnCreate(ctx)", 1, true)
      local places = create:find("b:PlacePartsIfDecorated(ctx)", 1, true)
      assert.is_not_nil(places)
      assert.is_true(places > made)
    end)

    it("updates its hidden count with each draw", function()
      local bag = newBag()
      local slotInfo = slotInfoWith({ itemAt(0, 1, "Weapons") }, {})
      slotInfo.tabs[1].hiddenItems = 2
      bag:Draw(context:New("draw"), slotInfo, function() end)
      assert.is_true(bag.hiddenText:IsShown())
      assert.are.equal("2 hidden", bag.hiddenText:GetText())
      slotInfo.tabs[1].hiddenItems = 0
      bag:Draw(context:New("draw"), slotInfo, function() end)
      assert.is_false(bag.hiddenText:IsShown())
    end)

    -- Asked (issue #1222): the old hide confused players about where their items went.
    it("says in the footer how many items a hidden category keeps out of the tab shown", function()
      local bag = partsBag()
      assert.is_false(bag.hiddenText:IsShown())
      bag:ShowHiddenCount({ tabs = { [1] = { hiddenItems = 3 } } }, 1)
      assert.is_true(bag.hiddenText:IsShown())
      assert.are.equal("3 hidden", bag.hiddenText:GetText())
      bag:ShowHiddenCount({ tabs = { [1] = { hiddenItems = 3 }, [2] = { hiddenItems = 0 } } }, 2)
      assert.is_false(bag.hiddenText:IsShown())
      bag:ShowHiddenCount({}, 1)
      assert.is_false(bag.hiddenText:IsShown(), "data that was never read")
    end)

    it("puts the hidden count on the footer bar beside the money", function()
      local bag = partsBag()
      bag.moneyFrame = { frame = CreateFrame("Frame") }
      bag:PlaceParts(context:New("Test"), bag.window.decoration)
      local point, relativeTo, relativePoint = bag.hiddenText:GetPoint(1)
      assert.are.same({ "BOTTOMRIGHT", bag.moneyFrame.frame, "BOTTOMLEFT" }, { point, relativeTo, relativePoint })
      bag.moneyFrame = nil
      bag:PlaceParts(context:New("Test"), bag.window.decoration)
      local _, relative2, relativePoint2 = bag.hiddenText:GetPoint(1)
      assert.are.same({ bag.bottomBar, "BOTTOMRIGHT" }, { relative2, relativePoint2 }, "a bag with no money")
    end)

    it("puts the footer bar along the bottom and the menu button where the theme says", function()
      local bag = partsBag()
      assert.are.same({ "BOTTOMLEFT", bag.frame, "BOTTOMLEFT", 6, 6 }, { bag.bottomBar:GetPoint(1) })
      assert.are.same({ "BOTTOMRIGHT", bag.frame, "BOTTOMRIGHT", -6, 6 }, { bag.bottomBar:GetPoint(2) })
      assert.are.equal(20, bag.bottomBar:GetHeight())
      local menu, actions
      for _, entry in ipairs(placed) do
        if entry.button == bag.menuButton then menu = entry end
        if entry.actions ~= nil and entry.actions == bag.actions then actions = entry end
      end
      assert.are.same({ { Point = "TOPLEFT", X = -10, Y = 7 } }, menu.layout.Points)
      assert.are.equal(bag.frame, menu.frame)
      assert.are.equal(bag.window.decoration:GetOverlayFrame(), menu.overlay)
      -- The theme's action buttons go where its layout says, on the bag's frame.
      assert.are.equal(bag, bag.actions.bag)
      assert.are.same({ Size = 32, Buttons = { { Action = "Sort" } } }, actions.layout)
      assert.are.equal(bag.frame, actions.frame)
      assert.are.equal(bag.window.decoration:GetOverlayFrame(), actions.overlay)
    end)

    it("keeps its bottom edge, or follows its anchor, when sized to its content", function()
      local bag = newBag()
      bag.OnResize = nil
      local anchorFrame = CreateFrame("Frame")
      bag.anchor = { IsActive = function() return true end, anchorPoint = "BOTTOMRIGHT", frame = anchorFrame }
      bag:OnResize()
      assert.are.same({ "BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0 }, { bag.frame:GetPoint(1) })
    end)

    it("stays where the player put it when the player sizes it", function()
      local bag = newBag()
      bag.OnResize = nil
      sizeMode = "window"
      bag.frame:ClearAllPoints()
      bag.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
      bag.anchor = { IsActive = function() return true end, anchorPoint = "BOTTOMRIGHT", frame = CreateFrame("Frame") }
      bag:OnResize()
      assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", 100, -100 }, { bag.frame:GetPoint(1) })
    end)
  end)
end)
