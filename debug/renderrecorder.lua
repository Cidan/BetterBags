local addonName = ... ---@type string

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

---@class Events: AceModule
local events = addon:GetModule('Events')

---@class Context: AceModule
local context = addon:GetModule('Context')

-- RenderRecorder records how BetterBags' windows render, for debugging layout and sizing: while
-- it records, every render of a window that changed what the window shows adds a snapshot of the
-- window, from its frame down to its item buttons, and every step of a resize or a move adds the
-- window's geometry. Recordings are kept in the BetterBagsPerfDB SavedVariable
-- (renderRecordings), read offline. Started and stopped from the debug window's Performance tab.
---@class RenderRecorder: AceModule
---@field recording boolean
---@field db table
---@field current? table The recording in progress.
local recorder = addon:NewModule('RenderRecorder')

recorder.recording = false

-- How many recordings are kept, and how many entries one recording takes before it stops
-- adding more.
recorder.MAX_RECORDINGS = 5
recorder.MAX_ENTRIES = 20000

---@param n? number
---@return string
local function num(n)
  return string.format("%.1f", n or 0)
end

-- Init keeps the recordings in BetterBagsPerfDB (PerfSessions creates it first) and saves a
-- recording still running at logout.
function recorder:Init()
  local db = BetterBagsPerfDB
  if type(db) ~= 'table' then
    db = {}
    BetterBagsPerfDB = db
  end
  if type(db.renderRecordings) ~= 'table' then
    db.renderRecordings = {}
  end
  if type(db.nextRenderRecordingId) ~= 'number' then
    db.nextRenderRecordingId = 1
  end
  self.db = db
  self.recording = false
  self.current = nil
  events:RegisterEvent('PLAYER_LOGOUT', function()
    self:Stop()
  end)
end

---@return boolean
function recorder:IsRecording()
  return self.recording
end

-- Start begins a recording; it does nothing while one runs.
---@return boolean started
function recorder:Start()
  if self.recording then
    return false
  end
  local gameVersion, gameBuild = GetBuildInfo()
  self.current = {
    id = self.db.nextRenderRecordingId,
    startedAt = time(),
    character = UnitName('player'),
    realm = GetRealmName(),
    gameVersion = gameVersion,
    gameBuild = gameBuild,
    entries = {},
  }
  self.db.nextRenderRecordingId = self.db.nextRenderRecordingId + 1
  self.started = debugprofilestop()
  self.last = {}
  self.recording = true
  events:SendMessage(context:New('RenderRecorder_Start'), 'renderRecorder/StateChanged', true)
  return true
end

-- Stop ends the recording and keeps it, the newest last, dropping the oldest past MAX_RECORDINGS.
---@return table? recording
function recorder:Stop()
  if not self.recording then
    return nil
  end
  self.recording = false
  local recording = self.current
  self.current = nil
  self.last = nil
  recording.stoppedAt = time()
  local list = self.db.renderRecordings
  table.insert(list, recording)
  while #list > self.MAX_RECORDINGS do
    table.remove(list, 1)
  end
  events:SendMessage(context:New('RenderRecorder_Stop'), 'renderRecorder/StateChanged', false)
  return recording
end

---@return number
function recorder:GetEntryCount()
  return self.current and #self.current.entries or 0
end

---@return table[]
function recorder:GetRecordings()
  return self.db and self.db.renderRecordings or {}
end

---@private
---@param entry table
function recorder:add(entry)
  local entries = self.current.entries
  if #entries >= self.MAX_ENTRIES then
    self.current.full = true
    return
  end
  entry.t = string.format("%.1f", debugprofilestop() - self.started)
  table.insert(entries, entry)
end

---@param frame Frame
---@param origin Frame
---@return string
local function rectIn(frame, origin)
  local left, top = frame:GetLeft(), frame:GetTop()
  local originLeft, originTop = origin:GetLeft(), origin:GetTop()
  local x = (left or 0) - (originLeft or 0)
  local y = (originTop or 0) - (top or 0)
  return string.format("@%s,%s %sx%s", num(x), num(y), num(frame:GetWidth()), num(frame:GetHeight()))
end

---@param window BetterBagsWindow
---@return Bag?
local function bagOf(window)
  for _, bag in pairs(addon.Bags or {}) do
    if type(bag) == "table" and bag.window == window then
      return bag
    end
  end
  return nil
end

---@param section Section
---@return string
local function titleOf(section)
  local title = section.title
  if title ~= nil and title.GetText ~= nil then
    return tostring(title:GetText())
  end
  return "?"
end

-- describeSections adds a line for each section (sorted by title) and each of its items.
---@param lines string[]
---@param label string
---@param sections table<any, Section>
---@param origin Frame
local function describeSections(lines, label, sections, origin)
  local sorted = {}
  for _, section in pairs(sections or {}) do
    table.insert(sorted, section)
  end
  table.sort(sorted, function(a, b) return titleOf(a) < titleOf(b) end)
  for _, section in ipairs(sorted) do
    local frame = section.frame
    local cells = section.content and section.content.cells or {}
    table.insert(lines, string.format("%s section %s ipr=%s cells=%d shown=%s %s", label, titleOf(section),
      tostring(section.maxItemsPerRow), #cells, tostring(frame:IsShown()), rectIn(frame, origin)))
    for _, cell in ipairs(cells) do
      if cell.isGap then
        table.insert(lines, "  gap")
      elseif cell.frame ~= nil then
        table.insert(lines, string.format("  item %s %s", tostring(cell.slotkey), rectIn(cell.frame, origin)))
      end
    end
  end
end

-- Snapshot describes what a window shows, one line per part: the window (Geometry), its
-- content box, and for a bag its scroll area, canvas, layout, sections and item buttons.
-- Positions are relative to the window's top left.
---@param window BetterBagsWindow
---@return string[]
function recorder:Snapshot(window)
  local frame = window.frame
  local insets = window:GetContentInsets()
  local lines = {
    string.format("window %s mode=%s sizing=%s | %s", tostring(frame:GetName()), window:GetSizeMode(),
      tostring(window.sizing == true), window:Geometry("record")),
    string.format("content insets %s,%s,%s,%s %s", num(insets.Left), num(insets.Right), num(insets.Top),
      num(insets.Bottom), rectIn(window.content, frame)),
  }
  local bag = bagOf(window)
  if bag == nil then
    return lines
  end
  local scroll = bag.scroll
  if scroll ~= nil then
    table.insert(lines, string.format("scroll %s child %s bar=%s", rectIn(scroll.frame, frame),
      num(scroll.scrollChild:GetHeight()), tostring(scroll.scrollBar:IsShown())))
  end
  local canvas = bag.canvas
  if canvas ~= nil then
    local width = window:GetSizeMode() == "window" and canvas.frame:GetWidth() or nil
    local layout = canvas:GetLayout(width)
    table.insert(lines, string.format("canvas %s layout ipr=%s columns=%s header=%s tab=%s footer=%s",
      rectIn(canvas.frame, frame), tostring(layout.itemsPerRow), tostring(layout.columns),
      num(canvas.headerContainer:GetHeight()), num(canvas.tabContainer:GetHeight()), num(canvas.footerContainer:GetHeight())))
  end
  describeSections(lines, "global", bag.globalSections, frame)
  if bag.currentView ~= nil then
    describeSections(lines, "view", bag.currentView.sections, frame)
  end
  return lines
end

-- WindowRendered adds a snapshot of the window when what it shows changed since its last.
---@param window BetterBagsWindow
function recorder:WindowRendered(window)
  if not self.recording then
    return
  end
  local lines = self:Snapshot(window)
  local key = table.concat(lines, "\n")
  if self.last[window] == key then
    return
  end
  self.last[window] = key
  self:add({ kind = "render", window = tostring(window.frame:GetName()), lines = lines })
end

-- WindowStep adds a step of a resize or a move, with the window's geometry.
---@param window BetterBagsWindow
---@param step string
function recorder:WindowStep(window, step)
  if not self.recording then
    return
  end
  self:add({ kind = "step", window = tostring(window.frame:GetName()), step = step, geometry = window:Geometry(step) })
end
