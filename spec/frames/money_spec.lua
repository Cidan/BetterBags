local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

-- Load required modules
LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("core/events.lua")

local events = addon:GetModule("Events")
events:OnInitialize()

-- Stub any missing dependencies
local debug = StubBetterBagsModule("Debug")
debug.Log = function() end

LoadBetterBagsModule("frames/money.lua")
local money = addon:GetModule("MoneyFrame")

describe("Money Frame", function()
  before_each(function()
    _G._playerMoney = 1234567 -- 123 gold, 45 silver, 67 copper
    _G._depositedMoney = 9876543 -- 987 gold, 65 silver, 43 copper
    _G._lastPopupShown = nil
    _G.GameTooltip.lines = {}
    _G.GameTooltip.doubleLines = {}
  end)

  describe("Creation and Initialization", function()
    it("creates standard player money frame correctly", function()
      local m = money:Create(false)
      assert.is_not_nil(m)
      assert.is_not_nil(m.frame)
      assert.is_not_nil(m.overlay)
      assert.is_false(m.warbank)
      assert.are.equal(m.copperButton:GetText(), "67")
      assert.are.equal(m.silverButton:GetText(), "45")
      assert.are.equal(m.goldButton:GetText(), "123")
    end)

    it("creates warbank money frame correctly", function()
      local m = money:Create(true)
      assert.is_not_nil(m)
      assert.is_true(m.warbank)
      assert.are.equal(m.copperButton:GetText(), "43")
      assert.are.equal(m.silverButton:GetText(), "65")
      assert.are.equal(m.goldButton:GetText(), "987")
    end)
  end)

  describe("Update Loop and Formatting", function()
    it("updates copper/silver/gold dynamically when money changes", function()
      local m = money:Create(false)
      _G._playerMoney = 500020 -- 50 gold, 0 silver, 20 copper
      m:Update()
      assert.are.equal(m.goldButton:GetText(), "50")
      assert.are.equal(m.silverButton:GetText(), "0")
      assert.are.equal(m.copperButton:GetText(), "20")
    end)

    it("formats gold above 1000 with thousands separators", function()
      local m = money:Create(false)
      _G._playerMoney = 150000000 -- 15,000 gold
      m:Update()
      assert.are.equal(m.goldButton:GetText(), "15,000")
    end)
  end)

  describe("Event updates", function()
    it("responds to PLAYER_MONEY events", function()
      local m = money:Create(false)
      _G._playerMoney = 777777 -- 77 gold, 77 silver, 77 copper
      events._eventMap["PLAYER_MONEY"].fn()
      assert.are.equal(m.goldButton:GetText(), "77")
      assert.are.equal(m.silverButton:GetText(), "77")
      assert.are.equal(m.copperButton:GetText(), "77")
    end)
  end)

  describe("Mouse Interactions and Popups", function()
    it("shows PICKUP_MONEY popup on left-clicking standard frame", function()
      local m = money:Create(false)
      local onMouseDown = m.overlay:GetScript("OnMouseDown")
      assert.is_not_nil(onMouseDown)
      onMouseDown(m.overlay, "LeftButton")
      assert.is_not_nil(_G._lastPopupShown)
      assert.are.equal(_G._lastPopupShown.name, "PICKUP_MONEY")
    end)

    it("shows BANK_MONEY_WITHDRAW popup on left-clicking warbank frame", function()
      local m = money:Create(true)
      local onMouseDown = m.overlay:GetScript("OnMouseDown")
      onMouseDown(m.overlay, "LeftButton")
      assert.is_not_nil(_G._lastPopupShown)
      assert.are.equal(_G._lastPopupShown.name, "BANK_MONEY_WITHDRAW")
      assert.are.equal(_G._lastPopupShown.args[3].bankType, _G.Enum.BankType.Account)
    end)

    it("shows BANK_MONEY_DEPOSIT popup on right-clicking warbank frame", function()
      local m = money:Create(true)
      local onMouseDown = m.overlay:GetScript("OnMouseDown")
      onMouseDown(m.overlay, "RightButton")
      assert.is_not_nil(_G._lastPopupShown)
      assert.are.equal(_G._lastPopupShown.name, "BANK_MONEY_DEPOSIT")
      assert.are.equal(_G._lastPopupShown.args[3].bankType, _G.Enum.BankType.Account)
    end)
  end)

  describe("Tooltip Interaction", function()
    it("sets standard money tooltip correctly on OnEnter", function()
      local m = money:Create(false)
      local onEnter = m.overlay:GetScript("OnEnter")
      assert.is_not_nil(onEnter)
      onEnter()
      assert.are.equal(_G.GameTooltip._owner, m.overlay)
      assert.are.equal(#_G.GameTooltip.doubleLines, 1)
      assert.are.equal(_G.GameTooltip.doubleLines[1].left, "Left Click")
      assert.are.equal(_G.GameTooltip.doubleLines[1].right, "Pick up money")
    end)

    it("sets warbank money tooltip correctly on OnEnter", function()
      local m = money:Create(true)
      local onEnter = m.overlay:GetScript("OnEnter")
      onEnter()
      assert.are.equal(_G.GameTooltip._owner, m.overlay)
      assert.are.equal(#_G.GameTooltip.doubleLines, 2)
      assert.are.equal(_G.GameTooltip.doubleLines[1].left, "Left Click")
      assert.are.equal(_G.GameTooltip.doubleLines[2].left, "Right Click")
    end)

    it("hides tooltip on OnLeave", function()
      local m = money:Create(false)
      local onLeave = m.overlay:GetScript("OnLeave")
      assert.is_not_nil(onLeave)
      onLeave()
      assert.is_false(_G.GameTooltip._shown)
    end)
  end)
end)
