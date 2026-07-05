require("busted.runner")()
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")
LoadBetterBagsModule("data/database.lua")
LoadBetterBagsModule("data/groups.lua")
LoadBetterBagsModule("views/views.lua")
LoadBetterBagsModule("frames/bag.lua")
LoadBetterBagsModule("data/items_new.lua")

local addonName = "BetterBags"
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local events = addon:GetModule("Events")
local context = addon:GetModule("Context")
local database = addon:GetModule("Database")
local groups = addon:GetModule("Groups")
local categories = StubBetterBagsModule("Categories")
local const = addon:GetModule("Constants")

describe("Double Free bug on Tab Switch", function()
  before_each(function()
    addon.isRetail = true
    addon.Bags = {}
    
    local bagFrame = addon:GetModule("BagFrame")
    local ctx = context:New("test")
    
    -- Stub out sounds and UI functions
    _G.PlaySound = function() end
    _G.GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
    
    -- Setup items mock
    local items = addon:GetModule("Items")
    items:WipeSlotInfo(const.BAG_KIND.BACKPACK)
    local slotInfo = items.slotInfo[const.BAG_KIND.BACKPACK]
    
    -- Mock getting changeset and items
    slotInfo.GetChangeset = function() return {}, {}, {} end
    slotInfo.GetVisibleItems = function()
      return {
        {
          isItemEmpty = false,
          bagid = 0,
          slotid = 1,
          slotkey = "0_1",
          itemInfo = {
            category = "TestCategory",
            itemName = "Test Item",
            itemIcon = 134400,
            itemQuality = 1,
            currentItemLevel = 1,
          }
        }
      }
    end
    slotInfo.emptySlotByBagAndSlot = {}
    slotInfo.emptySlotsSorted = {}
    slotInfo.emptySlots = {}
    slotInfo.totalItems = 1
    
    -- Mock item data fetch
    items.GetItemDataFromSlotKey = function(self, slotkey)
      if slotkey == "0_1" then
        return slotInfo.GetVisibleItems()[1]
      end
      return nil
    end
    
    database:CreateGroup(const.BAG_KIND.BACKPACK, "Group1")
    database:CreateGroup(const.BAG_KIND.BACKPACK, "Group2")
    
    addon.Bags.Backpack = bagFrame:Create(ctx, const.BAG_KIND.BACKPACK)
  end)

  it("should not double-free when moving a category between tabs", function()
    local ctx = context:New("test")
    
    -- Start in Group1
    local bag = addon.Bags.Backpack
    bag.behavior:SwitchToGroup(ctx, 2) -- Switch to Group1
    
    -- Assign category to Group1
    groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "TestCategory", 2)
    
    -- Simulate a refresh and draw
    local items = addon:GetModule("Items")
    bag:Draw(ctx, items.slotInfo[const.BAG_KIND.BACKPACK], function() end)
    
    -- Now assign to Group2
    groups:AssignCategoryToGroup(ctx, const.BAG_KIND.BACKPACK, "TestCategory", 3)
    
    -- Switch to Group2
    bag.behavior:SwitchToGroup(ctx, 3)
    
    -- Simulate the draw that happens after
    bag:Draw(ctx, items.slotInfo[const.BAG_KIND.BACKPACK], function() end)
    
    -- And switch back to Group1 just in case
    bag.behavior:SwitchToGroup(ctx, 2)
    bag:Draw(ctx, items.slotInfo[const.BAG_KIND.BACKPACK], function() end)
    
    -- If no errors were thrown by the strict pool validation, we passed!
    assert.is_true(true)
  end)
end)