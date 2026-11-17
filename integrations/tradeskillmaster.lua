local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Context: AceModule
local context = addon:GetModule('Context')

-- TradeSkillMaster is the TradeSkillMaster integration (.claude/rules/tradeskillmaster.md, issue #1315): what BetterBags
-- Next's vendor needs to swap with TSM's own vendor window, one at a time, as TSM swaps its window with Blizzard's merchant
-- frame. TSM offers no API to show its vendor window, only to ask whether it is up (TSM_API.IsUIVisible); the rest is read
-- from TSM itself (v4.15.6): its saved choice in its settings, and its own switch button, which it parents to Blizzard's
-- merchant frame, where BetterBags Next hides it. Without TSM nothing of it shows and nothing is called.
---@class TradeSkillMasterIntegration: AceModule
---@field driver Frame Looks at TSM's vendor window every frame while a vendor is open (Follow).
---@field onChange? fun(ctx: Context) Told when TSM's window shows or hides, or its switch button appears.
---@field shown? boolean Whether TSM's window was up, as last looked.
---@field canSwitch? boolean Whether TSM's switch button was there, as last looked.
---@field switchButton? Button TSM's switch button, once found.
local tradeSkillMaster = addon:NewModule('TradeSkillMaster')

-- TSM's saved choice for its vendor window, in its settings (TradeSkillMasterDB): each setting is kept under
-- "scope@scopeValue@namespace@key", the global scope's value " " (LibTSMTypes Settings DB.lua, Types.lua), and the vendor
-- window mirrors its showDefault there (App/VendoringUI/Core.lua): false, TSM's default, for its own window; true once
-- its WoW UI button chose Blizzard's frame.
local SHOW_DEFAULT = "g@ @vendoringUIContext@showDefault"

tradeSkillMaster.driver = CreateFrame("Frame")

-- api returns TSM's API when TSM is loaded, else nil.
---@return {IsUIVisible: fun(uiName: string): boolean}?
local function api()
  local tsm = _G.TSM_API
  if type(tsm) == "table" and type(tsm.IsUIVisible) == "function" then
    return tsm
  end
  return nil
end

-- Available says whether TSM is loaded.
---@return boolean
function tradeSkillMaster:Available()
  return api() ~= nil
end

-- WindowShown says whether TSM's vendor window is up (TSM_API.IsUIVisible, called with a dot: TSM errors on a colon).
---@return boolean
function tradeSkillMaster:WindowShown()
  local tsm = api()
  return tsm ~= nil and tsm.IsUIVisible("VENDORING") == true
end

-- ChoosesWindow says whether TSM's saved choice is its own vendor window: TSM shows it a frame after every merchant
-- opens, and Blizzard's frame not at all, until its WoW UI button chooses that.
---@return boolean
function tradeSkillMaster:ChoosesWindow()
  local settings = _G.TradeSkillMasterDB
  return api() ~= nil and type(settings) == "table" and settings[SHOW_DEFAULT] == false
end

-- SwitchButton returns TSM's switch button, or nil before TSM has made it: the one Button on Blizzard's merchant frame
-- TSM made (every frame it makes carries its widget extensions, TSMSetScript among them; LibTSMUI Widgets.lua), which it
-- makes the first time it shows Blizzard's frame and keeps (SwitchButton.lua, App/VendoringUI/Core.lua).
---@return Button?
function tradeSkillMaster:SwitchButton()
  local button = self.switchButton
  if button ~= nil and button:GetParent() == MerchantFrame then
    return button
  end
  self.switchButton = nil
  for _, child in ipairs({ MerchantFrame:GetChildren() }) do
    if child:GetObjectType() == "Button" and type(child.TSMSetScript) == "function" then
      self.switchButton = child
      return child
    end
  end
  return nil
end

-- CanSwitch says whether TSM's switch button is there to open its window with.
---@return boolean
function tradeSkillMaster:CanSwitch()
  return self:SwitchButton() ~= nil
end

-- OpenWindow opens TSM's vendor window as its switch button on Blizzard's merchant frame does, by clicking it: TSM saves
-- its window as its choice, moves Blizzard's frame off the screen and shows its window (ACTION_SWITCH). Never while the
-- window is up: the switch would close it. It returns what it did, for profiler traces: "opened", "clicked" (TSM's window
-- not up yet), "shown" (it was up), "no switch" or "no tsm".
---@return string
function tradeSkillMaster:OpenWindow()
  if api() == nil then
    return "no tsm"
  end
  if self:WindowShown() then
    return "shown"
  end
  local button = self:SwitchButton()
  if button == nil then
    return "no switch"
  end
  button:Click()
  return self:WindowShown() and "opened" or "clicked"
end

-- Follow tells onChange, while a vendor is open, when TSM's window has shown or hidden, or its switch button appeared,
-- since it last looked (Look, every frame). TSM shows its window a frame after a merchant opens, and either of its
-- buttons switches it in a click of its own. It returns whether it follows: only with TSM loaded.
---@param onChange fun(ctx: Context)
---@return boolean
function tradeSkillMaster:Follow(onChange)
  if api() == nil then
    self:Stop()
    return false
  end
  self.onChange = onChange
  self.shown = self:WindowShown()
  self.canSwitch = self:CanSwitch()
  self.driver:SetScript("OnUpdate", function()
    self:Look()
  end)
  return true
end

-- Look looks at TSM's window, and for its switch button while it has not found it and the window is not up, telling
-- onChange when either changed. It returns what changed, for profiler traces: "window", "switch" or "same".
---@return string
function tradeSkillMaster:Look()
  local shown = self:WindowShown()
  local canSwitch = self.canSwitch
  if not canSwitch and not shown then
    canSwitch = self:CanSwitch()
  end
  if shown == self.shown and canSwitch == self.canSwitch then
    return "same"
  end
  local changed = shown ~= self.shown and "window" or "switch"
  self.shown, self.canSwitch = shown, canSwitch
  if self.onChange then
    self.onChange(context:New('TradeSkillMaster_Changed'))
  end
  return changed
end

-- Stop stops following TSM's window, as the vendor closes.
function tradeSkillMaster:Stop()
  self.driver:SetScript("OnUpdate", nil)
  self.onChange, self.shown, self.canSwitch = nil, nil, nil
end
