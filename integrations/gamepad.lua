---@diagnostic disable: duplicate-set-field,duplicate-doc-field,duplicate-doc-alias
local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- Gamepad puts BetterBags' bag windows in WoW: Forever's gamepad interface (.claude/rules/gamepad.md). Blizzard's
-- gamepad UI keeps a list of open windows (GamepadMode.FrameControlsManager): the d-pad cursor (SmartNavigation) moves
-- over the buttons of the one it focuses, A presses the selected button, B closes the window, and the triggers move
-- the focus to the window on the left or right. Each open bag window joins that list a frame after it opens (its
-- content laid out), and leaves it as it starts to close. The cursor lands only on the buttons the window marks
-- (bbGamepad: "item", "vendor", "guild", "tab"); everything else it would find is marked ignored. Inside the window's
-- scroll box a native ScrollFrame stands between the box and the content (Scrollbox:SetGamepad): Blizzard's
-- navigation scrolls the scroll frame closest above a button, and an addon's ScrollBox is one it cannot scroll. The
-- box is scrolled to the selected button from here (Scrollbox:ScrollIntoView). X right-clicks the selected item
-- through a secure button; Blizzard's input legend (InputPromptLegends) says what A, X and B do; its trigger hints
-- (FrameLeftJumpHintTemplate) show on the windows beside the focused one; the radial menu's Bags
-- (ToggleBackpack_Combined) toggles the bags and its Character entry (ToggleBackpack) opens them. Everything follows
-- the player switching between the gamepad and the
-- mouse (INPUT_DEVICE_INTERFACE_TRANSITION). Under the combat restriction Blizzard refuses an addon's calls to its
-- gamepad UI (SecureHelper:WrapFunction): every window leaves Blizzard's list as the restriction comes, while Blizzard
-- still takes the calls (ADDON_RESTRICTION_STATE_CHANGED, Activating), and joins again after it.
---@class Gamepad: AceModule
---@field available boolean Blizzard's gamepad interface is on this client.
---@field on boolean The gamepad interface style is the one in use.
---@field combat boolean Between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED.
---@field waiting boolean A change waits for the combat restriction to end.
---@field windows GamepadWindow[]
---@field byFrame table<Frame, GamepadWindow>
---@field marked table<Frame, boolean> The frames marked ignored, weakly.
---@field replaced table<Frame, number> Panels Blizzard's panel manager handed over, each with the frames left to see it
--- moved under BetterBagsSneakyFrame (a frame BetterBags stands in for), then taken out of Blizzard's list.
---@field radial boolean The radial menu's Bags was pressed, the toggle waits for the next frame.
---@field toggledAll boolean Blizzard's ToggleAllBags ran this frame (it calls ToggleBackpack_Combined).
---@field viaBackpack boolean Blizzard's ToggleBackpack ran this frame (it calls ToggleBackpack_Combined).
---@field viaCharacter boolean Blizzard's ToggleCharacter ran this frame: with viaBackpack, the radial's Character entry,
--- which asks for the bags open only when Blizzard's own backpack reads closed (GamepadRadial.lua).
---@field bound? Button The item X right-clicks.
---@field combatFocus? GamepadWindow The window Blizzard's cursor was in as the windows left for combat: it joins last.
---@field driver? Frame Runs Update on the next frame.
---@field useButton? Button The secure button X clicks.
local gamepad = addon:NewModule('Gamepad')

---@class (exact) GamepadWindow
---@field window table A bag window: frame, scroll, Show, Hide, IsShown, IsClosing.
---@field frame Frame
---@field registered boolean In Blizzard's window list.
---@field focused boolean The window Blizzard's cursor is in.
---@field prepared boolean Its scroll frame, hints and legend in place, its controls marked.
---@field dirty boolean Drawn again since its controls were marked and its buttons handed to Blizzard's navigation.
---@field hints? table<string, Frame>
---@field legend? Frame
---@field lastButton? Button The button Blizzard's cursor was on as the window left for combat (RestoreCursor).

-- How many frames a panel Blizzard's panel manager handed over is watched for BetterBags moving it out of sight
-- (BetterBags Next's guild bank moves Blizzard's frame a frame after it shows: next/guildbank.lua OnShowUIPanel).
local REPLACED_FRAMES = 5

-- What a label key a button gives (bbGamepadLabel) says, in Blizzard's words (its merchant's and bag's prompts).
local LABELS = { buy = "CONTEXT_ACTION_LABEL_BUY", sell = "CONTEXT_ACTION_LABEL_SELL" }

-- What X (a right click) does on an item at an NPC: it sells to a merchant, moves into a bank and places into mail,
-- a trade or an auction, else it uses the item (Blizzard's bag: ContainerFrame.lua Gamepad_IsSellItemActionValid).
local USE_LABELS = {
  { "Merchant", "CONTEXT_ACTION_LABEL_SELL" }, { "Banker", "CONTEXT_ACTION_LABEL_MOVE" },
  { "CharacterBanker", "CONTEXT_ACTION_LABEL_MOVE" }, { "AccountBanker", "CONTEXT_ACTION_LABEL_MOVE" },
  { "GuildBanker", "CONTEXT_ACTION_LABEL_MOVE" }, { "MailInfo", "CONTEXT_ACTION_LABEL_PLACE" },
  { "TradePartner", "CONTEXT_ACTION_LABEL_PLACE" }, { "Auctioneer", "CONTEXT_ACTION_LABEL_PLACE" },
}

-- available says whether Blizzard's gamepad interface is on this client (WoW: Forever's Blizzard_GamepadSmartNavigation
-- and Blizzard_GamepadSharedUtility, loaded for both interface styles).
---@return boolean
local function available()
  return _G.GamepadMode ~= nil and _G.GamepadMode.FrameControlsManager ~= nil and _G.SmartNavigation ~= nil
    and _G.InputUtil ~= nil and _G.InputUtil.IsGamepadUIEnabled ~= nil and _G.C_RestrictedActions ~= nil
    and _G.SmartNavigation_MarkFrameIgnored ~= nil and _G.InputPromptLegends ~= nil
end

-- restricted says whether Blizzard refuses an addon's calls to its gamepad UI now (SecureHelper.lua
-- IsSecureOrOutOfCombatRestriction).
---@return boolean
local function restricted()
  return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat)
end

-- focusable says whether Blizzard's navigation could land on a frame (SmartNavigation_CanFocusFrame).
---@param frame Frame
---@return boolean
local function focusable(frame)
  return frame:IsObjectType("Button") or frame:IsObjectType("EditBox") or frame:GetScript("OnMouseDown") ~= nil
    or frame:GetScript("OnMouseUp") ~= nil
end

---@param region? Region
---@return string?
local function nameOf(region)
  if region == nil then
    return nil
  end
  return region:GetName() or tostring(region)
end

-- hideHints hides a window's trigger hints: Blizzard hides them only on the windows still in its list.
---@param rec GamepadWindow
local function hideHints(rec)
  for _, hint in pairs(rec.hints or {}) do
    hint:Hide()
  end
end

function gamepad:Init()
  self.available = available()
  self.on = false
  self.combat = false
  self.waiting = false
  self.windows = {}
  self.byFrame = {}
  self.marked = setmetatable({}, { __mode = "k" })
  self.replaced = {}
  self.radial = false
  self.toggledAll = false
  self.viaBackpack = false
  self.viaCharacter = false
  self.bound = nil
  self.combatFocus = nil
end

function gamepad:OnEnable()
  if not self.available then
    return
  end
  self.on = InputUtil.IsGamepadUIEnabled()
  -- The next frame, by an OnUpdate of its own: a C_Timer started from a hook on Blizzard's bag functions taints its
  -- gamepad UI (GW2_UI, Core/API/utils.lua).
  local driver = CreateFrame("Frame")
  driver:Hide()
  driver:SetScript("OnUpdate", function(f)
    f:Hide()
    self:Update()
  end)
  self.driver = driver
  local use = CreateFrame("Button", "BetterBagsGamepadUse", UIParent, "SecureActionButtonTemplate")
  use:SetAttribute("type2", "click")
  use:RegisterForClicks("AnyDown")
  self.useButton = use

  events:RegisterEvent('INPUT_DEVICE_INTERFACE_TRANSITION', function(_, _, newStyle)
    self:OnTransition(newStyle)
  end)
  events:RegisterEvent('PLAYER_REGEN_DISABLED', function()
    self:OnCombatStart()
  end)
  events:RegisterEvent('PLAYER_REGEN_ENABLED', function()
    self.combat = false
    self:Schedule()
  end)
  events:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED', function(_, _, restrictionType, state)
    self:OnRestrictionChanged(restrictionType, state)
  end)
  events:RegisterEvent('CURSOR_CHANGED', function()
    self:UpdateLegends()
  end)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', function()
    self:UpdateLegends()
  end)
  events:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', function(_, _, interactionType)
    self:UpdateLegends(interactionType)
  end)
  SmartNavigation:RegisterCallback("SelectedButtonUpdated", function()
    self:OnSelected()
  end, self)
  EventRegistry:RegisterCallback("UIParentPanelManager.ShowUIPanel", function(_, frame)
    self:OnPanelShown(frame)
  end, self)
  if _G.ToggleBackpack_Combined ~= nil then
    hooksecurefunc("ToggleBackpack_Combined", function()
      self:OnRadialToggle()
    end)
  end
  if _G.ToggleBackpack ~= nil then
    hooksecurefunc("ToggleBackpack", function()
      self.viaBackpack = true
      self:Schedule()
    end)
  end
  -- The radial's Character entry calls ToggleCharacter right after ToggleBackpack; a Toggle Backpack key does not.
  if _G.ToggleCharacter ~= nil then
    hooksecurefunc("ToggleCharacter", function()
      self.viaCharacter = true
      self:Schedule()
    end)
  end
  hooksecurefunc("ToggleAllBags", function()
    self.toggledAll = true
    self:Schedule()
  end)
  self:Schedule()
end

-- Add takes in a bag window (a design's backpack, bank, vendor or guild bank): while it is open it is in Blizzard's
-- window list. It returns what it did: "added", "already" or "unavailable".
---@param window table
---@return string
function gamepad:Add(window)
  if not self.available then
    return "unavailable"
  end
  local frame = window.frame
  if self.byFrame[frame] ~= nil then
    return "already"
  end
  ---@type GamepadWindow
  local rec = { window = window, frame = frame, registered = false, focused = false, prepared = false, dirty = false }
  table.insert(self.windows, rec)
  self.byFrame[frame] = rec
  frame:HookScript("OnShow", function() self:Schedule() end)
  frame:HookScript("OnHide", function() self:Schedule() end)
  hooksecurefunc(window, "Show", function() self:Schedule() end)
  hooksecurefunc(window, "Hide", function() self:Schedule() end)
  if window.scroll ~= nil then
    hooksecurefunc(window.scroll, "Render", function() self:OnRendered(rec) end)
  end
  -- What Blizzard's gamepad UI calls on a window in its list (FrameControlsManager.lua, SmartNavigation.lua).
  frame.SmartNavigationCloseHandler = function() return self:Close(rec) end
  frame.FocusGamepad = function() self:OnFocus(rec, true) end
  frame.UnfocusGamepad = function() self:OnFocus(rec, false) end
  frame.ShowLeftJumpHint = function() self:ShowHint(rec, "left", true) end
  frame.HideLeftJumpHint = function() self:ShowHint(rec, "left", false) end
  frame.ShowRightJumpHint = function() self:ShowHint(rec, "right", true) end
  frame.HideRightJumpHint = function() self:ShowHint(rec, "right", false) end
  frame.ShowFocusJumpHint = function() self:ShowHint(rec, "focus", true) end
  frame.HideFocusJumpHint = function() self:ShowHint(rec, "focus", false) end
  self:Schedule()
  return "added"
end

-- Schedule runs Update on the next frame.
function gamepad:Schedule()
  if self.driver ~= nil then
    self.driver:Show()
  end
end

-- Update brings Blizzard's window list and every window in line with what is open and the interface style in use:
-- each open window prepared and in the list, its buttons handed over again after it drew; a closing or closed one
-- out of the list; on the mouse interface, every window back as it was. Blizzard's frames BetterBags stands in for
-- are taken out of the list. In combat the windows stay out of the list (LeaveForCombat) and a change waits
-- (waiting) for the events that end it. It returns how many windows are in the list.
---@return number
function gamepad:Update()
  if self.radial then
    local fromToggleAll = self.toggledAll
    local fromCharacter = self.viaBackpack and self.viaCharacter
    self.radial = false
    if self.on and not fromToggleAll then
      if fromCharacter then
        self:FollowBlizzardBackpack()
      else
        addon:ToggleAllBags(context:New('Gamepad_Radial'))
      end
    end
  end
  self.toggledAll = false
  self.viaBackpack = false
  self.viaCharacter = false

  local refused = restricted()
  local lockdown = InCombatLockdown()
  local waiting = false
  local manager = GamepadMode.FrameControlsManager
  local listed = 0
  -- The window that had the cursor before combat joins last: Blizzard focuses the window it adds last (FrameShown).
  local order = self.windows
  local focus = self.combatFocus
  if focus ~= nil then
    order = {}
    for _, rec in ipairs(self.windows) do
      if rec ~= focus then
        table.insert(order, rec)
      end
    end
    table.insert(order, focus)
  end
  for _, rec in ipairs(order) do
    if self.on then
      local open = rec.window:IsShown() and not rec.window:IsClosing()
      if open then
        if refused or lockdown or self.combat then
          waiting = waiting or not rec.registered or rec.dirty
        else
          -- Prepared again as it joins: what it drew while out of the list (in combat) is marked too.
          if not rec.prepared or rec.dirty or not rec.registered then
            self:Prepare(rec)
          end
          if not rec.registered then
            rec.registered = true
            manager:FrameShown(rec.frame)
            self:RestoreCursor(rec)
            if self.combatFocus == rec then
              self.combatFocus = nil
            end
          elseif rec.dirty then
            SmartNavigation:RefreshButtonGroups(rec.frame)
          end
          rec.dirty = false
        end
      else
        -- Hidden: a place kept for it, or the focus, from before combat is forgotten; it opens fresh. Only once it hid:
        -- a window sliding out can be opened again (its OnHide schedules the pass that forgets them).
        if not rec.window:IsShown() then
          rec.lastButton = nil
          if self.combatFocus == rec then
            self.combatFocus = nil
          end
        end
        if rec.registered then
          if refused then
            waiting = true
          else
            rec.registered = false
            manager:FrameHidden(rec.frame)
            rec.focused = false
            hideHints(rec)
          end
        end
      end
    else
      rec.lastButton = nil
      self.combatFocus = nil
      if rec.prepared and not self:Unprepare(rec, lockdown) then
        waiting = true
      end
    end
    if rec.registered then
      listed = listed + 1
    end
  end
  local watching = false
  for frame, left in pairs(self.replaced) do
    if not frame:IsShown() then
      self.replaced[frame] = nil
    elseif _G.BetterBagsSneakyFrame ~= nil and frame:GetParent() == _G.BetterBagsSneakyFrame then
      if refused then
        waiting = true
      else
        manager:FrameHidden(frame)
        self.replaced[frame] = nil
      end
    elseif left <= 1 then
      self.replaced[frame] = nil
    else
      self.replaced[frame] = left - 1
      watching = true
    end
  end
  if watching then
    self:Schedule()
  end
  self.waiting = waiting
  self:Retarget()
  self:UpdateLegends()
  return listed
end

-- LeaveForCombat takes every window out of Blizzard's list and out of its cursor before the combat restriction comes
-- (ADDON_RESTRICTION_STATE_CHANGED Activating, while Blizzard still takes an addon's calls, or PLAYER_REGEN_DISABLED
-- before the restriction is on). Under the restriction Blizzard refuses to take a window out, and one left in through
-- combat and closed then stays in, hidden, with Blizzard's cursor in it and the face buttons held by its UI. Blizzard's
-- cursor forgets each window too: a frame made under a window it knows has it look again (its CreateFrame hook,
-- SmartNavigation.lua UpdateParent), which it refuses in combat. The windows join again when combat ends (Update). It
-- returns how many windows left the list. The button Blizzard's cursor was on in each window is kept, to give back when
-- the window joins again (RestoreCursor), and the window's trigger hints are hidden (Blizzard clears them only on the
-- windows still in its list).
---@return number
function gamepad:LeaveForCombat()
  if not self.on or restricted() then
    return 0
  end
  local manager = GamepadMode.FrameControlsManager
  local current = SmartNavigation:GetCurrentButton()
  -- Before the first FrameHidden: Blizzard hands the focus to another window as the focused one leaves.
  local active = manager:GetActiveFrame()
  if active ~= nil and self.byFrame[active] ~= nil then
    self.combatFocus = self.byFrame[active]
  end
  local left = 0
  for _, rec in ipairs(self.windows) do
    if rec.prepared then
      local info = SmartNavigation:GetPanelInfo(rec.frame, true)
      if current ~= nil and self:WindowOf(current) == rec then
        rec.lastButton = current
      elseif info ~= nil then
        rec.lastButton = info.lastButton
      end
    end
    if rec.registered then
      rec.registered = false
      manager:FrameHidden(rec.frame)
      rec.focused = false
      left = left + 1
    end
    if rec.prepared then
      SmartNavigation:RemovePanelInfo(rec.frame)
    end
    hideHints(rec)
  end
  for frame in pairs(self.replaced) do
    if frame:IsShown() and frame:GetParent() == _G.BetterBagsSneakyFrame then
      manager:FrameHidden(frame)
    end
  end
  self.replaced = {}
  self:UpdateLegends()
  self:Schedule()
  return left
end

-- RestoreCursor puts Blizzard's cursor back on the button it was on in a window before the window left for combat
-- (SetTargetButtonForFrame: selected now if the window is the one Blizzard's cursor is in, else when it comes to it),
-- if that button still shows in the window and is one the cursor lands on. It returns "restored", "gone" or "none".
---@param rec GamepadWindow
---@return string
function gamepad:RestoreCursor(rec)
  local button = rec.lastButton
  rec.lastButton = nil
  if button == nil then
    return "none"
  end
  if button.bbGamepad == nil or not button:IsVisible() or self:WindowOf(button) ~= rec then
    return "gone"
  end
  SmartNavigation:SetTargetButtonForFrame(rec.frame, button)
  return "restored"
end

-- OnRestrictionChanged: an addon restriction is changing (ADDON_RESTRICTION_STATE_CHANGED). The combat restriction
-- coming (Activating) takes the windows out at once (LeaveForCombat); anything else is looked at on the next frame. It
-- returns "left" or "scheduled".
---@param restrictionType number
---@param state number
---@return string
function gamepad:OnRestrictionChanged(restrictionType, state)
  if restrictionType == Enum.AddOnRestrictionType.Combat and state == Enum.AddOnRestrictionState.Activating then
    self:LeaveForCombat()
    return "left"
  end
  self:Schedule()
  return "scheduled"
end

-- FollowBlizzardBackpack opens or closes the backpack as Blizzard's own, hidden, one ended up, after the radial menu's
-- Character entry: it calls ToggleBackpack only when Blizzard's backpack reads closed, to open the bags
-- (GamepadRadial.lua ToggleCharacterAndOpenBags), so a backpack BetterBags opened itself stays open. It asks for the
-- backpack open or closed as BetterBags' interaction windows do (bags/OpenClose), not toggled: a backpack sliding out
-- is shown, and a toggle would close it again. It returns what it did: "opened", "closed", "unchanged" or
-- "no backpack".
---@return string
function gamepad:FollowBlizzardBackpack()
  local backpack = addon.Bags and addon.Bags.Backpack
  if backpack == nil then
    return "no backpack"
  end
  local want = IsBagOpen(Enum.BagIndex.Backpack) and true or false
  local open = backpack:IsShown() and not backpack:IsClosing()
  if want == open then
    return "unchanged"
  end
  if want then
    addon.backpackShouldOpen = true
  else
    addon.backpackShouldClose = true
  end
  events:SendMessage(context:New('Gamepad_Radial'), 'bags/OpenClose')
  return want and "opened" or "closed"
end

-- Prepare readies a window for the gamepad interface: the native scroll frame in its scroll box, Blizzard's trigger
-- hints and input legend (made here, out of combat: a frame made under a window Blizzard's cursor knows has it look
-- again, refused in combat), and every control the cursor must not land on marked. It returns how many controls it
-- marked.
---@param rec GamepadWindow
---@return number
function gamepad:Prepare(rec)
  local scroll = rec.window.scroll
  if scroll ~= nil then
    scroll:SetGamepad(true)
  end
  local frame = rec.frame
  if rec.legend == nil then
    local legend = InputPromptLegends.CreateInputLegend(frame, "bbGamepadLegend")
    legend:Hide()
    rec.legend = legend
  end
  if rec.hints == nil then
    local hints = {
      left = CreateFrame("Frame", nil, frame, "FrameLeftJumpHintTemplate"),
      right = CreateFrame("Frame", nil, frame, "FrameRightJumpHintTemplate"),
      focus = CreateFrame("Frame", nil, frame, "FrameFocusJumpHintTemplate"),
    }
    for _, hint in pairs(hints) do
      hint:Hide()
    end
    rec.hints = hints
    frame.bbGamepadHints = hints
  end
  rec.prepared = true
  return self:MarkControls(frame)
end

-- Unprepare puts a window back as the mouse interface has it: its hints and legend hidden at once, its content back
-- under the scroll child unless in combat lockdown (the classic tabs' secure buttons are under it), when that waits.
-- It returns whether the window is all put back.
---@param rec GamepadWindow
---@param lockdown boolean
---@return boolean
function gamepad:Unprepare(rec, lockdown)
  for _, hint in pairs(rec.hints or {}) do
    hint:Hide()
  end
  if rec.legend ~= nil then
    rec.legend:Hide()
  end
  rec.registered = false
  rec.focused = false
  if lockdown then
    return false
  end
  local scroll = rec.window.scroll
  if scroll ~= nil then
    scroll:SetGamepad(false)
  end
  rec.prepared = false
  return true
end

-- MarkControls marks ignored every frame under root Blizzard's navigation could land on that is not one the window
-- marks for it (bbGamepad), each once, itself only (its children still found). It returns how many it marked.
---@param root Frame
---@return number
function gamepad:MarkControls(root)
  local marked = 0
  local seen = self.marked
  local function walk(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
      if seen[child] == nil and child.bbGamepad == nil and focusable(child) then
        SmartNavigation_MarkFrameIgnored(child, true)
        seen[child] = true
        marked = marked + 1
      end
      walk(child)
    end
  end
  walk(root)
  return marked
end

-- WindowOf returns the window a region is in.
---@param region Region
---@return GamepadWindow?
function gamepad:WindowOf(region)
  local frame = region
  while frame ~= nil do
    local rec = self.byFrame[frame]
    if rec ~= nil then
      return rec
    end
    frame = frame:GetParent()
  end
  return nil
end

-- OnRendered: a window in Blizzard's list drew again; its new controls are marked, and its new buttons handed over,
-- on the next frame. A window out of the list is prepared again as it joins (Update).
---@param rec GamepadWindow
function gamepad:OnRendered(rec)
  if self.on and rec.registered then
    rec.dirty = true
    self:Schedule()
  end
end

-- OnFocus: Blizzard's cursor came into a window or left it (FocusGamepad, UnfocusGamepad).
---@param rec GamepadWindow
---@param focused boolean
function gamepad:OnFocus(rec, focused)
  rec.focused = focused
  self:UpdateLegend(rec)
  self:Retarget()
end

-- inside says whether region hangs below ancestor.
---@param region Region
---@param ancestor Frame
---@return boolean
local function inside(region, ancestor)
  local frame = region:GetParent()
  while frame ~= nil do
    if frame == ancestor then
      return true
    end
    frame = frame:GetParent()
  end
  return false
end

-- OnSelected: Blizzard's cursor moved to a button (SelectedButtonUpdated). The window's box scrolls to show it when
-- it is in the box's content (a tab outside the content leaves the box where it is).
function gamepad:OnSelected()
  local button = SmartNavigation:GetCurrentButton()
  local rec = button ~= nil and self:WindowOf(button) or nil
  local scroll = rec ~= nil and rec.window.scroll or nil
  if scroll ~= nil and scroll.gamepad and inside(button, scroll.navFrame) then
    scroll:ScrollIntoView(button)
  end
  self:Retarget()
  self:UpdateLegends()
end

-- Retarget binds X to right-click the item Blizzard's cursor is on, through the secure button (a click from a key
-- binding uses an item in combat too), and unbinds it off an item. Bindings and a secure button's attributes cannot
-- change in combat: X is unbound as combat starts (OnCombatStart) and bound again after it. It returns what it did:
-- "bound", "unbound" or "combat".
---@return string
function gamepad:Retarget()
  local use = self.useButton
  if use == nil or self.combat or InCombatLockdown() then
    return "combat"
  end
  local button = self.on and SmartNavigation:GetCurrentButton() or nil
  local rec = button ~= nil and self:WindowOf(button) or nil
  if button ~= nil and button.bbGamepad == "item" and rec ~= nil and rec.registered and rec.focused then
    use:SetAttribute("clickbutton2", button)
    -- Set again on every move, so it is the last priority binding of the key set (Blizzard's own binding sets block
    -- the face buttons while its UI has the focus, InputBindingManager).
    SetOverrideBindingClick(use, true, GAMEPAD_FACE_LEFT, use:GetName(), "RightButton")
    self.bound = button
    return "bound"
  end
  if self.bound ~= nil then
    ClearOverrideBindings(use)
    self.bound = nil
  end
  return "unbound"
end

-- OnCombatStart unbinds X while it still can (PLAYER_REGEN_DISABLED comes before the lockdown): bound in combat, it
-- would use the item it was bound to wherever the cursor went. The windows leave Blizzard's list too, if the
-- restriction's own event has not taken them out already (LeaveForCombat).
function gamepad:OnCombatStart()
  self.combat = true
  if self.bound ~= nil and self.useButton ~= nil then
    ClearOverrideBindings(self.useButton)
    self.bound = nil
  end
  self:LeaveForCombat()
  self:UpdateLegends()
end

-- Close is B on a window (SmartNavigationCloseHandler): it puts back an item the cursor holds, else closes the window
-- as its own close button does. The window has no CloseButton for Blizzard to press: Blizzard clicks one an addon set
-- tainted on purpose (SmartNavigation.lua AttemptClose), which HideUIPanel refuses in combat; and in combat the windows
-- are out of Blizzard's list (LeaveForCombat), so B does not reach them.
---@param rec GamepadWindow
---@return boolean handled
function gamepad:Close(rec)
  if CursorHasItem() then
    ClearCursor()
    self:UpdateLegends()
    return true
  end
  rec.window:Hide(context:New('Gamepad_Close'))
  return true
end

-- ShowHint shows or hides one of Blizzard's trigger hints on a window (ShowLeftJumpHint and the others).
---@param rec GamepadWindow
---@param which "left"|"right"|"focus"
---@param shown boolean
function gamepad:ShowHint(rec, which, shown)
  local hint = rec.hints and rec.hints[which]
  if hint ~= nil then
    hint:SetShown(shown and rec.prepared)
  end
end

-- OnPanelShown: Blizzard's panel manager showed a panel and put it in its window list. One BetterBags stands in for
-- (the bank, the merchant and the guild bank frames under BetterBagsSneakyFrame) is taken out from the next frame on,
-- after Blizzard's window list has it; a panel is watched for a few frames (REPLACED_FRAMES), since BetterBags Next's
-- guild bank moves Blizzard's frame out of sight a frame after it shows. It returns "watching" or "ignored".
---@param frame? Frame
---@return string
function gamepad:OnPanelShown(frame)
  if not self.on or frame == nil then
    return "ignored"
  end
  self.replaced[frame] = REPLACED_FRAMES
  self:Schedule()
  return "watching"
end

-- OnRadialToggle: ToggleBackpack_Combined ran: the radial menu's Bags, or Blizzard's ToggleBackpack (the radial's
-- Character entry) or ToggleAllBags (which BetterBags hooks itself). On the next frame the bags toggle (Bags), follow
-- Blizzard's backpack (ToggleBackpack), or are left to BetterBags' own hook (ToggleAllBags).
function gamepad:OnRadialToggle()
  self.radial = true
  self:Schedule()
end

-- useLabel names what X does on an item now. closed is an interaction that is ending (it still counts as under way
-- while its hide event runs).
---@param closed? number
---@return string
local function useLabel(closed)
  local types = Enum.PlayerInteractionType
  for _, entry in ipairs(USE_LABELS) do
    local interaction = types and types[entry[1]]
    if interaction ~= nil and interaction ~= closed and C_PlayerInteractionManager.IsInteractingWithNpcOfType(interaction) then
      return _G[entry[2]]
    end
  end
  return CONTEXT_ACTION_LABEL_USE
end

-- UpdateLegend shows Blizzard's input legend under a window while Blizzard's cursor is in it: A (what the selected
-- button says it does, else select), X on an item (greyed out in combat), B (back with an item held, else close).
-- It hangs under what the window says is its foot (GamepadFooter: the classic bags' tabs hang below the window), else
-- under the window. It returns "shown" or "hidden".
---@param rec GamepadWindow
---@param closed? number An interaction that is ending.
---@return string
function gamepad:UpdateLegend(rec, closed)
  local legend = rec.legend
  if legend == nil then
    return "hidden"
  end
  if not (self.on and rec.registered and rec.focused) then
    legend:Hide()
    return "hidden"
  end
  local foot = rec.window.GamepadFooter ~= nil and rec.window:GamepadFooter() or rec.frame
  legend:ClearAllPoints()
  legend:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, 0)
  local button = SmartNavigation:GetCurrentButton()
  local kind = button ~= nil and self:WindowOf(button) == rec and button.bbGamepad or nil
  local template = InputPromptLegends.PromptTemplates.StandardOneIcon.name
  local function prompt(key, label, enabled)
    local p = legend:GetOrCreatePromptFrameUsingTemplateAndInputs(template, { key }, GAMEPAD_PROMPT_DIVIDER_SLASH)
    if label == nil then
      p:Hide()
      return
    end
    p:SetPromptText(label)
    if enabled then
      p:EnablePrompt()
    else
      p:DisablePrompt()
    end
    p:Show()
  end
  local selectLabel = ACTION_LABEL_SELECT
  if kind ~= nil and button.bbGamepadLabel ~= nil then
    local key = LABELS[button.bbGamepadLabel()]
    selectLabel = key and _G[key] or ACTION_LABEL_SELECT
  end
  prompt(GAMEPAD_FACE_BOTTOM, selectLabel, kind ~= nil)
  prompt(GAMEPAD_FACE_LEFT, kind == "item" and useLabel(closed) or nil, not (self.combat or InCombatLockdown()))
  prompt(GAMEPAD_FACE_RIGHT, CursorHasItem() and FRAME_ACTION_BACK or FRAME_ACTION_CLOSE, true)
  legend:ApplyDefaultPromptPositioning()
  legend:Show()
  return "shown"
end

-- UpdateLegends updates every window's legend.
---@param closed? number An interaction that is ending.
function gamepad:UpdateLegends(closed)
  for _, rec in ipairs(self.windows or {}) do
    self:UpdateLegend(rec, closed)
  end
end

-- OnTransition: the player switched the interface style (INPUT_DEVICE_INTERFACE_TRANSITION). Leaving the gamepad
-- interface, Blizzard forgets its window list (UninitializeGamepad); the windows are put back on the next frame.
-- Coming to it, the open windows join the list on the next frame. It returns "gamepad" or "mouse".
---@param newStyle number
---@return string
function gamepad:OnTransition(newStyle)
  self.on = newStyle == Enum.InputDeviceInterfaceType.Gamepad
  if not self.on then
    for _, rec in ipairs(self.windows) do
      rec.registered = false
      rec.focused = false
    end
  end
  self:Schedule()
  return self.on and "gamepad" or "mouse"
end

-- Dump is what the gamepad support knows, for /bbdb's dump (debugDumpExtras.gamepad): the interface style and the
-- combat restriction, Blizzard's window list and its focused window, the button its cursor is on and the one X
-- uses, and each window's state.
---@return table
function gamepad:Dump()
  if not self.available then
    return { available = false }
  end
  local manager = GamepadMode.FrameControlsManager
  local shown = {}
  for _, frame in ipairs(manager.shownFrames or {}) do
    table.insert(shown, nameOf(frame))
  end
  local windows = {}
  for _, rec in ipairs(self.windows) do
    table.insert(windows, {
      name = nameOf(rec.frame),
      shown = rec.window:IsShown() and true or false,
      closing = rec.window:IsClosing() and true or false,
      registered = rec.registered,
      focused = rec.focused,
      prepared = rec.prepared,
      navFrame = rec.window.scroll ~= nil and rec.window.scroll.gamepad == true,
      lastButton = nameOf(rec.lastButton),
    })
  end
  local current = SmartNavigation:GetCurrentButton()
  local replaced = {}
  for frame in pairs(self.replaced) do
    table.insert(replaced, nameOf(frame))
  end
  table.sort(replaced)
  return {
    available = true,
    on = self.on,
    style = C_InputInterfaceStyle.GetCurrentStyle(),
    restricted = restricted(),
    combat = self.combat,
    waiting = self.waiting,
    current = nameOf(current),
    currentKind = current ~= nil and current.bbGamepad or nil,
    bound = nameOf(self.bound),
    focused = nameOf(manager:GetActiveFrame()),
    shown = shown,
    windows = windows,
    replaced = replaced,
    combatFocus = self.combatFocus ~= nil and nameOf(self.combatFocus.frame) or nil,
  }
end
