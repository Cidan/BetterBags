-- theme_switch_spec.lua -- Switching BetterBags Next's theme with its effects running, on the whole addon
-- (spec/helpers/whole_addon.lua). A theme's palette names exist only in that theme, so anything that outlives its theme
-- and looks its colors up in the next one fails: restyling a moving ornament did, in game ("the Next theme has no color
-- named LcarsLilac"). SonataNext restyles each widget in a protected call, so such a failure only reaches the error
-- handler.

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("switching BetterBags Next's theme with its effects running", function()
  local handle, timers, methods, setScript

  after_each(function()
    if handle then handle:Restore() end
    if methods then methods.SetScript = setScript end
    handle, timers, methods, setScript = nil, nil, nil, nil
  end)

  it("leaves nothing of the old theme behind, from every theme", function()
    timers = {}
    local updating, tracked = {}, {}
    methods = _G.__mockWidgetMethods
    setScript = methods.SetScript
    methods.SetScript = function(self, name, fn)
      if name == "OnUpdate" and fn and not tracked[self] then
        tracked[self] = true
        table.insert(updating, self)
      end
      return setScript(self, name, fn)
    end
    local gameMenu = CreateFrame("Frame")
    gameMenu:Hide()
    handle = WholeAddon.Load({ next = true, globals = {
      GameMenuFrame = gameMenu,
      C_Container = setmetatable({ GetContainerNumSlots = function() return 0 end }, { __index = _G.C_Container }),
      C_Timer = {
        After = function(delay, fn) table.insert(timers, { delay = delay, fn = fn }) end,
        NewTimer = function(delay, fn)
          local t = { delay = delay, fn = fn }
          function t:Cancel() self.cancelled = true end
          table.insert(timers, t)
          return t
        end,
      },
    } })
    handle:Start()
    local addon = handle.addon

    -- A second of frames: everything shown moves.
    local function play()
      for _ = 1, 30 do
        for _, f in ipairs(updating) do
          local onUpdate = f:GetScript("OnUpdate")
          if onUpdate and f:IsVisible() then onUpdate(f, 1 / 30) end
        end
        local due = timers
        timers = {}
        for _, t in ipairs(due) do
          t.delay = t.delay - 1 / 30
          if t.delay <= 0 then
            if not t.cancelled then t.fn() end
          else
            table.insert(timers, t)
          end
        end
      end
    end

    local refresh = addon:GetModule("Refresh")
    refresh._worldFrame:GetScript("OnEvent")(refresh._worldFrame, "LOADING_SCREEN_DISABLED")
    play()
    local ctx = addon:GetModule("Context"):New("theme switch")
    local engine = addon:GetModule("SonataNext")
    addon.Bags.Backpack:Show(ctx)
    addon:GetModule("NextSettings"):Open("appearance")
    play()
    assert.same({}, handle.errors, "starting")

    local tried = 0
    for key in pairs(engine:GetThemes()) do
      if key ~= "Default" and engine:IsSelectable(key) then
        tried = tried + 1
        engine:ApplyTheme(ctx, key, false)
        play()
        engine:ApplyTheme(ctx, "Default", false)
        play()
        assert.same({}, handle.errors, key)
      end
    end
    assert.is_true(tried > 5, "themes tried: " .. tried)
  end)
end)
