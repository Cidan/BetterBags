-- itemrow_spec.lua -- Unit tests for itemrow font validation

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load core context and events modules
LoadBetterBagsModule("core/context.lua")
local context = addon:GetModule("Context")

LoadBetterBagsModule("core/events.lua")

-- Stub other dependencies
local const = StubBetterBagsModule("Constants")
const.ITEM_QUALITY_COLOR = {
  [0] = {1, 1, 1, 1},
  [1] = {1, 1, 1, 1}
}
const.ITEM_QUALITY_COLOR_HIGH = {
  [0] = {1, 1, 1, 1},
  [1] = {1, 1, 1, 1}
}
const.ITEM_QUALITY_COLOR_LOW = {
  [0] = {1, 1, 1, 1},
  [1] = {1, 1, 1, 1}
}

StubBetterBagsModule("Items")

local itemFrame = StubBetterBagsModule("ItemFrame")
function itemFrame:Create(_)
  local button = {
    frame = CreateFrame("Frame"),
    SetSize = function() end,
    SetItemFromData = function() end,
    SetStaticItemFromData = function() end,
    GetItemData = function() return {} end
  }
  return button
end

LoadBetterBagsModule("core/pool.lua")

-- Clear loaded modules to force a clean load of the files we want to test
local originalLoadBetterBagsModule = _G.LoadBetterBagsModule
_G.LoadBetterBagsModule = function(path)
  -- Allow reloading files by clearing them from loadedModules
  _G.package.loaded[path] = nil
  local loadedModules = debug.getupvalue(originalLoadBetterBagsModule, 1)
  if type(loadedModules) == "table" then
    loadedModules[path] = nil
  end
  originalLoadBetterBagsModule(path)
end

describe("ItemRow Frame Font Validation", function()
  local ctx

  before_each(function()
    ctx = context:New("ItemRowTest")
  end)

  it("should successfully initialize because of the valid normal font flag in retail", function()
    ResetModuleStub("ItemRowFrame", "frames/itemrow.lua")
    LoadBetterBagsModule("frames/itemrow.lua")
    local itemRowFrame = addon:GetModule("ItemRowFrame")
    itemRowFrame:OnInitialize()

    -- This should NOT throw a SetFont error anymore because '' is valid
    assert.has_no_error(function()
      itemRowFrame:Create(ctx)
    end)
  end)

  it("should successfully initialize because of the valid normal font flag in era", function()
    -- First make sure the main ItemRowFrame is loaded
    ResetModuleStub("ItemRowFrame", "frames/itemrow.lua")
    LoadBetterBagsModule("frames/itemrow.lua")

    -- Now load era/itemrow.lua which retrieves 'ItemRowFrame' and modifies it
    LoadBetterBagsModule("frames/era/itemrow.lua")
    local itemRowFrame = addon:GetModule("ItemRowFrame")

    -- This should NOT throw a SetFont error anymore because '' is valid
    assert.has_no_error(function()
      itemRowFrame:_DoCreate(ctx)
    end)
  end)
end)

-- Restore original helper
_G.LoadBetterBagsModule = originalLoadBetterBagsModule
