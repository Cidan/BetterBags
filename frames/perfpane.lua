local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Constants: AceModule
local const = addon:GetModule('Constants')

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class List: AceModule
local list = addon:GetModule('List')

---@class Form: AceModule
local form = addon:GetModule('Form')

---@class Question: AceModule
local question = addon:GetModule('Question')

---@class Perf: AceModule
local perf = addon:GetModule('Perf')

---@class PerfSessions: AceModule
local perfSessions = addon:GetModule('PerfSessions')

---@class PerfFormat: AceModule
local perfFormat = addon:GetModule('PerfFormat')

---@class FlameGraph: AceModule
local flameGraph = addon:GetModule('FlameGraph')

-- PerfPane is the Performance tab of the /bbdb debug window: it starts and stops profiler
-- captures, lists the sessions saved in BetterBagsPerfDB, and shows a session as a flame
-- graph, a function table, its worst frames, and a summary.
---@class PerfPane: AceModule
local perfPane = addon:NewModule('PerfPane')

local VIEW_ORDER = { 'flame', 'functions', 'frames', 'summary' }
local VIEW_LABELS = {
  flame = 'Flame Graph',
  functions = 'Functions',
  frames = 'Frames',
  summary = 'Summary',
}

local FUNCTION_COLUMNS = {
  { key = 'name', label = 'Function', width = 180, justify = 'LEFT' },
  { key = 'calls', label = 'Calls', width = 48, justify = 'RIGHT' },
  { key = 'incl', label = 'Total', width = 60, justify = 'RIGHT' },
  { key = 'self', label = 'Self', width = 60, justify = 'RIGHT' },
  { key = 'avg', label = 'Avg', width = 58, justify = 'RIGHT' },
  { key = 'max', label = 'Max', width = 60, justify = 'RIGHT' },
  { key = 'alloc', label = 'Alloc', width = 56, justify = 'RIGHT' },
}

local BLIZZARD_METRICS = {
  { 'RecentAverageTime', 'Recent average', true },
  { 'PeakTime', 'Peak time', true },
  { 'CountTimeOver5Ms', 'Frames over 5 ms', false },
  { 'CountTimeOver10Ms', 'Frames over 10 ms', false },
  { 'CountTimeOver50Ms', 'Frames over 50 ms', false },
  { 'CountTimeOver100Ms', 'Frames over 100 ms', false },
  { 'CountTimeOver500Ms', 'Frames over 500 ms', false },
}

-- Above this share of profiler overhead, an adjusted time is mostly an estimate.
local ROUGH_ESTIMATE_SHARE = 0.75
local ADJUSTED_FIELD = { incl = 'adjIncl', self = 'adjSelf', avg = 'adjAvg' }

local TIMELINE_COLUMNS = 270
local TIMELINE_HEIGHT = 70
local STATUS_INTERVAL = 0.5

local function plural(n, word)
  return string.format('%s %s%s', perfFormat:Count(n), word, n == 1 and '' or 's')
end

local function formatDate(t, pattern)
  if not t then return '?' end
  return date(pattern, t)
end

---@param button Button
---@param data table
local function initRow(button, data)
  button.Text:SetText(data.text)
  button.Selected:SetShown(data.selected == true)
  button:SetScript('OnClick', data.onClick)
end

---@class PerfPaneFrame
---@field frame Frame
---@field status FontString
---@field startButton Button
---@field armCheck CheckButton
---@field settingsButton Button
---@field deleteButton Button
---@field deleteAllButton Button
---@field sessionList ListFrame
---@field views table<string, Frame>
---@field viewButtons table<string, Button>
---@field flame FlameGraphFrame
---@field searchBox EditBox
---@field metricButton Button
---@field adjustCheck CheckButton
---@field adjust boolean Subtract profiler overhead when the session has a calibration.
---@field overhead PerfOverhead|nil
---@field showAlloc boolean
---@field functionList ListFrame
---@field functionHeaders table<string, Button>
---@field frameList ListFrame
---@field frameFlame FlameGraphFrame
---@field timeline Frame
---@field timelineBars Texture[]
---@field timelineBlizzardBars Texture[]
---@field summaryText FontString
---@field settingsForm FormFrame|nil
---@field selectedId number|nil
---@field selectedFrame number|nil
---@field session table|nil
---@field tree PerfTree|nil
---@field functions PerfFunctionStats[]
---@field sortKey string
---@field sortDescending boolean
---@field newestSeen number
---@field currentView string
local paneProto = {}

---@param parent Frame
---@return PerfPaneFrame
function perfPane:Create(parent)
  local pane = setmetatable({}, { __index = paneProto }) --[[@as PerfPaneFrame]]
  pane.frame = CreateFrame('Frame', nil, parent)
  pane.views = {}
  pane.viewButtons = {}
  pane.functionHeaders = {}
  pane.functions = {}
  pane.timelineBars = {}
  pane.timelineBlizzardBars = {}
  pane.sortKey = 'self'
  pane.adjust = true
  pane.showAlloc = false
  pane.sortDescending = true
  pane.newestSeen = 0
  pane.sinceStatus = 0

  pane:CreateControls()
  pane:CreateSessionList()
  pane:CreateViews()
  pane:ShowView('flame')
  pane:ClearSelection()

  events:RegisterMessage('perf/StateChanged', function()
    pane:UpdateControls()
    pane:UpdateStatus()
  end)
  events:RegisterMessage('perf/SessionsChanged', function()
    pane:OnSessionsChanged()
  end)

  pane.frame:SetScript('OnUpdate', function(_, elapsed)
    pane.sinceStatus = pane.sinceStatus + (elapsed or 0)
    if pane.sinceStatus >= STATUS_INTERVAL then
      pane.sinceStatus = 0
      if perfSessions:IsCapturing() then
        pane:UpdateStatus()
      end
    end
  end)

  pane:Update()
  return pane
end

function paneProto:CreateControls()
  local f = self.frame

  self.startButton = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate') --[[@as Button]]
  self.startButton:SetSize(120, 22)
  self.startButton:SetPoint('TOPLEFT', f, 'TOPLEFT', 10, -8)
  self.startButton:SetScript('OnClick', function()
    if perfSessions:IsCapturing() then
      perfSessions:StopCapture()
    else
      perfSessions:StartCapture('manual')
    end
  end)

  self.settingsButton = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate') --[[@as Button]]
  self.settingsButton:SetSize(90, 22)
  self.settingsButton:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -10, -8)
  self.settingsButton:SetText('Settings')
  self.settingsButton:SetScript('OnClick', function()
    self:OpenSettings()
  end)

  local armLabel = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  armLabel:SetPoint('RIGHT', self.settingsButton, 'LEFT', -12, 0)
  armLabel:SetText('Capture next reload')

  self.armCheck = CreateFrame('CheckButton', nil, f, 'UICheckButtonTemplate') --[[@as CheckButton]]
  self.armCheck:SetSize(24, 24)
  self.armCheck:SetPoint('RIGHT', armLabel, 'LEFT', -2, 0)
  self.armCheck:SetScript('OnClick', function(button)
    perfSessions:SetArmedForNextReload(button:GetChecked())
  end)

  self.status = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  self.status:SetPoint('LEFT', self.startButton, 'RIGHT', 12, 0)
  self.status:SetPoint('RIGHT', self.armCheck, 'LEFT', -8, 0)
  self.status:SetJustifyH('LEFT')
  self.status:SetWordWrap(false)
end

function paneProto:CreateSessionList()
  local f = self.frame
  local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOPLEFT', f, 'TOPLEFT', 10, -42)
  title:SetText('Saved Sessions')

  self.sessionList = list:Create(f)
  self.sessionList.frame:SetPoint('TOPLEFT', f, 'TOPLEFT', 4, -56)
  self.sessionList.frame:SetPoint('BOTTOMRIGHT', f, 'BOTTOMLEFT', 214, 36)
  self.sessionList:SetupDataSource('BetterBagsPerfRow', initRow, function() end)

  self.deleteButton = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate') --[[@as Button]]
  self.deleteButton:SetSize(98, 22)
  self.deleteButton:SetPoint('BOTTOMLEFT', f, 'BOTTOMLEFT', 10, 8)
  self.deleteButton:SetText('Delete')
  self.deleteButton:SetScript('OnClick', function()
    if self.selectedId then
      perfSessions:DeleteSession(self.selectedId)
    end
  end)

  self.deleteAllButton = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate') --[[@as Button]]
  self.deleteAllButton:SetSize(98, 22)
  self.deleteAllButton:SetPoint('LEFT', self.deleteButton, 'RIGHT', 6, 0)
  self.deleteAllButton:SetText('Delete All')
  self.deleteAllButton:SetScript('OnClick', function()
    local count = #perfSessions:GetSessions()
    if count == 0 then return end
    question:YesNo('Delete All Sessions', string.format('Delete all %s?', plural(count, 'saved performance session')), function()
      perfSessions:DeleteAllSessions()
    end, function() end)
  end)
end

function paneProto:CreateViews()
  local f = self.frame
  local previous
  for _, name in ipairs(VIEW_ORDER) do
    local button = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate') --[[@as Button]]
    button:SetSize(90, 22)
    if previous then
      button:SetPoint('LEFT', previous, 'RIGHT', 4, 0)
    else
      button:SetPoint('TOPLEFT', f, 'TOPLEFT', 224, -38)
    end
    button:SetText(VIEW_LABELS[name])
    button:SetScript('OnClick', function()
      self:ShowView(name)
    end)
    self.viewButtons[name] = button
    previous = button

    local view = CreateFrame('Frame', nil, f)
    view:SetPoint('TOPLEFT', f, 'TOPLEFT', 224, -66)
    view:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -8, 8)
    self.views[name] = view
  end

  self.adjustCheck = CreateFrame('CheckButton', nil, f, 'UICheckButtonTemplate') --[[@as CheckButton]]
  self.adjustCheck:SetSize(24, 24)
  self.adjustCheck:SetPoint('LEFT', previous, 'RIGHT', 10, 0)
  self.adjustCheck:SetScript('OnClick', function(button)
    self.adjust = button:GetChecked()
    self:ApplyMetric()
  end)
  self.adjustCheck:SetScript('OnEnter', function(button)
    GameTooltip:SetOwner(button, 'ANCHOR_TOP')
    GameTooltip:SetText('Subtract profiler overhead', 1, 1, 1)
    GameTooltip:AddLine('Every measured call costs a little time inside the profiler itself. The cost per call is measured when the capture starts and removed from the numbers. Functions that are mostly overhead are greyed out: their adjusted time is a rough estimate.', nil, nil, nil, true)
    GameTooltip:Show()
  end)
  self.adjustCheck:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)
  local adjustLabel = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  adjustLabel:SetPoint('LEFT', self.adjustCheck, 'RIGHT', 2, 0)
  adjustLabel:SetText('Subtract overhead')

  self:CreateFlameView(self.views.flame)
  self:CreateFunctionsView(self.views.functions)
  self:CreateFramesView(self.views.frames)
  self:CreateSummaryView(self.views.summary)
end

---@param view Frame
function paneProto:CreateFlameView(view)
  local label = view:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  label:SetPoint('TOPLEFT', view, 'TOPLEFT', 0, -4)
  label:SetText('Search')

  self.searchBox = CreateFrame('EditBox', nil, view, 'InputBoxTemplate') --[[@as EditBox]]
  self.searchBox:SetSize(170, 20)
  self.searchBox:SetPoint('LEFT', label, 'RIGHT', 10, 0)
  self.searchBox:SetAutoFocus(false)
  self.searchBox:SetScript('OnTextChanged', function(box)
    self.flame:SetSearch(box:GetText())
  end)
  self.searchBox:SetScript('OnEscapePressed', function(box)
    box:ClearFocus()
  end)

  self.metricButton = CreateFrame('Button', nil, view, 'UIPanelButtonTemplate') --[[@as Button]]
  self.metricButton:SetSize(150, 20)
  self.metricButton:SetPoint('TOPRIGHT', view, 'TOPRIGHT', 0, 0)
  self.metricButton:SetScript('OnClick', function()
    self.showAlloc = not self.showAlloc
    self.flame:SetMetric(self:FlameMetric())
    self:UpdateMetricButton()
  end)

  self.flame = flameGraph:Create(view)
  self.flame.frame:SetPoint('TOPLEFT', view, 'TOPLEFT', 0, -26)
  self.flame.frame:SetPoint('BOTTOMRIGHT', view, 'BOTTOMRIGHT', 0, 0)
  self:UpdateMetricButton()
end

-- TimeMetric is the time the views show: adjusted for profiler overhead when the session
-- has a calibration and the box is ticked, raw otherwise.
---@return "time"|"adjusted"
function paneProto:TimeMetric()
  if self.adjust and self.overhead then
    return 'adjusted'
  end
  return 'time'
end

---@return "time"|"adjusted"|"alloc"
function paneProto:FlameMetric()
  if self.showAlloc then
    return 'alloc'
  end
  return self:TimeMetric()
end

function paneProto:UpdateAdjustCheck()
  if self.overhead then
    self.adjustCheck:Enable()
    self.adjustCheck:SetChecked(self.adjust)
  else
    self.adjustCheck:Disable()
    self.adjustCheck:SetChecked(false)
  end
end

-- ApplyMetric redraws every view after the overhead adjustment was switched on or off.
function paneProto:ApplyMetric()
  self.flame:SetMetric(self:FlameMetric())
  self.frameFlame:SetMetric(self:TimeMetric())
  self:UpdateMetricButton()
  self:UpdateAdjustCheck()
  self:FillFunctions()
  self:FillFrames()
  self:DrawTimeline()
end

function paneProto:UpdateMetricButton()
  if self.showAlloc then
    self.metricButton:SetText('Showing: Allocations')
  else
    self.metricButton:SetText('Showing: Time')
  end
  if self.tree and self.tree.hasAlloc then
    self.metricButton:Enable()
  else
    self.metricButton:Disable()
  end
end

---@param view Frame
function paneProto:CreateFunctionsView(view)
  local previous
  for _, column in ipairs(FUNCTION_COLUMNS) do
    local header = CreateFrame('Button', nil, view) --[[@as Button]]
    header:SetSize(column.width, 18)
    if previous then
      header:SetPoint('LEFT', previous, 'RIGHT', 0, 0)
    else
      header:SetPoint('TOPLEFT', view, 'TOPLEFT', 8, 0)
    end
    header.text = header:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
    header.text:SetAllPoints(header)
    header.text:SetJustifyH(column.justify)
    header.label = column.label
    header:SetScript('OnClick', function()
      self:SortFunctions(column.key)
    end)
    self.functionHeaders[column.key] = header
    previous = header
  end

  self.functionList = list:Create(view)
  self.functionList.frame:SetPoint('TOPLEFT', view, 'TOPLEFT', 0, -20)
  self.functionList.frame:SetPoint('BOTTOMRIGHT', view, 'BOTTOMRIGHT', 0, 0)
  self.functionList:SetupDataSource('BetterBagsPerfFunctionRow', function(button, fn)
    local hasAlloc = self.tree and self.tree.hasAlloc
    local adjusted = self:TimeMetric() == 'adjusted' and fn.adjIncl ~= nil
    button.Name:SetText(fn.name)
    button.Calls:SetText(perfFormat:Count(fn.calls))
    button.Total:SetText(perfFormat:Ms(adjusted and fn.adjIncl or fn.incl))
    button.Self:SetText(perfFormat:Ms(adjusted and fn.adjSelf or fn.self))
    button.Avg:SetText(perfFormat:Ms(adjusted and fn.adjAvg or fn.avg))
    button.Max:SetText(perfFormat:Ms(fn.max))
    button.Alloc:SetText(hasAlloc and perfFormat:KB(fn.alloc) or '-')
    local shade = (adjusted and fn.overheadShare > ROUGH_ESTIMATE_SHARE) and 0.5 or 1
    for _, key in ipairs({ 'Name', 'Calls', 'Total', 'Self', 'Avg', 'Max', 'Alloc' }) do
      button[key]:SetTextColor(shade, shade, shade)
    end
  end, function() end)
  self:UpdateFunctionHeaders()
end

function paneProto:UpdateFunctionHeaders()
  for key, header in pairs(self.functionHeaders) do
    local text = header.label
    if key == self.sortKey then
      text = text .. (self.sortDescending and ' v' or ' ^')
    end
    header.text:SetText(text)
  end
end

---@param key string
function paneProto:SortFunctions(key)
  if key == self.sortKey then
    self.sortDescending = not self.sortDescending
  else
    self.sortKey = key
    self.sortDescending = key ~= 'name'
  end
  self:UpdateFunctionHeaders()
  self:FillFunctions()
end

function paneProto:FillFunctions()
  local key, descending = self.sortKey, self.sortDescending
  if self:TimeMetric() == 'adjusted' and ADJUSTED_FIELD[key] then
    key = ADJUSTED_FIELD[key]
  end
  local sorted = {}
  for i, fn in ipairs(self.functions) do sorted[i] = fn end
  table.sort(sorted, function(a, b)
    local av, bv = a[key], b[key]
    if av ~= bv then
      if descending then return av > bv end
      return av < bv
    end
    return a.name < b.name
  end)
  self.functionList:Wipe()
  self.functionList:InsertTable(sorted)
end

---@param view Frame
function paneProto:CreateFramesView(view)
  self.timeline = CreateFrame('Frame', nil, view)
  self.timeline:SetPoint('TOPLEFT', view, 'TOPLEFT', 0, 0)
  self.timeline:SetPoint('TOPRIGHT', view, 'TOPRIGHT', 0, 0)
  self.timeline:SetHeight(TIMELINE_HEIGHT)
  local background = self.timeline:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints(self.timeline)
  background:SetColorTexture(0, 0, 0, 0.35)
  self.timelineThreshold = self.timeline:CreateTexture(nil, 'OVERLAY')
  self.timelineThreshold:SetHeight(1)
  self.timelineThreshold:SetColorTexture(1, 0.2, 0.2, 0.8)
  self.timelineCaption = self.timeline:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
  self.timelineCaption:SetPoint('TOPLEFT', self.timeline, 'TOPLEFT', 4, -2)
  self.timeline:SetScript('OnSizeChanged', function()
    self:DrawTimeline()
  end)

  self.frameList = list:Create(view)
  self.frameList.frame:SetPoint('TOPLEFT', self.timeline, 'BOTTOMLEFT', 0, -4)
  self.frameList.frame:SetPoint('TOPRIGHT', self.timeline, 'BOTTOMRIGHT', 0, -4)
  self.frameList.frame:SetHeight(100)
  self.frameList:SetupDataSource('BetterBagsPerfRow', initRow, function() end)

  self.frameFlame = flameGraph:Create(view)
  self.frameFlame.frame:SetPoint('TOPLEFT', self.frameList.frame, 'BOTTOMLEFT', 0, -4)
  self.frameFlame.frame:SetPoint('BOTTOMRIGHT', view, 'BOTTOMRIGHT', 0, 0)
end

---@param view Frame
function paneProto:CreateSummaryView(view)
  self.summaryText = view:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  self.summaryText:SetPoint('TOPLEFT', view, 'TOPLEFT', 4, -4)
  self.summaryText:SetPoint('BOTTOMRIGHT', view, 'BOTTOMRIGHT', -4, 4)
  self.summaryText:SetJustifyH('LEFT')
  self.summaryText:SetJustifyV('TOP')
  self.summaryText:SetWordWrap(true)
end

---@param name string
function paneProto:ShowView(name)
  self.currentView = name
  for viewName, view in pairs(self.views) do
    if viewName == name then
      view:Show()
      self.viewButtons[viewName]:LockHighlight()
    else
      view:Hide()
      self.viewButtons[viewName]:UnlockHighlight()
    end
  end
  if name == 'frames' then
    self:DrawTimeline()
  end
end

function paneProto:Show()
  self.frame:Show()
end

function paneProto:Hide()
  self.frame:Hide()
end

function paneProto:Update()
  self:UpdateControls()
  self:UpdateStatus()
  self:FillSessions()
  for _, session in ipairs(perfSessions:GetSessions()) do
    if session.id > self.newestSeen then self.newestSeen = session.id end
  end
end

function paneProto:UpdateControls()
  if perfSessions:IsCapturing() then
    self.startButton:SetText('Stop Capture')
  else
    self.startButton:SetText('Start Capture')
  end
  self.armCheck:SetChecked(perfSessions:IsArmedForNextReload())
end

function paneProto:UpdateStatus()
  local live = perf:GetLiveStats()
  if live then
    self.status:SetText(string.format('|cff00ff00Capturing|r  %s, %s, %s, worst frame %s',
      perfFormat:Ms(live.elapsedMs), plural(live.calls, 'call'), plural(live.frames, 'frame'),
      perfFormat:Ms(live.worstFrameMs)))
    return
  end
  local text = 'Idle, ' .. plural(#perfSessions:GetSessions(), 'saved session')
  if perfSessions:IsArmedForNextReload() then
    text = text .. ', capture armed for the next reload'
  end
  self.status:SetText(text)
end

function paneProto:FillSessions()
  local items = {}
  for _, session in ipairs(perfSessions:GetSessions()) do
    local meta = session.meta or {}
    local stats = session.stats or {}
    local id = session.id
    items[#items + 1] = {
      id = id,
      selected = id == self.selectedId,
      text = string.format('#%d  %s  %s%s', id, formatDate(meta.startedAt, '%m-%d %H:%M'),
        perfFormat:Ms(stats.durationMs or 0), meta.reason == 'reload' and '  (reload)' or ''),
      onClick = function()
        self:SelectSession(id)
      end,
    }
  end
  self.sessionList:Wipe()
  self.sessionList:InsertTable(items)
end

function paneProto:OnSessionsChanged()
  local sessions = perfSessions:GetSessions()
  local newest = sessions[1]
  if self.selectedId and not perfSessions:GetSession(self.selectedId) then
    self:ClearSelection()
  end
  self:FillSessions()
  self:UpdateStatus()
  if newest and newest.id > self.newestSeen then
    self.newestSeen = newest.id
    self:SelectSession(newest.id)
  end
end

function paneProto:ClearSelection()
  self.selectedId = nil
  self.selectedFrame = nil
  self.session = nil
  self.tree = nil
  self.overhead = nil
  self.functions = {}
  self.flame:SetTree(nil)
  self.frameFlame:SetTree(nil)
  self.functionList:Wipe()
  self.frameList:Wipe()
  self.summaryText:SetText('Select a saved session on the left, or start a capture.')
  self:UpdateMetricButton()
  self:UpdateAdjustCheck()
  self:DrawTimeline()
end

---@param id number
function paneProto:SelectSession(id)
  local session = perfSessions:GetSession(id)
  if not session then
    self:ClearSelection()
    self:FillSessions()
    return
  end
  self.selectedId = id
  self.session = session
  self.tree = perfFormat:Decode(session)
  self.overhead = perfFormat:Overhead(session)
  if self.overhead then
    perfFormat:Adjust(self.tree, self.overhead)
  end
  self.functions = perfFormat:DecodeFunctions(session, self.tree)
  self.showAlloc = false
  self.flame.metric = self:FlameMetric()
  self.flame:SetTree(self.tree)
  self:UpdateMetricButton()
  self:UpdateAdjustCheck()
  self:FillFunctions()
  self.selectedFrame = nil
  self:FillFrames()
  if session.worst and #session.worst > 0 then
    self:SelectFrame(1)
  else
    self.frameFlame:SetTree(nil)
  end
  self.summaryText:SetText(self:BuildSummary(session))
  self:DrawTimeline()
  self:FillSessions()
end

-- FrameTree decodes one worst frame, adjusted for profiler overhead when the session has a
-- calibration.
---@param index number
---@return PerfFrame
function paneProto:FrameTree(index)
  local frame = perfFormat:DecodeFrame(self.session, index)
  if self.overhead then
    perfFormat:Adjust(frame.tree, self.overhead)
  end
  return frame
end

function paneProto:FillFrames()
  local items = {}
  for i, entry in ipairs(self.session and self.session.worst or {}) do
    local ms = entry.us / 1000
    if self:TimeMetric() == 'adjusted' then
      local root = self:FrameTree(i).tree.root
      ms = ms - (root.total - root.adjTotal)
    end
    local text = string.format('#%d  %s', i, perfFormat:Ms(ms))
    if entry.blizzardUs then
      text = text .. string.format('  (Blizzard %s)', perfFormat:Ms(entry.blizzardUs / 1000))
    end
    text = text .. string.format('  at %s', perfFormat:Ms(entry.atUs / 1000))
    items[i] = {
      index = i,
      selected = i == self.selectedFrame,
      text = text,
      onClick = function()
        self:SelectFrame(i)
      end,
    }
  end
  self.frameList:Wipe()
  self.frameList:InsertTable(items)
end

---@param index number
function paneProto:SelectFrame(index)
  if not self.session or not self.session.worst[index] then return end
  self.selectedFrame = index
  self.frameFlame.metric = self:TimeMetric()
  self.frameFlame:SetTree(self:FrameTree(index).tree)
  self:FillFrames()
end

function paneProto:AcquireTimelineBar(bars, index, layer)
  local bar = bars[index]
  if not bar then
    bar = self.timeline:CreateTexture(nil, layer)
    bars[index] = bar
  end
  return bar
end

function paneProto:DrawTimeline()
  local ours, blizzard = {}, nil
  if self.session then
    local timeline = perfFormat:DecodeTimeline(self.session)
    ours, blizzard = timeline.ours, timeline.blizzard
    if self:TimeMetric() == 'adjusted' then
      ours = perfFormat:AdjustTimeline(timeline, self.overhead) or ours
    end
  end
  local width, height = self.timeline:GetWidth(), self.timeline:GetHeight()
  local frames = #ours
  local drawn = 0
  if frames > 0 and width > 0 and height > 0 then
    local threshold = (self.session.options and self.session.options.spikeThresholdMs) or 16
    local columns = math.min(TIMELINE_COLUMNS, frames)
    local perColumn = frames / columns
    local scale = threshold * 2
    for i = 1, frames do
      if ours[i] > scale then scale = ours[i] end
      if blizzard and blizzard[i] and blizzard[i] > scale then scale = blizzard[i] end
    end
    local columnWidth = width / columns
    for c = 1, columns do
      local from = math.floor((c - 1) * perColumn) + 1
      local to = math.max(from, math.floor(c * perColumn))
      local oursMax, blizzardMax = 0, 0
      for i = from, to do
        if ours[i] > oursMax then oursMax = ours[i] end
        if blizzard and blizzard[i] and blizzard[i] > blizzardMax then blizzardMax = blizzard[i] end
      end
      local x = (c - 1) * columnWidth
      local w = math.max(1, columnWidth - 1)
      local bar = self:AcquireTimelineBar(self.timelineBars, c, 'ARTWORK')
      if oursMax > 0 then
        bar:ClearAllPoints()
        bar:SetPoint('BOTTOMLEFT', self.timeline, 'BOTTOMLEFT', x, 0)
        bar:SetSize(w, math.max(1, oursMax / scale * height))
        if oursMax >= threshold then
          bar:SetColorTexture(1, 0.25, 0.2, 1)
        else
          bar:SetColorTexture(0.95, 0.6, 0.2, 1)
        end
        bar:Show()
        drawn = c
      else
        bar:Hide()
      end
      local blizzardBar = self:AcquireTimelineBar(self.timelineBlizzardBars, c, 'BORDER')
      if blizzardMax > 0 then
        blizzardBar:ClearAllPoints()
        blizzardBar:SetPoint('BOTTOMLEFT', self.timeline, 'BOTTOMLEFT', x, 0)
        blizzardBar:SetSize(w, math.max(1, blizzardMax / scale * height))
        blizzardBar:SetColorTexture(0.55, 0.55, 0.6, 0.6)
        blizzardBar:Show()
      else
        blizzardBar:Hide()
      end
    end
    self.timelineThreshold:ClearAllPoints()
    self.timelineThreshold:SetPoint('BOTTOMLEFT', self.timeline, 'BOTTOMLEFT', 0, threshold / scale * height)
    self.timelineThreshold:SetPoint('BOTTOMRIGHT', self.timeline, 'BOTTOMRIGHT', 0, threshold / scale * height)
    self.timelineThreshold:Show()
    self.timelineCaption:SetText(string.format('%s, tallest %s; red line = spike threshold %s; grey = Blizzard addon profiler',
      plural(frames, 'frame'), perfFormat:Ms(scale), perfFormat:Ms(threshold)))
  else
    self.timelineThreshold:Hide()
    self.timelineCaption:SetText(frames == 0 and 'No frame timeline recorded' or '')
  end
  for i = drawn + 1, #self.timelineBars do
    self.timelineBars[i]:Hide()
  end
  if drawn == 0 then
    for _, bar in ipairs(self.timelineBlizzardBars) do bar:Hide() end
  end
end

---@param session table
---@return string
function paneProto:BuildSummary(session)
  local meta, stats = session.meta or {}, session.stats or {}
  local lines = {}
  local function add(fmt, ...)
    lines[#lines + 1] = string.format(fmt, ...)
  end

  add('|cffffd100Session #%d|r, captured %s (%s)', session.id or 0,
    formatDate(meta.startedAt, '%Y-%m-%d %H:%M:%S'), meta.reason == 'reload' and 'from a reload' or 'manually')
  add('Character: %s - %s.  Client: %s %s (%s).  BetterBags %s.', meta.character or '?', meta.realm or '?',
    meta.flavor or '?', meta.gameVersion or '?', meta.gameBuild or '?', meta.addonVersion or '?')
  add('What was measured: %s.', (perfSessions.PRESETS[meta.preset or 'full'] or perfSessions.PRESETS.full).label)
  add('')
  local duration = stats.durationMs or 0
  local measured = stats.instrumentedMs or 0
  add('Duration: %s.  Frames: %s, with BetterBags code running in %s.', perfFormat:Ms(duration),
    perfFormat:Count(stats.frames or 0), perfFormat:Count(stats.activeFrames or 0))
  add('Measured BetterBags time: %s (%.1f%% of the capture).', perfFormat:Ms(measured),
    duration > 0 and measured / duration * 100 or 0)
  local overhead = perfFormat:Overhead(session)
  if overhead then
    local tree = session == self.session and self.tree or nil
    if not tree then
      tree = perfFormat:Decode(session)
      perfFormat:Adjust(tree, overhead)
    end
    local removed = tree.root.total - tree.root.adjTotal
    add('Profiler overhead per call%s: %.2f microseconds on the caller and %.2f on the function itself%s.',
      overhead.approximate and ' (estimated; this session predates the split calibration)' or '',
      overhead.parentMs * 1000, overhead.childMs * 1000,
      overhead.approximate and '' or ', measured when the capture started')
    add('About %s of the measured time was the profiler itself, so BetterBags ran for about %s without profiler overhead.',
      perfFormat:Ms(removed), perfFormat:Ms(tree.root.adjTotal))
  end

  local timeline = perfFormat:DecodeTimeline(session)
  if timeline.blizzard then
    local ours, theirs = 0, 0
    for i, v in ipairs(timeline.ours) do
      ours = ours + v
      theirs = theirs + (timeline.blizzard[i] or 0)
    end
    if theirs > 0 then
      add('The wrappers saw %.1f%% of the time Blizzard\'s addon profiler charged to BetterBags (%s of %s, both including the profiler\'s own cost). The rest ran in code that is not wrapped.',
        ours / theirs * 100, perfFormat:Ms(ours), perfFormat:Ms(theirs))
    end
  end
  add('Worst frame: %s.', perfFormat:Ms(stats.worstFrameMs or 0))

  local histogram = session.histogram
  if histogram then
    local parts = {}
    local bounds = histogram.bounds
    for i, count in ipairs(histogram.counts) do
      local label
      if i == 1 then
        label = string.format('<%d ms', bounds[1])
      elseif i > #bounds then
        label = string.format('%d+ ms', bounds[#bounds])
      else
        label = string.format('%d-%d ms', bounds[i - 1], bounds[i])
      end
      parts[#parts + 1] = string.format('%s: %s', label, perfFormat:Count(count))
    end
    add('Frames by BetterBags time: %s.', table.concat(parts, ', '))
  end
  add('')
  add('Calls: %s.  Functions wrapped: %s.  Call-tree nodes: %s%s.', perfFormat:Count(stats.calls or 0),
    perfFormat:Count(stats.wrappedFunctions or 0), perfFormat:Count(stats.nodeCount or 0),
    (stats.droppedNodes or 0) > 0 and string.format(' (limit reached %s times)', perfFormat:Count(stats.droppedNodes)) or '')
  if (stats.aborted or 0) > 0 then
    local parts = {}
    for i, entry in ipairs(perfFormat:DecodeAborted(session)) do
      if i > 5 then break end
      parts[#parts + 1] = string.format('%s (%s)', entry.name, perfFormat:Count(entry.count))
    end
    if #parts > 0 then
      add('Calls cut short by errors: %s, in %s.', perfFormat:Count(stats.aborted), table.concat(parts, ', '))
    else
      add('Calls cut short by errors: %s.', perfFormat:Count(stats.aborted))
    end
  end
  if session.options and session.options.trackAllocations then
    add('Allocated while measured: %s.  Collected by the garbage collector: %s.',
      perfFormat:KB(stats.allocatedKB or 0), perfFormat:KB(stats.gcFreedKB or 0))
  end

  if meta.blizzardStart and meta.blizzardStop then
    local parts = {}
    for _, metric in ipairs(BLIZZARD_METRICS) do
      local before, after = meta.blizzardStart[metric[1]], meta.blizzardStop[metric[1]]
      if before and after then
        if metric[3] then
          parts[#parts + 1] = string.format('%s %s -> %s', metric[2], perfFormat:Ms(before), perfFormat:Ms(after))
        else
          parts[#parts + 1] = string.format('%s %s -> %s', metric[2], perfFormat:Count(before), perfFormat:Count(after))
        end
      end
    end
    add('Blizzard addon profiler, start -> stop: %s.', table.concat(parts, '; '))
  end
  if meta.memoryStartKB and meta.memoryStopKB then
    add('Addon memory: %s -> %s.', perfFormat:KB(meta.memoryStartKB), perfFormat:KB(meta.memoryStopKB))
  end
  if meta.backpackItems or meta.bankItems then
    add('Items: %s in the backpack, %s in the bank.', perfFormat:Count(meta.backpackItems or 0), perfFormat:Count(meta.bankItems or 0))
  end
  return table.concat(lines, '\n')
end

function paneProto:OpenSettings()
  if not self.settingsForm then
    self.settingsForm = self:CreateSettings()
  end
  self.settingsForm:ReloadAllFormElements()
  self.settingsForm:Show()
end

---@return FormFrame
function paneProto:CreateSettings()
  local settings = function() return perfSessions:GetSettings() end
  local f = form:Create({
    title = 'Profiler Settings',
    layout = const.FORM_LAYOUT.STACKED,
    index = false,
    tabbed = false,
  })

  f:AddSection({
    title = 'Capture',
    description = 'What to measure and how much detail to keep. Changes apply to the next capture.',
  })
  local presetLabels = {}
  for _, key in ipairs(perfSessions.PRESET_ORDER) do
    presetLabels[#presetLabels + 1] = perfSessions.PRESETS[key].label
  end
  f:AddDropdown({
    title = 'What to measure',
    description = 'Everything wraps every module. The pipeline preset wraps only the code between a bag event and the finished draw.',
    items = presetLabels,
    getValue = function(_, value)
      return perfSessions.PRESETS[settings().preset].label == value
    end,
    setValue = function(_, value)
      for key, preset in pairs(perfSessions.PRESETS) do
        if preset.label == value then
          perfSessions:SetSetting('preset', key)
        end
      end
    end,
  })
  f:AddInputBox({
    title = 'Modules to skip',
    description = 'Comma-separated module or prototype names that are never measured, for example Database, Localization.',
    getValue = function() return settings().excludedModules end,
    setValue = function(_, value) perfSessions:SetSetting('excludedModules', value) end,
  })

  local function addSlider(title, description, key, step)
    local limits = perfSessions.LIMITS[key]
    f:AddSlider({
      title = title,
      description = description,
      min = limits[1],
      max = limits[2],
      step = step,
      getValue = function() return settings()[key] end,
      setValue = function(_, value) perfSessions:SetSetting(key, value) end,
    })
  end
  addSlider('Spike threshold (ms)', 'A frame where BetterBags takes at least this long counts as a spike and keeps its own call tree.', 'spikeThresholdMs', 1)
  addSlider('Worst frames kept', 'How many of the slowest frames keep their own call tree.', 'worstFrames', 1)
  addSlider('Auto-stop after (seconds)', 'Stop the capture on its own after this long. 0 never stops.', 'maxDurationSec', 5)

  f:AddSection({
    title = 'Storage',
    description = 'Sessions are saved to SavedVariables when the capture stops, and written to disk on logout or reload.',
  })
  addSlider('Saved sessions kept', 'The oldest sessions are deleted past this many.', 'maxSessions', 1)
  addSlider('Call-tree node limit', 'Distinct call paths kept per session. Paths past the limit are folded into one node.', 'maxNodes', 500)
  addSlider('Timeline length (frames)', 'How many frames of per-frame timings to keep. 18000 is five minutes at 60 FPS.', 'timelineFrames', 600)

  f:AddSection({
    title = 'Accuracy',
    description = 'Every wrapped call costs a little time; these options trade overhead for detail.',
  })
  local function addCheckbox(title, description, key)
    f:AddCheckbox({
      title = title,
      description = description,
      getValue = function() return settings()[key] end,
      setValue = function(_, value) perfSessions:SetSetting(key, value) end,
    })
  end
  addCheckbox('Track memory allocations', 'Charge Lua memory growth to the call that caused it. Garbage collection running mid-call makes the numbers approximate unless the next option is on.', 'trackAllocations')
  addCheckbox('Pause garbage collection while capturing', 'Makes allocation numbers exact. Memory keeps growing until the capture stops, so keep captures short.', 'pauseGC')
  addCheckbox('Measure profiler overhead', 'Time 1,000 empty wrapped calls at the start of each capture to estimate how much of the measured time is the profiler itself.', 'calibrate')

  f:GetFrame():SetSize(520, 600)
  f:GetFrame():SetPoint('CENTER')
  local name = f:GetFrame():GetName()
  if name then
    table.insert(UISpecialFrames, name)
  end
  return f
end
