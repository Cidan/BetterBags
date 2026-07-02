local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

addon.ForceHideBlizzardBags = function() end

local ctx = addon:GetModule("Context")

-- Stub standard dependencies
local L = StubBetterBagsModule("Localization")
L.G = function(_, key) return key end

local database = StubBetterBagsModule("Database")
database.GetShowBankTabs = function() return true end
database.GetBagView = function() return 1 end
database.SetBagView = function() end
database.GetPreviousView = function() return 1 end
database.SetPreviousView = function() end
database.GetEnableBagFading = function() return false end
database.GetGroupsEnabled = function() return true end

local const = StubBetterBagsModule("Constants")
const.BAG_KIND = { BACKPACK = 1, BANK = 2 }
const.BACKPACK_ONLY_BAGS_LIST = { 1, 2, 3, 4 }
const.BANK_ONLY_BAGS_LIST = { 5, 6, 7, 8 }
const.BANK_ONLY_BAGS = { [5]=5, [6]=6, [7]=7, [8]=8 }
const.BAG_VIEW = { SECTION_GRID = 1, SECTION_ALL_BAGS = 2 }
const.OFFSETS = {
  BAG_LEFT_INSET = 10,
  BAG_TOP_INSET = -40,
  BAG_RIGHT_INSET = -10,
  BAG_BOTTOM_INSET = 10,
}

local items = StubBetterBagsModule("Items")
items.ClearBankCache = function() end

StubBetterBagsModule("Tabs")
StubBetterBagsModule("Groups")
StubBetterBagsModule("ContextMenu")

local themes = StubBetterBagsModule("Themes")
themes.RegisterFlatWindow = function() end
themes.GetFlatHeaderHeight = function() return 12 end

local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

local animations = StubBetterBagsModule("Animations")
animations.AttachFadeAndSlideTop = function(region)
  local mockAnimGroup = {
    Play = function() end,
    Stop = function() end,
    HookScript = function() end,
  }
  return mockAnimGroup, mockAnimGroup
end

local grid = StubBetterBagsModule("Grid")
grid.Create = function()
  return {
    GetContainer = function()
      local container = CreateFrame("Frame")
      return container
    end,
    HideScrollBar = function() end,
    EnableMouseWheelScroll = function() end,
    Show = function() end,
    AddCell = function() end,
    Draw = function() return 100, 100 end,
    cells = {},
  }
end

-- Define Enums if not set
_G.Enum = _G.Enum or {}
_G.Enum.BagIndex = _G.Enum.BagIndex or {
  CharacterBankTab_1 = 10,
  CharacterBankTab_6 = 15,
  AccountBankTab_1 = 16,
  AccountBankTab_2 = 17,
  AccountBankTab_3 = 18,
  AccountBankTab_4 = 19,
  AccountBankTab_5 = 20,
}
_G.Enum.BankType = _G.Enum.BankType or {
  Character = 1,
  Account = 2,
}

_G.C_Bank = _G.C_Bank or {}
_G.C_Bank.FetchPurchasedBankTabData = function(bankType)
  if bankType == _G.Enum.BankType.Character then
    return {
      { ID = 10, icon = 1337 },
    }
  elseif bankType == _G.Enum.BankType.Account then
    return {
      { ID = 16, icon = 1338 },
    }
  end
  return {}
end

_G.GetInventoryItemTexture = function() return 12345 end
_G.SetItemButtonTexture = function() end
_G.SetItemButtonQuality = function() end
_G.SetItemButtonCount = function() end
_G.SetItemButtonDesaturated = function() end
_G.GetInventoryItemQuality = function() return 1 end
_G.GetNumBankSlots = function() return 2 end
_G.ItemButtonUtil = {
  Event = { ItemContextChanged = 1 },
  TriggerEvent = function() end,
}

_G.C_Container = _G.C_Container or {}
_G.C_Container.ContainerIDToInventoryID = function(bagid) return bagid + 10 end

-- Load modules
LoadBetterBagsModule("frames/bagbutton.lua")
LoadBetterBagsModule("frames/bagslots.lua")
LoadBetterBagsModule("frames/bankslots.lua")
LoadBetterBagsModule("frames/money.lua")
LoadBetterBagsModule("bags/bank.lua")

addon:GetModule("BagButton"):OnInitialize()

describe("Bank Bag/Slot Window Pane Tests", function()
  before_each(function()
    _G.BankFrame = nil
    _G.BankPanel = nil
    _G.AccountBankPanel = nil
    events:OnInitialize()
  end)

  describe("1. Classic/Era Event Typo (PLAYERBANKSLOTS_CHANGED)", function()
    it("should register PLAYERBANKSLOTS_CHANGED instead of PLAYERBANKBAGSLOTS_CHANGED in frames/bagslots.lua", function()
      addon.isRetail = false
      local registeredEvents = {}
      local oldRegisterEvent = events.RegisterEvent
      events.RegisterEvent = function(self, event, fn)
        registeredEvents[event] = true
      end

      local bagFrame = CreateFrame("Frame")
      local bagSlots = addon:GetModule("BagSlots")
      bagSlots:CreatePanel(ctx:New("test"), 1, bagFrame)

      -- Restore
      events.RegisterEvent = oldRegisterEvent

      -- Assertions (reproduce the typo issue)
      assert.is_nil(registeredEvents["PLAYERBANKBAGSLOTS_CHANGED"], "Should not register the typo event PLAYERBANKBAGSLOTS_CHANGED")
      assert.is_true(registeredEvents["PLAYERBANKSLOTS_CHANGED"], "Should register correct event PLAYERBANKSLOTS_CHANGED")
    end)
  end)

  describe("2. Retail Character Bank Tab Purchase Event Registration", function()
    it("should register BANK_TABS_CHANGED in frames/bankslots.lua and bags/bank.lua", function()
      addon.isRetail = true
      local registeredEvents = {}
      local oldRegisterEvent = events.RegisterEvent
      events.RegisterEvent = function(self, event, fn)
        registeredEvents[event] = true
      end

      -- Create panel
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      -- Load BankBehavior and register its events
      local bankBehavior = addon:GetModule("BankBehavior")
      local mockBag = {
        frame = bagFrame,
        moneyFrame = { Update = function() end },
        tabs = { SetClickHandler = function() end },
      }
      local bInstance = setmetatable({ bag = mockBag }, { __index = bankBehavior.proto })
      bInstance:RegisterEvents()

      -- Restore
      events.RegisterEvent = oldRegisterEvent

      -- Assertions
      assert.is_true(registeredEvents["BANK_TABS_CHANGED"], "BANK_TABS_CHANGED should be registered")
    end)
  end)

  describe("3. Overwriting tabsWereShown State", function()
    it("should not overwrite tabsWereShown to false on redundant Show calls", function()
      addon.isRetail = true
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      -- Mock parent bag tabs frame
      addon.Bags = {
        Bank = {
          tabs = {
            frame = {
              IsShown = function() return true end,
              Hide = function() end,
            }
          }
        }
      }

      panel:Show()
      assert.is_true(panel.tabsWereShown)

      -- Mock tabs hidden now
      addon.Bags.Bank.tabs.frame.IsShown = function() return false end

      -- Call Show again when already shown (IsShown returns true)
      panel.frame.IsShown = function() return true end
      panel:Show()

      -- tabsWereShown should still be true!
      assert.is_true(panel.tabsWereShown, "tabsWereShown should not be overwritten to false if panel is already shown")
    end)
  end)

  describe("4. Warbank/Account Tab Right-Click Configuration Silent Failure", function()
    it("should safely open configuration settings on right click with unified/legacy panel structures", function()
      addon.isRetail = true
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      -- Let's mock a unified bankPanel (no global AccountBankPanel)
      local mockMenu = CreateFrame("Frame")
      mockMenu.IconSelector = {}
      mockMenu.BorderBox = {
        SelectedIconArea = {
          SelectedIconButton = { SetIconTexture = function() end },
        }
      }
      mockMenu.SetSelectedTab = function(self, id)
        self.selectedTabData = { ID = id, icon = 1234 }
      end
      mockMenu.Update = spy.new(function() end)

      _G.BankFrame = {
        BankPanel = {
          TabSettingsMenu = mockMenu
        }
      }

      panel:OpenTabConfig(16) -- Warbank slot ID

      -- Assertions
      assert.spy(mockMenu.Update).was.called()
      assert.is_not_nil(mockMenu.selectedTabData)
    end)
  end)

  describe("5. Stuck Filter / blizzardBankTab Leak on Close", function()
    it("should cleanly reset blizzardBankTab and button select state when closed", function()
      addon.isRetail = true
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      local mockBag = {
        frame = bagFrame,
        moneyFrame = { Update = function() end },
        tabs = {
          SetClickHandler = function() end,
          frame = { Show = function() end, IsShown = function() return true end }
        },
        slots = panel,
        Wipe = function() end,
        blizzardBankTab = 10,
      }

      local bankBehavior = addon:GetModule("BankBehavior")
      local bInstance = setmetatable({ bag = mockBag }, { __index = bankBehavior.proto })
      addon.Bags = { Bank = mockBag }
      mockBag.behavior = bInstance

      -- Select a tab, setting blizzardBankTab and selectedBagIndex
      panel:SelectTab(ctx:New("test"), 10)
      assert.are.equal(10, mockBag.blizzardBankTab)
      assert.are.equal(10, panel.selectedBagIndex)

      -- Hide the bank (reproducing the CloseBankFrame or UI Special Frame hide)
      bInstance:OnHide()

      -- Assertions: filter should be cleared, selectedBagIndex nil, buttons deselected
      assert.is_nil(mockBag.blizzardBankTab, "blizzardBankTab should be cleared on bank OnHide")
      assert.is_nil(panel.selectedBagIndex, "selectedBagIndex should be cleared on bank OnHide")
    end)
  end)

  describe("6. Classic/Era OnClose Method Compatibility", function()
    it("should safely handle bank OnHide on Classic/Era without OnClose nil errors", function()
      addon.isRetail = false
      local bagFrame = CreateFrame("Frame")

      -- Load BagSlots and create Classic/Era panel
      local bagSlots = addon:GetModule("BagSlots")
      local panel = bagSlots:CreatePanel(ctx:New("test"), const.BAG_KIND.BANK, bagFrame)

      local mockBag = {
        frame = bagFrame,
        moneyFrame = { Update = function() end },
        tabs = {
          SetClickHandler = function() end,
          frame = { Show = function() end, IsShown = function() return true end }
        },
        slots = panel,
        Wipe = function() end,
      }

      local bankBehavior = addon:GetModule("BankBehavior")
      local bInstance = setmetatable({ bag = mockBag }, { __index = bankBehavior.proto })
      addon.Bags = { Bank = mockBag }
      mockBag.behavior = bInstance

      -- Closing the bank on Classic/Era should not throw "attempt to call method 'OnClose' (a nil value)"
      assert.has_no.errors(function()
        bInstance:OnHide()
      end)
    end)
  end)

  describe("7. Restore Group Tabs even if tabsWereShown was false (Bugfix)", function()
    it("should restore group tabs on close if groups are enabled, even if tabsWereShown is false", function()
      addon.isRetail = true
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      local tabsShown = false
      addon.Bags = {
        Bank = {
          tabs = {
            frame = {
              IsShown = function() return false end,
              Show = function() tabsShown = true end,
              Hide = function() end,
            }
          }
        }
      }

      panel.tabsWereShown = false
      database.GetGroupsEnabled = function(_, kind) return true end

      panel:OnClose(ctx:New("test"))
      assert.is_true(tabsShown, "group tabs should have been shown on close because groups are enabled")
    end)
  end)
end)
