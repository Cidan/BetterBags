local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")
LoadBetterBagsModule("core/pool.lua")

local events = addon:GetModule("Events")
events:Init()

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
-- Character bank tabs (CharacterBankTab_1..6) and account bank tabs
-- (AccountBankTab_1..5) in tab-index order, matching the stubbed Enum.BagIndex
-- below. The bank tab slots panel builds its buttons from these lists.
const.BANK_ONLY_BAGS_LIST = { 10, 11, 12, 13, 14, 15 }
const.BANK_ONLY_BAGS = { [10]=10, [11]=11, [12]=12, [13]=13, [14]=14, [15]=15 }
const.ACCOUNT_BANK_BAGS_LIST = { 16, 17, 18, 19, 20 }
const.ACCOUNT_BANK_BAGS = { [16]=16, [17]=17, [18]=18, [19]=19, [20]=20 }
const.BAG_VIEW = { SECTION_GRID = 1, SECTION_ALL_BAGS = 2 }
const.OFFSETS = {
  BAG_LEFT_INSET = 10,
  BAG_TOP_INSET = -40,
  BAG_RIGHT_INSET = -10,
  BAG_BOTTOM_INSET = 10,
}

local items = StubBetterBagsModule("Items")
items.ClearBankCache = function() end
items.GetAllSlotInfo = function()
  return {
    [const.BAG_KIND.BANK] = {
      GetChangeset = function() return {}, {}, {} end,
      GetCurrentItems = function() return {} end,
      emptySlots = {},
      freeSlotKeys = {},
      emptySlotsSorted = {},
      stacks = { GetStackInfo = function() end },
      totalItems = 0
    }
  }
end

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
ResetModuleStub("BagButton", "frames/bagbutton.lua")
ResetModuleStub("BagSlots", "frames/bagslots.lua")
ResetModuleStub("BankSlots", "frames/bankslots.lua")
ResetModuleStub("MoneyFrame", "frames/money.lua")
ResetModuleStub("Bank", "bags/bank.lua")
LoadBetterBagsModule("frames/bagbutton.lua")
LoadBetterBagsModule("frames/bagslots.lua")
LoadBetterBagsModule("frames/bankslots.lua")
LoadBetterBagsModule("frames/money.lua")
LoadBetterBagsModule("bags/bank.lua")

addon:GetModule("BagButton"):Init()

describe("Bank Bag/Slot Window Pane Tests", function()
  before_each(function()
    _G.BankFrame = nil
    _G.BankPanel = nil
    _G.AccountBankPanel = nil
    events:Init()
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
        Draw = function() end,
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

  describe("8. Dynamic tab count derived from Constants (Camelot 9+9)", function()
    local savedCharList, savedAcctList

    before_each(function()
      savedCharList = const.BANK_ONLY_BAGS_LIST
      savedAcctList = const.ACCOUNT_BANK_BAGS_LIST
    end)

    after_each(function()
      const.BANK_ONLY_BAGS_LIST = savedCharList
      const.ACCOUNT_BANK_BAGS_LIST = savedAcctList
    end)

    it("builds one slot button per character + account tab (retail 6+5)", function()
      addon.isRetail = true
      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      assert.are.equal(11, #panel.buttons)
      assert.are.equal(11, panel.content.maxCellWidth)
      -- First six are Character tabs, remaining five are Account tabs.
      for i = 1, 6 do
        assert.are.equal(Enum.BankType.Character, panel.buttons[i].bankType)
      end
      for i = 7, 11 do
        assert.are.equal(Enum.BankType.Account, panel.buttons[i].bankType)
      end
      -- Button bag indices match the constant lists in order.
      assert.are.equal(const.BANK_ONLY_BAGS_LIST[1], panel.buttons[1].bagIndex)
      assert.are.equal(const.ACCOUNT_BANK_BAGS_LIST[1], panel.buttons[7].bagIndex)
    end)

    it("expands to 18 slot buttons when the client exposes 9+9 tabs", function()
      addon.isRetail = true
      -- Simulate Camelot: 9 character tabs + 9 account tabs.
      const.BANK_ONLY_BAGS_LIST = { 10, 11, 12, 13, 14, 15, 21, 22, 23 }
      const.ACCOUNT_BANK_BAGS_LIST = { 16, 17, 18, 19, 20, 24, 25, 26, 27 }

      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      assert.are.equal(18, #panel.buttons)
      assert.are.equal(18, panel.content.maxCellWidth)
      for i = 1, 9 do
        assert.are.equal(Enum.BankType.Character, panel.buttons[i].bankType)
      end
      for i = 10, 18 do
        assert.are.equal(Enum.BankType.Account, panel.buttons[i].bankType)
      end
      assert.are.equal(23, panel.buttons[9].bagIndex)
      assert.are.equal(27, panel.buttons[18].bagIndex)
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

  describe("9. Camelot headerless decoration", function()
    local savedIsForever, savedRegister
    before_each(function()
      savedIsForever = addon.isForever
      savedRegister = themes.RegisterFlatWindow
    end)
    after_each(function()
      addon.isForever = savedIsForever
      themes.RegisterFlatWindow = savedRegister
    end)

    it("does not use the themed flat window on Camelot (uses a headerless decoration)", function()
      addon.isRetail = true
      addon.isForever = true
      local registered = false
      themes.RegisterFlatWindow = function() registered = true end

      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      local panel = bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      assert.is_not_nil(panel)
      assert.is_false(registered, "Camelot must not register the broken themed flat window")
    end)

    it("still uses the themed flat window on ordinary retail", function()
      addon.isRetail = true
      addon.isForever = false
      local registered = false
      themes.RegisterFlatWindow = function() registered = true end

      local bagFrame = CreateFrame("Frame")
      local bankSlots = addon:GetModule("BankSlots")
      bankSlots:CreatePanel(ctx:New("test"), bagFrame)

      assert.is_true(registered)
    end)

    -- The slot grid is a clipping WowScrollBox child of the panel. A filled backdrop on a
    -- sibling child frame shares the grid's frame level and can render over the buttons
    -- (the darkened "buttons under the window" look). The panel frame must own the
    -- backdrop so it always sits a level below the grid.
    it("draws the Camelot backdrop on the panel frame itself, not on a sibling of the grid", function()
      addon.isRetail = true
      addon.isForever = true

      local calls = {}
      local origCreateFrame = _G.CreateFrame
      _G.CreateFrame = function(frameType, name, parent, template)
        local f = origCreateFrame(frameType, name, parent, template)
        table.insert(calls, { frame = f, parent = parent, template = template })
        return f
      end
      local bagFrame = origCreateFrame("Frame")
      local ok, panel = pcall(function()
        return addon:GetModule("BankSlots"):CreatePanel(ctx:New("test"), bagFrame)
      end)
      _G.CreateFrame = origCreateFrame
      assert.is_true(ok, tostring(panel))

      local panelTemplate
      for _, c in ipairs(calls) do
        if c.frame == panel.frame then panelTemplate = c.template end
        assert.is_false(c.parent == panel.frame and c.template == "TooltipBorderedFrameTemplate",
          "the backdrop must not be a sibling frame of the slot grid")
      end
      assert.are.equal("TooltipBorderedFrameTemplate", panelTemplate)
      assert.are.same({ r = 0, g = 0, b = 0, a = 0.9 }, panel.frame._backdropColor)
    end)
  end)

  -- WoW: Forever (Camelot/BankFrame.lua): every character bank tab after the first is a
  -- bag socket addressed as (Enum.BagIndex.Characterbanktab, socketIndex). The tab only
  -- has slots once a bag is placed in its socket; C_Container.PickupContainerItem on
  -- the socket picks the bag up, places the cursor bag, or swaps them.
  describe("10. Forever bank tabs are bag sockets", function()
    local EMPTY_BAG_SLOT = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
    local saved = {}

    local function newPanel()
      local panel = addon:GetModule("BankSlots"):CreatePanel(ctx:New("test"), CreateFrame("Frame"))
      panel:Draw(ctx:New("test"))
      return panel
    end

    local function tooltipHasLine(text)
      for _, line in ipairs(GameTooltip.lines) do
        if line.text == text then return true end
      end
      return false
    end

    before_each(function()
      saved.isRetail = addon.isRetail
      saved.isForever = addon.isForever
      saved.charList = const.BANK_ONLY_BAGS_LIST
      saved.charBags = const.BANK_ONLY_BAGS
      saved.acctList = const.ACCOUNT_BANK_BAGS_LIST
      saved.acctBags = const.ACCOUNT_BANK_BAGS
      saved.characterbanktab = Enum.BagIndex.Characterbanktab
      saved.characterBankTab1 = Enum.BagIndex.CharacterBankTab_1
      saved.fetch = C_Bank.FetchPurchasedBankTabData
      saved.inCombat = _G.InCombatLockdown
      saved.itemsAtLocation = _G._itemsAtLocation

      addon.isRetail = true
      addon.isForever = true
      -- Forever enum values (BagIndexConstantsDocumentation.lua): 9 character tabs at
      -- bag ids 6..14, sockets at Characterbanktab (-2), no warbank.
      const.BANK_ONLY_BAGS_LIST = { 6, 7, 8, 9, 10, 11, 12, 13, 14 }
      const.BANK_ONLY_BAGS = {}
      for _, id in ipairs(const.BANK_ONLY_BAGS_LIST) do const.BANK_ONLY_BAGS[id] = id end
      const.ACCOUNT_BANK_BAGS_LIST = {}
      const.ACCOUNT_BANK_BAGS = {}
      Enum.BagIndex.Characterbanktab = -2
      Enum.BagIndex.CharacterBankTab_1 = 6
      C_Bank.FetchPurchasedBankTabData = function(bankType)
        if bankType == Enum.BankType.Character then
          return {
            { ID = 6, name = "Base", icon = 100 },
            { ID = 7, name = "Herbs", icon = 101 },
            { ID = 8, name = "Spare", icon = 102 },
          }
        end
        return {}
      end
      -- Tab 7's socket (slot 2) holds a bag; tab 8's socket (slot 3) is empty.
      _G._itemsAtLocation = { ["-2:2"] = { icon = 555 } }
      C_Container._pickups = {}
      _G._cursorType = nil
      _G._isShiftKeyDown = false
      GameTooltip._bagItem = nil
      GameTooltip._text = ""
    end)

    after_each(function()
      addon.isRetail = saved.isRetail
      addon.isForever = saved.isForever
      const.BANK_ONLY_BAGS_LIST = saved.charList
      const.BANK_ONLY_BAGS = saved.charBags
      const.ACCOUNT_BANK_BAGS_LIST = saved.acctList
      const.ACCOUNT_BANK_BAGS = saved.acctBags
      Enum.BagIndex.Characterbanktab = saved.characterbanktab
      Enum.BagIndex.CharacterBankTab_1 = saved.characterBankTab1
      C_Bank.FetchPurchasedBankTabData = saved.fetch
      _G.InCombatLockdown = saved.inCombat
      _G._itemsAtLocation = saved.itemsAtLocation
      _G._cursorType = nil
      _G._isShiftKeyDown = false
    end)

    it("maps every character tab after the first to its bag socket", function()
      local panel = newPanel()
      assert.is_nil(panel.buttons[1]:GetBagSocketIndex(), "the first tab is the bagless base bank")
      assert.are.equal(2, panel.buttons[2]:GetBagSocketIndex())
      assert.are.equal(3, panel.buttons[3]:GetBagSocketIndex())
      assert.are.equal(9, panel.buttons[9]:GetBagSocketIndex())
    end)

    it("has no bag sockets on live retail", function()
      addon.isForever = false
      local panel = newPanel()
      assert.is_nil(panel.buttons[2]:GetBagSocketIndex())
      assert.is_nil(panel.buttons[2].viewButton._registeredDrags)
      local onReceiveDrag = panel.buttons[2].viewButton:GetScript("OnReceiveDrag")
      if onReceiveDrag then onReceiveDrag(panel.buttons[2].viewButton) end
      assert.are.equal(0, #C_Container._pickups)
    end)

    it("places a dropped bag into the tab's socket", function()
      local panel = newPanel()
      local button = panel.buttons[3].viewButton
      button:GetScript("OnReceiveDrag")(button)
      assert.are.same({ { bag = -2, slot = 3 } }, C_Container._pickups)
    end)

    it("picks the socketed bag up when the tab is dragged", function()
      local panel = newPanel()
      local button = panel.buttons[2].viewButton
      assert.are.same({ "LeftButton" }, button._registeredDrags)
      button:GetScript("OnDragStart")(button)
      assert.are.same({ { bag = -2, slot = 2 } }, C_Container._pickups)
    end)

    -- Records the tab a click selected (nil when the click selected nothing).
    local function recordSelection(panel)
      local selection = {}
      panel.SelectTab = function(_, _, bagIndex) selection.bagIndex = bagIndex end
      return selection
    end

    it("places the cursor item on left-click instead of selecting the tab", function()
      local panel = newPanel()
      local selection = recordSelection(panel)
      _G._cursorType = "item"
      local button = panel.buttons[2].viewButton
      button:GetScript("OnClick")(button, "LeftButton")
      assert.are.same({ { bag = -2, slot = 2 } }, C_Container._pickups)
      assert.is_nil(selection.bagIndex)
    end)

    it("picks the bag up on shift-left-click", function()
      local panel = newPanel()
      local selection = recordSelection(panel)
      _G._isShiftKeyDown = true
      local button = panel.buttons[2].viewButton
      button:GetScript("OnClick")(button, "LeftButton")
      assert.are.same({ { bag = -2, slot = 2 } }, C_Container._pickups)
      assert.is_nil(selection.bagIndex)
    end)

    it("still selects the tab on a plain left-click", function()
      local panel = newPanel()
      local selection = recordSelection(panel)
      local button = panel.buttons[2].viewButton
      button:GetScript("OnClick")(button, "LeftButton")
      assert.are.equal(0, #C_Container._pickups)
      assert.are.equal(7, selection.bagIndex)
    end)

    it("never moves bags through the bagless base tab", function()
      local panel = newPanel()
      local selection = recordSelection(panel)
      local button = panel.buttons[1].viewButton
      button:GetScript("OnReceiveDrag")(button)
      _G._cursorType = "item"
      button:GetScript("OnClick")(button, "LeftButton")
      assert.are.equal(0, #C_Container._pickups)
      assert.are.equal(6, selection.bagIndex)
    end)

    it("refuses to change bags in combat", function()
      local panel = newPanel()
      _G.InCombatLockdown = function() return true end
      local button = panel.buttons[2].viewButton
      button:GetScript("OnReceiveDrag")(button)
      button:GetScript("OnDragStart")(button)
      assert.are.equal(0, #C_Container._pickups)
    end)

    it("badges each socket tab with its bag, or an empty bag slot", function()
      local panel = newPanel()
      local withBag, emptySocket, base = panel.buttons[2], panel.buttons[3], panel.buttons[1]

      assert.is_true(withBag.bagBadge:IsShown())
      assert.are.equal(555, withBag.bagBadge._texturePath)
      assert.is_false(withBag.iconTexture:IsDesaturated())

      assert.is_true(emptySocket.bagBadge:IsShown())
      assert.are.equal(EMPTY_BAG_SLOT, emptySocket.bagBadge._texturePath)
      assert.is_true(emptySocket.iconTexture:IsDesaturated())

      assert.is_false(base.bagBadge:IsShown())
      assert.is_false(base.iconTexture:IsDesaturated())
    end)

    it("leads the tooltip with the socketed bag, then the tab and its free slots", function()
      local panel = newPanel()
      local button = panel.buttons[2].viewButton
      button:GetScript("OnEnter")(button)
      assert.are.same({ bag = -2, slot = 2 }, GameTooltip._bagItem)
      assert.is_true(tooltipHasLine("Herbs"))
      assert.is_true(tooltipHasLine("4 of 16 slots free"))
      assert.is_true(tooltipHasLine("Drag to remove this bag"))
      assert.is_true(tooltipHasLine("Drop a bag here to swap it"))
    end)

    it("explains an empty socket in the tooltip", function()
      local panel = newPanel()
      local button = panel.buttons[3].viewButton
      button:GetScript("OnEnter")(button)
      assert.are.equal("Spare", GameTooltip._text)
      assert.is_true(tooltipHasLine("No bag in this slot"))
      assert.is_true(tooltipHasLine("Drop a bag here to use this tab"))
      assert.is_false(tooltipHasLine("4 of 16 slots free"))
    end)

    it("shows the base tab's free slots without bag hints", function()
      local panel = newPanel()
      local button = panel.buttons[1].viewButton
      button:GetScript("OnEnter")(button)
      assert.is_nil(GameTooltip._bagItem)
      assert.are.equal("Base", GameTooltip._text)
      assert.is_true(tooltipHasLine("4 of 16 slots free"))
      assert.is_false(tooltipHasLine("Drag to remove this bag"))
      assert.is_false(tooltipHasLine("Drop a bag here to use this tab"))
    end)

    it("redraws when a bank bag socket changes, only on Forever", function()
      local registered = {}
      local oldRegisterEvent = events.RegisterEvent
      events.RegisterEvent = function(_, event) registered[event] = true end
      newPanel()
      events.RegisterEvent = oldRegisterEvent
      assert.is_true(registered["PLAYERBANKSLOTS_CHANGED"])
      assert.is_true(registered["BAG_CONTAINER_UPDATE"])

      addon.isForever = false
      registered = {}
      events.RegisterEvent = function(_, event) registered[event] = true end
      newPanel()
      events.RegisterEvent = oldRegisterEvent
      assert.is_nil(registered["PLAYERBANKSLOTS_CHANGED"])
      assert.is_nil(registered["BAG_CONTAINER_UPDATE"])
    end)
  end)
end)
