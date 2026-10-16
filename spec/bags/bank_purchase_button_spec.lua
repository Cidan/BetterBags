-- bank_purchase_button_spec.lua -- The "Purchase Bank" button shown in the middle of the bank
-- while the character owns no character bank tab.
--
-- On WoW: Forever the first character bank tab is free, but only Blizzard's own bank window
-- buys it (BankFrameMixin:PurchaseFirstSlot, run from BankFrame's OnShow,
-- Blizzard_UIPanels_Game/Camelot/BankFrame.lua). BetterBags hides that window, and
-- C_Bank.PurchaseBankTab is protected (HasRestrictions, BankDocumentation.lua), so the bank
-- opened empty and the tab could only be bought from the Show Bags panel. The button goes
-- through Blizzard's BankPanelPurchaseButtonScriptTemplate, like the slots panel's purchase
-- buttons (frames/bankslots.lua): its own OnClick opens Blizzard's purchase dialog.

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local aceAddon = LibStub("AceAddon-3.0")

describe("Bank Purchase Bank button", function()
  local moduleNames = {
    "Localization", "Constants", "Events", "Items", "Database",
    "MoneyFrame", "Tabs", "Groups", "Context", "ContextMenu", "BankBehavior", "BankSlots"
  }
  local oldModules, oldAddons = {}, {}
  local savedCreateFrame, savedBagIndex, savedBankPanel, savedSetType, savedTrigger
  local createdFrames
  local registeredEvents
  local const
  local bag, behavior

  local CHARACTER_GROUP, WARBANK_GROUP = 2, 3

  local function newContext()
    return { Copy = function(self) return self end, Set = function() end }
  end

  -- The bank state a fresh character has at the banker: no character tab, the first one
  -- purchasable for free.
  local function noCharacterTab()
    _G._purchasedBankTabs[Enum.BankType.Character] = 0
    _G._nextPurchasableBankTab[Enum.BankType.Character] = {
      tabCost = 0, canAfford = true, purchasePromptTitle = "", purchasePromptBody = "",
      purchasePromptConfirmation = "",
    }
  end

  local function oneCharacterTab()
    _G._purchasedBankTabs[Enum.BankType.Character] = 1
    _G._nextPurchasableBankTab[Enum.BankType.Character] = {
      tabCost = 100000, canAfford = true, purchasePromptTitle = "", purchasePromptBody = "",
      purchasePromptConfirmation = "",
    }
  end

  before_each(function()
    for _, name in ipairs(moduleNames) do
      oldModules[name] = addon.modules[name]
      oldAddons[name] = aceAddon.addons["BetterBags_" .. name]
      addon.modules[name] = nil
      aceAddon.addons["BetterBags_" .. name] = nil
    end

    savedCreateFrame = _G.CreateFrame
    createdFrames = {}
    _G.CreateFrame = function(frameType, name, parent, template)
      local frame = savedCreateFrame(frameType, name, parent, template)
      table.insert(createdFrames, { frame = frame, frameType = frameType, template = template })
      return frame
    end

    -- Live retail bag indices (Blizzard_APIDocumentationGenerated/BagIndexConstantsDocumentation.lua).
    savedBagIndex = _G.Enum.BagIndex
    _G.Enum.BagIndex = {
      Characterbanktab = -2,
      CharacterBankTab_1 = 6,
      AccountBankTab_1 = 12,
    }
    savedBankPanel = _G.BankPanel
    _G.BankPanel = CreateFrame("Frame")
    _G.BankPanel.SetBankType = function() end
    savedSetType, savedTrigger = addon.SetBlizzardBankType, addon.TriggerItemContextChanged
    addon.SetBlizzardBankType = function() end
    addon.TriggerItemContextChanged = function() end
    addon.isRetail = true
    addon.atBank = true

    _G._purchasedBankTabs = {}
    _G._nextPurchasableBankTab = {}

    local L = StubBetterBagsModule("Localization")
    function L:G(key) return key end

    const = StubBetterBagsModule("Constants")
    const.BAG_KIND = { BACKPACK = 0, BANK = 1, UNDEFINED = -1 }
    const.ACCOUNT_BANK_BAGS = { [12] = true }

    registeredEvents = {}
    local events = StubBetterBagsModule("Events")
    function events:SendMessage() end
    function events:RegisterEvent(event, fn) registeredEvents[event] = fn end
    function events:RegisterMessage() end

    local items = StubBetterBagsModule("Items")
    function items:GetAllSlotInfo() return { [1] = {} } end

    local database = StubBetterBagsModule("Database")
    database._activeGroup = { [1] = CHARACTER_GROUP }
    function database:SetActiveGroup(kind, groupID) self._activeGroup[kind] = groupID end
    function database:GetActiveGroup(kind) return self._activeGroup[kind] end
    function database:GetShowBankTabs() return false end
    function database:GetEnableBagFading() return false end
    function database:GetGroupsEnabled() return false end

    StubBetterBagsModule("MoneyFrame")
    StubBetterBagsModule("Context")
    StubBetterBagsModule("ContextMenu")

    local tabs = StubBetterBagsModule("Tabs")
    function tabs:Create()
      return {
        frame = CreateFrame("Frame"),
        SetClickHandler = function() end,
        SetTabByID = function() end,
        ResizeAllTabs = function() end,
      }
    end

    local groups = StubBetterBagsModule("Groups")
    groups._groups = {
      [CHARACTER_GROUP] = { id = CHARACTER_GROUP, name = "Bank", bankType = Enum.BankType.Character },
      [WARBANK_GROUP] = { id = WARBANK_GROUP, name = "Warbank", bankType = Enum.BankType.Account },
    }
    function groups:GetGroup(_, groupID) return self._groups[groupID] end

    local bankSlots = StubBetterBagsModule("BankSlots")
    function bankSlots:CreatePanel() return nil end

    ResetModuleStub("BankBehavior", "bags/bank.lua")
    LoadBetterBagsModule("bags/bank.lua")
    local bankBehavior = addon:GetModule("BankBehavior")

    local frame = CreateFrame("Frame")
    frame:Hide()
    bag = {
      kind = 1,
      frame = frame,
      scrollBox = CreateFrame("Frame", nil, frame),
      bankTab = Enum.BagIndex.Characterbanktab,
      moneyFrame = { Update = function() end },
      currentItemCount = 0,
      Hide = function() end,
      SetTitle = function() end,
      Draw = function() end,
      window = {
        Show = function() frame:Show() end,
        Hide = function(_, _, callback) frame:Hide() if callback then callback() end end,
      },
    }
    behavior = bankBehavior:Create(bag)
    behavior:OnCreate(newContext())
    behavior:RegisterEvents()
  end)

  after_each(function()
    _G.CreateFrame = savedCreateFrame
    _G.Enum.BagIndex = savedBagIndex
    _G.BankPanel = savedBankPanel
    addon.SetBlizzardBankType, addon.TriggerItemContextChanged = savedSetType, savedTrigger
    _G._purchasedBankTabs = {}
    _G._nextPurchasableBankTab = {}
    for _, name in ipairs(moduleNames) do
      addon.modules[name] = oldModules[name]
      aceAddon.addons["BetterBags_" .. name] = oldAddons[name]
    end
  end)

  local function creationOf(frame)
    for _, created in ipairs(createdFrames) do
      if created.frame == frame then
        return created
      end
    end
  end

  describe("the button", function()
    it("is created on the bank frame, hidden, by Blizzard's purchase button template", function()
      local button = bag.purchaseBankButton
      assert.is_not_nil(button, "OnCreate must create the Purchase Bank button")
      local created = creationOf(button)
      assert.are.equal("Button", created.frameType)
      assert.is_truthy(created.template:find("BankPanelPurchaseButtonScriptTemplate", 1, true),
        "buying a tab is protected: the click must run Blizzard's template, not ours")
      assert.is_truthy(created.template:find("UIPanelButtonTemplate", 1, true))
      assert.are.equal(bag.frame, button:GetParent())
      assert.is_false(button:IsShown())
    end)

    it("buys a character bank tab through the template's own click handler", function()
      local button = bag.purchaseBankButton
      assert.are.equal(Enum.BankType.Character, button:GetAttribute("overrideBankType"))
      assert.is_nil(button:GetScript("OnClick"),
        "an OnClick of ours would replace the template's and the purchase would be blocked")
    end)

    it("reads Purchase Bank and sits in the middle of the bank's content, above it", function()
      local button = bag.purchaseBankButton
      assert.are.equal("Purchase Bank", button:GetText())
      local point, relativeTo, relativePoint = button:GetPoint(1)
      assert.are.equal("CENTER", point)
      assert.are.equal(bag.scrollBox, relativeTo)
      assert.are.equal("CENTER", relativePoint)
      assert.is_true(button:GetFrameLevel() > bag.scrollBox:GetFrameLevel())
      assert.is_true(button:GetWidth() > button:GetTextWidth())
    end)
  end)

  describe("when it shows", function()
    it("shows when the bank opens and the character owns no character bank tab", function()
      noCharacterTab()
      behavior:OnShow(newContext())
      assert.is_true(bag.purchaseBankButton:IsShown())
    end)

    it("stays hidden when the bank opens and the character owns a character bank tab", function()
      oneCharacterTab()
      behavior:OnShow(newContext())
      assert.is_false(bag.purchaseBankButton:IsShown())
    end)

    it("stays hidden when no character bank tab can be purchased", function()
      _G._purchasedBankTabs[Enum.BankType.Character] = 0
      _G._nextPurchasableBankTab[Enum.BankType.Character] = nil
      behavior:OnShow(newContext())
      assert.is_false(bag.purchaseBankButton:IsShown())
    end)

    it("hides once the tab is purchased (BANK_TABS_CHANGED)", function()
      noCharacterTab()
      behavior:OnShow(newContext())
      assert.is_true(bag.purchaseBankButton:IsShown())

      oneCharacterTab()
      registeredEvents["BANK_TABS_CHANGED"](newContext(), Enum.BankType.Character)
      assert.is_false(bag.purchaseBankButton:IsShown())
    end)

    it("hides while a Warbank group is shown and shows again on the character bank", function()
      noCharacterTab()
      behavior:OnShow(newContext())
      assert.is_true(bag.purchaseBankButton:IsShown())

      behavior:SwitchToGroup(newContext(), WARBANK_GROUP)
      assert.is_false(bag.purchaseBankButton:IsShown(),
        "the button buys a character bank tab; it does not belong over the Warbank")

      behavior:SwitchToGroup(newContext(), CHARACTER_GROUP)
      assert.is_true(bag.purchaseBankButton:IsShown())
    end)

    it("follows the Show Bags tab between the Warbank and the character bank", function()
      noCharacterTab()
      behavior:SwitchToBlizzardTab(newContext(), Enum.BagIndex.AccountBankTab_1)
      assert.is_false(bag.purchaseBankButton:IsShown())

      behavior:SwitchToBlizzardTab(newContext(), Enum.BagIndex.CharacterBankTab_1)
      assert.is_true(bag.purchaseBankButton:IsShown())
    end)

    it("shows on WoW: Forever, which has no Warbank", function()
      const.ACCOUNT_BANK_BAGS = {}
      noCharacterTab()
      behavior:OnShow(newContext())
      assert.is_true(bag.purchaseBankButton:IsShown())
    end)
  end)
end)
