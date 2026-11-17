-- gamepad_spec.lua -- BetterBags on WoW: Forever's gamepad interface (integrations/gamepad.lua, .claude/rules/gamepad.md):
-- each open bag window joins Blizzard's window handling, so its d-pad cursor reaches the window's buttons and the
-- triggers move between windows; the cursor lands on what the window marks it may, inside a native scroll frame; X
-- uses the item the cursor is on, B closes; Blizzard's legend and trigger hints show; the radial menu's Bags opens
-- the bags; all of it follows the player switching between the gamepad and the mouse, and waits out the combat
-- restriction. The gamepad interface is the mock of spec/helpers/gamepad.lua, ported from Blizzard's.
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local Gamepad = dofile("spec/helpers/gamepad.lua")

LoadBetterBagsModule("core/context.lua")
LoadBetterBagsModule("render/render.lua")
LoadBetterBagsModule("render/drawable.lua")
LoadBetterBagsModule("render/scrollbox.lua")

local createdStubs = {}
local function trackStub(name)
  local mod, created = StubBetterBagsModule(name)
  if created then table.insert(createdStubs, name) end
  return mod
end

local events = trackStub("Events")

local replaced = {}
local function override(tbl, key, value)
  table.insert(replaced, { tbl, key, rawget(tbl, key) })
  tbl[key] = value
end

ResetModuleStub("Gamepad", "integrations/gamepad.lua")
LoadBetterBagsModule("integrations/gamepad.lua")
local gamepad = addon:GetModule("Gamepad")
local render = addon:GetModule("Render")
local drawable = addon:GetModule("Drawable")
local scrollbox = addon:GetModule("Scrollbox")

describe("Gamepad (WoW: Forever's gamepad interface)", function()
  local gp, handlers, sneaky

  -- fire sends a WoW event to the module, as the events module does (the callback gets a context and the event).
  local function fire(name, ...)
    for _, cb in ipairs(handlers[name] or {}) do
      cb(addon:GetModule("Context"):New(name), name, ...)
    end
  end

  local function script(frame, name)
    local handler = frame:GetScript(name)
    if handler then handler(frame) end
  end

  -- step runs the next frame: the module's driver, while it waits for one.
  local function step()
    local driver = gamepad.driver
    if driver and driver:IsShown() then
      driver:GetScript("OnUpdate")(driver, 0.016)
    end
  end

  -- window builds a bag window as the designs make theirs: a frame with a scroll box (render/scrollbox.lua) whose
  -- content holds an item (its holder, the button that takes the clicks, the decoration behind it) and a section a
  -- drag lifts, a close button and a search box in its header. It slides out as BetterBags Next's panels do: Hide
  -- starts the slide (closing), Finish ends it.
  local function window(name, x)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:Hide()
    frame:_SetRect(x or 0, 0, 300, 400)
    local sb = scrollbox:Create(frame, name .. "Scroll")
    sb.scrollBox:_SetRect(x or 0, 0, 300, 400)
    local content = drawable:Create({})
    content.frame = CreateFrame("Frame", nil, sb.scrollChild)
    function content:GetRenderPlan() return { Plan = { { step = render.SELF } } } end
    function content:Render() return { Width = 300, Height = 400 } end
    sb:SetChild(content)
    -- As its first render shows it.
    content.frame:Show()
    local holder = CreateFrame("Frame", nil, content.frame)
    local item = CreateFrame("ItemButton", name .. "Item", holder)
    item.bbGamepad = "item"
    item:_SetRect((x or 0) + 10, 300, 37, 37)
    local decoration = CreateFrame("ItemButton", name .. "ItemDecoration", holder)
    local section = CreateFrame("Frame", nil, content.frame)
    section:SetSize(200, 20)
    section:SetScript("OnMouseDown", function() end)
    local header = CreateFrame("Button", nil, frame)
    local search = CreateFrame("EditBox", nil, frame)
    local w = { frame = frame, scroll = sb, content = content, item = item, decoration = decoration,
      section = section, header = header, search = search, closing = false, hides = 0 }
    function w:Show()
      self.closing = false
      self.frame:Show()
      script(self.frame, "OnShow")
    end
    function w:Hide()
      self.hides = self.hides + 1
      self.closing = true
    end
    function w:Finish()
      self.closing = false
      self.frame:Hide()
      script(self.frame, "OnHide")
    end
    function w:IsShown() return self.frame:IsShown() end
    function w:IsClosing() return self.closing end
    return w
  end

  -- start gives the module a fresh start on a client with the gamepad interface (style "gamepad" or "mkb").
  local function start(style)
    gp = Gamepad.Install({ style = style or "gamepad" })
    gamepad:Init()
    gamepad:OnEnable()
  end

  local function navigable(frame)
    local out = {}
    for _, entry in ipairs(gp:Navigable(frame)) do
      table.insert(out, entry.button)
    end
    return out
  end

  before_each(function()
    render:Init()
    handlers = {}
    override(events, "RegisterEvent", function(_, name, cb)
      handlers[name] = handlers[name] or {}
      table.insert(handlers[name], cb)
    end)
    _G.__mockOverrideBindings = {}
    _G.__mockInteractions = {}
    sneaky = CreateFrame("Frame")
    sneaky:Hide()
    override(_G, "BetterBagsSneakyFrame", sneaky)
    override(addon, "ToggleAllBags", function() end)
  end)

  after_each(function()
    if gp then
      gp:Restore()
      gp = nil
    end
    _G.ClearCursor()
    for i = #replaced, 1, -1 do replaced[i][1][replaced[i][2]] = replaced[i][3] end
    replaced = {}
  end)

  teardown(function()
    ResetModuleStub("Gamepad", "integrations/gamepad.lua")
    for i = #createdStubs, 1, -1 do ResetModuleStub(createdStubs[i]) end
  end)

  it("does nothing on a client without Blizzard's gamepad interface", function()
    gamepad:Init()
    gamepad:OnEnable()
    local w = window("SpecNoGamepad")
    assert.are.equal("unavailable", gamepad:Add(w))
    assert.is_nil(gamepad.driver)
    assert.are.same({ available = false }, gamepad:Dump())
  end)

  describe("an open window", function()
    it("joins Blizzard's window handling a frame after it opens, the cursor on its item", function()
      start()
      local w = window("SpecBag")
      assert.are.equal("added", gamepad:Add(w))
      assert.are.equal("already", gamepad:Add(w))
      w:Show()
      assert.are.same({}, gp.manager.shownFrames, "not before its content is laid out")
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
      assert.are.equal(w.frame, gp.nav:GetActiveFrame())
      assert.are.equal(w.item, gp.nav:GetCurrentButton())
      assert.are.equal(0, gp.blocked)
    end)

    it("lets the cursor land only on its items, each in a native scroll frame", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      assert.are.same({ w.item }, navigable(w.frame))
      local found = gp:Navigable(w.frame)[1].scrollFrame
      assert.are.equal(w.scroll.navFrame, found)
      assert.is_true(found:IsObjectType("ScrollFrame"))
    end)

    it("leaves Blizzard's window handling as it starts to close, and when it hides at once", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      w:Hide()
      step()
      assert.are.same({}, gp.manager.shownFrames, "sliding out")
      w:Show()
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames, "opened again as it slid out")
      w.frame:Hide()
      script(w.frame, "OnHide")
      step()
      assert.are.same({}, gp.manager.shownFrames, "hidden at once (Escape)")
    end)

    it("draws its content again: the cursor reaches what it drew", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      local holder = CreateFrame("Frame", nil, w.content.frame)
      local item = CreateFrame("ItemButton", "SpecBagItem2", holder)
      item.bbGamepad = "item"
      CreateFrame("ItemButton", "SpecBagItem2Decoration", holder)
      local root = drawable:Create({})
      root.frame = CreateFrame("Frame")
      function root:GetRenderPlan()
        return { Plan = { { step = render.PRE }, { step = render.DEP, target = w.scroll }, { step = render.SELF } } }
      end
      function root:PreRender() return { MaxHeight = 400 } end
      function root:Render(_, _, results) return results.Results[w.scroll] end
      render:NewRenderChain(root, {})
      step()
      local panel = gp.nav:GetPanelInfo(w.frame, true)
      local inPanel = {}
      for _, info in ipairs(panel.buttonGroups.mainGroup.scrollFrames) do
        for _, b in ipairs(info.buttons) do inPanel[b] = true end
      end
      assert.is_true(inPanel[item], "Blizzard's list of its buttons refreshed")
      assert.are.same({ w.item, item }, navigable(w.frame))
    end)
  end)

  it("takes Blizzard's frames BetterBags stands in for out of Blizzard's window handling", function()
    start()
    local bank = CreateFrame("Frame", "SpecBankFrame", sneaky)
    bank:Hide()
    ShowUIPanel(bank)
    assert.are.same({ bank }, gp.manager.shownFrames, "Blizzard's panel manager hands it over shown")
    step()
    assert.are.same({}, gp.manager.shownFrames)
    local own = CreateFrame("Frame", "SpecOwnPanel", UIParent)
    own:Hide()
    ShowUIPanel(own)
    step()
    assert.are.same({ own }, gp.manager.shownFrames, "a panel that shows is left alone")
  end)

  describe("the combat restriction", function()
    it("waits for it to end to join, without Blizzard's refusal", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      gp:SetCombat(true)
      w:Show()
      step()
      assert.are.same({}, gp.manager.shownFrames)
      assert.are.equal(0, gp.blocked)
      assert.is_false(w.scroll.gamepad == true, "its content stays where it is in combat")
      gp:SetCombat(false)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Inactive)
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
    end)

    -- Found by the bug review: a window left in Blizzard's list through combat and closed then stays there, hidden,
    -- with Blizzard's cursor in it and the face buttons held by its UI. ADDON_RESTRICTION_STATE_CHANGED comes before the
    -- restriction (Activating), while Blizzard still takes an addon's calls: every window leaves then, its cursor panel
    -- forgotten, and joins again after.
    it("leaves Blizzard's window list as it comes, while Blizzard still takes the calls, and joins again after", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      assert.are.same({}, gp.manager.shownFrames, "at once, not a frame later")
      assert.is_nil(gp.nav:GetPanelInfo(w.frame, true), "Blizzard's cursor forgets it")
      assert.is_false(w.frame.bbGamepadLegend:IsShown())
      assert.are.equal(0, gp.blocked)
      gp:SetCombat(true)
      -- PLAYER_REGEN_DISABLED after the restriction is on asks nothing Blizzard would refuse.
      fire("PLAYER_REGEN_DISABLED")
      step()
      assert.are.same({}, gp.manager.shownFrames, "out of the list in combat")
      assert.are.equal(0, gp.blocked)
      gp:SetCombat(false)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Inactive)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
    end)

    it("leaves at PLAYER_REGEN_DISABLED too, while the restriction is not on yet, and stays out until combat ends", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      fire("PLAYER_REGEN_DISABLED")
      assert.are.same({}, gp.manager.shownFrames)
      assert.are.equal(0, gp.blocked)
      step()
      assert.are.same({}, gp.manager.shownFrames, "not back the next frame, before the restriction is on")
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
    end)

    -- Found by the second review: Blizzard clears the trigger hints only on the windows still in its list.
    it("hides the trigger hints of the windows it takes out", function()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      assert.is_true(left.frame.bbGamepadHints.left:IsShown())
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      for _, w in ipairs({ left, right }) do
        for which, hint in pairs(w.frame.bbGamepadHints) do
          assert.is_false(hint:IsShown(), w.frame:GetName() .. " " .. which)
        end
      end
    end)

    -- Found by the second review: what a window drew while out of the list in combat was never marked.
    it("marks what a window drew in combat when it joins again", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      local holder = CreateFrame("Frame", nil, w.content.frame)
      local loot = CreateFrame("ItemButton", "SpecLoot", holder)
      loot.bbGamepad = "item"
      CreateFrame("ItemButton", "SpecLootDecoration", holder)
      local section = CreateFrame("Frame", "SpecNewSection", w.content.frame)
      section:SetSize(200, 20)
      section:SetScript("OnMouseDown", function() end)
      gamepad:OnRendered(gamepad.byFrame[w.frame])
      step()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.same({ w.item, loot }, navigable(w.frame))
    end)

    -- Found by the second review: Blizzard's cursor forgets a window as it leaves; the button it was on is given back.
    it("puts the cursor back where it was after combat", function()
      start()
      local w = window("SpecBag")
      local second = CreateFrame("ItemButton", "SpecBagSecond", w.content.frame)
      second.bbGamepad = "item"
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(second)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.equal(second, gp.nav:GetCurrentButton())
    end)

    -- Found by the third review: a place kept for a window that closed in the fight steered the cursor on a later open.
    it("forgets the place when the window closes in combat", function()
      start()
      local w = window("SpecBag")
      local second = CreateFrame("ItemButton", "SpecBagSecond", w.content.frame)
      second.bbGamepad = "item"
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(second)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      w:Hide()
      w:Finish()
      step()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      w:Show()
      step()
      assert.are.equal(w.item, gp.nav:GetCurrentButton(), "a fresh open starts at the first item")
    end)

    it("starts on the first item when the button it was on went in the fight", function()
      start()
      local w = window("SpecBag")
      local second = CreateFrame("ItemButton", "SpecBagSecond", w.content.frame)
      second.bbGamepad = "item"
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(second)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      second:Hide()
      step()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.equal(w.item, gp.nav:GetCurrentButton())
    end)

    -- Found by the third review: the windows joined in the order they were added, so the last took the focus.
    it("gives the focus back to the window that had it, and each window its place", function()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      local leftSecond = CreateFrame("ItemButton", "SpecBankSecond", left.content.frame)
      leftSecond.bbGamepad = "item"
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      gp.manager:FocusPreviousFrame()
      gp.nav:SelectButton(leftSecond)
      gp.manager:FocusNextFrame()
      gp.manager:FocusPreviousFrame()
      assert.are.equal(left.frame, gp.manager:GetActiveFrame())
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      local dump = gamepad:Dump()
      assert.are.equal("SpecBank", dump.combatFocus, "what the dump shows in the fight")
      assert.are.equal("SpecBankSecond", dump.windows[1].lastButton)
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.equal(left.frame, gp.manager:GetActiveFrame())
      assert.are.equal(leftSecond, gp.nav:GetCurrentButton())
    end)

    -- left and right windows, the cursor on a second item in the left one: the window added first, so the focus is not
    -- the one Blizzard gives by itself.
    local function focusedLeft()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      local leftSecond = CreateFrame("ItemButton", "SpecBankSecond", left.content.frame)
      leftSecond.bbGamepad = "item"
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      gp.manager:FocusPreviousFrame()
      gp.nav:SelectButton(leftSecond)
      return left, right, leftSecond
    end

    local function endCombat()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
    end

    -- Found by the fourth review: a window only sliding out counted as closed, and lost its place and the focus though
    -- it was opened again before it hid.
    it("keeps the place and the focus of a window opened again as it slid out in the fight", function()
      local left, _, leftSecond = focusedLeft()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      left:Hide()
      step()
      left:Show()
      step()
      endCombat()
      assert.are.equal(left.frame, gp.manager:GetActiveFrame())
      assert.are.equal(leftSecond, gp.nav:GetCurrentButton())
    end)

    it("forgets the focus of a window that closed in the fight", function()
      local left, right = focusedLeft()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      for _, w in ipairs({ left, right }) do
        w:Hide()
        w:Finish()
      end
      step()
      endCombat()
      left:Show()
      right:Show()
      step()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame(), "as Blizzard gives it, to the window added last")
    end)

    it("keeps the focus through both of combat's events, in either order", function()
      local left = focusedLeft()
      fire("PLAYER_REGEN_DISABLED")
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      endCombat()
      assert.are.equal(left.frame, gp.manager:GetActiveFrame())
    end)

    it("drops the kept focus once it gives it back, so a later fight starting on a Blizzard panel does not steer it", function()
      local _, right = focusedLeft()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      endCombat()
      local panel = CreateFrame("Frame", "SpecBlizzardPanel", UIParent)
      panel:Hide()
      ShowUIPanel(panel)
      step()
      assert.are.equal(panel, gp.manager:GetActiveFrame())
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      endCombat()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame(), "the window added last, as Blizzard gives it")
    end)

    it("forgets the place and the focus when the player switches to the mouse in the fight", function()
      local left, right = focusedLeft()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      gp:SetStyle("mkb")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Mkb, Enum.InputDeviceInterfaceType.Gamepad)
      step()
      endCombat()
      gp:SetStyle("gamepad")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Gamepad, Enum.InputDeviceInterfaceType.Mkb)
      step()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame())
      gp.manager:FocusPreviousFrame()
      assert.are.equal(left.item, gp.nav:GetCurrentButton())
    end)

    it("keeps the place in a window the cursor was not in", function()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      local leftSecond = CreateFrame("ItemButton", "SpecBankSecond", left.content.frame)
      leftSecond.bbGamepad = "item"
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      gp.manager:FocusPreviousFrame()
      gp.nav:SelectButton(leftSecond)
      gp.manager:FocusNextFrame()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame())
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      step()
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame())
      gp.manager:FocusPreviousFrame()
      assert.are.equal(leftSecond, gp.nav:GetCurrentButton())
    end)

    it("takes out a panel BetterBags stands in for, handed over that frame, as combat comes", function()
      start()
      local bank = CreateFrame("Frame", "SpecBankFrame", sneaky)
      bank:Hide()
      ShowUIPanel(bank)
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      assert.are.same({}, gp.manager.shownFrames)
      assert.are.same({}, gamepad:Dump().replaced)
    end)

    -- What is left (gamepad.md §10): Blizzard's cursor hooked the window's OnHide when it first came in, and that hook asks
    -- to forget it from whatever code hid it; a close from BetterBags' code in combat is refused (once a session, a chat
    -- line). The window is out of Blizzard's list by then.
    it("leaves only Blizzard's own hook to ask, once, when the window closes in combat", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Combat, Enum.AddOnRestrictionState.Activating)
      gp:SetCombat(true)
      w:Hide()
      w:Finish()
      step()
      assert.are.same({}, gp.manager.shownFrames)
      assert.are.equal(1, gp.blocked)
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.same({}, gp.manager.shownFrames)
    end)
  end)

  describe("switching between the gamepad and the mouse", function()
    it("puts the window back as the mouse has it, and takes it in again", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(w.item)
      assert.are.equal(1, #_G.__mockOverrideBindings)
      gp:SetStyle("mkb")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Mkb, Enum.InputDeviceInterfaceType.Gamepad)
      step()
      assert.is_false(w.scroll.gamepad)
      assert.are.equal(w.scroll.scrollChild, w.content.frame:GetParent())
      assert.is_false(w.frame.bbGamepadLegend:IsShown())
      assert.is_false(w.frame.bbGamepadHints.left:IsShown())
      assert.are.same({}, _G.__mockOverrideBindings, "X unbound")
      gp:SetStyle("gamepad")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Gamepad, Enum.InputDeviceInterfaceType.Mkb)
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
      assert.is_true(w.scroll.gamepad)
    end)

    -- Found by the bug review: switched to the mouse in combat, the trigger hints stayed until combat ended. Only moving
    -- the content (under secure tab buttons) waits for combat to end.
    it("hides the hints and the legend at once when switched to the mouse in combat, the content put back after", function()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      assert.is_true(left.frame.bbGamepadHints.left:IsShown())
      gp:SetCombat(true)
      gp:SetStyle("mkb")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Mkb, Enum.InputDeviceInterfaceType.Gamepad)
      step()
      assert.is_false(left.frame.bbGamepadHints.left:IsShown())
      assert.is_false(right.frame.bbGamepadLegend:IsShown())
      assert.is_true(right.scroll.gamepad, "the content waits")
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.is_false(right.scroll.gamepad)
      assert.are.equal(right.scroll.scrollChild, right.content.frame:GetParent())
    end)

    it("leaves a window alone on the mouse interface, and takes it in when the gamepad's comes on", function()
      start("mkb")
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      assert.is_nil(w.scroll.navFrame)
      assert.is_nil(w.frame.bbGamepadLegend)
      gp:SetStyle("gamepad")
      fire("INPUT_DEVICE_INTERFACE_TRANSITION", Enum.InputDeviceInterfaceType.Gamepad, Enum.InputDeviceInterfaceType.Mkb)
      step()
      assert.are.same({ w.frame }, gp.manager.shownFrames)
    end)
  end)

  describe("X", function()
    it("right-clicks the item the cursor is on, through a secure button", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      local clicks = {}
      w.item:SetScript("OnClick", function(_, button) table.insert(clicks, button) end)
      local binding = _G.__mockPressBindingKey(GAMEPAD_FACE_LEFT)
      assert.are.equal(gamepad.useButton, binding.owner)
      assert.is_true(binding.priority)
      assert.are.same({ "RightButton" }, clicks)
      assert.are.equal(w.item, gamepad.useButton:GetAttribute("clickbutton2"))
      assert.are.equal("click", gamepad.useButton:GetAttribute("type2"))
    end)

    it("is unbound while the cursor is on anything else", function()
      start()
      local w = window("SpecBag")
      local tab = CreateFrame("Button", nil, w.frame)
      tab.bbGamepad = "tab"
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(w.item)
      assert.are.equal(1, #_G.__mockOverrideBindings, "bound on the item")
      gp.nav:SelectButton(tab)
      assert.are.same({}, _G.__mockOverrideBindings)
    end)

    it("is unbound as combat starts, and bound again after", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      fire("PLAYER_REGEN_DISABLED")
      assert.are.same({}, _G.__mockOverrideBindings)
      gp:SetCombat(true)
      gp.nav:SelectButton(nil)
      gp.nav:SelectButton(w.item)
      gp:SetCombat(false)
      fire("PLAYER_REGEN_ENABLED")
      step()
      assert.are.equal(1, #_G.__mockOverrideBindings)
    end)
  end)

  describe("B", function()
    -- Blizzard falls back to clicking a visible button named like a close button when the handler does not handle B
    -- (SmartNavigation.lua AttemptClose); the handler always does.
    it("puts back an item held, then closes the window as its close button does, handling B itself", function()
      start()
      local w = window("SpecBag")
      local named = CreateFrame("Button", "SpecBagCloseButton", w.frame)
      local namedClicks = 0
      named:SetScript("OnClick", function() namedClicks = namedClicks + 1 end)
      gamepad:Add(w)
      w:Show()
      step()
      _G._cursorHasItem = true
      gp.nav:AttemptClose()
      assert.is_false(CursorHasItem())
      assert.are.equal(0, w.hides)
      assert.is_true(w.frame.SmartNavigationCloseHandler(w.frame))
      assert.are.equal(1, w.hides)
      gp.nav:AttemptClose()
      assert.are.equal(2, w.hides)
      assert.are.equal(0, namedClicks)
    end)

    -- Found by the bug review: a CloseButton an addon sets is a reference Blizzard clicks tainted on purpose
    -- (SmartNavigation.lua AttemptClose), and HideUIPanel refuses that in combat. The window has none: B always closes
    -- it BetterBags' way, and in combat the window is out of Blizzard's list (B never reaches it).
    it("gives the window no CloseButton for Blizzard to press", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      assert.is_nil(w.frame.CloseButton)
    end)
  end)

  describe("the legend (Blizzard's InputPromptLegends)", function()
    local function prompts(w)
      local out = {}
      for _, prompt in ipairs(w.frame.bbGamepadLegend.laidOut) do
        out[prompt.keys[1]] = prompt.text
      end
      return out
    end

    it("shows under the window while it has the cursor: select, use, close", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      local legend = w.frame.bbGamepadLegend
      assert.is_true(legend:IsShown())
      local point, relativeTo, relativePoint = legend:GetPoint(1)
      assert.are.same({ "TOPLEFT", w.frame, "BOTTOMLEFT" }, { point, relativeTo, relativePoint })
      assert.are.same({ [GAMEPAD_FACE_BOTTOM] = ACTION_LABEL_SELECT, [GAMEPAD_FACE_LEFT] = CONTEXT_ACTION_LABEL_USE,
        [GAMEPAD_FACE_RIGHT] = FRAME_ACTION_CLOSE }, prompts(w))
    end)

    it("says what X does at a vendor, and what B does with an item held", function()
      start()
      local w = window("SpecBag")
      gamepad:Add(w)
      w:Show()
      step()
      _G.__mockInteractions[Enum.PlayerInteractionType.Merchant] = true
      fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
      assert.are.equal(CONTEXT_ACTION_LABEL_SELL, prompts(w)[GAMEPAD_FACE_LEFT])
      _G._cursorHasItem = true
      fire("CURSOR_CHANGED")
      assert.are.equal(FRAME_ACTION_BACK, prompts(w)[GAMEPAD_FACE_RIGHT])
    end)

    it("greys out X while combat starts, and leaves it out off an item", function()
      start()
      local w = window("SpecBag")
      local tab = CreateFrame("Button", nil, w.frame)
      tab.bbGamepad = "tab"
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(w.item)
      local legend = w.frame.bbGamepadLegend
      local x
      for _, prompt in ipairs(legend.laidOut) do
        if prompt.keys[1] == GAMEPAD_FACE_LEFT then x = prompt end
      end
      assert.is_not_nil(x, "X shows on an item")
      assert.is_true(x.enabled)
      gamepad.combat = true
      gamepad:UpdateLegends()
      assert.is_false(x.enabled)
      gamepad.combat = false
      gp.nav:SelectButton(tab)
      assert.is_nil(prompts(w)[GAMEPAD_FACE_LEFT])
    end)

    -- Found by the bug review: under the classic bags the tabs hang below the window, and a legend on the window's bottom
    -- covered them (the cursor's tab hidden under it). A window says what the legend goes under (GamepadFooter).
    it("hangs under what the window says is its foot", function()
      start()
      local w = window("SpecBag")
      local foot = CreateFrame("Frame", nil, w.frame)
      function w:GamepadFooter() return foot end
      gamepad:Add(w)
      w:Show()
      step()
      local point, relativeTo, relativePoint = w.frame.bbGamepadLegend:GetPoint(1)
      assert.are.same({ "TOPLEFT", foot, "BOTTOMLEFT" }, { point, relativeTo, relativePoint })
      function w:GamepadFooter() return self.frame end
      gamepad:UpdateLegends()
      point, relativeTo, relativePoint = w.frame.bbGamepadLegend:GetPoint(1)
      assert.are.same({ "TOPLEFT", w.frame, "BOTTOMLEFT" }, { point, relativeTo, relativePoint })
      assert.are.equal(1, w.frame.bbGamepadLegend:GetNumPoints())
    end)

    it("names what a button says it does", function()
      start()
      local w = window("SpecBag")
      local vendorButton = CreateFrame("Button", nil, w.frame)
      vendorButton.bbGamepad = "vendor"
      vendorButton.bbGamepadLabel = function() return "buy" end
      gamepad:Add(w)
      w:Show()
      step()
      gp.nav:SelectButton(vendorButton)
      assert.are.equal(CONTEXT_ACTION_LABEL_BUY, prompts(w)[GAMEPAD_FACE_BOTTOM])
      vendorButton.bbGamepadLabel = function() return "sell" end
      gp.nav:SelectButton(w.item)
      gp.nav:SelectButton(vendorButton)
      assert.are.equal(CONTEXT_ACTION_LABEL_SELL, prompts(w)[GAMEPAD_FACE_BOTTOM])
    end)

    it("hides when another window takes the cursor", function()
      start()
      local left, right = window("SpecBank", 0), window("SpecBag", 600)
      gamepad:Add(left)
      gamepad:Add(right)
      left:Show()
      right:Show()
      step()
      assert.are.equal(right.frame, gp.manager:GetActiveFrame(), "the one shown last, as Blizzard focuses")
      assert.is_true(right.frame.bbGamepadLegend:IsShown())
      assert.is_false(left.frame.bbGamepadLegend:IsShown())
      gp.manager:FocusPreviousFrame()
      assert.is_true(left.frame.bbGamepadLegend:IsShown())
      assert.is_false(right.frame.bbGamepadLegend:IsShown())
    end)
  end)

  it("shows Blizzard's trigger hints on the windows beside the one with the cursor", function()
    start()
    local left, right = window("SpecBank", 0), window("SpecBag", 600)
    gamepad:Add(left)
    gamepad:Add(right)
    left:Show()
    right:Show()
    step()
    assert.are.equal(GAMEPAD_TRIGGER_LEFT, left.frame.bbGamepadHints.left.mappedButtonKey)
    assert.is_true(left.frame.bbGamepadHints.left:IsShown(), "LT reaches the one on the left")
    assert.is_false(right.frame.bbGamepadHints.right:IsShown())
    gp.manager:FocusPreviousFrame()
    assert.are.equal(GAMEPAD_TRIGGER_RIGHT, right.frame.bbGamepadHints.right.mappedButtonKey)
    assert.is_true(right.frame.bbGamepadHints.right:IsShown(), "RT reaches the one on the right")
    assert.is_false(left.frame.bbGamepadHints.left:IsShown())
  end)

  -- Found by the second review: Blizzard clears the hints only on the windows still in its list, so one sliding out kept
  -- its trigger hint.
  it("hides the trigger hints of a window that starts to close", function()
    start()
    local left, right = window("SpecBank", 0), window("SpecBag", 600)
    gamepad:Add(left)
    gamepad:Add(right)
    left:Show()
    right:Show()
    step()
    assert.is_true(left.frame.bbGamepadHints.left:IsShown())
    left:Hide()
    step()
    assert.are.same({ right.frame }, gp.manager.shownFrames)
    assert.is_false(left.frame.bbGamepadHints.left:IsShown())
  end)

  it("scrolls the window's box to show the button the cursor moves to", function()
    start()
    local w = window("SpecBag")
    gamepad:Add(w)
    w:Show()
    step()
    w.scroll.scrollBox._extent = 800
    local holder = CreateFrame("Frame", nil, w.content.frame)
    local low = CreateFrame("ItemButton", "SpecBagLow", holder)
    low.bbGamepad = "item"
    low:_SetRect(10, -100, 37, 37)
    gp.nav:SelectButton(low)
    assert.are.equal(100, w.scroll.scrollBox:GetDerivedScrollOffset())
  end)

  -- Found by the bug review: moving between the classic tabs, which hang below the window, scrolled its content.
  it("leaves the box where it is for a button outside its content (a tab)", function()
    start()
    local w = window("SpecBag")
    local tab = CreateFrame("Button", nil, w.frame)
    tab.bbGamepad = "tab"
    tab:_SetRect(0, -40, 60, 32)
    gamepad:Add(w)
    w:Show()
    step()
    w.scroll.scrollBox._extent = 800
    gp.nav:SelectButton(w.item)
    assert.are.equal(w.item, gp.nav:GetCurrentButton())
    gp.nav:SelectButton(tab)
    assert.are.equal(tab, gp.nav:GetCurrentButton(), "the cursor moved to the tab")
    assert.are.equal(0, w.scroll.scrollBox:GetDerivedScrollOffset())
  end)

  -- Found by the bug review: BetterBags Next's guild bank moves Blizzard's guild bank frame under a tiny frame as it is
  -- shown, then under BetterBagsSneakyFrame a frame later (next/guildbank.lua OnShowUIPanel), so on its first visit it
  -- was not yet a frame BetterBags stands in for when Blizzard's panel manager handed it over.
  it("takes out a frame BetterBags moves out of sight a frame after it shows", function()
    start()
    local tiny = CreateFrame("Frame", nil, UIParent)
    local guild = CreateFrame("Frame", "SpecGuildBankFrame", tiny)
    guild:Hide()
    ShowUIPanel(guild)
    step()
    assert.are.same({ guild }, gp.manager.shownFrames, "still where it shows")
    guild:SetParent(sneaky)
    step()
    assert.are.same({}, gp.manager.shownFrames)
  end)

  it("stops looking at a panel that stays where it shows", function()
    start()
    local own = CreateFrame("Frame", "SpecOwnPanel", CreateFrame("Frame", nil, UIParent))
    own:Hide()
    ShowUIPanel(own)
    for _ = 1, 10 do step() end
    assert.are.same({ own }, gp.manager.shownFrames)
    assert.is_false(gamepad.driver:IsShown(), "no frame left to run")
  end)

  -- The radial menu's Bags (ToggleBackpack_Combined) and its Character (ToggleCharacterAndOpenBags: ToggleBackpack when
  -- Blizzard's own hidden backpack reads closed, to open the bags, then ToggleCharacter). The Bags entry and a Toggle
  -- Backpack key toggle the backpack; the Character entry opens it as Blizzard's ends up open.
  describe("the radial menu (ToggleBackpack_Combined)", function()
    local toggles, asked, backpack

    local function radial()
      start()
      toggles, asked = 0, {}
      backpack = { open = false, closing = false }
      function backpack:IsShown() return self.open end
      function backpack:IsClosing() return self.closing end
      override(addon, "Bags", { Backpack = backpack })
      override(addon, "backpackShouldOpen", nil)
      override(addon, "backpackShouldClose", nil)
      override(addon, "ToggleAllBags", function()
        toggles = toggles + 1
        backpack.open = not backpack.open
      end)
      -- BetterBags' bags/OpenClose (addon.OnUpdate): open or close as asked.
      override(events, "SendMessage", function(_, _, name)
        if name ~= "bags/OpenClose" then return end
        if addon.backpackShouldOpen then
          table.insert(asked, "open")
          backpack.open, backpack.closing = true, false
        elseif addon.backpackShouldClose then
          table.insert(asked, "close")
          backpack.open = false
        end
        addon.backpackShouldOpen, addon.backpackShouldClose = false, false
      end)
      local combined = CreateFrame("Frame", "SpecCombinedBags")
      combined:Hide()
      override(_G, "ContainerFrameCombinedBags", combined)
      -- Enum.BagIndex.Backpack (BagIndexConstantsDocumentation, every client).
      override(Enum, "BagIndex", setmetatable({ Backpack = 0 }, { __index = Enum.BagIndex }))
    end

    -- What the Character entry runs (GamepadRadial.lua ToggleCharacterAndOpenBags).
    local function characterEntry()
      if not IsBagOpen(Enum.BagIndex.Backpack) then
        ToggleBackpack()
      end
      ToggleCharacter("PaperDollFrame")
    end

    it("opens and closes the backpack from the Bags entry", function()
      radial()
      ToggleBackpack_Combined()
      step()
      assert.are.equal(1, toggles)
      assert.is_true(backpack.open)
      ToggleBackpack_Combined()
      step()
      assert.are.equal(2, toggles)
      assert.is_false(backpack.open)
    end)

    -- Found by the bug review: the Character entry closed a backpack BetterBags had opened itself.
    it("leaves a backpack BetterBags opened itself open when the Character entry asks for the bags", function()
      radial()
      backpack.open = true
      characterEntry()
      step()
      assert.are.equal(0, toggles)
      assert.are.same({}, asked)
      assert.is_true(backpack.open)
    end)

    it("opens a closed backpack when the Character entry asks for the bags", function()
      radial()
      characterEntry()
      step()
      assert.are.same({ "open" }, asked)
      assert.are.equal(0, toggles)
      assert.is_true(backpack.open)
    end)

    -- Found by the second review: a backpack sliding out counts as closed, and a toggle closed it again.
    it("opens a backpack sliding out when the Character entry asks for the bags", function()
      radial()
      backpack.open, backpack.closing = true, true
      characterEntry()
      step()
      assert.are.same({ "open" }, asked)
      assert.is_false(backpack.closing)
    end)

    it("toggles from the Bags entry whatever Blizzard's own backpack reads", function()
      radial()
      backpack.open = true
      ToggleBackpack_Combined()
      step()
      assert.is_false(backpack.open, "Blizzard's opened, BetterBags' closed")
    end)

    -- Found by the second review: a Toggle Backpack key calls ToggleBackpack too, and following Blizzard's backpack
    -- made its first press do nothing once the two disagreed.
    it("toggles from a Toggle Backpack key whatever Blizzard's own backpack reads", function()
      radial()
      backpack.open = true
      ToggleBackpack()
      step()
      assert.are.equal(1, toggles)
      assert.is_false(backpack.open)
    end)

    it("reads each frame's calls afresh", function()
      radial()
      characterEntry()
      step()
      assert.is_true(backpack.open)
      backpack.open = false
      ToggleBackpack_Combined()
      step()
      assert.is_true(backpack.open, "the Bags entry toggles, though Blizzard's now reads closed")
    end)

    -- Found by the third review: a ToggleCharacter flag left from an earlier frame made a Toggle Backpack key follow
    -- Blizzard's backpack.
    it("toggles from a Toggle Backpack key a frame after the character pane opened", function()
      radial()
      ToggleCharacter("PaperDollFrame")
      step()
      backpack.open = true
      ToggleBackpack()
      step()
      assert.are.equal(1, toggles)
      assert.is_false(backpack.open)
    end)

    it("leaves Blizzard's ToggleAllBags, which calls it, to BetterBags' own hook", function()
      radial()
      ToggleAllBags()
      step()
      assert.are.equal(0, toggles)
      ToggleBackpack_Combined()
      step()
      assert.are.equal(1, toggles, "a press frames later still acts")
    end)

    it("does nothing on the mouse interface", function()
      radial()
      gp:SetStyle("mkb")
      gamepad.on = false
      ToggleBackpack_Combined()
      step()
      assert.are.equal(0, toggles)
    end)
  end)

  it("dumps what it knows for /bbdb", function()
    start()
    local w = window("SpecBag")
    gamepad:Add(w)
    w:Show()
    step()
    local dump = gamepad:Dump()
    assert.is_true(dump.available)
    assert.is_true(dump.on)
    assert.are.equal("SpecBagItem", dump.current)
    assert.are.equal("item", dump.currentKind, "what it is, for an unnamed button")
    assert.are.equal("SpecBagItem", dump.bound)
    assert.are.same({ "SpecBag" }, dump.shown)
    assert.are.equal("SpecBag", dump.focused)
    assert.are.same({ { name = "SpecBag", shown = true, closing = false, registered = true, focused = true,
      prepared = true, navFrame = true } }, dump.windows)
    assert.are.same({}, dump.replaced)
  end)
end)
