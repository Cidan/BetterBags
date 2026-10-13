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

  -- Claim, then sweep. A draw pass releases nothing up front: every renderer claims the
  -- buttons and sections it draws, and only what the previous pass drew and nobody
  -- claimed is released, after every renderer has run. A button drawn in consecutive
  -- passes is never hidden or unparented in between, so Blizzard's OnHide/OnShow
  -- handlers on the item button template do not run on every redraw.
  describe("claim, then sweep", function()
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
end)
