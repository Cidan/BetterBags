-- tsm.lua -- TradeSkillMaster's vendor window as v4.15.6 runs it (its CurseForge file 9546800; "Interface: 120105, 50504,
-- 20506, 16001, 11509"), for the TradeSkillMaster integration (integrations/tradeskillmaster.lua,
-- .claude/rules/tradeskillmaster.md). Only what another addon meets of it, each piece from its source:
--   TSM_API.IsUIVisible("VENDORING") (App/API.lua:60-73): whether its window is up (VendoringUI.IsVisible: its state's
--     frame is set). Called with a colon, it errors (CheckCallMethod, App/API.lua:536-540).
--   Its saved choice, TradeSkillMasterDB["g@ @vendoringUIContext@showDefault"] (App/VendoringUI/Core.lua:65-75: the state
--     mirrored to the setting; LibTSMTypes/Source/Settings/Internal/DB.lua:275-293, 603-619: each setting under
--     "scope@scopeValue@namespace@key", the global scope's value " ", Types.lua:46-50; the table protected from new keys,
--     DB.lua:215-242): false, its default, for its own window; true once its WoW UI button chose Blizzard's frame.
--   At a merchant (PLAYER_INTERACTION_MANAGER_FRAME_SHOW, LibTSMWoW/Source/UI/DefaultUI.lua:151-186), a frame later
--     (DelayTimer RunForFrames(0), Core.lua:86, 140-148; Frame runs it): with that choice Blizzard's frame
--     (ACTION_SHOW_DEFAULT, Core.lua:149-154: its switch button shown, the frame given its place and its width in the
--     layout back, Move.RestoreDefaultUI, LibTSMWoW/Source/Service/Move.lua:142-165, then MerchantFrame_Update), else its
--     window (ACTION_SHOW_FRAME, Core.lua:155-161: the merchant frame moved off the screen and out of the layout,
--     Move.SetDefaultUIOffScreen, Move.lua:109-137, kept there whenever it is placed, Move.lua:186-198; then its window).
--   Its window (LibTSMUI/Source/Frames/ApplicationFrame.lua:59-162): under UIParent, in UISpecialFrames, a "WoW UI"
--     button in its title bar that switches (ACTION_SWITCH_TO_DEFAULT, OnSwitchButtonClick); as it hides, the visit ends
--     (ACTION_FRAME_HIDE, Core.lua:167-172: CloseMerchant) unless it is switching.
--   The switch (ACTION_SWITCH, Core.lua:173-180), from either button: the choice flipped; to Blizzard's frame, its window
--     hidden while switching and let go; then Blizzard's frame or its window.
--   Its switch button (Core.lua:122-127; LibTSMUI/Source/Components/Controls/SwitchButton.lua:24-39, ActionButton.lua:
--     158-166, 384-398): a Button made the first time Blizzard's frame shows and kept, parented to MerchantFrame, its
--     OnClick the switch. Every frame TSM makes carries its widget extensions, copied onto it (LibTSMUI/Source/Util/
--     Widgets.lua:605-614, 689-: TSMSetScript and the rest).
--   Its close button or Escape (ApplicationFrame.lua:150-154, 466-467; UISpecialFrames): its window hidden, ending the
--     visit, but not let go: TSM_API.IsUIVisible says it is up until the interaction ends.
--   The merchant closing (PLAYER_INTERACTION_MANAGER_FRAME_HIDE, DefaultUI.lua:38-51; Core.lua:140-146, 162-166): its
--     window hidden, ending the visit again when it was still shown, and let go.
-- The mocks hide a frame without running its OnHide; the client runs it, so this runs its window's as it hides it.
local M = {}

M.KEY = "g@ @vendoringUIContext@showDefault"

-- Move.lua's DEFAULT_POINTS and DEFAULT_ATTRIBUTES for MerchantFrame.
local DEFAULT_POINT = { "TOPLEFT", "UIParent", "TOPLEFT", 16, -116 }
local DEFAULT_ATTRIBUTES = { xoffset = 0, width = 336 }

-- extend copies TSM's widget extensions onto a frame it makes (Widgets.lua WithExtension): its TSM* methods.
local function extend(frame)
  frame.__debug = {}
  function frame:TSMSetScript(script, handler) self:SetScript(script, handler) end
  function frame:TSMHookScript(script, handler) self:HookScript(script, handler) end
  function frame:TSMSetDisabled(value) if value then self:Disable() else self:Enable() end end
  return frame
end

-- Install puts TradeSkillMaster in place: TSM_API, TradeSkillMasterDB with its vendor window's saved choice
-- (showDefault: true for Blizzard's frame; false, TSM's default, for its own window), nothing at a merchant yet. It
-- returns the model; Remove takes TSM away again.
---@param showDefault? boolean
function M.Install(showDefault)
  local tsm = { showDefault = showDefault == true, merchant = false, pending = false, switching = false,
    frame = nil, switchButton = nil, point = nil, hooked = {}, updates = 0, closes = 0 }
  M.current = tsm

  local db = setmetatable({ [M.KEY] = tsm.showDefault }, {
    __newindex = function() error("Attempting to modify a protected table") end,
    __metatable = false,
  })
  local api = {}
  function api.IsUIVisible(uiName)
    if uiName == api then
      error("Invalid usage of colon operator to call TSM_API function", 3)
    end
    if uiName == "VENDORING" then
      return tsm.frame ~= nil
    end
    return false
  end
  M.saved = { TSM_API = rawget(_G, "TSM_API"), TradeSkillMasterDB = rawget(_G, "TradeSkillMasterDB"),
    UISpecialFrames = rawget(_G, "UISpecialFrames") }
  _G.TSM_API = api
  _G.TradeSkillMasterDB = db
  _G.UISpecialFrames = rawget(_G, "UISpecialFrames") or {}

  local function choose(value)
    tsm.showDefault = value
    rawset(db, M.KEY, value)
  end

  -- Move.SetPointHook: the merchant frame kept off the screen wherever it is placed, while its point is saved.
  local function keepOff(frame)
    if tsm.point == nil or tsm.ignoreSetPoint then
      return
    end
    tsm.ignoreSetPoint = true
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100000, 100000)
    tsm.ignoreSetPoint = nil
  end

  local function offScreen()
    local frame = MerchantFrame
    frame.ignoreFramePositionManager = true
    SetUIPanelAttribute(frame, "xoffset", -32)
    SetUIPanelAttribute(frame, "width", 0)
    UpdateUIPanelPositions(frame)
    -- Saved once, until it is restored: off the screen a second time, the place it had before stays.
    if tsm.point == nil then
      local point = { frame:GetPoint(1) }
      tsm.point = point[1] ~= nil and point or { unpack(DEFAULT_POINT) }
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100000, 100000)
    if not tsm.hooked[frame] then
      hooksecurefunc(frame, "SetPoint", keepOff)
      tsm.hooked[frame] = true
    end
  end

  local function restore()
    local frame = MerchantFrame
    frame:ClearAllPoints()
    local point = tsm.point or DEFAULT_POINT
    tsm.point = nil
    frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
    frame.ignoreFramePositionManager = nil
    for name, value in pairs(DEFAULT_ATTRIBUTES) do
      SetUIPanelAttribute(frame, name, value)
    end
    UpdateUIPanelPositions(frame)
  end

  local switch

  -- hide hides its window, running its OnHide as the client does when it was shown.
  local function hide(frame)
    local shown = frame:IsShown()
    frame:Hide()
    if shown then
      frame:GetScript("OnHide")(frame)
    end
  end

  -- hideWindow hides its window and lets go of it (ACTION_HIDE_FRAME: Hide, then Release, which clears the state's frame).
  local function hideWindow()
    hide(tsm.frame)
    tsm.frame = nil
  end

  local function showDefaultUI()
    if tsm.switchButton == nil then
      local button = extend(CreateFrame("Button"))
      button:SetParent(MerchantFrame)
      button:TSMSetScript("OnClick", function() switch() end)
      tsm.switchButton = button
    end
    tsm.switchButton:Show()
    restore()
    tsm.updates = tsm.updates + 1
    local update = rawget(_G, "MerchantFrame_Update")
    if update then
      update()
    end
  end

  local function showWindow()
    assert(tsm.frame == nil)
    offScreen()
    local frame = extend(CreateFrame("Frame", nil, UIParent))
    table.insert(UISpecialFrames, 1, tostring(frame))
    frame.switchBtn = extend(CreateFrame("Button", nil, frame))
    frame.switchBtn:TSMSetScript("OnClick", function() switch() end)
    frame:SetScript("OnHide", function()
      if tsm.switching then
        return
      end
      tsm.closes = tsm.closes + 1
      CloseMerchant()
    end)
    frame:Show()
    tsm.frame = frame
  end

  switch = function()
    choose(not tsm.showDefault)
    if tsm.showDefault and tsm.frame then
      tsm.switching = true
      hideWindow()
      tsm.switching = false
    end
    if tsm.showDefault then
      showDefaultUI()
    else
      showWindow()
    end
  end

  -- MerchantShow is PLAYER_INTERACTION_MANAGER_FRAME_SHOW for a merchant: TSM decides a frame later (Frame).
  function tsm:MerchantShow()
    if self.merchant then
      return
    end
    self.merchant = true
    self.pending = true
  end

  -- Frame runs what TSM left for the next frame: the window or Blizzard's frame, at a merchant just opened.
  function tsm:Frame()
    if not self.pending then
      return
    end
    self.pending = false
    if self.showDefault then
      showDefaultUI()
    else
      showWindow()
    end
  end

  -- MerchantHide is PLAYER_INTERACTION_MANAGER_FRAME_HIDE for a merchant.
  function tsm:MerchantHide()
    if not self.merchant then
      return
    end
    self.merchant = false
    if self.frame then
      hideWindow()
    end
  end

  -- CloseWindow closes TSM's window as its close button or Escape does (ApplicationFrame.lua ACTION_HIDE, the frame's
  -- Hide): it hides, ending the visit, and stays TSM's (still up to TSM_API.IsUIVisible) until the interaction ends.
  function tsm:CloseWindow()
    hide(self.frame)
  end

  -- ClickWoWUI clicks the WoW UI button in its window's title bar.
  function tsm:ClickWoWUI()
    self.frame.switchBtn:Click()
  end

  return tsm
end

-- Remove takes TradeSkillMaster away: TSM_API and TradeSkillMasterDB as they were.
function M.Remove()
  if M.saved == nil then
    return
  end
  _G.TSM_API = M.saved.TSM_API
  _G.TradeSkillMasterDB = M.saved.TradeSkillMasterDB
  _G.UISpecialFrames = M.saved.UISpecialFrames
  M.saved, M.current = nil, nil
end

return M
