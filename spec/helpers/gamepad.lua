-- gamepad.lua -- WoW: Forever's gamepad interface, for specs of BetterBags' gamepad support (integrations/gamepad.lua,
-- .claude/rules/gamepad.md). Ported from the forever branch of wow-ui-source (1.60.1.70938): Blizzard_GamepadSmartNavigation
-- (SecureHelper.lua, Utility.lua, SmartNavigation.lua), Blizzard_GamepadSharedUtility (FrameControlsManager.lua,
-- InputPrompts/InputLegendPromptGroup.lua), Blizzard_SharedXML (Mainline/InputUtil.lua, Shared/GamepadConstants.lua,
-- Shared/InputIcons/InputIconTexture.xml), Blizzard_SharedXMLBase/FocusEffectTemplates.xml, Blizzard_UIPanels_Game/
-- Mainline/ContainerFrame.lua (ToggleBackpack_Combined, ToggleAllBags) and Blizzard_UIParentPanelManager/Shared/
-- UIParentPanelManager.lua (the events ShowUIPanel and HideUIPanel broadcast).
--
-- Every addon load on Forever has these: Blizzard_GamepadSmartNavigation and Blizzard_GamepadSharedUtility load for both
-- interface styles (AllowLoad: Both), Blizzard_Gamepad on the camelot game type. Only the parts BetterBags reaches are
-- ported, as Blizzard wrote them; what is left out is said where it would be.
--
-- Security. In the client the functions SecureHelper wraps (FrameShown, FrameHidden, RefreshButtonGroups,
-- SetTargetButtonForFrame, HandlePanelOpen, the SmartNavigation_* marks) run for an addon only while the combat
-- restriction is off; else Blizzard shows its "Interface action failed" message (DisplayInterfaceActionBlockedMessage)
-- and does nothing. The mock does the same for every call an addon makes, and counts the refusals (handle.blocked).
-- Blizzard's own calls (an event the panel manager broadcasts, the B button) are secure and always run.
--
-- local Gamepad = dofile("spec/helpers/gamepad.lua"); local gp = Gamepad.Install({ style = "gamepad" }).
-- opts.setGlobal / opts.setField put globals and table fields in place with the caller's restorers (the whole-addon
-- helper's); without them gp:Restore() puts everything back.

local Gamepad = {}

-- Enum.InputDeviceInterfaceType (InputConstantsDocumentation), Enum.AddOnRestrictionType and AddOnRestrictionState
-- (RestrictedActionsConstantsDocumentation).
local INTERFACE_TYPE = { Mkb = 0, Gamepad = 1 }
local RESTRICTION_TYPE = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
local RESTRICTION_STATE = { Inactive = 0, Activating = 1, Active = 2 }

-- Blizzard_SharedXML/Shared/GamepadConstants.lua.
local CONSTANTS = {
  GAMEPAD_FACE_RIGHT = "PAD2", GAMEPAD_FACE_BOTTOM = "PAD1", GAMEPAD_FACE_LEFT = "PAD3", GAMEPAD_FACE_TOP = "PAD4",
  GAMEPAD_DPAD = "DIRPAD", GAMEPAD_TRIGGER_LEFT = "PADLTRIGGER", GAMEPAD_TRIGGER_RIGHT = "PADRTRIGGER",
  GAMEPAD_MENU_LEFT = "PADBACK",
}

-- The client's GlobalStrings Blizzard's gamepad UI labels its prompts with (ContainerFrame.lua SetupGamepad,
-- MerchantFrame.lua MerchantFrame_SetupGamepad). Their text is the client's; specs check which one shows.
local STRINGS = { "ACTION_LABEL_SELECT", "CONTEXT_ACTION_LABEL_USE", "CONTEXT_ACTION_LABEL_SELL",
  "CONTEXT_ACTION_LABEL_MOVE", "CONTEXT_ACTION_LABEL_PLACE", "CONTEXT_ACTION_LABEL_BUY", "FRAME_ACTION_CLOSE",
  "FRAME_ACTION_BACK" }

---@param opts? { style?: "gamepad"|"mkb", setGlobal?: fun(name: string, value: any), setField?: fun(tbl: table, key: any, value: any) }
function Gamepad.Install(opts)
  opts = opts or {}
  local restorers = {}
  local setGlobal = opts.setGlobal or function(name, value)
    local old = rawget(_G, name)
    table.insert(restorers, function() rawset(_G, name, old) end)
    rawset(_G, name, value)
  end
  local setField = opts.setField or function(tbl, key, value)
    local old = rawget(tbl, key)
    table.insert(restorers, function() rawset(tbl, key, old) end)
    rawset(tbl, key, value)
  end

  local handle = { blocked = 0, style = opts.style == "mkb" and INTERFACE_TYPE.Mkb or INTERFACE_TYPE.Gamepad,
    restricted = false }

  setField(Enum, "InputDeviceInterfaceType", INTERFACE_TYPE)
  setField(Enum, "AddOnRestrictionType", RESTRICTION_TYPE)
  setField(Enum, "AddOnRestrictionState", RESTRICTION_STATE)
  for name, value in pairs(CONSTANTS) do setGlobal(name, value) end
  for _, name in ipairs(STRINGS) do setGlobal(name, name) end

  setGlobal("C_InputInterfaceStyle", { GetCurrentStyle = function() return handle.style end })
  -- Mainline/InputUtil.lua.
  setGlobal("InputUtil", {
    GetCurrentInterfaceStyle = function() return handle.style end,
    IsGamepadUISupported = function() return true end,
    IsGamepadUIEnabled = function() return handle.style == INTERFACE_TYPE.Gamepad end,
    IsMKBUIEnabled = function() return handle.style == INTERFACE_TYPE.Mkb end,
  })
  setGlobal("C_RestrictedActions", {
    IsAddOnRestrictionActive = function(t) return t == RESTRICTION_TYPE.Combat and handle.restricted end,
    GetAddOnRestrictionState = function(t)
      return (t == RESTRICTION_TYPE.Combat and handle.restricted) and RESTRICTION_STATE.Active or RESTRICTION_STATE.Inactive
    end,
  })
  local inCombat = _G.InCombatLockdown
  setGlobal("InCombatLockdown", function() return handle.restricted or inCombat() end)

  -- SecureHelper: an addon's call runs only out of the combat restriction (IsSecureOrOutOfCombatRestriction).
  local function allowed()
    if handle.restricted then
      handle.blocked = handle.blocked + 1
      return false
    end
    return true
  end

  ---------------------------------------------------------------------------------------------------------------
  -- Utility.lua
  local function setSecureValue(obj, name, value)
    if allowed() then
      obj[name] = value
    end
  end
  setGlobal("SmartNavigation_MarkFrameIgnored", function(frame, dontPropagate)
    if dontPropagate then
      setSecureValue(frame, "smartNavigationIgnoredDontPropagate", true)
    else
      setSecureValue(frame, "smartNavigationIgnored", true)
    end
  end)
  setGlobal("SmartNavigation_ClearIgnoreStatus", function(frame)
    setSecureValue(frame, "smartNavigationIgnored", nil)
    setSecureValue(frame, "smartNavigationIgnoredDontPropagate", nil)
  end)
  local function isFrameIgnored(frame)
    if not frame then
      return true
    end
    if frame.smartNavigationIgnored == true or frame.smartNavigationIgnoredDontPropagate == true then
      return true
    end
    local parent = frame:GetParent()
    if parent then
      if parent.smartNavigationIgnoredDontPropagate == true then
        return false
      end
      return isFrameIgnored(parent)
    end
    return false
  end
  setGlobal("SmartNavigation_IsFrameIgnored", isFrameIgnored)
  local function isSubSection(frame)
    return frame and frame.smartNavigationFocusKey ~= nil
  end
  -- SmartNavigation_CanFocusFrame: a button or edit box, or anything with a mouse script, sized, and not a container
  -- marked to be passed over.
  local function canFocusFrame(frame)
    local isButton = frame:IsObjectType("Button") or frame:IsObjectType("EditBox")
    local canFocus = frame.smartNavigationCanFocus == true
    if not isButton then
      isButton = frame:GetScript("OnMouseUp") ~= nil or frame:GetScript("OnMouseDown") ~= nil
    end
    return (isButton or canFocus) and frame:GetSize() and not frame.smartNavigationIgnoredContainerFrame
  end
  setGlobal("SmartNavigation_CanFocusFrame", canFocusFrame)
  -- Utility.FindButtons: every frame that can take the cursor under inFrame, each in the scroll frame closest above it
  -- (a ScrollFrame, or anything with a ScrollTarget: a ScrollBox).
  local function findButtons(inFrame, extraPanels, includeInFrame)
    local buttonsFound, scrollFramesFound = {}, {}
    local function find(frame, foundButtons)
      if isSubSection(frame) and frame ~= inFrame then
        return
      end
      if canFocusFrame(frame) and (includeInFrame or frame ~= inFrame) then
        table.insert(foundButtons, frame)
      end
      local isScrollFrame = frame:IsObjectType("ScrollFrame") or frame.ScrollTarget ~= nil
      local scrollInfo
      if isScrollFrame then
        scrollInfo = { scrollFrame = frame, buttons = {} }
        table.insert(scrollFramesFound, scrollInfo)
      end
      for _, child in ipairs({ frame:GetChildren() }) do
        find(child, scrollInfo and scrollInfo.buttons or foundButtons)
      end
    end
    find(inFrame, buttonsFound)
    for _, panel in pairs(extraPanels or {}) do
      find(panel, buttonsFound)
    end
    return buttonsFound, scrollFramesFound
  end
  local function findButtonGroups(inFrame, extraPanels)
    local groups = { mainGroup = {}, subGroups = {} }
    groups.mainGroup.buttons, groups.mainGroup.scrollFrames = findButtons(inFrame, extraPanels)
    return groups
  end
  handle.FindButtonGroups = findButtonGroups

  ---------------------------------------------------------------------------------------------------------------
  -- SmartNavigation.lua: the frame "SmartNavigation", a CallbackRegistry (CallbackRegistryMixin: a callback is
  -- func(owner, ...)).
  local nav = CreateFrame("Frame", nil, UIParent)
  nav:Hide()
  nav.activePanels = {}
  nav.hookedFrames = {}
  nav.callbacks = {}
  function nav:RegisterCallback(event, func, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][owner] = func
    return owner
  end
  function nav:UnregisterCallback(event, owner)
    if self.callbacks[event] then
      self.callbacks[event][owner] = nil
    end
  end
  function nav:TriggerEvent(event, ...)
    local list = {}
    for owner, func in pairs(self.callbacks[event] or {}) do
      table.insert(list, { owner, func })
    end
    for _, entry in ipairs(list) do
      entry[2](entry[1], ...)
    end
  end
  -- IsButtonValid: not ignored, visible, and inside its scroll frame when it is in one.
  function nav:IsButtonValid(button, scrollFrame)
    if isFrameIgnored(button) or not button:IsVisible() then
      return false
    end
    if scrollFrame then
      local l, b, w, h = button:GetScaledRect()
      local sl, sb, sw, sh = scrollFrame:GetScaledRect()
      if l and sl then
        local x, y = l + w / 2, b + h / 2
        return x > sl and x < sl + sw and y < sb + sh and y > sb
      end
    end
    return true
  end
  -- GetPanelInfo and CreatePanelInfo: a panel's info, made the first time with its OnHide hooked (HandlePanelClose).
  function nav:GetPanelInfo(frame, dontCreate)
    for _, info in ipairs(self.activePanels) do
      if info.frame == frame then
        return info
      end
    end
    if dontCreate then
      return nil
    end
    local info = { buttonGroups = {}, frame = frame }
    if not self.hookedFrames[frame] then
      self.hookedFrames[frame] = true
      frame:HookScript("OnHide", function(hidden) self:RemovePanelInfo(hidden) end)
    end
    table.insert(self.activePanels, info)
    if frame.smartNavPanelInfoAddedCallback then
      frame.smartNavPanelInfoAddedCallback(info)
    end
    return info
  end
  function nav:RemovePanelInfo(frame)
    for i, info in ipairs(self.activePanels) do
      if info.frame == frame then
        table.remove(self.activePanels, i)
        break
      end
    end
    if self.activeInfo and self.activeInfo.frame == frame then
      self:SetActiveFrame(nil)
    end
  end
  function nav:SetActiveFrame(info)
    if self.activeInfo == info then
      return
    end
    if self.activeInfo then
      self.activeInfo.lastButton = self.currentButton
    end
    self:SelectButton(nil)
    self.activeInfo = info
    if info then
      self:Show()
      self:SelectFirstButton()
      if info.frame.OnSmartNavFocus then
        info.frame.OnSmartNavFocus(info.frame)
      end
    else
      self:Hide()
    end
  end
  -- SelectButton: the button it leaves gets its OnLeave (FocusExit) and OnSmartNavDeselect, the one it selects its
  -- OnEnter (FocusEnter), the panel's SmartNavigationOnSelect and its own OnSmartNavSelect; then SelectedButtonUpdated.
  function nav:SelectButton(button)
    if self.activeInfo == nil or self.currentButton == button then
      return
    end
    local prev = self.currentButton
    if prev then
      prev:SetHighlightLocked(false)
      prev:FocusExit()
      if prev.OnSmartNavDeselect then
        prev.OnSmartNavDeselect(prev)
      end
      self.currentButton = nil
    end
    if button then
      self.currentButton = button
      button:SetHighlightLocked(true)
      button:FocusEnter()
      local frame = self.activeInfo.frame
      if frame.SmartNavigationOnSelect then
        frame.SmartNavigationOnSelect(frame, button)
      end
      if button.OnSmartNavSelect then
        button.OnSmartNavSelect(button)
      end
    end
    self:TriggerEvent("SelectedButtonUpdated")
  end
  -- FindTopLeftButton: the valid button furthest left, then highest (the mock frames without a rect come in the order
  -- they were found).
  function nav:FindTopLeftButton(info)
    local found, lowestX, highestY
    local function search(buttons, scrollFrame)
      for _, button in ipairs(buttons) do
        if self:IsButtonValid(button, scrollFrame) then
          local x, y = button:GetLeft(), button:GetBottom()
          if found == nil or (x and lowestX and y and highestY and lowestX >= x and highestY < y) then
            found, lowestX, highestY = button, x, y
          end
        end
      end
    end
    local group = info and info.buttonGroups.mainGroup
    if group and group.buttons then
      search(group.buttons)
      for _, scrollInfo in ipairs(group.scrollFrames) do
        search(scrollInfo.buttons, scrollInfo.scrollFrame)
      end
    end
    return found
  end
  function nav:SelectFirstButton()
    if self.activeInfo then
      self:SelectButton(self.activeInfo.lastButton or self.activeInfo.targetButton
        or self:FindTopLeftButton(self.activeInfo))
    end
  end
  function nav:HandlePanelOpen(frame)
    local info = self:GetPanelInfo(frame)
    info.buttonGroups = findButtonGroups(frame)
    self:SetActiveFrame(info)
  end
  function nav:GetCurrentButton() return self.currentButton end
  function nav:GetActiveFrame() return self.activeInfo and self.activeInfo.frame end
  -- PerformClick: the press Blizzard gives a button (MouseDown, MouseUp), unless its OnSmartNavClick handles it.
  local function performClick(button, mouse)
    button:MouseDown(mouse)
    button:MouseUp(mouse)
  end
  function nav:Click()
    local button = self.currentButton
    if self.activeInfo and button and button:IsEnabled() then
      if not (button.OnSmartNavClick and button.OnSmartNavClick(button)) then
        performClick(button)
      end
    end
  end
  function nav:RightClick()
    if self.activeInfo and self.currentButton then
      performClick(self.currentButton, "RightButton")
    end
  end
  -- AttemptClose (B): the panel's SmartNavigationCloseHandler, unless it does not handle it; then its CloseButton; else
  -- the first visible button the panel's main group holds whose name has "CloseButton" in it.
  function nav:AttemptClose()
    if not self.activeInfo then
      return
    end
    local frame = self.activeInfo.frame
    if frame.SmartNavigationCloseHandler and frame.SmartNavigationCloseHandler(frame) then
      return
    end
    if frame.CloseButton then
      performClick(frame.CloseButton)
      return
    end
    local group = self.activeInfo.buttonGroups.mainGroup
    for _, button in ipairs(group and group.buttons or {}) do
      local name = button:IsVisible() and button:GetName()
      if name and string.match(name, "CloseButton") then
        performClick(button)
        break
      end
    end
  end
  -- The addon-callable wrapped functions (SecureHelper:WrapFunction): refused under the combat restriction.
  local function wrap(fn)
    return function(...)
      if allowed() then
        return fn(...)
      end
    end
  end
  -- RemovePanelInfo is wrapped too (SmartNavigation.lua: "The combat restriction should be kept for this one"). The
  -- OnHide hook GetPanelInfo puts on a panel calls it, from whatever code hid the panel: in specs an addon's, so under
  -- the combat restriction Blizzard refuses it (and counts).
  nav.RemovePanelInfo = wrap(nav.RemovePanelInfo)
  nav.RefreshButtonGroups = wrap(function(self, frame)
    local info = frame and self:GetPanelInfo(frame) or self.activeInfo
    if info then
      info.buttonGroups = findButtonGroups(info.frame)
    end
  end)
  nav.SetTargetButtonForFrame = wrap(function(self, frame, button)
    local info = self:GetPanelInfo(frame, true)
    if info then
      info.targetButton = button
      if self.activeInfo == info and button then
        self:SelectButton(button)
      end
    end
  end)
  handle.nav = nav
  setGlobal("SmartNavigation", nav)

  ---------------------------------------------------------------------------------------------------------------
  -- FrameControlsManager.lua.
  local manager = { shownFrames = {}, isUIFocused = false }
  local function indexOf(frame)
    for i, f in ipairs(manager.shownFrames) do
      if f == frame then
        return i
      end
    end
    return 0
  end
  local function call(frame, method)
    if frame[method] then
      frame[method](frame)
    end
  end
  local function unfocusFocused()
    local frame = manager.focusedFrame
    if not frame then
      return
    end
    call(frame, "UnfocusGamepad")
    call(frame, "EndFocus")
    if manager.focusedFrame == frame then
      manager.focusedFrame = nil
    end
  end
  local function enableNavigation(frame)
    if frame.useCustomNavigation then
      nav:SetActiveFrame(nil)
    else
      nav:HandlePanelOpen(frame)
    end
  end
  local function refreshJumpHints()
    for _, frame in ipairs(manager.shownFrames) do
      call(frame, "HideLeftJumpHint")
      call(frame, "HideRightJumpHint")
      call(frame, "HideFocusJumpHint")
    end
    local focused = manager.focusedFrame
    if not focused then
      return
    end
    if not manager.isUIFocused then
      call(focused, "ShowFocusJumpHint")
    end
    local index = indexOf(focused)
    local prev, nxt = manager.shownFrames[index - 1], manager.shownFrames[index + 1]
    if prev and manager.isUIFocused then
      call(prev, "ShowLeftJumpHint")
    end
    if nxt and manager.isUIFocused then
      call(nxt, "ShowRightJumpHint")
    end
  end
  local function focusFrame(index)
    local frame = manager.shownFrames[index]
    if not frame or not frame:IsShown() then
      return false
    end
    if manager.focusedFrame == frame then
      manager.isUIFocused = true
      return true
    end
    unfocusFocused()
    manager.isUIFocused = true
    manager.focusedFrame = frame
    enableNavigation(frame)
    call(frame, "FocusGamepad")
    call(frame, "StartFocus")
    refreshJumpHints()
    return true
  end
  -- FrameLessThanCmp: left to right by center, top to bottom where the centers line up.
  local function lessThan(a, b)
    local ax, ay = a:GetCenter()
    local bx, by = b:GetCenter()
    ax, ay, bx, by = ax or 0, ay or 0, bx or 0, by or 0
    if ax == bx then
      return ay > by
    end
    return ax < bx
  end
  local function frameShown(_, frame)
    if not _G.InputUtil.IsGamepadUIEnabled() or not frame or indexOf(frame) > 0 then
      return false
    end
    table.insert(manager.shownFrames, frame)
    table.sort(manager.shownFrames, lessThan)
    if not manager.isUIFocused then
      manager.isUIFocused = true
    end
    focusFrame(indexOf(frame))
    if not manager.focusedFrame then
      manager.focusedFrame = frame
    end
    refreshJumpHints()
    return true
  end
  local function frameHidden(_, frame)
    if not _G.InputUtil.IsGamepadUIEnabled() or not frame then
      return false
    end
    local index = indexOf(frame)
    if index == 0 then
      return false
    end
    table.remove(manager.shownFrames, index)
    if manager.focusedFrame == frame then
      if #manager.shownFrames >= 1 and manager.isUIFocused then
        if not focusFrame(1) then
          unfocusFocused()
        end
      else
        unfocusFocused()
      end
    end
    if #manager.shownFrames == 0 then
      nav:SetActiveFrame(nil)
      manager.isUIFocused = false
    end
    refreshJumpHints()
    return true
  end
  manager.FrameShown = wrap(frameShown)
  manager.FrameHidden = wrap(frameHidden)
  function manager:GetActiveFrame() return self.focusedFrame end
  function manager:GetShownFrameCount() return #self.shownFrames end
  -- The triggers (FocusNextFrame, FocusPreviousFrame): the frame to the right or left of the focused one.
  function manager:FocusNextFrame()
    local index = indexOf(self.focusedFrame)
    if index == 0 or index == #self.shownFrames then
      return false
    end
    return focusFrame(index + 1)
  end
  function manager:FocusPreviousFrame()
    local index = indexOf(self.focusedFrame)
    if index <= 1 then
      return false
    end
    return focusFrame(index - 1)
  end
  -- UninitializeGamepad (leaving the gamepad interface): everything forgotten.
  local function uninitialize()
    manager.shownFrames = {}
    manager.focusedFrame = nil
    manager.isUIFocused = false
    nav.activeInfo = nil
    nav.currentButton = nil
    nav.activePanels = {}
    nav:Hide()
  end
  handle.manager = manager
  setGlobal("GamepadMode", { FrameControlsManager = manager })

  -- The panel manager's broadcasts reach the manager securely (FrameControlsManager:Init).
  local showOwner, hideOwner = {}, {}
  EventRegistry:RegisterCallback("UIParentPanelManager.ShowUIPanel", function(_, frame) frameShown(nil, frame) end,
    showOwner)
  EventRegistry:RegisterCallback("UIParentPanelManager.HideUIPanel", function(_, frame) frameHidden(nil, frame) end,
    hideOwner)
  table.insert(restorers, function()
    EventRegistry:UnregisterCallback("UIParentPanelManager.ShowUIPanel", showOwner)
    EventRegistry:UnregisterCallback("UIParentPanelManager.HideUIPanel", hideOwner)
  end)
  -- ShowUIPanel and HideUIPanel broadcast once the frame shows or hides (BroadcastShowUIPanelEvent,
  -- BroadcastHideUIPanelEvent); the mock's placing of the panel is kept.
  local showUIPanel, hideUIPanel = _G.ShowUIPanel, _G.HideUIPanel
  setGlobal("ShowUIPanel", function(frame, ...)
    if not frame or frame:IsShown() then
      return
    end
    showUIPanel(frame, ...)
    if frame:IsShown() then
      EventRegistry:TriggerEvent("UIParentPanelManager.ShowUIPanel", frame)
    end
  end)
  setGlobal("HideUIPanel", function(frame, ...)
    if not frame or not frame:IsShown() then
      return
    end
    hideUIPanel(frame, ...)
    if not frame:IsShown() then
      EventRegistry:TriggerEvent("UIParentPanelManager.HideUIPanel", frame)
    end
  end)
  -- UIPanelCloseButton (SharedUIPanelTemplates.xml, UIPanelCloseButton_OnClick): hides its parent through HideUIPanel.
  local closeTemplate = _G.__mockTemplates.UIPanelCloseButton
  setField(_G.__mockTemplates, "UIPanelCloseButton", function(frame)
    closeTemplate(frame)
    frame:SetScript("OnClick", function(self)
      local parent = self:GetParent()
      if parent then
        _G.HideUIPanel(parent)
      end
    end)
  end)

  ---------------------------------------------------------------------------------------------------------------
  -- ContainerFrame.lua: the radial's bags entry (ToggleBackpack_Combined), and ToggleAllBags, which on the gamepad
  -- interface calls it. Live ToggleAllBags (the mouse interface) is the one already there.
  setGlobal("ToggleBackpack_Combined", function()
    local bags = _G.ContainerFrameCombinedBags
    if bags and bags:IsShown() then
      bags:Hide()
    elseif bags then
      bags:Show()
    end
  end)
  -- ToggleBackpack (ContainerFrame.lua): ToggleBackpack_Combined while the bags are combined, which the gamepad style
  -- always has them (ContainerFrameSettingsManager:IsUsingCombinedBags); the radial's Character entry calls it when
  -- Blizzard's backpack reads closed (GamepadRadial.lua ToggleCharacterAndOpenBags). The individual bags of the mouse
  -- style are left out.
  setGlobal("ToggleBackpack", function()
    if _G.InputUtil.IsGamepadUIEnabled() then
      _G.ToggleBackpack_Combined()
    end
  end)
  -- ToggleCharacter(tab, onlyShow) (Camelot/CharacterFrame.lua): the radial's Character entry calls it right after
  -- ToggleBackpack (GamepadRadial.lua ToggleCharacterAndOpenBags). The character frame itself is left out.
  setGlobal("ToggleCharacter", function() end)
  -- IsBagOpen(id) (ContainerFrame.lua): on the gamepad style every held bag is in the combined frame
  -- (IsUsingCombinedBags), open while it is shown (ContainerFrameCombinedBagsMixin:IsBagOpen; NumBagSlots 4).
  setGlobal("IsBagOpen", function(id)
    local bags = _G.ContainerFrameCombinedBags
    return bags ~= nil and bags:IsShown() and id <= 4 or false
  end)
  local toggleAllBags = _G.ToggleAllBags
  setGlobal("ToggleAllBags", function(...)
    if _G.InputUtil.IsGamepadUIEnabled() then
      _G.ToggleBackpack_Combined()
      return
    end
    if toggleAllBags then
      return toggleAllBags(...)
    end
  end)

  ---------------------------------------------------------------------------------------------------------------
  -- InputIconTextureFrameTemplate (InputIconTexture.xml, InputIconTextureMixin): 24 x 24, the art of the button it is
  -- mapped to (mappedButtonKey, A by default; SetInputKey). The jump hints (FocusEffectTemplates.xml): 32 x 32, mapped to
  -- the left trigger, the right trigger or the back button, at the middle of the parent's bottom edge, 4 up.
  local function iconTemplate(frame)
    frame:SetSize(24, 24)
    frame.mappedButtonKey = frame.mappedButtonKey or CONSTANTS.GAMEPAD_FACE_BOTTOM
    function frame:SetInputKey(key)
      assert(type(key) == "string", "Passed in button must be a string type")
      self.mappedButtonKey = key
    end
  end
  setField(_G.__mockTemplates, "InputIconTextureFrameTemplate", iconTemplate)
  for template, key in pairs({ FrameLeftJumpHintTemplate = "GAMEPAD_TRIGGER_LEFT",
    FrameRightJumpHintTemplate = "GAMEPAD_TRIGGER_RIGHT", FrameFocusJumpHintTemplate = "GAMEPAD_MENU_LEFT" }) do
    setField(_G.__mockTemplates, template, function(frame)
      frame.mappedButtonKey = CONSTANTS[key]
      iconTemplate(frame)
      frame:SetSize(32, 32)
      frame:SetPoint("CENTER", frame:GetParent(), "BOTTOM", 0, 4)
    end)
  end

  -- InputLegendPromptGroup.lua: CreateInputLegend(parentFrame, parentKey) makes a legend as the parent's parentKey;
  -- GetOrCreatePromptFrameUsingTemplateAndInputs(template, keys, divider) gives the prompt for those buttons (made once);
  -- a prompt shows its text (SetPromptText) enabled or not (EnablePrompt, DisablePrompt); ApplyDefaultPromptPositioning
  -- lays out the shown prompts in the order they were made.
  setGlobal("GAMEPAD_PROMPT_DIVIDER_SLASH", 1)
  setGlobal("InputPromptLegends", {
    PromptTemplates = { StandardOneIcon = { name = "StandardOneIcon" }, StandardTwoIcon = { name = "StandardTwoIcon" } },
    CreateInputLegend = function(parentFrame, parentKey)
      local legend = CreateFrame("Frame", nil, parentFrame)
      if parentKey then
        parentFrame[parentKey] = legend
      end
      legend.promptFrames = {}
      legend.promptFramesAddOrder = {}
      legend.promptContainerFrame = CreateFrame("Frame", nil, legend)
      function legend:GetOrCreatePromptFrameUsingTemplateAndInputs(templateName, inputKeys, dividerType)
        local key = templateName
        for _, value in ipairs(inputKeys) do key = key .. value end
        if dividerType then key = key .. dividerType end
        local prompt = self.promptFrames[key]
        if prompt then
          return prompt
        end
        prompt = CreateFrame("Frame", nil, self.promptContainerFrame)
        prompt.keys = inputKeys
        prompt.template = templateName
        prompt.SetPromptText = function(p, text) p.text = text end
        prompt.EnablePrompt = function(p) p.enabled = true end
        prompt.DisablePrompt = function(p) p.enabled = false end
        self.promptFrames[key] = prompt
        table.insert(self.promptFramesAddOrder, key)
        return prompt
      end
      function legend:ApplyDefaultPromptPositioning()
        self.laidOut = {}
        for _, key in ipairs(self.promptFramesAddOrder) do
          local prompt = self.promptFrames[key]
          if prompt:IsShown() then
            table.insert(self.laidOut, prompt)
          end
        end
      end
      return legend
    end,
  })

  ---------------------------------------------------------------------------------------------------------------
  -- The spec's controls.

  -- SetCombat puts the combat restriction (and the combat lockdown) on or off.
  function handle:SetCombat(active)
    self.restricted = active and true or false
  end
  -- SetStyle switches the interface style as the client does before it fires INPUT_DEVICE_INTERFACE_TRANSITION (the
  -- caller fires it): leaving the gamepad interface, Blizzard's window handling forgets everything
  -- (UninitializeGamepad).
  function handle:SetStyle(style)
    local new = style == "mkb" and INTERFACE_TYPE.Mkb or INTERFACE_TYPE.Gamepad
    local old = self.style
    self.style = new
    if old == INTERFACE_TYPE.Gamepad and new ~= old then
      uninitialize()
    end
    return new, old
  end
  -- Navigable lists the buttons the cursor can land on in a panel, each with the scroll frame it scrolls (nil outside
  -- one): what FindButtonGroups found that IsButtonValid lets through.
  function handle:Navigable(frame)
    local groups = findButtonGroups(frame)
    local out = {}
    for _, button in ipairs(groups.mainGroup.buttons) do
      if nav:IsButtonValid(button) then
        table.insert(out, { button = button })
      end
    end
    for _, scrollInfo in ipairs(groups.mainGroup.scrollFrames) do
      for _, button in ipairs(scrollInfo.buttons) do
        if nav:IsButtonValid(button) then
          table.insert(out, { button = button, scrollFrame = scrollInfo.scrollFrame })
        end
      end
    end
    return out
  end
  -- Restore puts back what Install changed (not needed when the whole-addon helper's restorers did it).
  function handle:Restore()
    for i = #restorers, 1, -1 do restorers[i]() end
    restorers = {}
  end

  return handle
end

return Gamepad
