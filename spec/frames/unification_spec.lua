local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Stub standard dependencies
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 0, BANK = 1 }
const.BACKPACK_ONLY_BAGS_LIST = { 1, 2, 3, 4 }
const.BANK_ONLY_BAGS_LIST = { 5, 6, 7, 8, 9, 10, 11 }
const.BANK_ONLY_BAGS = { [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }

local events = addon:GetModule("Events")
events:OnInitialize()

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

describe("UI Unification Classic/Era Fallbacks", function()
  before_each(function()
    _G.GameTooltip.lines = {}
    _G.GameTooltip.doubleLines = {}
  end)

  describe("Money Frame Classic Fallback", function()
    setup(function()
      addon.isRetail = false
      ResetModuleStub("MoneyFrame", "frames/money.lua")
      LoadBetterBagsModule("frames/money.lua")
    end)

    teardown(function()
      addon.isRetail = true
    end)

    it("should use textures instead of Atlases in Classic Era for money buttons", function()
      local money = addon:GetModule("MoneyFrame")
      local m = money:Create(false)
      assert.is_not_nil(m)

      -- Verify that NormalTexture is set to Classic texture path
      local copperBtn = m.copperButton
      assert.equal("Interface\\MONEYFRAME\\UI-MoneyIcons", copperBtn:GetNormalTexture()._texturePath)

      -- Verify that no normal atlas is set for copper
      assert.is_nil(copperBtn._normalAtlas)

      -- Verify TexCoords are set for copper, silver, gold
      assert.is_table(copperBtn:GetNormalTexture()._texCoords)
      assert.equal(0.5, copperBtn:GetNormalTexture()._texCoords[1])
      assert.equal(0.75, copperBtn:GetNormalTexture()._texCoords[2])
    end)
  end)

  describe("BagButton Classic Fallback", function()
    setup(function()
      addon.isRetail = false
      _G.GetInventoryItemTexture = _G.GetInventoryItemTexture or function() return nil end
      _G.GetInventoryItemQuality = _G.GetInventoryItemQuality or function() return 1 end
      _G.GetInventorySlotInfo = _G.GetInventorySlotInfo or function() return 1, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag" end
      _G.SetItemButtonTexture = _G.SetItemButtonTexture or function() end
      _G.SetItemButtonQuality = _G.SetItemButtonQuality or function() end
      _G.SetItemButtonCount = _G.SetItemButtonCount or function() end
      _G.GetNumBankSlots = _G.GetNumBankSlots or function() return 0, false end
      _G.GetBankSlotCost = _G.GetBankSlotCost or function() return 100 end

      -- Load real Pool dependency
      LoadBetterBagsModule("core/pool.lua")

      local c = addon:GetModule("Constants")
      c.BACKPACK_ONLY_BAGS_LIST = { 1, 2, 3, 4 }
      c.BANK_ONLY_BAGS_LIST = { 5, 6, 7, 8, 9, 10, 11 }
      c.BANK_ONLY_BAGS = { [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }
      c.BAG_KIND = { BACKPACK = 1, BANK = 2 }

      local loc = addon:GetModule("Localization")
      loc.G = function(_, key) return key end

      ResetModuleStub("BagButton", "frames/bagbutton.lua")
      LoadBetterBagsModule("frames/bagbutton.lua")
      addon:GetModule("BagButton"):OnInitialize()
    end)

    teardown(function()
      addon.isRetail = true
    end)

    it("should fallback to Button with ItemButtonTemplate and set up empty slot background in Classic Era", function()
      local bagButton = addon:GetModule("BagButton")
      local ctxObj = addon:GetModule("Context"):New("test")
      local btn = bagButton:Create(ctxObj)
      assert.is_not_nil(btn)
      assert.is_not_nil(btn.frame)
      assert.is_not_nil(btn.frame.ItemSlotBackground)

      -- Let's call SetBag to test empty slots
      btn:SetBag(ctxObj, 1)
      assert.is_true(btn.empty)
      -- In classic era it should have registered ItemSlotBackground texture as UI-PaperDoll-Slot-Bag
      assert.equal("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", btn.frame.ItemSlotBackground._texturePath)
    end)
  end)
end)
