-- logout_spec.lua -- What runs once the player logs out or reloads, on the whole addon
-- (spec/helpers/whole_addon.lua). At PLAYER_LOGOUT AceDB strips every setting still at its default,
-- and every table left empty, from the profile before the saved variables are written, so nothing of
-- BetterBags may read a setting after it (initialization.md §7). Reported: "database.lua:86: attempt
-- to index field 'views' (a nil value)", in GetBagView from the classic backpack window's
-- OnSizeChanged.

local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("logging out on the whole addon", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
    end
    handle = nil
  end)

  -- Runs the scripts the client can still run on a frame as the UI is torn down.
  local function teardown(frame)
    for _, script in ipairs({ "OnSizeChanged", "OnHide" }) do
      local fn = frame:GetScript(script)
      if fn then
        fn(frame)
      end
    end
  end

  it("reads no setting the logout stripped when a classic bag window is resized or hidden after it", function()
    handle = WholeAddon.Load()
    handle:Start()
    local bags = handle.addon.Bags
    handle:Logout()

    -- What the report shows: a profile whose bags kept their default view has none after the logout.
    assert.is_nil(rawget(handle.addon:GetModule("Database").data.profile, "views"))
    teardown(bags.Backpack.frame)
    teardown(bags.Bank.frame)
    assert.same({}, handle.errors)
  end)

  it("reads no setting the logout stripped when a BetterBags Next panel is resized or hidden after it", function()
    handle = WholeAddon.Load({ next = true })
    handle:Start()
    local bags = handle.addon.Bags
    handle:Logout()

    assert.is_nil(rawget(handle.addon:GetModule("Database").data.profile, "views"))
    teardown(bags.Backpack.frame)
    teardown(bags.Bank.frame)
    assert.same({}, handle.errors)
  end)

  it("still runs the scripts of a session that has not logged out", function()
    handle = WholeAddon.Load()
    handle:Start()
    local frame = handle.addon.Bags.Backpack.frame
    local ran = 0
    handle.addon.HookScript(frame, "OnSizeChanged", function() ran = ran + 1 end)
    frame:GetScript("OnSizeChanged")(frame)
    assert.equal(1, ran)

    handle:Logout()
    frame:GetScript("OnSizeChanged")(frame)
    assert.equal(1, ran)
  end)
end)
