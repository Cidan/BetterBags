-- gamepad_spec.lua -- BetterBags on WoW: Forever's gamepad interface, the whole addon (spec/helpers/whole_addon.lua) with
-- Blizzard's gamepad UI mocked from its source (spec/helpers/gamepad.lua): the real bag windows of both designs join
-- Blizzard's window list as they open, the cursor reaches only what the windows mark for it, inside native scroll
-- frames, the player can switch between the gamepad and the mouse at any time, Blizzard's bank frame BetterBags stands
-- in for is taken out of the list, and the radial menu's Bags opens the backpack once (integrations/gamepad.lua,
-- .claude/rules/gamepad.md).
local WholeAddon = dofile("spec/helpers/whole_addon.lua")

describe("the gamepad interface on the whole addon (WoW: Forever)", function()
  local handle

  after_each(function()
    if handle then
      handle:Restore()
      handle = nil
    end
  end)

  local function start(opts)
    opts = opts or {}
    opts.client = "forever"
    handle = WholeAddon.Load(opts)
    handle:Start()
    assert.are.same({}, handle.errors, "starting")
    return handle.addon
  end

  local function ctx(addon)
    return addon:GetModule("Context"):New("spec")
  end

  -- step runs the next frame of the gamepad support's driver.
  local function step(addon)
    local driver = addon:GetModule("Gamepad").driver
    if driver:IsShown() then
      driver:GetScript("OnUpdate")(driver, 0.016)
    end
  end

  local function fire(addon, name, ...)
    local entry = addon:GetModule("Events")._eventMap[name]
    if entry then entry.fn(name, ...) end
  end

  -- found lists what Blizzard's navigation finds in a frame, before it sorts out what it may land on.
  local function found(frame)
    local groups = handle.gamepad.FindButtonGroups(frame).mainGroup
    local out = {}
    for _, b in ipairs(groups.buttons) do table.insert(out, b) end
    for _, info in ipairs(groups.scrollFrames) do
      for _, b in ipairs(info.buttons) do table.insert(out, b) end
    end
    return out
  end

  for _, design in ipairs({ "classic", "next" }) do
    describe("with the " .. design .. " bags", function()
      it("opens the backpack into Blizzard's window list, the cursor reaching only what the bag marks", function()
        local addon = start({ gamepad = true, next = design == "next" })
        local backpack = addon.Bags.Backpack
        backpack:Show(ctx(addon))
        step(addon)
        assert.are.same({ backpack.frame }, handle.gamepad.manager.shownFrames)
        assert.are.equal(backpack.frame, handle.gamepad.nav:GetActiveFrame())
        assert.is_true(#found(backpack.frame) > 0, "the window has controls Blizzard's navigation finds")
        local navigable = handle.gamepad:Navigable(backpack.frame)
        assert.is_true(#navigable > 0, "the cursor has somewhere to land (the tabs: the mocks draw no item buttons)")
        for _, entry in ipairs(navigable) do
          assert.is_not_nil(entry.button.bbGamepad, "only a marked button: " .. tostring(entry.button:GetName()))
        end
        -- The content hangs in the native scroll frame, and nothing the cursor can land on is in the addon-built box
        -- itself (moving there would scroll it). BetterBags Next's own scroll bar is in it, marked ignored.
        assert.are.equal(backpack.scroll.navFrame, backpack.scroll:GetChild().frame:GetParent())
        local inBox = {}
        for _, info in ipairs(handle.gamepad.FindButtonGroups(backpack.frame).mainGroup.scrollFrames) do
          if info.scrollFrame == backpack.scroll.scrollBox then
            for _, b in ipairs(info.buttons) do
              if not SmartNavigation_IsFrameIgnored(b) then table.insert(inBox, b) end
            end
          end
        end
        assert.are.same({}, inBox)
        assert.are.equal(0, handle.gamepad.blocked)
        assert.are.same({}, handle.errors)
      end)

      it("follows the player to the mouse and back while the backpack is open", function()
        local addon = start({ gamepad = true, next = design == "next" })
        local backpack = addon.Bags.Backpack
        backpack:Show(ctx(addon))
        step(addon)
        handle.gamepad:SetStyle("mkb")
        fire(addon, "INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Mkb,
          Enum.InputDeviceInterfaceType.Gamepad)
        step(addon)
        assert.is_false(backpack.scroll.gamepad)
        assert.are.equal(backpack.scroll.scrollChild, backpack.scroll:GetChild().frame:GetParent())
        handle.gamepad:SetStyle("gamepad")
        fire(addon, "INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Gamepad,
          Enum.InputDeviceInterfaceType.Mkb)
        step(addon)
        assert.are.same({ backpack.frame }, handle.gamepad.manager.shownFrames)
        assert.are.equal(backpack.scroll.navFrame, backpack.scroll:GetChild().frame:GetParent())
        backpack:Hide(ctx(addon))
        step(addon)
        assert.are.same({}, handle.gamepad.manager.shownFrames)
        assert.are.same({}, handle.errors)
      end)

      it("opens and closes the backpack from the radial menu, once with Blizzard's ToggleAllBags", function()
        local addon = start({ gamepad = true, next = design == "next" })
        local backpack = addon.Bags.Backpack
        ToggleBackpack_Combined()
        step(addon)
        assert.is_true(backpack:IsShown() and not backpack:IsClosing(), "the radial's Bags opens it")
        ToggleBackpack_Combined()
        step(addon)
        assert.is_true(not backpack:IsShown() or backpack:IsClosing(), "and closes it")
        -- The slide out ends (BetterBags Next's panels; the classic window has no fade by default).
        local tween = addon:GetModule("NextTween")
        for _ = 1, 100 do
          local update = tween.driver and tween.driver:GetScript("OnUpdate")
          if update == nil or not backpack:IsShown() then break end
          update(tween.driver, 0.05)
        end
        assert.is_false(backpack:IsShown())
        ToggleAllBags()
        step(addon)
        assert.is_true(backpack:IsShown() and not backpack:IsClosing(), "ToggleAllBags opens it, not twice")
        assert.are.same({}, handle.errors)
      end)
    end)
  end

  -- Found by the second review: the radial's Character entry, while the backpack slid out, left it closing.
  it("reopens BetterBags Next's backpack sliding out when the radial's Character entry asks for the bags", function()
    local addon = start({ gamepad = true, next = true })
    local backpack = addon.Bags.Backpack
    ToggleBackpack_Combined()
    step(addon)
    ToggleBackpack_Combined()
    step(addon)
    assert.is_true(backpack:IsShown() and backpack:IsClosing(), "sliding out")
    if not IsBagOpen(Enum.BagIndex.Backpack) then
      ToggleBackpack()
    end
    ToggleCharacter("PaperDollFrame")
    step(addon)
    assert.is_true(backpack:IsShown())
    assert.is_false(backpack:IsClosing())
    assert.are.same({}, handle.errors)
  end)

  -- Found by the bug review: the classic bags' tabs hang below the window (frames/tabs.lua), and the legend on the window's
  -- bottom covered them.
  it("hangs the classic backpack's legend under its tabs, and under the window when they are hidden", function()
    local addon = start({ gamepad = true })
    local backpack = addon.Bags.Backpack
    backpack:Show(ctx(addon))
    step(addon)
    local legend = backpack.frame.bbGamepadLegend
    assert.is_true(legend:IsShown())
    assert.is_true(backpack.tabs.frame:IsShown())
    local _, relativeTo = legend:GetPoint(1)
    assert.are.equal(backpack.tabs.frame, relativeTo)
    backpack.tabs.frame:Hide()
    addon:GetModule("Gamepad"):UpdateLegends()
    _, relativeTo = legend:GetPoint(1)
    assert.are.equal(backpack.frame, relativeTo)
    assert.are.same({}, handle.errors)
  end)

  it("takes Blizzard's bank frame, which BetterBags stands in for, out of Blizzard's window list", function()
    local addon = start({ gamepad = true })
    assert.are.equal(_G.BetterBagsSneakyFrame, BankFrame:GetParent())
    BankFrame:Hide()
    ShowUIPanel(BankFrame)
    step(addon)
    assert.are.same({}, handle.gamepad.manager.shownFrames)
    assert.are.same({}, handle.errors)
  end)

  it("leaves every window as it is on the mouse interface", function()
    local addon = start({ next = true })
    local backpack = addon.Bags.Backpack
    backpack:Show(ctx(addon))
    step(addon)
    assert.are.same({}, handle.gamepad.manager.shownFrames)
    assert.is_nil(backpack.scroll.navFrame)
    assert.are.same({}, handle.errors)
  end)
end)
