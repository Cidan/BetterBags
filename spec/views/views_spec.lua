local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local context = addon:GetModule("Context")
local ctx = context:New("ViewsSpec")

local sectionFrame = StubBetterBagsModule("SectionFrame")
sectionFrame.Create = function()
  return {
    frame = {
      SetParent = function() end,
    },
    SetTitle = function() end,
  }
end

local const = StubBetterBagsModule("Constants")
const.BAG_VIEW = { SECTION_GRID = 2, SECTION_ALL_BAGS = 4 }

local itemFrame = StubBetterBagsModule("ItemFrame")
itemFrame.GetButton = function() return {} end

local categories = StubBetterBagsModule("Categories")
categories.GetCategoryByName = function() return nil end

LoadBetterBagsModule("views/views.lua")
local views = addon:GetModule("Views")

describe("Views Module - Pure Presentation", function()
  it("should not call categories:CreateCategory when GetOrCreateSection is invoked", function()
    local createCategoryCalled = false
    categories.CreateCategory = function()
      createCategoryCalled = true
    end

    local view = views:NewBlankView()
    view.bagview = const.BAG_VIEW.SECTION_GRID
    view.sections = {}
    view.content = {
      GetScrollView = function() return {} end,
      AddCell = function() end,
      GetCell = function() return nil end,
    }

    local section = view:GetOrCreateSection(ctx, "TestCategory")
    assert.is_not_nil(section)
    assert.is_false(createCategoryCalled, "categories:CreateCategory should NOT be called in GetOrCreateSection during draw phase")
  end)
end)

-- A redraw keeps whatever it draws again: a render pass starts without releasing or
-- hiding anything, reuses last pass's section for each category it draws, and at the
-- end releases only the sections nobody drew. Item buttons are never released here;
-- the bag releases the ones no renderer claimed (frames/bag.lua).
describe("Views render passes", function()
  local created, savedCreate, savedGetButton

  local function fakeSection()
    local s = {
      frame = { SetParent = function() end },
      SetTitle = function() end,
      released = 0,
      prepared = 0,
      cellsReleased = 0,
    }
    function s:Release() self.released = self.released + 1 end
    function s:PrepareForReuse() self.prepared = self.prepared + 1 end
    function s:ReleaseAllCells() self.cellsReleased = self.cellsReleased + 1 end
    return s
  end

  local function newView()
    local view = views:NewBlankView()
    view.bagview = const.BAG_VIEW.SECTION_GRID
    view.cells = {}
    view.content = {
      GetScrollView = function() return {} end,
      AddCell = function(_, id, cell) view.cells[id] = cell end,
      GetCell = function(_, id) return view.cells[id] end,
      Wipe = function() view.cells = {} end,
    }
    return view
  end

  before_each(function()
    created = {}
    savedCreate = sectionFrame.Create
    sectionFrame.Create = function()
      local s = fakeSection()
      table.insert(created, s)
      return s
    end
    savedGetButton = itemFrame.GetButton
    local buttons = {}
    itemFrame.GetButton = function(_, _, slotkey)
      buttons[slotkey] = buttons[slotkey] or { slotkey = slotkey }
      return buttons[slotkey]
    end
  end)

  after_each(function()
    sectionFrame.Create = savedCreate
    itemFrame.GetButton = savedGetButton
  end)

  it("does not keep a growing list of the static slot buttons it draws", function()
    local view = newView()
    for _ = 1, 5 do
      view:BeginRender(ctx, {})
      view:GetOrCreateItemButton(ctx, "0_1")
      view:FinishRender(ctx)
    end
    assert.are.equal(0, #(view.itemFrames or {}))
  end)

  it("records every button it draws as claimed for this pass", function()
    local view = newView()
    local claims = {}
    view:BeginRender(ctx, claims)
    local button = view:GetOrCreateItemButton(ctx, "0_1")
    assert.is_true(claims[button])
  end)

  it("reuses last pass's section for a category it draws again, without releasing it", function()
    local view = newView()
    view:BeginRender(ctx, {})
    local weapons = view:GetOrCreateSection(ctx, "Weapons")
    view:FinishRender(ctx)

    view:BeginRender(ctx, {})
    assert.are.equal(0, weapons.released, "starting a pass releases nothing")
    assert.are.equal(weapons, view:GetOrCreateSection(ctx, "Weapons"))
    assert.are.equal(1, weapons.prepared)
    assert.are.equal(weapons, view.cells["Weapons"])
    view:FinishRender(ctx)
    assert.are.equal(0, weapons.released)
    assert.are.equal(1, #created)
  end)

  it("releases sections it did not draw again at the end of the pass, but never their item buttons", function()
    local view = newView()
    view:BeginRender(ctx, {})
    local weapons = view:GetOrCreateSection(ctx, "Weapons")
    local armor = view:GetOrCreateSection(ctx, "Armor")
    view:FinishRender(ctx)

    view:BeginRender(ctx, {})
    view:GetOrCreateSection(ctx, "Weapons")
    assert.are.equal(0, armor.released, "a stale section is only released once the pass is finished")
    view:FinishRender(ctx)
    assert.are.equal(1, armor.released)
    assert.are.equal(0, armor.cellsReleased)
    assert.are.equal(0, weapons.released)
    assert.is_nil(view.sections["Armor"])
  end)

  it("releases every section of a view that is not drawn this pass", function()
    local view = newView()
    view:BeginRender(ctx, {})
    local weapons = view:GetOrCreateSection(ctx, "Weapons")
    view:FinishRender(ctx)

    view:BeginRender(ctx, {})
    view:FinishRender(ctx)
    assert.are.equal(1, weapons.released)
    assert.is_nil(next(view.sections))
  end)

  it("releases the item buttons in sections a failed pass set aside when the view is torn down", function()
    local view = newView()
    view.WipeHandler = function() end
    view:BeginRender(ctx, {})
    local armor = view:GetOrCreateSection(ctx, "Armor")
    view:FinishRender(ctx)

    view:BeginRender(ctx, {}) -- this pass fails before FinishRender; Armor stays set aside
    view:Wipe(ctx)
    assert.are.equal(1, armor.cellsReleased)
    assert.are.equal(1, armor.released)
    assert.is_false(view.rendering)
  end)

  it("treats a second BeginRender in the same pass as a no-op", function()
    local view = newView()
    view:BeginRender(ctx, {})
    local weapons = view:GetOrCreateSection(ctx, "Weapons")
    view:FinishRender(ctx)

    local claims = {}
    view:BeginRender(ctx, claims)
    assert.are.equal(weapons, view:GetOrCreateSection(ctx, "Weapons"))
    view:BeginRender(ctx, claims)
    assert.are.equal(weapons, view.sections["Weapons"], "the pass already started must not be restarted")
    view:FinishRender(ctx)
    assert.are.equal(0, weapons.released)
  end)
end)
