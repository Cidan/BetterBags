-- tradeskillmaster_spec.lua -- the TradeSkillMaster integration (integrations/tradeskillmaster.lua,
-- .claude/rules/tradeskillmaster.md): what BetterBags Next's vendor needs to swap with TSM's own vendor window, against
-- TSM's vendor window as v4.15.6 runs it (spec/helpers/tsm.lua): whether it is up, TSM's saved choice, its switch button
-- on Blizzard's merchant frame, opening the window with it, and following the window while a vendor is open.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local TSM = dofile("spec/helpers/tsm.lua")

LoadBetterBagsModule("core/context.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

trackStub("Events")

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end
local function restore()
  for i = #replaced, 1, -1 do
    replaced[i][1][replaced[i][2]] = replaced[i][3]
  end
  replaced = {}
end

ResetModuleStub("TradeSkillMaster", "integrations/tradeskillmaster.lua")
LoadBetterBagsModule("integrations/tradeskillmaster.lua")
local tradeSkillMaster = addon:GetModule("TradeSkillMaster")

describe("TradeSkillMaster integration", function()
  -- atMerchant opens a merchant as the client does with TSM loaded: the interaction, then the frame TSM waits.
  local function atMerchant(tsm)
    MerchantFrame:Show()
    tsm:MerchantShow()
    tsm:Frame()
  end

  -- look runs what the integration follows each frame (its driver's OnUpdate).
  local function look()
    local update = tradeSkillMaster.driver:GetScript("OnUpdate")
    if update then update(tradeSkillMaster.driver, 1 / 60) end
  end

  before_each(function()
    override(_G, "MerchantFrame", CreateFrame("Frame", "MerchantFrame", UIParent))
    -- Blizzard's own buttons on its merchant frame, and another addon's, none of them TSM's.
    CreateFrame("Button", "MerchantNextPageButton", MerchantFrame)
    CreateFrame("Frame", nil, MerchantFrame)
    CreateFrame("Button", nil, MerchantFrame)
    tradeSkillMaster:Stop()
    tradeSkillMaster.switchButton = nil
  end)

  after_each(function()
    tradeSkillMaster:Stop()
    TSM.Remove()
    restore()
  end)

  teardown(function()
    ResetModuleStub("TradeSkillMaster")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  describe("without TradeSkillMaster", function()
    it("is not there, and asks, clicks and follows nothing", function()
      assert.is_false(tradeSkillMaster:Available())
      assert.is_false(tradeSkillMaster:WindowShown())
      assert.is_false(tradeSkillMaster:ChoosesWindow())
      assert.is_false(tradeSkillMaster:CanSwitch())
      assert.are.equal("no tsm", tradeSkillMaster:OpenWindow())
      assert.is_false(tradeSkillMaster:Follow(function() error("told") end))
      assert.is_nil(tradeSkillMaster.driver:GetScript("OnUpdate"))
    end)
  end)

  describe("with TradeSkillMaster", function()
    it("is there", function()
      TSM.Install(false)
      assert.is_true(tradeSkillMaster:Available())
    end)

    -- TSM_API.IsUIVisible errors when called with a colon (App/API.lua CheckCallMethod). Closed by its close button, TSM's
    -- window is TSM's until the interaction ends.
    it("says whether TSM's vendor window is up", function()
      local tsm = TSM.Install(false)
      assert.is_false(tradeSkillMaster:WindowShown())
      atMerchant(tsm)
      assert.is_true(tradeSkillMaster:WindowShown())
      tsm:CloseWindow()
      assert.is_true(tradeSkillMaster:WindowShown())
      tsm:MerchantHide()
      assert.is_false(tradeSkillMaster:WindowShown())
    end)

    it("reads TSM's saved choice: its own window, its default, or Blizzard's frame its WoW UI button chose", function()
      TSM.Install(false)
      assert.is_true(tradeSkillMaster:ChoosesWindow())
      TSM.Remove()
      TSM.Install(true)
      assert.is_false(tradeSkillMaster:ChoosesWindow())
    end)

    it("reads no choice from settings without TSM's vendor window's", function()
      TSM.Install(false)
      rawset(_G.TradeSkillMasterDB, TSM.KEY, nil)
      assert.is_false(tradeSkillMaster:ChoosesWindow())
    end)

    it("finds TSM's switch button among the merchant frame's children once TSM has made it", function()
      local tsm = TSM.Install(true)
      assert.is_nil(tradeSkillMaster:SwitchButton())
      assert.is_false(tradeSkillMaster:CanSwitch())
      atMerchant(tsm)
      assert.are.equal(tsm.switchButton, tradeSkillMaster:SwitchButton())
      assert.is_true(tradeSkillMaster:CanSwitch())
    end)

    it("finds it again on another merchant frame", function()
      local tsm = TSM.Install(true)
      atMerchant(tsm)
      assert.are.equal(tsm.switchButton, tradeSkillMaster:SwitchButton())
      override(_G, "MerchantFrame", CreateFrame("Frame", "MerchantFrame", UIParent))
      assert.is_nil(tradeSkillMaster:SwitchButton())
    end)

    it("opens TSM's window with TSM's own switch button, which saves the choice as clicking it does", function()
      local tsm = TSM.Install(true)
      atMerchant(tsm)
      assert.are.equal("opened", tradeSkillMaster:OpenWindow())
      assert.is_true(tradeSkillMaster:WindowShown())
      assert.is_false(_G.TradeSkillMasterDB[TSM.KEY])
      assert.are.equal(0, tsm.closes, "the visit goes on")
    end)

    -- TSM's switch flips its choice: clicked while its window is up, it would close the window.
    it("clicks nothing while TSM's window is up", function()
      local tsm = TSM.Install(false)
      atMerchant(tsm)
      assert.are.equal("shown", tradeSkillMaster:OpenWindow())
      assert.is_true(tradeSkillMaster:WindowShown())
      assert.is_false(_G.TradeSkillMasterDB[TSM.KEY])
    end)

    it("has nothing to click before TSM has made its switch button", function()
      TSM.Install(true)
      assert.are.equal("no switch", tradeSkillMaster:OpenWindow())
    end)

    describe("following its window", function()
      it("looks every frame while it follows, telling only what changed", function()
        local tsm = TSM.Install(false)
        local told = 0
        MerchantFrame:Show()
        tsm:MerchantShow()
        assert.is_true(tradeSkillMaster:Follow(function(ctx)
          assert.is_not_nil(ctx)
          told = told + 1
        end))
        look()
        assert.are.equal(0, told, "nothing yet")
        tsm:Frame()
        look()
        assert.are.equal(1, told, "TSM's window showed")
        look()
        assert.are.equal(1, told, "nothing changed")
        tsm:ClickWoWUI()
        look()
        assert.are.equal(2, told, "TSM's window hid, its switch button there")
        tradeSkillMaster:Stop()
        assert.is_nil(tradeSkillMaster.driver:GetScript("OnUpdate"))
      end)

      it("tells when TSM's switch button appears", function()
        local tsm = TSM.Install(true)
        local told = 0
        MerchantFrame:Show()
        tsm:MerchantShow()
        tradeSkillMaster:Follow(function() told = told + 1 end)
        look()
        assert.are.equal(0, told)
        tsm:Frame()
        look()
        assert.are.equal(1, told)
        assert.is_true(tradeSkillMaster:CanSwitch())
      end)

      it("tells what it saw, for profiler traces", function()
        local tsm = TSM.Install(true)
        MerchantFrame:Show()
        tsm:MerchantShow()
        tradeSkillMaster:Follow(function() end)
        assert.are.equal("same", tradeSkillMaster:Look())
        tsm:Frame()
        assert.are.equal("switch", tradeSkillMaster:Look())
        tradeSkillMaster:OpenWindow()
        assert.are.equal("window", tradeSkillMaster:Look())
      end)
    end)
  end)
end)
