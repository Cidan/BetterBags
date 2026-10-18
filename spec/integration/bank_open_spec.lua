-- bank_open_spec.lua -- Opening the bank on the whole addon (spec/helpers/whole_addon.lua), in
-- both designs: the bank's window shows at once, nothing reads the bank until its show animation
-- has finished, then the bank is read once (refresh-scheduler.md §11). Asked: "finish our bank
-- window show animation, before we start loading in bank info, just to prevent hitching".

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("opening the bank on the whole addon", function()
  local handle, timers

  after_each(function()
    if handle then
      handle:Restore()
    end
    handle = nil
  end)

  -- A frame clock: every timer waits until the test runs it.
  local function clock()
    timers = {}
    return {
      After = function(delay, fn)
        table.insert(timers, { delay = delay, fn = fn })
      end,
      NewTimer = function(delay, fn)
        local t = { delay = delay, fn = fn }
        function t:Cancel() self.cancelled = true end
        table.insert(timers, t)
        return t
      end,
    }
  end

  -- frames runs the timers due on the next frame (delay 0), and those they schedule, n frames.
  local function frames(n)
    for _ = 1, n or 40 do
      local due = {}
      for i = #timers, 1, -1 do
        if timers[i].delay == 0 then
          table.insert(due, 1, table.remove(timers, i))
        end
      end
      if #due == 0 then
        return
      end
      for _, t in ipairs(due) do
        if not t.cancelled then t.fn() end
      end
    end
  end

  -- Every bag empty: the frame mock has no ContainerFrameItemButtonTemplate, so no item button
  -- can be drawn on the whole addon (test-harness.md §5); this spec is about when the bank is read.
  local function emptyBags()
    return setmetatable({ GetContainerNumSlots = function() return 0 end }, { __index = _G.C_Container })
  end

  ---@param design "classic"|"next"
  ---@param fading? boolean
  local function start(design, fading)
    local gameMenu = CreateFrame("Frame")
    gameMenu:Hide()
    handle = WholeAddon.Load({
      next = design == "next",
      globals = { C_Timer = clock(), GameMenuFrame = gameMenu, C_Container = emptyBags() },
      profile = function(defaults) defaults.enableBagFading = fading == true end,
    })
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    local addon = handle.addon
    -- The startup read: the loading screen ends, a quiet frame passes, the item data has loaded.
    local refresh = addon:GetModule("Refresh")
    refresh._startupFrame:GetScript("OnEvent")(refresh._startupFrame, "LOADING_SCREEN_DISABLED")
    refresh._startupFrame:GetScript("OnUpdate")(refresh._startupFrame, 0.016)
    frames()
    assert.is_false(refresh._held, "past the startup read")
    return addon
  end

  -- countBankReads counts every harvest of the bank from now on.
  local function countBankReads(addon)
    local items = addon:GetModule("Items")
    local bank = addon:GetModule("Constants").BAG_KIND.BANK
    local counter = { n = 0 }
    local harvest = items.Phase2_Harvest
    items.Phase2_Harvest = function(self, kind, ...)
      if kind == bank then
        counter.n = counter.n + 1
      end
      return harvest(self, kind, ...)
    end
    return counter
  end

  local function openBank(addon)
    addon:GetModule("Events")._eventMap["BANKFRAME_OPENED"].fn("BANKFRAME_OPENED")
    frames()
  end

  it("reads nothing while BetterBags Next's bank slides in, then reads it once", function()
    local addon = start("next")
    local reads = countBankReads(addon)
    local bank = addon.Bags.Bank
    openBank(addon)
    assert.is_true(bank:IsShown(), "the bank shows at once")
    assert.equal("Loading...", bank.emptyText:GetText())
    assert.is_true(bank.emptyText:IsShown())
    local tween = addon:GetModule("NextTween")
    local style = addon:GetModule("NextStyle")
    local slid = 0
    while slid < style.Time.Open * 0.9 do
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.03)
      slid = slid + 0.03
      frames()
      assert.equal(0, reads.n, "nothing reads the bank while it slides in")
    end
    for _ = 1, 4 do
      tween.driver:GetScript("OnUpdate")(tween.driver, 0.03)
    end
    frames()
    assert.equal(1, reads.n, "read once it has slid in")
    assert.are.same({}, handle.errors)
  end)

  it("reads nothing while the classic bank fades in, then reads it once and drops Loading...", function()
    local addon = start("classic", true)
    local reads = countBankReads(addon)
    local bank = addon.Bags.Bank
    openBank(addon)
    local fade = bank.window.showAnimation
    assert.is_true(fade:IsPlaying(), "fading in")
    assert.is_true(bank.loadingText:IsShown(), "Loading... while it waits")
    assert.equal(0, reads.n, "nothing reads the bank while it fades in")
    fade:Finish()
    frames()
    assert.equal(1, reads.n, "read once it has faded in")
    assert.is_false(bank.loadingText:IsShown(), "drawn")
    assert.are.same({}, handle.errors)
  end)

  it("reads the classic bank at once when fading is off, as before", function()
    local addon = start("classic", false)
    local reads = countBankReads(addon)
    openBank(addon)
    assert.equal(1, reads.n)
    assert.are.same({}, handle.errors)
  end)
end)
