-- pawn_spec.lua -- Pawn on the whole addon (spec/helpers/whole_addon.lua): BetterBags registers as a third-party bag once it is
-- enabled, and Pawn's signal runs against the real modules. The integration itself is spec/integrations/pawn_spec.lua, and with
-- items in the bags spec/refresh_pipeline_spec.lua ("Pawn's answers"); the whole addon keeps its bags empty (test-harness.md §5).

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("Pawn on the whole addon", function()
  local handle, registered, timers

  after_each(function()
    if handle then
      handle:Restore()
    end
    -- busted keeps this file's closures, and with them these, for the whole run.
    handle, registered, timers = nil, nil, nil
  end)

  local function load(opts)
    registered, timers = {}, {}
    opts = opts or {}
    opts.globals = {
      C_Container = setmetatable({
        GetContainerNumSlots = function() return 0 end,
      }, { __index = _G.C_Container }),
      C_Timer = {
        After = function(_, fn) table.insert(timers, fn) end,
        NewTimer = function(_, fn)
          table.insert(timers, fn)
          return { Cancel = function() end }
        end,
      },
      PawnShouldItemLinkHaveUpgradeArrow = function() return false end,
      PawnRegisterThirdPartyBag = function(name, overrides)
        table.insert(registered, { name = name, overrides = overrides })
      end,
    }
    handle = WholeAddon.Load(opts)
    handle:Start()
  end

  it("registers as a third-party bag once, and takes over as the provider", function()
    load()
    assert.are.equal(1, #registered, "Pawn prints a failure for a bag registered twice")
    assert.are.equal("BetterBags", registered[1].name)
    assert.are.equal("Pawn", handle.addon:GetModule("Items"):GetActiveUpgradeProvider())
    assert.are.same({}, handle.errors)
  end)

  for _, design in ipairs({ "classic", "next" }) do
    it("takes Pawn's signal with nothing in the bags, in the " .. design .. " bags", function()
      load({ next = design == "next" })
      local items = handle.addon:GetModule("Items")
      local before = items:GetUpgradeGeneration()
      registered[1].overrides.RefreshAll()
      assert.are.equal(before + 1, items:GetUpgradeGeneration())
      assert.are.equal(0, handle.addon:GetModule("Pawn"):Waiting())
      assert.are.same({}, handle.errors)
    end)
  end
end)
