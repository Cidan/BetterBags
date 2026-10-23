-- motion_layout_spec.lua -- Motion through real sections in a real grid, arranged the way a view
-- arranges them (views/views.lua Arrange: every section's items, then the sections): only what
-- changed place moves, a section moves with its items still in it, items move in a section that
-- stays, and an item that changes section starts where it was on screen (render-pipeline.md,
-- motion).
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")
addon:GetModule("Events"):Init()

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local const = trackStub("Constants")
const.GRID_COMPACT_STYLE = const.GRID_COMPACT_STYLE or { NONE = 0 }
const.BAG_VIEW = const.BAG_VIEW or { SECTION_GRID = 1 }
const.BAG_KIND = const.BAG_KIND or { BACKPACK = 1, BANK = 2 }
const.MOVEMENT_FLOW = const.MOVEMENT_FLOW or { UNDEFINED = 0 }
trackStub("Debug").Log = function() end
trackStub("Categories").GetGroupForCategory = function() return nil end
local sort = trackStub("Sort")
sort.GetItemSortBySlot = function() end
sort.GetItemSortFunction = function() end
local database = trackStub("Database")
local originalFullNames = database.GetShowFullSectionNames
database.GetShowFullSectionNames = function() return false end
local sonata = trackStub("Sonata")
local originalRegister = rawget(sonata, "RegisterElement")
sonata.RegisterElement = function() end
local elements = trackStub("SonataElements")
local originalHeaderColor = rawget(elements, "GetSectionHeaderColor")
elements.GetSectionHeaderColor = function() return 1, 1, 1, 1 end
trackStub("Items")
trackStub("MovementFlow").GetMovementFlow = function() return 0 end
trackStub("Seller")
local groups = trackStub("Groups")
groups.GetGroupForCategory = function() return nil end
groups.IsDefaultGroup = function() return false end
trackStub("Localization").G = function(_, key) return key end

-- The scroll box a section's grid uses (frames/grid.lua CreateScrollFrame).
local originalLinearView, originalScrollUtil = _G.CreateScrollBoxLinearView, _G.ScrollUtil
_G.CreateScrollBoxLinearView = function() return { SetPanExtent = function() end } end
_G.ScrollUtil = { InitScrollBoxWithScrollBar = function() end }
local originalCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
  local frame = originalCreateFrame(...)
  frame.SetInterpolateScroll = frame.SetInterpolateScroll or function() end
  return frame
end

ResetModuleStub("Grid", "frames/grid.lua")
LoadBetterBagsModule("frames/grid.lua")
ResetModuleStub("SectionFrame", "frames/section.lua")
LoadBetterBagsModule("frames/section.lua")

local grid = addon:GetModule("Grid")
local sectionFrame = addon:GetModule("SectionFrame")
local motion = addon:GetModule("Motion")
local context = addon:GetModule("Context")

describe("Motion through sections in a grid", function()
  local root, view, weapons, armor, items, key

  local function item()
    local f = CreateFrame("Frame")
    f:SetSize(37, 37)
    return { frame = f }
  end

  -- arrange lays the sections out like a view: every section measured at perRow items per row,
  -- the sections placed in rows of rowLimit, then each section's items, all in one pass.
  local function arrange(perRow, rowLimit)
    motion:BeginPass(key)
    local measures = {}
    for _, section in ipairs(view.cells) do
      measures[section] = section:Measure(1, perRow[section] or 3)
    end
    view:Arrange(view:Measure({
      cells = view.cells,
      maxWidthPerRow = rowLimit,
      sizeOf = function(cell) return measures[cell].width, measures[cell].height end,
    }))
    for _, section in ipairs(view.cells) do
      section:Arrange(1, measures[section])
    end
    return motion:EndPass()
  end

  before_each(function()
    motion:Init()
    sectionFrame:Init()
    key = {}
    root = CreateFrame("Frame")
    view = grid:Create(root, false)
    view.frame:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    weapons = sectionFrame:Create(context:New("spec"))
    armor = sectionFrame:Create(context:New("spec"))
    items = { a = item(), b = item(), c = item(), d = item() }
    weapons:AddCell("a", items.a)
    weapons:AddCell("b", items.b)
    weapons:AddCell("c", items.c)
    armor:AddCell("d", items.d)
    view:AddCell("weapons", weapons)
    view:AddCell("armor", armor)
  end)

  teardown(function()
    _G.CreateFrame = originalCreateFrame
    _G.CreateScrollBoxLinearView, _G.ScrollUtil = originalLinearView, originalScrollUtil
    database.GetShowFullSectionNames = originalFullNames
    sonata.RegisterElement = originalRegister
    elements.GetSectionHeaderColor = originalHeaderColor
    ResetModuleStub("SectionFrame", "frames/section.lua")
    ResetModuleStub("Grid", "frames/grid.lua")
    for i = #createdStubs, 1, -1 do
      ResetModuleStub(createdStubs[i])
    end
  end)

  it("moves a section with its items still in it", function()
    arrange({}, 1000)
    assert.are.equal(1, arrange({}, 150))
    assert.are.same({ 135, 0, 0, -65 }, { motion:GetMove(armor.frame) })
    for _, frame in ipairs({ weapons.frame, items.a.frame, items.b.frame, items.c.frame, items.d.frame }) do
      assert.is_nil(motion:GetMove(frame))
    end
  end)

  it("moves items inside a section that stays where it is", function()
    arrange({}, 1000)
    arrange({ [weapons] = 2 }, 1000)
    assert.are.same({ 82, 0, 0, -41 }, { motion:GetMove(items.c.frame) })
    assert.is_nil(motion:GetMove(items.a.frame))
    assert.is_nil(motion:GetMove(items.b.frame))
    assert.is_nil(motion:GetMove(weapons.frame))
    assert.are.same({ 135, 0, 94, 0 }, { motion:GetMove(armor.frame) }, "the narrower section pulls the next one in")
  end)

  -- c is 88 in and 18 down from the view (Weapons at 0, its cells 6 in and a title down, c the third
  -- of them); Armor's cells start at 141, 18 when c lands in them, before Armor itself moves.
  it("carries an item to another section from where it was on screen", function()
    arrange({}, 1000)
    weapons:RemoveCell("c")
    armor:AddCell("c", items.c)
    arrange({}, 1000)
    assert.are.same({ -53, 0, 41, 0 }, { motion:GetMove(items.c.frame) })
    assert.are.same({ "TOPLEFT", armor.content.inner, "TOPLEFT", -53, 0 }, { items.c.frame:GetPoint(1) })
    assert.are.same({ 135, 0, 94, 0 }, { motion:GetMove(armor.frame) })
    assert.is_nil(motion:GetMove(items.d.frame))
  end)

  -- Tools appears at 147 (after Weapons, now 90 wide, and Armor) and is put there at once; c, 88 in
  -- and 18 down, travels from there into Tools' cells at 153, 18.
  it("carries an item into a section that just appeared, from where it was", function()
    arrange({}, 1000)
    local tools = sectionFrame:Create(context:New("spec"))
    weapons:RemoveCell("c")
    tools:AddCell("c", items.c)
    view:AddCell("tools", tools)
    arrange({}, 1000)
    assert.is_nil(motion:GetMove(tools.frame))
    assert.are.same({ "TOPLEFT", view.inner, "TOPLEFT", 147, 0 }, { tools.frame:GetPoint(1) })
    assert.are.same({ -65, 0, 0, 0 }, { motion:GetMove(items.c.frame) })
  end)
end)
