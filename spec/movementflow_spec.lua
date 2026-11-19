-- movementflow_spec.lua -- Unit tests for util/movementflow.lua

local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local const = StubBetterBagsModule("Constants")

-- Set up constants that movementflow.lua references
const.MOVEMENT_FLOW = {
  UNDEFINED = 0,
  BANK = 1,
  WARBANK = 3,
  SENDMAIL = 4,
  TRADE = 5,
  NPCSHOP = 6,
}

-- Classic's bank tab constants (used when not retail): Blizzard's Enum.BagIndex on Classic Era, The
-- Burning Crusade Anniversary and Mists of Pandaria Classic (Bank -1, Reagentbank -3,
-- AccountBankTab_1 13).
const.BANK_TAB = {
  BANK = -1,
  REAGENT = -3,
  ACCOUNT_BANK_1 = 13,
}

-- Set addon state defaults
addon.isRetail = false
addon.atBank = false
addon.Bags = {}

ResetModuleStub("MovementFlow", "util/movementflow.lua")
LoadBetterBagsModule("util/movementflow.lua")
local movementFlow = addon:GetModule("MovementFlow")

describe("MovementFlow", function()

  before_each(function()
    addon.isRetail = false
    addon.atBank = false
    addon.Bags = {}
    -- Clear any frame globals
    _G["SendMailFrame"] = nil
    _G["TradeFrame"] = nil
    _G["MerchantFrame"] = nil
  end)

  -- ─── Context checks ────────────────────────────────────────────────────────

  describe("AtSendMail", function()

    it("returns false when SendMailFrame doesn't exist", function()
      assert.is_false(movementFlow:AtSendMail())
    end)

    it("returns false when SendMailFrame exists but is not visible", function()
      _G["SendMailFrame"] = { IsVisible = function() return false end }
      assert.is_false(movementFlow:AtSendMail())
    end)

    it("returns true when SendMailFrame is visible", function()
      _G["SendMailFrame"] = { IsVisible = function() return true end }
      assert.is_true(movementFlow:AtSendMail())
    end)
  end)

  describe("AtTradeWindow", function()

    it("returns false when TradeFrame doesn't exist", function()
      assert.is_false(movementFlow:AtTradeWindow())
    end)

    it("returns true when TradeFrame is visible", function()
      _G["TradeFrame"] = { IsVisible = function() return true end }
      assert.is_true(movementFlow:AtTradeWindow())
    end)
  end)

  describe("AtNPCShopWindow", function()

    it("returns false when MerchantFrame doesn't exist", function()
      assert.is_false(movementFlow:AtNPCShopWindow())
    end)

    -- As Blizzard's bag code decides to sell (ContainerFrameItemButton_OnClick: MerchantFrame:IsShown()).
    it("returns true while MerchantFrame is shown, even under a hidden parent (BetterBags Next's vendor)", function()
      local hidden = CreateFrame("Frame")
      hidden:Hide()
      local frame = CreateFrame("Frame", nil, hidden)
      frame:Show()
      _G["MerchantFrame"] = frame
      assert.is_false(frame:IsVisible())
      assert.is_true(movementFlow:AtNPCShopWindow())
      frame:Hide()
      assert.is_false(movementFlow:AtNPCShopWindow())
    end)
  end)

  -- ─── GetMovementFlow ───────────────────────────────────────────────────────

  describe("GetMovementFlow", function()

    it("returns UNDEFINED when not at any special location", function()
      assert.are.equal(const.MOVEMENT_FLOW.UNDEFINED, movementFlow:GetMovementFlow())
    end)

    it("returns BANK when at the bank", function()
      addon.atBank = true
      assert.are.equal(const.MOVEMENT_FLOW.BANK, movementFlow:GetMovementFlow())
    end)

    it("returns SENDMAIL when at the mailbox", function()
      _G["SendMailFrame"] = { IsVisible = function() return true end }
      assert.are.equal(const.MOVEMENT_FLOW.SENDMAIL, movementFlow:GetMovementFlow())
    end)

    it("returns TRADE when at the trade window", function()
      _G["TradeFrame"] = { IsVisible = function() return true end }
      assert.are.equal(const.MOVEMENT_FLOW.TRADE, movementFlow:GetMovementFlow())
    end)

    it("returns NPCSHOP when at a merchant", function()
      _G["MerchantFrame"] = { IsShown = function() return true end }
      assert.are.equal(const.MOVEMENT_FLOW.NPCSHOP, movementFlow:GetMovementFlow())
    end)

    it("prioritizes BANK over SENDMAIL when both are true", function()
      addon.atBank = true
      _G["SendMailFrame"] = { IsVisible = function() return true end }
      assert.are.equal(const.MOVEMENT_FLOW.BANK, movementFlow:GetMovementFlow())
    end)

    it("returns WARBANK for account bank tabs (non-retail)", function()
      addon.atBank = true
      addon.Bags.Bank = { bankTab = 13 }
      assert.are.equal(const.MOVEMENT_FLOW.WARBANK, movementFlow:GetMovementFlow())
    end)

    -- No client has a reagent bank: Blizzard's source for none of them has its frame or its API.
    -- Classic's Enum.BagIndex still names one (Reagentbank, -3).
    it("moves to the bank, never a reagent bank, on Classic's reagent bank index (non-retail)", function()
      addon.atBank = true
      addon.Bags.Bank = { bankTab = const.BANK_TAB.REAGENT }
      assert.are.equal(const.MOVEMENT_FLOW.BANK, movementFlow:GetMovementFlow())
      addon.Bags.Bank = { bankTab = const.BANK_TAB.BANK }
      assert.are.equal(const.MOVEMENT_FLOW.BANK, movementFlow:GetMovementFlow())
    end)

    it("returns regular BANK when bank tab is below account bank start", function()
      addon.atBank = true
      addon.Bags.Bank = { bankTab = 3 }
      assert.are.equal(const.MOVEMENT_FLOW.BANK, movementFlow:GetMovementFlow())
    end)
  end)
end)
