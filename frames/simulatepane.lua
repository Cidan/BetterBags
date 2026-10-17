local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Sonata: AceModule
local sonata = addon:GetModule('Sonata')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

---@class List: AceModule
local list = addon:GetModule('List')

---@class PerfSessions: AceModule
local perfSessions = addon:GetModule('PerfSessions')

---@class Simulator: AceModule
local simulator = addon:GetModule('Simulator')

-- The Simulate tab of the debug window: pick one of the events BetterBags listens to, a rate
-- and a duration, and fire it through the event simulator (debug/simulator.lua), with the bags
-- opened and a profiler capture when asked. It shows the run's progress and which addon
-- restrictions are active, so a test inside a dungeon or raid can be checked.
---@class SimulatePane: AceModule
local simulatePane = addon:NewModule('SimulatePane')

-- The Dream Breath test: the busiest second of BAG_UPDATE_COOLDOWN in a user's capture while
-- casting it (22 fires), for 30 seconds.
local PRESET = { event = 'BAG_UPDATE_COOLDOWN', rate = 22, duration = 30 }

local STATUS_INTERVAL = 0.25

---@class SimulatePaneFrame
---@field frame Frame
---@field eventList ListFrame
---@field selected? string
---@field eventLabel FontString
---@field rateBox EditBox
---@field durationBox EditBox
---@field payloadBox EditBox
---@field openBagsCheck CheckButton
---@field captureCheck CheckButton
---@field startButton Button
---@field presetButton Button
---@field status FontString
---@field restrictions FontString
local paneProto = {}
addon:GetModule('Perf'):RegisterPrototype(paneProto, 'SimulatePaneFrame')

---@param parent Frame
---@param text string
---@param anchor Region
---@param y number
---@return FontString
local function label(parent, text, anchor, y)
  local fs = sonata:CreateText(parent, "Body")
  fs:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, y)
  fs:SetText(text)
  return fs
end

---@param parent Frame
---@param anchor Region
---@param width number
---@return EditBox
local function inputBox(parent, anchor, width)
  local box = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate') --[[@as EditBox]]
  box:SetSize(width, 20)
  box:SetAutoFocus(false)
  box:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 6, -4)
  box:SetScript('OnEscapePressed', function(me) me:ClearFocus() end)
  box:SetScript('OnEnterPressed', function(me) me:ClearFocus() end)
  return box
end

---@param parent Frame
---@param text string
---@param anchor Region
---@return CheckButton
local function checkbox(parent, text, anchor)
  local check = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate') --[[@as CheckButton]]
  check:SetSize(24, 24)
  check:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', -6, -10)
  local fs = sonata:CreateText(parent, "Body")
  fs:SetPoint('LEFT', check, 'RIGHT', 2, 0)
  fs:SetText(text)
  check.label = fs
  return check
end

---@param parent Frame
---@return SimulatePaneFrame
function simulatePane:Create(parent)
  local pane = setmetatable({}, { __index = paneProto }) --[[@as SimulatePaneFrame]]
  local f = CreateFrame('Frame', nil, parent)
  pane.frame = f
  pane.sinceStatus = 0

  pane.eventList = list:Create(f)
  pane.eventList.frame:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, 0)
  pane.eventList.frame:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 0, 0)
  pane.eventList.frame:SetWidth(240)
  pane.eventList:SetupDataSource('BetterBagsPlainTextListButton', function(button, entry)
    pane:InitEventButton(button, entry)
  end, function() end)

  local right = CreateFrame('Frame', nil, f)
  right:SetPoint('TOPLEFT', pane.eventList.frame, 'TOPRIGHT', 16, -8)
  right:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -10, 8)

  local title = sonata:CreateText(right, "Title")
  title:SetPoint('TOPLEFT', right, 'TOPLEFT', 0, 0)
  title:SetText('Simulate an event')

  local help = sonata:CreateText(right, "BodySmall")
  help:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6)
  help:SetPoint('RIGHT', right, 'RIGHT', 0, 0)
  help:SetJustifyH('LEFT')
  help:SetText('Fires the event through BetterBags\' own handlers, as if the game had sent it. '
    .. 'Other addons and Blizzard\'s frames do not see it. Run it inside a dungeon or raid to '
    .. 'test under the addon restrictions those apply.')

  local eventTitle = label(right, 'Event', help, -14)
  pane.eventLabel = sonata:CreateText(right, "Field")
  pane.eventLabel:SetPoint('LEFT', eventTitle, 'RIGHT', 10, 0)
  pane.eventLabel:SetText('none picked')

  local rateTitle = label(right, 'Fires per second', eventTitle, -14)
  pane.rateBox = inputBox(right, rateTitle, 80)
  pane.rateBox:SetNumeric(true)
  pane.rateBox:SetText('12')

  local durationTitle = label(right, 'Seconds', pane.rateBox, -10)
  durationTitle:SetPoint('TOPLEFT', pane.rateBox, 'BOTTOMLEFT', -6, -10)
  pane.durationBox = inputBox(right, durationTitle, 80)
  pane.durationBox:SetNumeric(true)
  pane.durationBox:SetText('30')

  local payloadTitle = label(right, 'Payload (comma-separated, optional)', pane.durationBox, -10)
  payloadTitle:SetPoint('TOPLEFT', pane.durationBox, 'BOTTOMLEFT', -6, -10)
  pane.payloadBox = inputBox(right, payloadTitle, 300)

  pane.openBagsCheck = checkbox(right, 'Open the bags first', pane.payloadBox)
  pane.openBagsCheck:SetChecked(true)
  pane.captureCheck = checkbox(right, 'Capture with the profiler', pane.openBagsCheck)
  pane.captureCheck:SetPoint('TOPLEFT', pane.openBagsCheck, 'BOTTOMLEFT', 0, -2)
  pane.captureCheck:SetChecked(true)

  pane.startButton = CreateFrame('Button', nil, right, 'UIPanelButtonTemplate') --[[@as Button]]
  pane.startButton:SetSize(110, 22)
  pane.startButton:SetPoint('TOPLEFT', pane.captureCheck, 'BOTTOMLEFT', 6, -14)
  pane.startButton:SetText('Start')
  pane.startButton:SetScript('OnClick', function()
    if simulator:IsRunning() then
      pane:Stop()
    else
      pane:Start()
    end
  end)

  pane.presetButton = CreateFrame('Button', nil, right, 'UIPanelButtonTemplate') --[[@as Button]]
  pane.presetButton:SetSize(160, 22)
  pane.presetButton:SetPoint('LEFT', pane.startButton, 'RIGHT', 10, 0)
  pane.presetButton:SetText('Dream Breath test')
  pane.presetButton:SetScript('OnClick', function()
    pane:ApplyPreset()
  end)

  pane.status = sonata:CreateText(right, "Body")
  pane.status:SetPoint('TOPLEFT', pane.startButton, 'BOTTOMLEFT', 0, -14)
  pane.status:SetPoint('RIGHT', right, 'RIGHT', 0, 0)
  pane.status:SetJustifyH('LEFT')
  pane.status:SetText('')

  pane.restrictions = sonata:CreateText(right, "BodySmall")
  pane.restrictions:SetPoint('TOPLEFT', pane.status, 'BOTTOMLEFT', 0, -10)
  pane.restrictions:SetPoint('RIGHT', right, 'RIGHT', 0, 0)
  pane.restrictions:SetJustifyH('LEFT')

  events:RegisterMessage('simulator/StateChanged', function()
    pane:UpdateStatus()
  end)
  f:SetScript('OnUpdate', function(_, elapsed)
    pane.sinceStatus = pane.sinceStatus + (elapsed or 0)
    if pane.sinceStatus >= STATUS_INTERVAL then
      pane.sinceStatus = 0
      pane:UpdateStatus()
    end
  end)
  pane:UpdateStatus()
  return pane
end

---@param button Button
---@param entry {event: string}
function paneProto:InitEventButton(button, entry)
  local text = button.Text or button.text
  if text == nil then
    text = sonata:CreateText(button, "Body")
    text:SetPoint('LEFT', button, 'LEFT', 8, 0)
    button.text = text
  end
  text:SetText(entry.event)
  button:SetScript('OnClick', function()
    self:SelectEvent(entry.event)
  end)
end

---@param event string
function paneProto:SelectEvent(event)
  self.selected = event
  self.eventLabel:SetText(event)
end

-- Update lists the events BetterBags listens to (the debug window calls it on showing the tab).
function paneProto:Update()
  self.eventList:Wipe()
  local entries = {}
  for _, name in ipairs(simulator:GetEvents()) do
    table.insert(entries, { event = name })
  end
  self.eventList:InsertTable(entries)
  self:UpdateStatus()
end

function paneProto:ApplyPreset()
  self:SelectEvent(PRESET.event)
  self.rateBox:SetText(tostring(PRESET.rate))
  self.durationBox:SetText(tostring(PRESET.duration))
  self.payloadBox:SetText('')
  self.openBagsCheck:SetChecked(true)
  self.captureCheck:SetChecked(true)
end

function paneProto:Start()
  if self.selected == nil then
    self.status:SetText('Pick an event to simulate.')
    return
  end
  local text = self.payloadBox:GetText() or ''
  local payload, count = simulator:ParsePayload(text)
  local started = simulator:Start(context:New('SimulatePane_Start'), {
    event = self.selected,
    rate = tonumber(self.rateBox:GetText()) or 0,
    duration = tonumber(self.durationBox:GetText()) or 0,
    payload = payload,
    payloadCount = count,
    payloadText = text,
    openBags = self.openBagsCheck:GetChecked() == true,
    capture = self.captureCheck:GetChecked() == true,
  })
  if not started then
    self.status:SetText('Could not start: ' .. self.selected .. ' is not an event BetterBags listens to, or a run is going.')
  end
  self:UpdateStatus()
end

function paneProto:Stop()
  simulator:Stop(context:New('SimulatePane_Stop'))
  self:UpdateStatus()
end

-- restrictionText lists the active addon restrictions, alphabetically.
---@return string
local function restrictionText()
  local states = perfSessions:RestrictionStates()
  if states == nil then
    return 'Addon restrictions: not available on this client'
  end
  local active = {}
  for name, state in pairs(states) do
    if state == 'Active' then
      table.insert(active, name)
    elseif state == 'Activating' then
      table.insert(active, name .. ' (activating)')
    end
  end
  table.sort(active)
  if #active == 0 then
    return 'Addon restrictions: none active'
  end
  return 'Addon restrictions: ' .. table.concat(active, ', ')
end

function paneProto:UpdateStatus()
  local run = simulator:GetStatus()
  if simulator:IsRunning() and run then
    self.startButton:SetText('Stop')
    self.status:SetText(string.format('Firing %s at %d/s: %d of %d, %.1f s left', run.event, run.rate,
      run.fired, run.total, math.max(0, run.duration - run.elapsed)))
  else
    self.startButton:SetText('Start')
    if run then
      self.status:SetText(string.format('Fired %s %d times at %d/s', run.event, run.fired, run.rate))
    end
  end
  self.restrictions:SetText(restrictionText())
end

function paneProto:Show()
  self.frame:Show()
end

function paneProto:Hide()
  self.frame:Hide()
end
