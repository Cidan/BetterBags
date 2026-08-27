-- bag_draw_ownership_spec.lua -- Every physical slot maps to exactly one static item
-- button (itemFrame.buttonsBySlotkey) that is shared by the bag's global sections
-- (Recent Items / Free Space) and by every tab view. A single bagProto:Draw pass must
-- release every previous owner of a button BEFORE any renderer acquires it. If a
-- renderer that runs later in the pass wipes a button that an earlier renderer just
-- claimed, the button is hidden and unparented and simply vanishes from the UI.
--
-- These specs run the real ItemFrame, SectionFrame, Views and BagFrame modules so
-- that button identity and section cell release behave exactly as in the client.

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

local function stubModules()
  local L = stubModule("Localization")
  override(L, "G", function(_, key) return key end)

  local debug = stubModule("Debug")
  override(debug, "Log", function() end)
  override(debug, "StartProfile", function() end)
  override(debug, "EndProfile", function() end)
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
  override(database, "GetExtraGlowyButtons", function() return false end)
  override(database, "ToggleSectionCollapsed", function() end)
  override(database, "GetUpgradeIconProvider", function() return "None" end)

  local color = stubModule("Color")
  override(color, "GetItemLevelColor", function() return 1, 1, 1 end)

  local items = stubModule("Items")
  override(items, "GetSlotKeyFromBagAndSlot", function(_, bagid, slotid) return bagid .. "_" .. slotid end)
  override(items, "GetStackData", function() return nil end)
  override(items, "IsNewItem", function() return false end)
  override(items, "GetItemDataFromSlotKey", function() return nil end)
  override(items, "GetAllSlotInfo", function() return {} end)

  local themes = stubModule("Themes")
  override(themes, "GetItemButton", function(_, _, item)
    if not item._decoration then
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
      item._decoration = d
    end
    return item._decoration
  end)
  override(themes, "UpdateSectionFont", function() end)
  override(themes, "RegisterSectionFont", function() end)
  override(themes, "RegisterPortraitWindow", function() end)
  override(themes, "SetSearchState", function() end)
  override(themes, "GetTabButton", function() return {} end)

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

  local contextMenu = stubModule("ContextMenu")
  override(contextMenu, "CreateContextMenu", function() return {} end)
  stubModule("Resize")
  stubModule("Question")
  stubModule("WindowGroup")
  stubModule("Anchor")
  stubModule("BackpackBehavior")
  stubModule("BankBehavior")
end

local function loadRealModules()
  ResetModuleStub("ItemFrame", "frames/item.lua")
  LoadBetterBagsModule("frames/item.lua")
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
  ResetModuleStub("Views", "views/views.lua")
  ResetModuleStub("GridViewDummy", "views/gridview.lua")
  ResetModuleStub("BagViewDummy", "views/bagview.lua")
  ResetModuleStub("SectionFrame", "frames/section.lua")
  ResetModuleStub("ItemFrame", "frames/item.lua")
end

-- Builds a Bag object on top of the real bagProto with the frame hierarchy that
-- bagFrame:Create() would normally wire up.
local function newBag()
  local bagProto = addon:GetModule("BagFrame").bagProto
  local frame = CreateFrame("Frame", "BetterBagsOwnershipTestBag")
  frame.SetScale = function() end
  local scrollChild = CreateFrame("Frame", nil, frame)
  local bag = {
    kind = const.BAG_KIND.BACKPACK,
    frame = frame,
    tabViews = {},
    itemFrames = {},
    globalSections = {},
    scrollChild = scrollChild,
    headerContainer = CreateFrame("Frame", nil, scrollChild),
    tabContainer = CreateFrame("Frame", nil, scrollChild),
    footerContainer = CreateFrame("Frame", nil, scrollChild),
    OnResize = function() end,
    behavior = { OnShow = function() end },
  }
  return setmetatable(bag, { __index = bagProto })
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

  it("releases every previous button owner before any renderer acquires a button", function()
    local bag = newBag()
    bag:Draw(context:New("draw1"), slotInfoWith({ itemAt(0, 1, "Weapons") }, { freeSpaceButton(0, 2, 3) }), function() end)

    local view = bag.tabViews[const.BAG_VIEW.SECTION_GRID .. "_1"]
    assert.is_not_nil(view)

    -- Record every button release and acquisition during the second draw.
    local log = {}
    local originalRelease = itemFrame.itemProto.Release
    itemFrame.itemProto.Release = function(self, ctx)
      table.insert(log, "release:" .. tostring(self.slotkey))
      return originalRelease(self, ctx)
    end
    local originalGetButton = itemFrame.GetButton
    itemFrame.GetButton = function(self, ctx, slotkey)
      table.insert(log, "acquire:" .. slotkey)
      return originalGetButton(self, ctx, slotkey)
    end

    bag:Draw(context:New("draw2"), slotInfoWith({ itemAt(0, 2, "Weapons") }, { freeSpaceButton(0, 1, 3) }), function() end)
    itemFrame.itemProto.Release = originalRelease
    itemFrame.GetButton = originalGetButton

    local firstAcquire
    local lastRelease
    for i, entry in ipairs(log) do
      if not firstAcquire and entry:match("^acquire:") then
        firstAcquire = i
      end
      if entry:match("^release:") then
        lastRelease = i
      end
    end
    assert.is_not_nil(firstAcquire, "expected at least one button acquisition")
    assert.is_not_nil(lastRelease, "expected the previous draw's buttons to be released")
    assert.is_true(lastRelease < firstAcquire,
      "every button release must precede the first button acquisition, got: " .. table.concat(log, ", "))
  end)
end)
