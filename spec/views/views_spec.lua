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
